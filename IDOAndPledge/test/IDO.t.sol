// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import "../src/IDO/token.sol";
import "../src/IDO/IDO.sol";
contract IMintableTokenTest is Test {
    MyToken public token;
    IDOPresale public idoPersale;

    address public owner = address(0xABCD);
    address public user1 = address(2);
    address public user2 = address(3);
    address public user3 = address(4);

    event PresaleStarted(
        address indexed token,
        uint256 fundraisingGoal,
        uint256 fundraisingCap,
        uint256 minContribution,
        uint256 maxContribution,
        uint256 totalTokenSupply,
        uint256 startTime,
        uint256 endTime
    );
   
    function setUp() public {
        vm.startPrank(owner);

        token = new MyToken();

        idoPersale = new IDOPresale();

        token.transferOwnership(address(idoPersale));

        vm.stopPrank();

    }

    // Test pre-sale
    function testStartPresale() public {
        vm.startPrank(owner);

        vm.expectEmit(true, false, false, true);
        emit PresaleStarted(
            address(token),
            100 ether,
            150 ether,
            0.1 ether,
            1 ether,
            1_000_000 ether,
            block.timestamp,
            block.timestamp + 86400
        );

        // 启动预售
        idoPersale.startPresale(
            address(token),
            100 ether, // fundraisingGoal
            150 ether, // fundraisingCap
            0.1 ether, // minContribution
            1 ether, // maxContribution
            1_000_000 ether, // totalTokenSupply (假设代币有18位小数)
            86400 // duration: 1 day
        );

        IDOPresale.PresaleState state = idoPersale.getPresaleState();
        assertEq(uint(state), uint(IDOPresale.PresaleState.Active), "Presale should be active");

        assertEq(address(idoPersale.token()), address(token), "Token address mismatch");
        assertEq(idoPersale.fundraisingGoal(), 100 ether, "Fundraising goal mismatch");
        assertEq(idoPersale.fundraisingCap(), 150 ether, "Fundraising cap mismatch");
        assertEq(idoPersale.minContribution(), 0.1 ether, "Min contribution mismatch");
        assertEq(idoPersale.maxContribution(), 1 ether, "Max contribution mismatch");
        assertEq(idoPersale.totalTokenSupply(), 1_000_000 ether, "Total token supply mismatch");
        vm.stopPrank();
    }


    // Test Purchase token
    function testBuyTokens() public {
        vm.startPrank(owner);

        // 启动预售
        idoPersale.startPresale(
            address(token),
            100 ether, // fundraisingGoal
            150 ether, // fundraisingCap
            0.1 ether, // minContribution
            1 ether, // maxContribution
            1_000_000 ether, // totalTokenSupply
            86400 // duration: 1 day
        );

        vm.stopPrank();

        vm.deal(user1, 10 ether);
        vm.startPrank(user1);
        idoPersale.buyTokens{value: 0.5 ether}();
        vm.stopPrank();

        assertEq(idoPersale.contributions(user1), 0.5 ether, "User1 contribution mismatch");
        assertEq(idoPersale.totalRaised(), 0.5 ether, "Total raised mismatch");

        vm.deal(user2, 10 ether);
        vm.startPrank(user2);
        idoPersale.buyTokens{value: 1 ether}();
        vm.stopPrank();

        assertEq(idoPersale.contributions(user2), 1 ether, "User2 contribution mismatch");
        assertEq(idoPersale.totalRaised(), 1.5 ether, "Total raised mismatch");

        vm.deal(user3, 10 ether);
        vm.startPrank(user3);
        vm.expectRevert("Contribution below minimum limit");
        idoPersale.buyTokens{value: 0.05 ether}();
        vm.stopPrank();

        vm.startPrank(user3);
        vm.expectRevert("Contribution exceeds maximum limit");
        idoPersale.buyTokens{value: 1.5 ether}();
        vm.stopPrank();
    }

    // The user receives the token after successful test presale
    function testClaimTokens() public {
        vm.startPrank(owner);

        // 启动预售
        idoPersale.startPresale(
            address(token),
            10 ether, // fundraisingGoal
            150 ether, // fundraisingCap
            0.1 ether, // minContribution
            50 ether, // maxContribution
            1_000_000 ether, // totalTokenSupply
            86400 // duration: 1 day
        );

        vm.stopPrank();

        vm.deal(user1, 100 ether);
        vm.prank(user1);
        idoPersale.buyTokens{value: 5 ether}();

        vm.deal(user2, 100 ether);
        vm.prank(user2);

        idoPersale.buyTokens{value: 10 ether}();

        vm.warp(block.timestamp + 867000);

        vm.prank(user1);
        idoPersale.claimTokens();

        vm.startPrank(user2);
        idoPersale.claimTokens();

        // 检查代币余额
        uint256 user1Tokens = token.balanceOf(user1);
        uint256 user2Tokens = token.balanceOf(user2);
        console.log(user1Tokens);
        console.log(user2Tokens);

    }

    // Test presale failed users get their funds back
     function testClaimRefund() public {
        // 启动预售
        vm.startPrank(owner);
        idoPersale.startPresale(
            address(token),
            100 ether,        // fundraisingGoal
            150 ether,        // fundraisingCap
            0.1 ether,        // minContribution
            10 ether,         // maxContribution
            1_000_000 ether,  // totalTokenSupply
            86400             // duration: 1 day
        );
        vm.stopPrank();

        vm.deal(user1, 100 ether); 
        vm.startPrank(user1);
        idoPersale.buyTokens{value: 5 ether}();
        vm.stopPrank();

        vm.deal(user2, 100 ether); 
        vm.startPrank(user2);
        idoPersale.buyTokens{value: 10 ether}();
        vm.stopPrank();

        vm.warp(block.timestamp + 87000);

        vm.startPrank(user1);
        idoPersale.claimRefund();
        vm.stopPrank();

        vm.startPrank(user2);
        idoPersale.claimRefund();
        vm.stopPrank();

        assertEq(idoPersale.contributions(user1), 0, "User1 contribution should be reset");
        assertEq(idoPersale.contributions(user2), 0, "User2 contribution should be reset");

        uint256 user1Balance = user1.balance;
        uint256 user2Balance = user2.balance;
        assertEq(user1Balance, 100 ether, "User1 balance mismatch");
        assertEq(user2Balance, 100 ether, "User2 balance mismatch");
    }

    // The test project side draws funds
    function testWithdrawFunds() public {
        vm.startPrank(owner);
        idoPersale.startPresale(
            address(token),
            100 ether,        // fundraisingGoal
            150 ether,        // fundraisingCap
            0.1 ether,        // minContribution
            50 ether,         // maxContribution
            1_000_000 ether,  // totalTokenSupply
            86400             // duration: 1 day
        );
        vm.stopPrank();

        // 用户1购买50 ether
        vm.deal(user1, 100 ether); // 给 user1 一些 ETH
        vm.startPrank(user1);
        idoPersale.buyTokens{value: 50 ether}();
        vm.stopPrank();

        // 用户2购买50 ether
        vm.deal(user2, 100 ether); // 给 user2 一些 ETH
        vm.startPrank(user2);
        idoPersale.buyTokens{value: 50 ether}();
        vm.stopPrank();

        vm.warp(block.timestamp + 87000);

        vm.startPrank(owner);
        idoPersale.withdrawFunds();
        vm.stopPrank();

        assertEq(owner.balance, 100 ether, "Owner did not receive correct funds");

        vm.startPrank(owner);
        vm.expectRevert("Funds already withdrawn");
        idoPersale.withdrawFunds();
        vm.stopPrank();
    }

}