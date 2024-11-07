// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Token.sol";

contract FactoryContract{
     event InscriptionDeployed(address tokenAddress);

    function deployInscription(string memory symbol, uint256 totalSupply, uint256 perMint) external returns(address) {
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

    function mintInscription(address tokenAddr) external {
        InscriptionToken token = InscriptionToken(tokenAddr);
        token.mint(msg.sender);
    }
}