// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Counter {
    uint256 public number;

    address public admin = 0x4F1C004eC6A03e8BEA6e019d07ae25C2630c8Fb9;

    function setNumber(uint256 newNumber) public {
        number = newNumber;
    }

    function increment() public {
        // require(msg.sender == admin, "only call by admin");
        if (msg.sender != admin) {
            revert OnlyCallByAdmin(msg.sender, admin);
        }
        number++;
    }

    function batchTransfer(address token, address[] memory recipients, uint256[] memory amounts) public {
        require(recipients.length == amounts.length, "recipients and amounts length mismatch");

        for (uint256 i = 0; i < recipients.length; i++) {
            IERC20(token).transferFrom(msg.sender, recipients[i], amounts[i]);
        }

        emit BatchTransfer(msg.sender, token, recipients, amounts);
    }

    error OnlyCallByAdmin(address caller, address admin);

    event BatchTransfer(address sender, address token, address[] recipients, uint256[] amounts);
}
