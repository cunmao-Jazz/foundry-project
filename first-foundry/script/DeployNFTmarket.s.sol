// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/NFTmarket/NFTMarket.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployNFTMarket is Script {
    function run() external {
        vm.startBroadcast();

        // 部署实现合约
        NFTMarket nftMarketImplementation = new NFTMarket();

        // 初始化参数
        address paymentToken = "0x4162036C67De0B77A3359C752e299C87a163Df30"; // 您的ERC20代币合约地址
        address nftContract = "0x1e2f5d19cd614aab042d635e4dfc8fe286d27fe4";  // 您的ERC721合约地址

        // 构建初始化数据
        bytes memory data = abi.encodeWithSelector(
            NFTMarket.initialize.selector,
            paymentToken,
            nftContract
        );

        // 部署代理合约
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(nftMarketImplementation),
            data
        );

        vm.stopBroadcast();

        // 输出代理合约地址
        console.log("NFTMarket Proxy deployed at:", address(proxy));
    }
}