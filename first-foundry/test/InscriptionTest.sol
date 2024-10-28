// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/InscriptionContract/InscriptionContract.sol";
contract InscriptionTest is Test {
    address public deploy = address(1);
    address public mint = address(2);

    string public symbol = "cat";

    uint256 public totalSupplyCap = 1000;

    uint public permint = 100;

    FactoryContract public inscriptionFactory;
    InscriptionToken public inscriptionToken;
    function setUp() public {
        inscriptionFactory = new FactoryContract();

        vm.deal(deploy, 10 ether);
        vm.deal(mint, 10 ether);

    }

    function deployToken() internal returns(address){
        vm.prank(deploy);
        address token = inscriptionFactory.deployInscription(symbol, totalSupplyCap, permint);

        assertTrue(token != address(0));
        console.log("token_address:",token);
        inscriptionToken = InscriptionToken(token);

        assertEq(inscriptionToken.totalSupplyCap(), totalSupplyCap);
        assertEq(inscriptionToken.perMint(), permint);

        return token;
    }

    function testSuccessDeploy() public{
        deployToken();

    }

    function testSuccessmint() public {
        address token = deployToken();

        vm.prank(mint);
        inscriptionFactory.mintInscription(token);
        assertEq(inscriptionToken.balanceOf(mint), permint);
    }

    function testMintWhenExceedsTotal() public {
        address token = deployToken();

        for(uint256 i=0;i<10;i++){
            vm.prank(mint);
            inscriptionFactory.mintInscription(token);
            
            assertEq(inscriptionToken.totalMinted(), permint * (i + 1));
        }

        vm.expectRevert("Exceeds total supply cap");
        vm.prank(mint);
        inscriptionFactory.mintInscription(token);
    }
}