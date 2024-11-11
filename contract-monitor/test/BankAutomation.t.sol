// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Bank.sol";
import "../src/BankAutomation.sol";

contract BankAutomationTest is Test {
    Bank public bank;
    BankAutomation public automation;
    address public user = address(1);

    function setUp() public {
        bank = new Bank(10 ether);
        automation = new BankAutomation(address(bank));
    }

    function testUpkeepNotNeeded() public {
        vm.deal(user, 5 ether);
        vm.prank(user);
        bank.deposit{value: 5 ether}();

        (bool upkeepNeeded, ) = automation.checkUpkeep("");
        assertFalse(upkeepNeeded, "Upkeep should not be needed");
    }

    function testUpkeepNeeded() public {
        vm.deal(user, 15 ether);
        vm.prank(user);
        bank.deposit{value: 15 ether}();

        (bool upkeepNeeded, ) = automation.checkUpkeep("");
        assertTrue(upkeepNeeded, "Upkeep should be needed");
    }
}