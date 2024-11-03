// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * @dev MockToken 合约，具备铸造和燃烧功能。
 * 去除了 Ownable，mint 和 burn 函数对所有人开放。
 */
contract MockToken is ERC20Burnable {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    /**
     * @dev 铸造新代币，任何人都可以调用。
     * @param to 接收代币的地址。
     * @param amount 铸造的代币数量。
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}