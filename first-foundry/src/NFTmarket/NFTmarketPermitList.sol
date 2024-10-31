// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract NFTmarketPermitList is IERC721Receiver, EIP712 {
    BaseERC721 public nftContract;

    struct Listing {
        address seller;
        uint256 tokenId;
        uint256 price;
    }

    bytes32 public constant LISTING_TYPEHASH = keccak256("Listing(address seller,uint256 tokenId,uint256 price)");
    mapping(uint256 => Listing) public listings;

    event NFTListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event NFTPurchased(uint256 indexed tokenId, address indexed buyer, uint256 price);

    constructor(address _nftContract) EIP712("NFTMarket", "1") {
        nftContract = BaseERC721(_nftContract);
    }

    function List(address seller, uint256 tokenId,uint256 price,bytes memory signature) public {
        require(price > 0, "Price must be greater than zero");

        require(nftContract.ownerOf(tokenId) == seller,"NFT not is Owner");

        Listing memory listing = Listing({
            seller: seller,
            tokenId: tokenId,
            price: price
        });

        nftContract.permit(seller, address(this), tokenId, signature);

        listings[tokenId] = listing;
        emit NFTListed(tokenId, msg.sender, price);
    }

    function buy(uint256 tokenId) external payable {
        Listing memory listing = listings[tokenId];
        require(listing.seller != address(0), "NFT not for sale");
        require(msg.value >= listing.price, "Insufficient ETH sent");
        require(listing.seller != msg.sender, "Cannot buy your own listing");

        // Transfer ETH to the seller
        payable(listing.seller).transfer(listing.price);

        // Transfer NFT to buyer
        nftContract.safeTransferFrom(listing.seller, msg.sender, tokenId);

        delete listings[tokenId];
        emit NFTPurchased(tokenId, msg.sender, listing.price);
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        // This contract accepts all ERC721 tokens
        return this.onERC721Received.selector;
    }
}