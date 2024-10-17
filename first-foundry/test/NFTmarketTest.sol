// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/StdInvariant.sol";
import "forge-std/Test.sol";
import "../src/NFTmarket/NFTmerket.sol";
import "../src/NFTmarket/ERC20.sol";
import "../src/NFTmarket/ERC721.sol";

contract NFTmarketTest is StdInvariant,Test {
    BaseERC20  public erc20;
    BaseERC721 public erc721;
    NFTMarket  public market;

    event NFTListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event NFTPurchased(uint256 indexed tokenId, address indexed buyer, uint256 price);


    function setUp() public{
        erc20 = new BaseERC20();
        erc721 = new BaseERC721("cat","cat","ipfs://QmPMKdsqJCUMnnAHVsvzR9kqzrR3dRZxiwwEHSfdQ1gvtt");
        market = new NFTMarket(address(erc20),address(erc721));

        excludeContract(address(erc20));
        excludeContract(address(erc721));

        // 设置不变量测试的目标合约为 market
        targetContract(address(market));

    }

    function helperSetupUserAndMintNFT(address user, uint256 tokenId) internal {
        erc721.mint(user, tokenId);
        assertEq(erc721.ownerOf(tokenId), user);

        vm.prank(user);
        erc721.setApprovalForAll(address(market), true);
    }

    function invariant_NFTMarketHasNoTokenBalance() public {
        uint256 erc20Balance = erc20.balanceOf(address(market));
        assertEq(erc20Balance, 0, "NFTMarket contract should not hold any ERC20 tokens");
    }

    function testSuccessList() public {
        // success list test
        address user1 = address(1);

        helperSetupUserAndMintNFT(user1, 0);

        vm.expectEmit(true, true, true, true);
        emit NFTListed(0, user1, 100);

        vm.prank(user1);
        market.list(0,100);

        (address seller,uint256 price) = market.listings(0);
        assertEq(seller, user1);
        assertEq(price, 100);

    }

    function testListWhenNotList() public{
        address user1 = address(1);
        address user2 = address(2);

        erc721.mint(user1, 0);
        assertEq(erc721.ownerOf(0), user1);

        vm.prank(user1);
        vm.expectRevert("This NFT is not for sale.");
        market.list(0,0);

        vm.prank(user2);
        vm.expectRevert("Not the owner");
        market.list(0,100);

        vm.prank(user1);
        vm.expectRevert("NFT not approved");
        market.list(0,100);
        
    }

    function testSuccessBuy() public{
        address user1 = address(1);
        address user2 = address(2);

        deal(address(erc20), user2, 1000);

        assertEq(erc20.balanceOf(user2), 1000);

        helperSetupUserAndMintNFT(user1,0);

        vm.prank(user1);
        market.list(0,100);

        (address seller,uint256 price) = market.listings(0);
        assertEq(seller, user1);
        assertEq(price, 100);

        vm.prank(user2);
        erc20.approve(address(market), 100);
        assertEq(erc20.allowance(user2, address(market)), 100);

        vm.expectEmit(true, true, true, true);
        emit NFTPurchased(0, user2, 100);

        vm.prank(user2);
        market.buy(0);

        assertEq(erc721.ownerOf(0), user2);
        assertEq(erc20.balanceOf(user2), 1000 - 100);
        assertEq(erc20.balanceOf(user1), 100);

        (address newSeller, uint256 newPrice) = market.listings(0);
        assertEq(newSeller, address(0));
        assertEq(newPrice, 0);
    }

    function testBuyWhenNotBuy() public {
        address user1 = address(1);
        address user2 = address(2);

        deal(address(erc20), user2, 1000);

        assertEq(erc20.balanceOf(user2), 1000);

        helperSetupUserAndMintNFT(user1,0);

        vm.prank(user1);
        market.list(0,100);

        (address seller,uint256 price) = market.listings(0);
        assertEq(seller, user1);
        assertEq(price, 100);

        vm.prank(user1);
        vm.expectRevert("This NFT is not for sale.");
        market.buy(1);

        vm.prank(user1);
        vm.expectRevert("Cannot purchase NFTs that are self listed");
        market.buy(0);

        address user3 = address(3);
        vm.prank(user3);
        vm.expectRevert("Insufficient token balance.");
        market.buy(0);

        vm.prank(user2);
        vm.expectRevert("Insufficient allowance.");
        market.buy(0);

    }

    function testFuzzList(uint256 tokenId, uint256 price, address user) public {
        vm.assume(user != address(0));
        vm.assume(price > 0);
        vm.assume(user != address(market));
        vm.assume(user != address(erc20));
        vm.assume(user != address(erc721));

        tokenId = tokenId % 1e6;

        helperSetupUserAndMintNFT(user, tokenId);

        vm.expectEmit(true, true, true, true);
        emit NFTListed(tokenId, user, price);

        vm.prank(user);
        market.list(tokenId, price);

        (address seller, uint256 listedPrice) = market.listings(tokenId);
        assertEq(seller, user);
        assertEq(listedPrice, price);
    }
    function testFuzzBuy(uint256 tokenId,uint256 price, address user1, address user2, uint256 user2Balance) public{
        uint256 decimals = 18;
        uint256 decimalFactor = 10 ** decimals;

        tokenId = tokenId % 1e6;
        price = (price % 1e6) + 1;
        user2Balance = (user2Balance % 1e6) + price;

        uint256 scaledPrice = price * decimalFactor;
        uint256 scaledUser2Balance = user2Balance * decimalFactor;

        vm.assume(user1 != address(0) && user2 != address(0));
        vm.assume(user1 != user2);
        vm.assume(user1 != address(market));
        vm.assume(user2 != address(market));
        vm.assume(user1 != address(erc20));
        vm.assume(user2 != address(erc20));
        vm.assume(user1 != address(erc721));
        vm.assume(user2 != address(erc721));
        vm.assume(user2.code.length == 0);
        vm.assume(scaledUser2Balance >= scaledPrice);

        deal(address(erc20), user1, 0);
        assertEq(erc20.balanceOf(user1), 0);

        deal(address(erc20), user2, scaledUser2Balance);
        assertEq(erc20.balanceOf(user2), scaledUser2Balance);

        helperSetupUserAndMintNFT(user1, tokenId);

        vm.prank(user1);
        market.list(tokenId, scaledPrice);

        (address seller, uint256 listedPrice) = market.listings(tokenId);
        assertEq(seller, user1);
        assertEq(listedPrice, scaledPrice);

        vm.prank(user2);
        erc20.approve(address(market), scaledPrice);
        assertEq(erc20.allowance(user2, address(market)), scaledPrice);

        vm.prank(user2);
        market.buy(tokenId);

        assertEq(erc721.ownerOf(tokenId), user2);
        assertEq(erc20.balanceOf(user2), scaledUser2Balance - scaledPrice);
        assertEq(erc20.balanceOf(user1), scaledPrice);

        (address newSeller, uint256 newPrice) = market.listings(tokenId);
        assertEq(newSeller, address(0));
        assertEq(newPrice, 0);
    }
}