//SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {CCIPLocalSimulatorFork, Register} from "../lib/chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IERC20} from "@openzeppelin/contracts@4.8.3/token/ERC20/IERC20.sol";
import {TokenPool} from "../lib/chainlink-local/lib/chainlink-ccip/chains/evm/contracts/pools/TokenPool.sol";
import {RateLimiter} from "../lib/chainlink-local/lib/chainlink-ccip/chains/evm/contracts/libraries/RateLimiter.sol";
import {
    RegistryModuleOwnerCustom
} from "../lib/chainlink-local/lib/chainlink-ccip/chains/evm/contracts/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {
    TokenAdminRegistry
} from "../lib/chainlink-local/lib/chainlink-ccip/chains/evm/contracts/tokenAdminRegistry/TokenAdminRegistry.sol";

contract CrossChainTest is Test {
    RebaseToken sepoliaToken;
    RebaseToken arbSepoliaToken;

    CCIPLocalSimulatorFork ccipLocalSimulatorFork;

    uint256 sepoliaFork;
    uint256 arbSepoliaFork;
    address owner = makeAddr("owner");

    Vault vault;

    RebaseTokenPool sepoliaPool;
    RebaseTokenPool arbSepoliaPool;

    Register.NetworkDetails sepoliaNetworkDetails;
    Register.NetworkDetails arbSepoliaNetworkDetails;

    function setUp() public {
        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();

        sepoliaFork = vm.createSelectFork("sepolia");
        arbSepoliaFork = vm.createFork("arb-sepolia");

        vm.makePersistent(address(ccipLocalSimulatorFork));

        // Deploy and configure on Sepolia
        sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(sepoliaFork);
        vm.startPrank(owner);
        sepoliaToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(sepoliaToken)));
        sepoliaPool = new RebaseTokenPool(
            IERC20(address(sepoliaToken)), sepoliaNetworkDetails.rmnProxyAddress, sepoliaNetworkDetails.routerAddress
        );
        sepoliaToken.grantMintAndBurnRole(address(vault));
        sepoliaToken.grantMintAndBurnRole(address(sepoliaPool));
        RegistryModuleOwnerCustom(sepoliaNetworkDetails.registryModuleOwnerCustomAddress)
            .registerAdminViaOwner(address(sepoliaToken));
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(sepoliaToken));
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress)
            .setPool(address(sepoliaToken), address(sepoliaPool));
        vm.stopPrank();

        // Deploy and configure on Arbitrum Sepolia
        vm.selectFork(arbSepoliaFork);
        arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(arbSepoliaFork);
        vm.startPrank(owner);
        arbSepoliaToken = new RebaseToken();
        arbSepoliaPool = new RebaseTokenPool(
            IERC20(address(arbSepoliaToken)),
            arbSepoliaNetworkDetails.rmnProxyAddress,
            arbSepoliaNetworkDetails.routerAddress
        );
        arbSepoliaToken.grantMintAndBurnRole(address(arbSepoliaPool));
        RegistryModuleOwnerCustom(arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress)
            .registerAdminViaOwner(address(arbSepoliaToken));
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(arbSepoliaToken));
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress)
            .setPool(address(arbSepoliaToken), address(arbSepoliaPool));
        configureTokenPool(
            sepoliaFork,
            address(sepoliaPool),
            arbSepoliaNetworkDetails.chainSelector,
            address(arbSepoliaPool),
            address(arbSepoliaToken)
        );
        configureTokenPool(
            arbSepoliaFork,
            address(arbSepoliaPool),
            sepoliaNetworkDetails.chainSelector,
            address(sepoliaPool),
            address(sepoliaToken)
        );
        vm.stopPrank();
    }

    function configureTokenPool(
        uint256 fork,
        address localPool,
        uint64 _remoteChainSelector,
        address remotePool,
        address _remoteTokenAddress
    ) public {
        vm.selectFork(fork);
        vm.prank(owner);
        bytes[] memory _remotePoolAddresses = new bytes[](1);
        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        TokenPool(localPool).applyChainUpdates(new uint64[](0), chainsToAdd);
        _remotePoolAddresses[0] = abi.encode(remotePool);
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: _remoteChainSelector,
            remotePoolAddresses: _remotePoolAddresses,
            remoteTokenAddress: abi.encode(_remoteTokenAddress),
            outboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0}),
            inboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0})
        });
    }
}
