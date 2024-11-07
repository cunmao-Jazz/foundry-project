// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/NFTmarket/NFTmarketPermitList.sol";
import { Upgrades, Options } from "openzeppelin-foundry-upgrades/Upgrades.sol";


contract CounterScript is Script {
    

    function run() public {
        
        vm.startBroadcast();

        Options memory opts;
        opts.unsafeSkipAllChecks = true;
        opts.referenceContract = "NFTmarket.sol";

        address nftContract = address(0x1e2f5d19cd614AAB042D635E4dfC8fe286D27Fe4); 


        // proxy: 0x40f73853599D358520B65E9b374d9dcA69636425
        Upgrades.upgradeProxy(0x40f73853599D358520B65E9b374d9dcA69636425,
         "NFTmarketPermitList.sol",
          abi.encodeCall(NFTmarketV2.initializeV2, (nftContract)),
          opts);

        vm.stopBroadcast();

    }
}