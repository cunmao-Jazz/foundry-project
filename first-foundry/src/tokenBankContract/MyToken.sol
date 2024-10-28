// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "first-foundry/lib/openzeppelin-contracts/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract MyToken is ERC20Permit {
    constructor() ERC20("Base", "B") ERC20Permit("Base") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
}