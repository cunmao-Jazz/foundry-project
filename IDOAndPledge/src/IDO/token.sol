// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC20, Ownable(msg.sender) {
    constructor() ERC20("RNT", "RNT") {}

    // 仅拥有者（IDO合约）可以铸造代币
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}