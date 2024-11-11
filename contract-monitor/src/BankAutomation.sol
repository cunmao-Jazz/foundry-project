// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AutomationCompatibleInterface } from "chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

interface IBank {
    function withdraw() external;
    function total() external view returns (uint256);
}


contract BankAutomation is AutomationCompatibleInterface {
    IBank public bank;
    
    constructor(address _bankAddress){
        bank = IBank(_bankAddress);
    }

    function checkUpkeep(bytes calldata /* checkData */)
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        uint256 bankBalance = address(bank).balance;
        uint256 total = bank.total();
        upkeepNeeded = bankBalance > total;
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        uint256 bankBalance = address(bank).balance;
        uint256 total = bank.total();

        if (bankBalance > total) {
            bank.withdraw();
        }
    }
}
