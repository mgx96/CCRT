// Layout of Contract:
// license
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

//SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/*
* @title RebaseToken
* @author Malek Sharabi
* @notice This is going to be a cross-chain rebase token that incentivizes users to deposit into a vault.
* @notice The interest rate in the smart contract can only decrease.
* @notice Each users will have their own interest rates that is the global interest rate at the time of depositing.
*/

contract RebaseToken is ERC20, Ownable, AccessControl {
    error RebaseToken__NotOwner();
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 currentInterestRate, uint256 proposedInterestRate);

    uint256 private constant DECIMAL_PRECISION = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    uint256 private s_interestRate = 5e10;
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimeStamp;
    address private immutable s_owner;

    event InterestRateUpdated(uint256 newInterestRate);

    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {
        s_owner = msg.sender;
    }

    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    /**
     * @dev sets the interest rate for the rebase token. Only the owner of the protocol can call this function.
     * @param _newInterestRate The new interest rate to be set. It must be less than the current interest rate.
     * @notice only allow the interest rate to decrease but we don't want it to revert in case it's the destination chain that is updating the interest rate (in which case it will be either the same or larger so it won't update)
     */

    /**
     * @notice Set the interest rate in the contract.
     * @param _newInterestRate The new interest rate to be set.
     * @dev The interest rate can only decrease.
     */
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        if (_newInterestRate >= s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;
        emit InterestRateUpdated(_newInterestRate);
    }

    /**
     * @notice Mint the user tokens when they deposit into the vault.
     * @param _to The address of the user to mint the tokens to.
     * @param _amount The amount of tokens to be minted.
     * @dev When minting new tokens, we need to set the user's interest rate to the current global interest rate and set their last updated timestamp to the current block timestamp.
     */
    function mint(address _to, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_to);
        // we set the user's individual interest rate to the current global interest rate if they deposit later.
        // this is intended by design to prevent users from depositing small amounts to get a high interest rate.
        // we want to incentivize users to deposit as much as possible as early as possible.
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    /**
     * @notice Burn the user tokens when they withdraw from the vault.
     * @param _from The address of the user to burn the tokens from.
     * @param _amount The amount of tokens to be burned.
     */

    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    /**
     * @notice Get the balance of a user including the accrued interest since the last update.
     * @param _user The address of the user.
     * @return The balance of the user including the accrued interest since the last update.
     */
    function balanceOf(address _user) public view override returns (uint256) {
        // get the principle balance of the user -> balance from ERC20.
        // multiply the principle balance by the interest that has accumulated since the last time the balance was updated.
        return super.balanceOf(_user) * _calculateUserAccruedInterestSinceLastUpdate(_user) / DECIMAL_PRECISION;
    }

    /**
     * @notice Transfer tokens from the sender to the recipient. This function also mints the accrued interest for both the sender and the recipient before the transfer.
     * @param _recipient The address of the recipient.
     * @param _amount The amount of tokens to be transferred. If the amount is set to uint256 max, it will transfer the entire balance of the sender.
     * @return A boolean value indicating whether the operation succeeded.
     */

    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    }

    /**
     * @notice Transfer tokens from the sender to the recipient using the allowance mechanism. This function also mints the accrued interest for both the sender and the recipient before the transfer.
     * @param _sender The address of the sender.
     * @param _recipient The address of the recipient.
     * @param _amount The amount of tokens to be transferred. If the amount is set to uint256 max, it will transfer the entire balance of the sender.
     * @return A boolean value indicating whether the operation succeeded.
     */

    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[_sender];
        }
        return super.transferFrom(_sender, _recipient, _amount);
    }

    /**
     * @notice Calculate the accrued interest for a user since the last update.
     * @param _user The address of the user.
     * @return linearInterest accrued interest for the user since the last update.
     */

    function _calculateUserAccruedInterestSinceLastUpdate(address _user)
        internal
        view
        returns (uint256 linearInterest)
    {
        // we need to calculate the interest that has accumulated since the last update.
        // this is going to be linear growth over time.
        // 1. calculate the time since the last update.
        // 2. calculate the amount of linear growth.
        // principle balance + (prinicible balance * interest rate * time elapsed).
        // deposit: 100 tokens
        // interest rate 0.5 tokens per second.
        // time elapsed: 30 seconds.
        // 100 + (100 * 0.5 * 30)
        uint256 timeLapsed = block.timestamp - s_userLastUpdatedTimeStamp[_user];
        linearInterest = DECIMAL_PRECISION + (s_userInterestRate[_user] * timeLapsed);
    }

    /**
     * @notice Mint the accrued interest to the user.
     * @param _user The address of the user to mint the accrued interest to.
     * @dev This function should be called before any transfer or burn of the user's tokens to ensure that the user's balance is up to date with the accrued interest.
     */
    function _mintAccruedInterest(address _user) internal {
        // find the current balance of rebase tokens that have been minted to the user -> principle balance.
        uint256 principleBalance = super.balanceOf(_user);
        // calculate their current balance including any interest -> balanceOf.
        uint256 currentBalance = balanceOf(_user);
        // calculate the number of tokens that needs to be minted to the user.
        uint256 balanceIncrease = currentBalance - principleBalance;
        // set the user's last updated timestamp.
        s_userLastUpdatedTimeStamp[_user] = block.timestamp;
        // call the _mint function to mint the tokens to the user.
        _mint(_user, balanceIncrease);
    }

    /**
     * @notice Get the current global interest rate.
     * @return The current global interest rate.
     */

    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    /**
     * @notice Get the interest rate for a specific user.
     * @param _user The address of the user.
     * @return The interest rate for the user.
     */
    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }

    function getPrincipleAmount(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }
}
