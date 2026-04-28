//SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {CCIPLocalSimulatorFork} from "../lib/chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";

contract CrossChainTest is Test {
    RebaseToken sepoliaToken;
    RebaseToken arbSepoliaToken;

    CCIPLocalSimulatorFork ccipLocalSimulatorFork;

    uint256 sepoliaFork;
    uint256 arbSepoliaFork;
    address owner = makeAddr("owner");

    Vault vault;

    function setUp() public {
        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();

        sepoliaFork = vm.createSelectFork("sepolia");
        arbSepoliaFork = vm.createtFork("arb-sepolia");

        vm.makePersistent(address(ccipLocalSimulatorFork));

        // Deploy and configure on Sepolia
        vm.startPrank(owner);
        sepoliaToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(sepoliaToken)));
        vm.stopPrank();

        // Deploy and configure on Arbitrum Sepolia
        vm.selectFork(arbSepoliaFork);
        vm.startPrank(owner);
        arbSepoliaToken = new RebaseToken();
        vm.stopPrank();
    }
}
