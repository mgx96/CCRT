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


    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        if (_newInterestRate > s_interestRate) {
            revert RebaseToken__InvalidInterestRate();
        }
        s_interestRate = _newInterestRate;
        emit InterestRateUpdated(_newInterestRate);
    }
}
