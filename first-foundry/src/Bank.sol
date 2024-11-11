// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Bank {

    uint256 public total;

    address private owner;

    mapping(address => uint) public balanceOf;

    event Deposit(address indexed user, uint amount);

    event Withdraw(address indexed user,uint amount);

    event OwnerWithdraw(address indexed user,uint amount);

    constructor(uint256 _total){
        owner = msg.sender;
        total = _total;
    }

    function deposit() external payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");

        balanceOf[msg.sender] += msg.value;
        
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw() external {
        require(address(this).balance >= total,"contract balances less then total");

        uint256 amount = address(this).balance / 2;

        payable(owner).transfer(amount);

        emit Withdraw(owner,amount);
    }

    function ownerwithdraw() external {
        require(msg.sender == owner,"Only the owner can call this function");

        uint256 amount = address(this).balance;
        
        payable(owner).transfer(amount);

        emit OwnerWithdraw(owner, amount);
    }
}