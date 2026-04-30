//SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {Client} from "../lib/chainlink-local/lib/chainlink-ccip/chains/evm/contracts/libraries/Client.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {CCIPLocalSimulatorFork, Register} from "../lib/chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IERC20} from "@openzeppelin/contracts@4.8.3/token/ERC20/IERC20.sol";
import {TokenPool} from "../lib/chainlink-local/lib/chainlink-ccip/chains/evm/contracts/pools/TokenPool.sol";
import {RateLimiter} from "../lib/chainlink-local/lib/chainlink-ccip/chains/evm/contracts/libraries/RateLimiter.sol";
import {
    IRouterClient
} from "../lib/chainlink-local/lib/chainlink-ccip/chains/evm/contracts/interfaces/IRouterClient.sol";
import {
    RegistryModuleOwnerCustom
} from "../lib/chainlink-local/lib/chainlink-ccip/chains/evm/contracts/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {
    TokenAdminRegistry
} from "../lib/chainlink-local/lib/chainlink-ccip/chains/evm/contracts/tokenAdminRegistry/TokenAdminRegistry.sol";

interface IRouterCheck {
    function getOnRamp(uint64 destChainSelector) external view returns (address);
}

contract CrossChainTest is Test {
    RebaseToken sepoliaToken;
    RebaseToken arbSepoliaToken;

    CCIPLocalSimulatorFork ccipLocalSimulatorFork;

    uint256 sepoliaFork;
    uint256 arbSepoliaFork;
    uint256 constant SEND_VALUE = 1e5;
    address owner = makeAddr("owner");
    address user = makeAddr("user");

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
        sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        vm.startPrank(owner);
        sepoliaToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(sepoliaToken)));
        sepoliaPool = new RebaseTokenPool(
            IERC20(address(sepoliaToken)),
            new address[](0),
            sepoliaNetworkDetails.rmnProxyAddress,
            sepoliaNetworkDetails.routerAddress
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
        arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        vm.startPrank(owner);
        arbSepoliaToken = new RebaseToken();
        arbSepoliaPool = new RebaseTokenPool(
            IERC20(address(arbSepoliaToken)),
            new address[](0),
            arbSepoliaNetworkDetails.rmnProxyAddress,
            arbSepoliaNetworkDetails.routerAddress
        );
        arbSepoliaToken.grantMintAndBurnRole(address(arbSepoliaPool));
        RegistryModuleOwnerCustom(arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress)
            .registerAdminViaOwner(address(arbSepoliaToken));
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(arbSepoliaToken));
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress)
            .setPool(address(arbSepoliaToken), address(arbSepoliaPool));
        vm.stopPrank();
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
    }

    function configureTokenPool(
        uint256 fork,
        address localPool,
        uint64 _remoteChainSelector,
        address remotePool,
        address _remoteTokenAddress
    ) public {
        vm.selectFork(fork);
        bytes[] memory _remotePoolAddresses = new bytes[](1);
        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        _remotePoolAddresses[0] = abi.encode(remotePool);
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: _remoteChainSelector,
            remotePoolAddresses: _remotePoolAddresses,
            remoteTokenAddress: abi.encode(_remoteTokenAddress),
            outboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0}),
            inboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0})
        });

        vm.prank(owner);
        TokenPool(localPool).applyChainUpdates(new uint64[](0), chainsToAdd);
    }

    function bridgeTokens(
        uint256 amountToBridge,
        uint256 localFork,
        uint256 remoteFork,
        Register.NetworkDetails memory localNetworkDetails,
        Register.NetworkDetails memory remoteNetworkDetails,
        RebaseToken localToken,
        RebaseToken remoteToken
    ) public {
        vm.selectFork(localFork);
        address onRamp = IRouterCheck(localNetworkDetails.routerAddress).getOnRamp(remoteNetworkDetails.chainSelector);
        console.log("onRamp:", onRamp);
        Client.EVMTokenAmount[] memory _tokenAmounts = new Client.EVMTokenAmount[](1);
        _tokenAmounts[0] = Client.EVMTokenAmount({token: address(localToken), amount: amountToBridge});
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(user),
            data: "",
            tokenAmounts: _tokenAmounts,
            feeToken: localNetworkDetails.linkAddress,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 100_000}))
        });
        uint256 fee =
            IRouterClient(localNetworkDetails.routerAddress).getFee(remoteNetworkDetails.chainSelector, message);
        ccipLocalSimulatorFork.requestLinkFromFaucet(user, fee);
        vm.prank(user);
        IERC20(localNetworkDetails.linkAddress).approve(localNetworkDetails.routerAddress, fee);
        vm.prank(user);
        //casting localToken to an address because I'm using two different IERC20 versions, one from an older OpenZeppelin contracts and one from a newer version.
        IERC20(address(localToken)).approve(localNetworkDetails.routerAddress, amountToBridge);
        uint256 localBalanceBefore = localToken.balanceOf(user);
        vm.prank(user);
        IRouterClient(localNetworkDetails.routerAddress).ccipSend(remoteNetworkDetails.chainSelector, message);
        uint256 localBalanceAfter = localToken.balanceOf(user);
        assertEq(localBalanceAfter, localBalanceBefore - amountToBridge);
        uint256 localUserInterestRate = localToken.getUserInterestRate(user);

        vm.selectFork(remoteFork);
        uint256 remoteBalanceBefore = remoteToken.balanceOf(user);

        vm.selectFork(localFork);
        vm.warp(block.timestamp + 15 minutes);
        ccipLocalSimulatorFork.switchChainAndRouteMessage(remoteFork);

        uint256 remoteBalanceAfter = remoteToken.balanceOf(user);
        assertEq(remoteBalanceAfter, remoteBalanceBefore + amountToBridge);
        uint256 remoteUserInterestRate = remoteToken.getUserInterestRate(user);
        assertEq(localUserInterestRate, remoteUserInterestRate);
    }

    function testBridgeAllTokens() public {
        vm.selectFork(sepoliaFork);

        console.log("sepolia chainSelector:", sepoliaNetworkDetails.chainSelector);
        console.log("arbSepolia chainSelector:", arbSepoliaNetworkDetails.chainSelector);
        console.log("sepolia router:", sepoliaNetworkDetails.routerAddress);

        address router = sepoliaNetworkDetails.routerAddress;
        address onRamp = IRouterCheck(router).getOnRamp(arbSepoliaNetworkDetails.chainSelector);
        console.log("onRamp:", onRamp);

        vm.deal(user, SEND_VALUE);
        vm.prank(user);
        Vault(payable(address(vault))).deposit{value: SEND_VALUE}();
        assertEq(sepoliaToken.balanceOf(user), SEND_VALUE);
        bridgeTokens(
            SEND_VALUE,
            sepoliaFork,
            arbSepoliaFork,
            sepoliaNetworkDetails,
            arbSepoliaNetworkDetails,
            sepoliaToken,
            arbSepoliaToken
        );
    }
}
