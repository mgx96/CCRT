//SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {Vault} from "../src/Vault.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {CCIPLocalSimulatorFork, Register} from "../lib/chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IERC20} from "../lib/chainlink-local/src/vendor/openzeppelin-solidity/v5.0.2/contracts/interfaces/IERC20.sol";
import {RegisterModuleOwnerCustom} from "../lib/chainlink-local/lib/chainlink-ccip/chains/evm/contracts/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";

contract TokenAndPoolDeployer is Script {
    function run() public returns (RebaseToken token, RebaseTokenPool pool) {
        vm.startBroadcast();
        Register.NetworkDetails networkDetails = Register.getNetworkDetails(block.chainid);
        CCIPLocalSimulatorFork ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        token = new RebaseToken();
        pool = new RebaseTokenPool(IERC20(address(token)), new address[](0), networkDetails.rmnProxyAddress, networkDetails.routerAddress);
        token.grantMintAndBurnRole(address(pool));
        vm.stopBroadcast();
    }
}

contract VaultDeployer is Script {
    function run(address _rebaseToken) external returns (Vault vault) {
        vm.startBroadcast();
        vault = new Vault(IRebaseToken(_rebaseToken));
        IRebaseToken(_rebaseToken).grantMintAndBurnRole(address(vault));
        vm.stopBroadcast();
    }
}