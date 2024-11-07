// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract InscriptionToken is ERC20 {
    uint256 public totalSupplyCap;
    uint256 public perMint;
    uint256 public totalMinted;
    address public factory;

    constructor(
        string memory name_,
        string memory sysbol_,
        uint256 totalSupply_,
        uint256 perMint_,
        address factory_
    ) ERC20(name_,sysbol_){
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