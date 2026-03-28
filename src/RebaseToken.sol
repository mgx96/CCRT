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
* @notice This is going to be a cross-chain rebase tokens that incentivizes users to deposit into a vault.
* @notice The interest rate in the smart contract can only decrease.
* @notice Each user will have their own interest rates that is the global interest rate at the time of depositing.
*/

contract RebaseToken is ERC20 {
    error RebaseToken__NotOwner();
    error RebaseToken__InvalidInterestRate();

    uint256 private constant DECIMAL_PRECISION = 1e18;
    uint256 private s_interestRate = 5e10;
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
            revert RebaseToken__InvalidInterestRate();
        }
        s_interestRate = _newInterestRate;
        emit InterestRateUpdated(_newInterestRate);
    }

    function mint(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
    }
}
