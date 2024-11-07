// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import "../src/InscriptionContract/InscriptionContract.sol";
import "../src/InscriptionContract/InscriptionContractV2.sol";

contract InscriptionUpgradeTest is Test {
    address public deploy = address(1);
    address public mint = address(2);

    address public owner = address(this);

    string public symbol = "cat";

    uint256 public totalSupplyCap = 1000;

    uint256 public price = 0.1 ether;

    uint public permint = 100;

    Options public opts;

    FactoryContract public inscriptionFactory;
    InscriptionToken public inscriptionToken;
    FactoryContractV2 public inscriptionFactoryV2;
    InscriptionTokenV2 public inscriptionTokenV2;


    function setUp() public {
        vm.deal(deploy, 10 ether);
        vm.deal(mint, 10 ether);
    }
    function testDeployInscriptionProxy() public {

        opts.unsafeSkipAllChecks = true;
        // 初始化参数

        vm.prank(owner);
        address proxy = Upgrades.deployTransparentProxy(
            "InscriptionContract.sol",
            address(owner),
            "",
            opts
        );

        console.log("FactoryContract deployed on %s", address(proxy));

        inscriptionFactory = FactoryContract(address(proxy));

        vm.prank(deploy);
        address token = inscriptionFactory.deployInscription(symbol, totalSupplyCap, permint);

        assertTrue(token != address(0));
        console.log("token_address:",token);
        inscriptionToken = InscriptionToken(token);

        assertEq(inscriptionToken.totalSupplyCap(), totalSupplyCap);
        assertEq(inscriptionToken.perMint(), permint);

        vm.prank(mint);
        inscriptionFactory.mintInscription(token);
        assertEq(inscriptionToken.balanceOf(mint), permint);



    }

    function testUpgradeInscriptionProxy() public {
        opts.unsafeSkipAllChecks = true;
        // 初始化参数

        vm.prank(owner);
        address proxy = Upgrades.deployTransparentProxy(
            "InscriptionContract.sol",
            address(owner),
            "",
            opts
        );

        console.log("FactoryContract deployed on %s", address(proxy));

        opts.referenceContract = "InscriptionContract.sol";
        
        vm.prank(owner);
        Upgrades.upgradeProxy(address(proxy),
         "InscriptionContractV2.sol",
          abi.encodeCall(FactoryContractV2.initialize,(address(deploy))),
          opts);

        inscriptionFactoryV2 = FactoryContractV2(address(proxy));

        vm.prank(deploy);
        address token = inscriptionFactoryV2.deployInscription(symbol, totalSupplyCap, permint,price);

        assertTrue(token != address(0));
        console.log("token_address:",token);
        inscriptionTokenV2 = InscriptionTokenV2(token);

        assertEq(inscriptionTokenV2.totalSupplyCap(), totalSupplyCap);
        assertEq(inscriptionTokenV2.perMint(), permint);

        vm.prank(mint);
        inscriptionFactoryV2.mintInscription{value: price}(token);
        assertEq(inscriptionTokenV2.balanceOf(mint), permint);

        //balance verify
        uint256 deployBalanceBefore = deploy.balance;

        vm.prank(deploy);
        inscriptionFactoryV2.withdraw();

        uint256 deployBalanceAfter = deploy.balance;

        uint256 expectedIncrease = price;
        assertEq(deployBalanceAfter, deployBalanceBefore + expectedIncrease);
    }
}

