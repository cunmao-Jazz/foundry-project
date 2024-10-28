// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "first-foundry/lib/openzeppelin-contracts/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenBank{
    IERC20 public token;
    IERC20Permit public permitToken;

    mapping(address => uint) public balances;



    modifier AccountVerification(address account){
        require(account !=address(0), "Invalid address");
        _;
    }

    modifier AmountVerification(uint256 amount){
        require(amount > 0, "Insufficient funds");
        _;
    }

    constructor(address _tokenaddress) AccountVerification(_tokenaddress){
        token = IERC20(_tokenaddress);
        permitToken = IERC20Permit(_tokenaddress);

    }



    function deposit(uint256 amount) public AmountVerification(amount) {
        require(token.transferFrom(msg.sender,address(this), amount), "TransferFrom failed");

        balances[msg.sender]+=amount;
    }

    function permitDeposit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s,
       uint256 amountToDeposit
    ) external AmountVerification(amountToDeposit) {
        permitToken.permit(owner, spender, value, deadline, v, r, s);

        require(token.allowance(owner, address(this)) >= amountToDeposit, "Insufficient allowance after permit");

        require(token.transferFrom(owner, address(this), amountToDeposit), "TransferFrom failed");

        balances[owner] += amountToDeposit;

    }

    function withdraw(uint256 amount) public AmountVerification(amount) {
        require(balances[msg.sender] >= amount, "Insufficient balance in TokenBank");

        balances[msg.sender]-=amount;


        require(token.transfer(msg.sender, amount),"TransferFrom failed");
        

    }

    function balanceOf(address account) public view AccountVerification(account) returns(uint256){
        return balances[account];
    }
}