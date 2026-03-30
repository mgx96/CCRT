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

/*
* @title RebaseToken
* @author Malek Sharabi
* @notice This is going to be a cross-chain rebase token that incentivizes users to deposit into a vault.
* @notice The interest rate in the smart contract can only decrease.
* @notice Each users will have their own interest rates that is the global interest rate at the time of depositing.
*/

contract RebaseToken is ERC20 {
    error RebaseToken__NotOwner();
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 currentInterestRate, uint256 proposedInterestRate);

    uint256 private constant DECIMAL_PRECISION = 1e18;
    uint256 private s_interestRate = 5e10;
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimeStamp;
    address private immutable s_owner;

    event InterestRateUpdated(uint256 newInterestRate);

    modifier onlyOwner() {
        if (msg.sender != s_owner) {
            revert RebaseToken__NotOwner();
        }
        _;
    }

    constructor() ERC20("Rebase Token", "RBT") {
        s_owner = msg.sender;
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
    function mint(address _to, uint256 _amount) external onlyOwner {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
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
     * @notice Get the interest rate for a specific user.
     * @param _user The address of the user.
     * @return The interest rate for the user.
     */
    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }
}
