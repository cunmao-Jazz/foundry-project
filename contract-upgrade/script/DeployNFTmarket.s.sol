// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/NFTmarket/NFTmarket.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployNFTMarket is Script {

    address internal deployer;
    string internal mnemonic;
    function run() external {
        vm.startBroadcast();

        Options memory opts;
        opts.unsafeSkipAllChecks = true;
        // 初始化参数
        address paymentToken = address(0x4162036C67De0B77A3359C752e299C87a163Df30);
        address nftContract = address(0x1e2f5d19cd614AAB042D635E4dfC8fe286D27Fe4); 

        address proxy = Upgrades.deployTransparentProxy(
            "NFTmarket.sol",
            address(0xAA989Aabdf95e32cc57e331D9844121E0C16B618),
            abi.encodeCall(NFTMarket.initialize, (paymentToken,nftContract)),
            opts
        );
        vm.stopBroadcast();

        console.log("NFTMarket deployed on %s", address(proxy));


    }
}