// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "forge-std/console.sol";

contract AirdopMerkleNFTMarket is IERC721Receiver  {
    ERC20Permit public paymentToken;
    IERC721 public nftContract;

    bytes32 public immutable merkleRoot;

    struct Listing {
        address seller;
        uint256 price;
    }

    mapping(uint256 => Listing) public  listings;

    event NFTListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event NFTPurchased(uint256 indexed tokenId, address indexed buyer, uint256 price);

    constructor(address _paymentToken, address _nftContract,bytes32 _merkleRoot){
        paymentToken = ERC20Permit(_paymentToken);
        nftContract = IERC721(_nftContract);
        merkleRoot = _merkleRoot;
    }

    function list(uint256 tokenId, uint256 price ) public {

        require(price > 0, "This NFT is not for sale.");

        require(nftContract.ownerOf(tokenId) == msg.sender,"Not the owner");

        require(nftContract.isApprovedForAll(msg.sender, address(this)) || nftContract.getApproved(tokenId) == address(this), "NFT not approved");

        listings[tokenId] = Listing({seller: msg.sender,price: price});
        emit NFTListed(tokenId,msg.sender,price);
    }

    function permitPrePay(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        paymentToken.permit(owner, spender, value, deadline, v, r, s);
    }

    function claimNFT(
        uint256 tokenId,
        bytes32[] calldata merkleProof 
    ) external {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));

        require(MerkleProof.verify(merkleProof, merkleRoot, leaf), "Invalid Merkle Proof");

        Listing memory listing = listings[tokenId];
        require(listing.seller != address(0), "This NFT is not for sale.");
        require(listing.seller != msg.sender, "Cannot purchase NFTs that are self listed");
        uint256 discountedPrice = listing.price / 2;
        
        require(
            paymentToken.allowance(msg.sender, address(this)) >= discountedPrice, 
            "Insufficient allowance."
        );

        paymentToken.transferFrom(msg.sender, listing.seller, discountedPrice);

        nftContract.safeTransferFrom(listing.seller, msg.sender, tokenId);

        delete listings[tokenId];

        emit NFTPurchased(tokenId, msg.sender, discountedPrice);
    }
    function multicall(bytes[] calldata data) external returns (bytes[] memory results){
        results = new bytes[](data.length); // 初始化 results 数组
        for(uint i = 0; i < data.length; i++){
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);
            require(success, "Multicall: call failed");
            results[i] = result;
        }
        return results;
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