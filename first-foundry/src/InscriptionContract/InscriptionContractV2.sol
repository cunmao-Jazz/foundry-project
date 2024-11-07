// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/proxy/utils/Initializable.sol";

contract InscriptionToken is ERC20 {
    uint256 public totalSupplyCap;
    uint256 public perMint;
    uint256 public totalMinted;
    address public factory;

    bool private initialized;

    function initialize(
        string memory name_,
        string memory sysbol_,
        uint256 totalSupply_,
        uint256 perMint_,
        address factory_
    ) external {
        require(!initialized,"Already initialized");
        initialized = true;
        _name = name_;
        _symbol = symbol_;
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

contract FactoryContract{
     event InscriptionDeployed(address tokenAddress);
    
    function deployInscription(string memory symbol, uint256 totalSupply, uint256 perMint) public returns(address) {
            InscriptionToken token = new InscriptionToken (
                symbol,
                symbol,
                totalSupply,
                perMint,
                address(this)
            );

            emit InscriptionDeployed(address(token));
            return address(token);
    }

    function mintInscription(address tokenAddr) public {
        InscriptionToken token = InscriptionToken(tokenAddr);
        token.mint(msg.sender);
    }
}