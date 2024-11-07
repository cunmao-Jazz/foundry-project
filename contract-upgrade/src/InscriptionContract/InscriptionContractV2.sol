// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./TokenV2.sol";


contract FactoryContractV2 is Initializable{
    using Clones for address;
    
    mapping(address => uint256) public tokenPrices;

    address public masterInscription;
    address private owner;
    event InscriptionDeployed(address indexed tokenAddress,uint256 totalSupply,uint256 price);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    function initialize(address _owner) initializer external {
        owner = _owner;
        InscriptionTokenV2 master = new InscriptionTokenV2();
        masterInscription = address(master);
    }
    function deployInscription(string memory symbol, uint256 totalSupply, uint256 perMint,uint256 price) external returns(address token) {
        token = masterInscription.clone();
        InscriptionTokenV2(token).initialize(symbol, symbol, totalSupply, perMint, address(this));

        tokenPrices[token] = price;
        emit InscriptionDeployed(token, totalSupply,price);

        return token;
    }

    function mintInscription(address tokenAddr) external payable {
        require(tokenPrices[tokenAddr] > 0,"invalid token address");

        uint256 price = tokenPrices[tokenAddr];

        require(msg.value >= price,"underpayment");

        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }

        InscriptionTokenV2(tokenAddr).mint(msg.sender);
    }

    function withdraw() external {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");

        (bool success, ) = owner.call{value: balance}("");
        require(success, "Withdrawal failed");
}
}