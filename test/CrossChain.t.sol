//SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {CCIPLocalSimulatorFork} from "../lib/chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";

contract CrossChainTest is Test {
    RebaseToken private rebaseToken;
    CCIPLocalSimulatorFork private ccipLocalSimulatorFork;
    uint256 private sepoliaFork;
    uint256 private arbSepoliaFork;

    function setUp() public {
        rebaseToken = new RebaseToken();
        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();

        sepoliaFork = vm.createSelectFork("sepolia");
        arbSepoliaFork = vm.createtFork("arb-sepolia");

        vm.makePersistent(address(ccipLocalSimulatorFork));
    }
}
