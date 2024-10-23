// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/NFTmarket/ERC20.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        BaseERC20 baseERC20 = new BaseERC20();

        vm.stopBroadcast();

        console.log("BaseERC20 deployed at:", address(baseERC20));
    }
}