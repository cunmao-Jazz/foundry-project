// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import "../src/pledge/token.sol";
import "../src/pledge/pledge.sol";

/**
 * @dev TokenPledge 测试合约
 */
contract TokenPledgeTest is Test {
    TokenPledge public tokenPledge;
    esRNTToken public RNT;
    esRNTToken public esRNT;
    address public user;

    /**
     * @dev 设置测试环境
     */
    function setUp() public {
        RNT = new esRNTToken("RNT Token", "RNT");
        esRNT = new esRNTToken("esRNT Token", "esRNT");

        tokenPledge = new TokenPledge(IERC20(address(RNT)), IEsRNT(address(esRNT)));
        
        esRNT.transferOwnership(address(tokenPledge));

        user = address(7);

        RNT.mint(user, 100); 
        RNT.mint(address(tokenPledge), 1000);

        vm.prank(user);
        RNT.approve(address(tokenPledge), type(uint256).max);
    }

    function testConvertEsRNT() public {
        vm.startPrank(user);

        uint256 stakeAmount = 10;
        tokenPledge.stake(stakeAmount);

        vm.warp(block.timestamp + 20 days);

        tokenPledge.claim();
        uint256 esRNTBalance = esRNT.balanceOf(user);
        assertEq(esRNTBalance, 200, "User should have 200 esRNT after 20 days of staking");

        esRNT.approve(address(tokenPledge), type(uint256).max);

        vm.warp(block.timestamp + 1 days);

        tokenPledge.convertEsRNT(1);

        uint256 userRNTBalance = RNT.balanceOf(user);
        console.log("userRNTBalance",userRNTBalance);
        uint256 userEsRNTBalanceAfter = esRNT.balanceOf(user);
        console.log("userEsRNTBalanceAfter",userEsRNTBalanceAfter);
        uint256 tokenPledgeEsRNTBalance = esRNT.balanceOf(address(tokenPledge));
        console.log("tokenPledgeEsRNTBalance",tokenPledgeEsRNTBalance);
        vm.stopPrank();
    }

    function testPartialConvertEsRNT() public {
        vm.startPrank(user);

        uint256 stakeAmount = 10;
        tokenPledge.stake(stakeAmount);

        vm.warp(block.timestamp + 30 days);

        tokenPledge.claim();
        uint256 esRNTBalance = esRNT.balanceOf(user);
        assertEq(esRNTBalance, 300, "User should have 300 esRNT after 30 days of staking");

        esRNT.approve(address(tokenPledge), type(uint256).max);

        vm.warp(block.timestamp + 15 days);

        tokenPledge.convertEsRNT(1);

        uint256 userRNTBalance = RNT.balanceOf(user);
        console.log("userRNTBalance",userRNTBalance);
        uint256 userEsRNTBalanceAfter = esRNT.balanceOf(user);
        console.log("userEsRNTBalanceAfter",userEsRNTBalanceAfter);
        uint256 tokenPledgeEsRNTBalance = esRNT.balanceOf(address(tokenPledge));
        console.log(tokenPledgeEsRNTBalance);
        vm.stopPrank();
    }
}