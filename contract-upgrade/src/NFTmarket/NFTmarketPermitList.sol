// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
contract NFTmarketV2 is Initializable,IERC721Receiver,EIP712Upgradeable {
    BaseERC721 public nftContract;

    struct Listing {
        uint256 tokenId;
        uint256 price;
    }

    mapping(bytes32 => bool) public usedSignatures;


    bytes32 private constant LISTING_TYPEHASH = keccak256("Listing(uint256 tokenId,uint256 price)");

    event NFTListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event NFTPurchased(uint256 indexed tokenId, address indexed buyer, uint256 price);

    function initializeV2(address _nftContract) public reinitializer(2) {
        __EIP712_init("NFTMarket", "1");
        nftContract = BaseERC721(_nftContract);
    }

    function buy(uint256 tokenId, uint256 price, bytes memory signature) external payable {
        require(msg.value >= price, "Insufficient sending ETH");

        Listing memory listing = Listing({
            tokenId: tokenId,
            price: price
        });
        address seller = _verifyListing(listing, signature);
        require(seller != address(0),"The signature is invalid or unauthorized");

        bytes32 sigHash = keccak256(signature);
        require(!usedSignatures[sigHash], "The signature has been used");
        usedSignatures[sigHash] = true;

        require(nftContract.ownerOf(tokenId) == seller, "The seller no longer owns the NFT");

        nftContract.safeTransferFrom(seller, msg.sender, tokenId);

        payable(seller).transfer(price);

        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }

        emit NFTPurchased(tokenId, msg.sender, price);
    }

    function _verifyListing(
        Listing memory listing,
        bytes memory signature
    ) internal view returns(address) {
        bytes32 structHash = keccak256(abi.encode(
            LISTING_TYPEHASH,
            listing.tokenId,
            listing.price
        ));

        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = ECDSA.recover(hash, signature);

        return signer;
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