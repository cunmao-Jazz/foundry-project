// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/NFTmarket/NFTmarketPermitList.sol";
import "../src/NFTmarket/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/NFTmarket/NFTmarket.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../src/NFTmarket/ERC721.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract NFTMarketUpgradeTest is Test {
    NFTMarket public nftMarketV1;
    NFTmarketV2 public nftMarketV2;
    address public proxy;
    BaseERC721 public nftContract;
    MockERC20 public paymentToken;
    Options public opts;

    address public owner = address(this);
    address public buyer = address(2);
    uint256 public tokenId = 1;
    uint256 public price = 0.01 ether;

    string public constant NAME = "NFTMarket";
    string public constant VERSION = "1";

    bytes32 private constant LISTING_TYPEHASH = keccak256("Listing(uint256 tokenId,uint256 price)");

    bytes32 public constant DOMAIN_TYPEHASH =  keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    uint256 seller = 0xA11CE;

    // Generate the whitelist signer address from the private key using Foundry's vm.addr cheatcode
    address public sellerSigner = vm.addr(seller);
    function setUp() public {
        // 部署 Mock ERC20 和 ERC721 合约
        nftContract = new BaseERC721("cat","cat","ipfs://cat.com");
        paymentToken = new MockERC20();

        vm.deal(buyer, 10 ether);

        // 给卖家分配代币和 NFT
        vm.startPrank(sellerSigner);
        nftContract.mint(sellerSigner, tokenId);
        paymentToken.mint(sellerSigner, 1000 ether);
        vm.stopPrank();
    }

    function testDeployProxy() public{
        // 部署 V1 实现合约
        // NFTMarket nftMarketImplementation = new NFTMarket();

        opts.unsafeSkipAllChecks = true;
        // 初始化参数

        proxy = Upgrades.deployTransparentProxy(
            "NFTmarket.sol",
            address(owner),
            abi.encodeCall(NFTMarket.initialize, (address(paymentToken),address(nftContract))),
            opts
        );

        console.log("NFTMarket deployed on %s", address(proxy));

        nftMarketV1 = NFTMarket(address(proxy));

        // 卖家批准 NFT 和代币
        vm.startPrank(sellerSigner);
        nftContract.approve(address(proxy), tokenId);
        paymentToken.approve(address(proxy), price);
        vm.stopPrank();

        // 卖家在 V1 合约中挂牌 NFT
        vm.prank(sellerSigner);
        nftMarketV1.list(tokenId, price);

        console.log("NFTMarket deployed on %s", address(proxy));
    }

    function testUpgrade() public {

        opts.unsafeSkipAllChecks = true;
        // 初始化参数

        vm.prank(owner);
        proxy = Upgrades.deployTransparentProxy(
            "NFTmarket.sol",
            address(owner),
            abi.encodeCall(NFTMarket.initialize, (address(paymentToken),address(nftContract))),
            opts
        );

        nftMarketV1 = NFTMarket(address(proxy));

        opts.referenceContract = "NFTmarket.sol";
        
        vm.prank(owner);
        Upgrades.upgradeProxy(address(proxy),
         "NFTmarketPermitList.sol",
          abi.encodeCall(NFTmarketV2.initializeV2, (address(nftContract))),
          opts);

        // 将代理合约地址转换为 NFTmarketV2 类型
        nftMarketV2 = NFTmarketV2(address(proxy));
        
        vm.prank(sellerSigner);
        nftContract.approve(address(proxy), tokenId);

        bytes memory signature = getPermitBuySignature(tokenId, price);

        uint256 sellerBalanceBefore = sellerSigner.balance;

        console.log("sellerBalanceBefore:",sellerBalanceBefore);

        vm.prank(buyer);
        nftMarketV2.buy{value: price}(tokenId, price, signature);

        address newOwner = nftContract.ownerOf(tokenId);
        assertEq(newOwner, buyer, "Buyer should own the NFT after purchase");

        uint256 sellerBalanceAfter = sellerSigner.balance;

        assertEq(sellerBalanceAfter, sellerBalanceBefore + price);


    }

    function getPermitBuySignature(
        uint256 _tokenId,
        uint256 _price
    ) internal view returns (bytes memory) {
        // Create the struct hash for the PermitBuy struct
        bytes32 structHash = keccak256(
            abi.encode(
                LISTING_TYPEHASH,
                _tokenId,
                _price
            )
        );

        // Create the EIP-712 domain separator
        bytes32 DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(NAME)),
                keccak256(bytes(VERSION)),
                block.chainid,
                address(proxy)
            )
        );

        // Compute the final digest to be signed
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );

        // Sign the digest using the whitelist signer's private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(seller, digest);
        // Return the concatenated signature
        return abi.encodePacked(r, s, v);
    }
}


// Mock ERC20 合约
contract MockERC20 is ERC20 {
    constructor() ERC20("MockToken", "MTK") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}