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
    mapping(address => uint256) private s_userLastUpdatedTimeSamp;
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
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    function _calculateUserAccruedInterestSinceLastUpdate(address _user) internal view returns (uint256) {}

    /**
     * @notice Get the balance of a user including the accrued interest since the last update.
     * @param _user The address of the user.
     * @return The balance of the user including the accrued interest since the last update.
     */
    function balanceOf(address _user) public view override returns (uint256) {
        // get the principle balance of the user -> balance from ERC20.
        // multiply the principle balance by the interest that has accumulated since the last time the balance was updated.
        return super.balanceOf(_user) * _calculateUserAccruedInterestSinceLastUpdate(_user);
    }

    function _mintAccruedInterest(address _to) internal {
        // find the current balance of rebase tokens that have been minted to the user -> principle balance.
        // calculate their current balance including any interest -> balanceOf.
        // calculate the number of tokens that needs to be minted to the user.
        // call the _mint function to mint the tokens to the user.
        // set the user's last updated timestmp.
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
