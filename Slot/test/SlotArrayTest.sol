// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Slot/SlotArray.sol";
contract SlotArrayTest is Test {
    esRNT public esrnt;
    uint256 public locksSlot;

    function setUp() public {
        vm.warp(1690000000);
        esrnt = new esRNT();
        locksSlot = 0;
    }

    function testReadLocks() public {

        uint256 baseSlot = uint256(keccak256(abi.encode(locksSlot)));

        uint256 locksLength = uint256(vm.load(address(esrnt), bytes32(locksSlot)));

        emit log_named_uint("Total Locks", locksLength);

        for (uint256 i =0;i<locksLength;i++){
            uint256 userSolt = baseSlot + i *2;
            uint256 soltAmount = userSolt +1;

            bytes32 dataUser = vm.load(address(esrnt), bytes32(userSolt));
            bytes32 dataAmount = vm.load(address(esrnt), bytes32(soltAmount));

            uint256 dataUserUint = uint256(dataUser);

            address user = address(uint160(dataUserUint));
            uint64 startTime = uint64((dataUserUint >> 160));
            
            uint256 amount = uint256(dataAmount);

            emit log_named_uint("Index", i);
            emit log_named_address("User", user);
            emit log_named_uint("StartTime", uint256(startTime));
            emit log_named_uint("Amount", amount);
        }
        
    }
}