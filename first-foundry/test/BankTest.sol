// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Bank.sol";

contract BankTest is Test {
    Bank public bank;

    event Deposit(address indexed user, uint256 amount);
    function setUp() public{
        bank = new Bank();
    }

    function testDepositETH() public {
        address user1 = address(1);
        vm.deal(user1, 1 ether);

        vm.expectEmit(true, true, false, true);
        emit Deposit(user1, 0.5 ether);

        vm.prank(user1);
        bank.depositETH{value: 0.5 ether}();

        uint256 balance = bank.balanceOf(user1);
        assertEq(balance, 0.5 ether);
    }

    function testDepositZeroETH() public {
        
        address user = address(2);
        vm.deal(user, 1 ether);


        vm.prank(user);
        vm.expectRevert("Deposit amount must be greater than 0");
        bank.depositETH{value: 0}();
    }
} 