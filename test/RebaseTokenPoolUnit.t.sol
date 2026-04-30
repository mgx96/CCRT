//SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {Pool} from "../lib/chainlink-local/lib/chainlink-ccip/chains/evm/contracts/libraries/Pool.sol";
import {IERC20} from "@openzeppelin/contracts@4.8.3/token/ERC20/IERC20.sol";

contract RebaseTokenPoolUnitTest is Test {
    RebaseToken token;
    RebaseTokenPool pool;
    address mockRouter = makeAddr("mockRouter");
    address mockRmn = makeAddr("mockRMN");
    address mockOffRamp = makeAddr("mockOffRamp");
    address receiver = makeAddr("receiver");

    function setUp() public {
        token = new RebaseToken();
        pool = new RebaseTokenPool(IERC20(address(token)), new address[](0), mockRmn, mockRouter);
        token.grantMintAndBurnRole(address(pool));
    }

    function testReleaseOrMintDirect() public {
        // Test calling releaseOrMint directly as if we were an offRamp
        uint256 amount = 1e5;

        // Create the function call data
        Pool.ReleaseOrMintInV1 memory releaseOrMintIn = Pool.ReleaseOrMintInV1({
            originalSender: bytes(""),
            receiver: receiver,
            sourceDenominatedAmount: amount,
            localToken: address(token),
            remoteChainSelector: 1,
            sourcePoolAddress: abi.encode(makeAddr("remotePool")),
            sourcePoolData: abi.encode(uint8(18), uint256(5e10)),
            offchainTokenData: ""
        });

        vm.prank(mockOffRamp);
        // This should fail with the authorization error
        try pool.releaseOrMint(releaseOrMintIn) {
            console.log("No error - call succeeded");
        } catch Error(string memory reason) {
            console.log("Error:", reason);
        } catch Panic(uint256 errorCode) {
            console.log("Panic:", errorCode);
        } catch (bytes memory data) {
            console.log("Custom error bytes:");
            console.logBytes(data);
        }
    }
}
