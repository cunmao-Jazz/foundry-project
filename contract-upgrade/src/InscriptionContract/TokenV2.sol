// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
contract InscriptionTokenV2 is Initializable,ERC20Upgradeable {
    uint256 public totalSupplyCap;
    uint256 public perMint;
    uint256 public totalMinted;
    address public factory;

    function initialize(
        string memory name_,
        string memory symbol_,
        uint256 totalSupply_,
        uint256 perMint_,
        address factory_
    ) external initializer {
        __ERC20_init(name_, symbol_);
        totalSupplyCap = totalSupply_;
        perMint = perMint_;
        factory = factory_;
    }

    function mint(address to) external {
        require(msg.sender == factory, "Only factory can mint");
        require(perMint + totalMinted <= totalSupplyCap,"Exceeds total supply cap" );

        totalMinted+=perMint;
        _mint(to, perMint);

    }
}