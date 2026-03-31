//SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        (bool success,) = payable(address(vault)).call{value: 1e18}("");
        vm.stopPrank();
    }

    function testInterestRateIsLinear(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);

        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        uint256 startBalance = rebaseToken.balanceOf(user);
        console.log("Start Balance: ", startBalance);
        assertEq(startBalance, amount);

        vm.warp(block.timestamp + 30 days);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        console.log("Middle Balance: ", middleBalance);
        assertGt(middleBalance, startBalance);

        vm.warp(block.timestamp + 30 days);
        uint256 endBalance = rebaseToken.balanceOf(user);
        console.log("End Balance: ", endBalance);
        assertGt(endBalance, middleBalance);

        uint256 middleBalanceIncrease = middleBalance - startBalance;
        uint256 endBalanceIncrease = endBalance - middleBalance;
        console.log("Middle Balance Increase: ", middleBalanceIncrease);
        console.log("End Balance Increase: ", endBalanceIncrease);
        assertApproxEqAbs(middleBalanceIncrease, endBalanceIncrease, 1 wei);

        vm.stopPrank();
    }
}
