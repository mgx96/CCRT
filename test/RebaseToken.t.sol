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
        vm.stopPrank();
    }

    function addRewardsToVault(uint256 rewardAmount) public {
        (bool success,) = payable(address(vault)).call{value: rewardAmount}("");
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

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);

        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        uint256 startBalance = rebaseToken.balanceOf(user);
        console.log("Start Balance: ", startBalance);
        assertEq(startBalance, amount);

        vault.redeem(type(uint256).max);
        uint256 endBalance = rebaseToken.balanceOf(user);
        console.log("End Balance: ", endBalance);
        assertEq(endBalance, 0);

        vm.stopPrank();
    }

    function testRedeemAfterTimePassed(uint256 depositAmount, uint256 time) public {
        depositAmount = bound(depositAmount, 1e5, type(uint96).max);
        time = bound(time, 1000, type(uint96).max);

        vm.deal(user, depositAmount);
        vm.prank(user);
        vault.deposit{value: depositAmount}();

        vm.warp(block.timestamp + time);
        uint256 balanceAfterSomeTime = rebaseToken.balanceOf(user);

        vm.deal(owner, balanceAfterSomeTime - depositAmount);
        vm.prank(owner);
        addRewardsToVault(balanceAfterSomeTime - depositAmount);
        console.log("Balance After Some Time: ", balanceAfterSomeTime);

        vm.prank(user);
        vault.redeem(type(uint256).max);

        uint256 ethBalance = address(user).balance;
        console.log("End Balance: ", ethBalance);
        assertEq(ethBalance, balanceAfterSomeTime);
        assertGt(ethBalance, depositAmount);
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);

        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        address user2 = makeAddr("user2");
        vm.prank(user);
        rebaseToken.transfer(user2, amountToSend);

        uint256 user2Balance = rebaseToken.balanceOf(user2);
        assertEq(user2Balance, amountToSend);
        assertEq(rebaseToken.balanceOf(user), amount - amountToSend);
    }

    function testTransferFrom(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);

        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        address user2 = makeAddr("user2");
        vm.prank(user);
        rebaseToken.approve(user2, amountToSend);

        vm.prank(user2);
        rebaseToken.transferFrom(user, user2, amountToSend);

        assertEq(rebaseToken.balanceOf(user2), amountToSend);
        assertEq(rebaseToken.balanceOf(user), amount - amountToSend);
    }

    function testSetInterestRate(uint256 newInterestRate) public {
        newInterestRate = bound(newInterestRate, 0, rebaseToken.getInterestRate() - 1);

        vm.prank(owner);
        rebaseToken.setInterestRate(newInterestRate);

        uint256 currentInterestRate = rebaseToken.getInterestRate();
        console.log("Current Interest Rate: ", currentInterestRate);
        assertEq(currentInterestRate, newInterestRate);
    }

    function testGetUserInterestRate(address userAddress) public {
        userAddress = makeAddr("userAddress");
        vm.deal(userAddress, 1e18);
        vm.prank(userAddress);
        vault.deposit{value: 1e18}();
        uint256 userInterestRate = rebaseToken.getUserInterestRate(userAddress);
        uint256 globalInterestRate = rebaseToken.getInterestRate();
        console.log("User Interest Rate: ", userInterestRate);
        console.log("Global Interest Rate: ", globalInterestRate);
        assertEq(userInterestRate, globalInterestRate);
    }

    function testCannotSetInterestRateIfNotOwner(uint256 newInterestRate) public {
        vm.prank(user);
        vm.expectRevert();
        rebaseToken.setInterestRate(newInterestRate);
    }

    function testCannotCallMintAndBurn() public {
        vm.prank(user);
        vm.expectRevert();
        rebaseToken.mint(user, 1e18);

        vm.prank(user);
        vm.expectRevert();
        rebaseToken.burn(user, 1e18);
    }
}
