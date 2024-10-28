// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract NFTMarketPermit is IERC721Receiver, EIP712, ReentrancyGuard {
    using ECDSA for bytes32;

    IERC20 public paymentToken;
    IERC721 public nftContract;
    address public whitelistSigner;

    struct Listing {
        address seller;
        uint256 price;
    }

    mapping(uint256 => Listing) public  listings;

    mapping(address => uint256) public nonces;

    bytes32 private constant PERMIT_TYPEHASH = keccak256("PermitBuy(address buyer,uint256 tokenId,uint256 price,uint256 nonce)");

    event NFTListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event NFTPurchased(uint256 indexed tokenId, address indexed buyer, uint256 price);

    constructor(address _paymentToken, address _nftContract, address _whitelistSigner)
        EIP712("NFTMarket", "1")
    {
        paymentToken = IERC20(_paymentToken);
        nftContract = IERC721(_nftContract);
        whitelistSigner = _whitelistSigner;
    }

    function list(uint256 tokenId, uint256 price ) public {

        require(price > 0, "This NFT is not for sale.");

        require(nftContract.ownerOf(tokenId) == msg.sender,"Not the owner");

        require(nftContract.isApprovedForAll(msg.sender, address(this)) || nftContract.getApproved(tokenId) == address(this), "NFT not approved");

        listings[tokenId] = Listing({seller: msg.sender,price: price});
        emit NFTListed(tokenId,msg.sender,price);
    }

    function permitBuy(uint256 tokenId, uint256 price, bytes memory signature) external nonReentrant {
        Listing memory listing = listings[tokenId];
        require(listing.seller != address(0), "This NFT is not for sale.");
        require(listing.seller != msg.sender, "Cannot purchase NFTs that are self listed");
        require(price == listing.price, "Incorrect price");

        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                msg.sender,
                tokenId,
                price,
                nonces[msg.sender]
            )
        );
        
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, signature);
        require(signer == whitelistSigner, "Invalid signature or not whitelisted");

        nonces[msg.sender] +=1;

        require(paymentToken.balanceOf(msg.sender) >= listing.price, "Insufficient token balance.");

        require(paymentToken.allowance(msg.sender, address(this)) >= listing.price, "Insufficient allowance.");


        paymentToken.transferFrom(msg.sender, listing.seller, listing.price);

        nftContract.safeTransferFrom(listing.seller, msg.sender, tokenId);

        delete listings[tokenId];

        emit NFTPurchased(tokenId, msg.sender, listing.price);

    }


    function buy(uint256 tokenId) external {

        Listing memory listing = listings[tokenId];

        require(listing.seller != address(0), "This NFT is not for sale.");

        require(listing.seller != msg.sender,"Cannot purchase NFTs that are self listed");

        require(paymentToken.balanceOf(msg.sender) >= listing.price, "Insufficient token balance.");

        require(paymentToken.allowance(msg.sender, address(this)) >= listing.price, "Insufficient allowance.");


        paymentToken.transferFrom(msg.sender, listing.seller, listing.price);

        nftContract.safeTransferFrom(listing.seller, msg.sender, tokenId);

        delete listings[tokenId];

        emit NFTPurchased(tokenId, msg.sender, listing.price);

    }

    function tokensReceived(address from, uint256 amount, bytes calldata data) external {
        require(msg.sender == address(paymentToken), "Invalid sender");
        
        uint256 tokenId = abi.decode(data, (uint256));
        Listing memory listing = listings[tokenId];

        require(listing.seller != address(0), "This NFT is not for sale.");

        require(listing.seller != from,"Cannot purchase NFTs that are self listed");

        require(listing.price > 0, "This NFT is not for sale.");

        require(amount >= listing.price, "Insufficient token amount sent.");


        paymentToken.transferFrom(from, listing.seller, listing.price);
        nftContract.safeTransferFrom(listing.seller, from, tokenId);

        delete listings[tokenId];

        emit NFTPurchased(tokenId, from, listing.price);
    }

    function setWhitelistSigner(address _whitelistSigner) external {
        require(msg.sender == whitelistSigner, "Only current signer can set a new signer");
        whitelistSigner = _whitelistSigner;
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