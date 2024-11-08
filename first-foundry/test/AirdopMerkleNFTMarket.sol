// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/NFTmarket/AirdopMerkleNFTMarket.sol";
import "../src/test_contract/ERC20Permit_test.sol";
import "../src/test_contract/ERC721_test.sol";
contract TestAirdopMerkleNFTMarket is Test {
    ERC721_test public erc721;
    BaseERC20Permit public erc20;
    AirdopMerkleNFTMarket public market;

    uint256 public tokenId = 1;
    uint256 public price = 100;

    uint256 buyerPrivateKey = 0xA11CE;
    uint256 sellerPrivateKey = 0xA13CE;
    address public seller = vm.addr(sellerPrivateKey);
    address public buyer = vm.addr(buyerPrivateKey);

    bytes32 public merkleRoot = 0x277aa3ac08847fbad6f72b6502236a73757a568d621a809d44cfbd3023c48a57;

    bytes32[] public buyerProof;
    bytes[] public multicallData;

    function setUp() public {
        erc20 = new BaseERC20Permit();
        erc721 = new ERC721_test();
        market = new AirdopMerkleNFTMarket(
            address(erc20),
            address(erc721),
            merkleRoot
            );

        deal(address(erc20), buyer, price);
        assertEq(erc20.balanceOf(buyer), price);

        erc721.mint(seller, tokenId);
        assertEq(erc721.balanceOf(seller), tokenId);

        vm.prank(seller);
        erc721.setApprovalForAll(address(market), true);

        buyerProof.push(0x00f369b03139ffa987d43ef2453e4b14a9a184bc669bd087e69c25c51332c32f);
        buyerProof.push(0xbcd38b2035ca1923d0fefc1401c8297a14c0a497c125912152dfd3c279e3386b);
    }

    function testAirdopMerkleNFTMarket() public {
        console.log("Buyer:", buyer);
        console.log("Seller:", seller);

        vm.prank(seller);
        market.list(tokenId, price);

        (address seller2,uint256 price2) = market.listings(1);
        assertEq(seller2, seller);
        assertEq(price2, price);

        (uint8 v, bytes32 r, bytes32 s) = getPermitSignature(
            buyer,
            address(market),
            price / 2 , // discounted price
            erc20.nonces(buyer),
            block.timestamp + 1000
        );

        bytes memory permitPrePayCalldata = abi.encodeWithSelector(
            market.permitPrePay.selector,
            buyer,
            address(market),
            price / 2 ,
            block.timestamp + 1000,
            v,
            r,
            s
        );

        bytes memory claimNFTCalldata = abi.encodeWithSelector(
            market.claimNFT.selector,
            tokenId,
            buyerProof
        );


        multicallData.push(permitPrePayCalldata);
        multicallData.push(claimNFTCalldata);

        vm.prank(buyer);
        market.multicall(multicallData);

        assertEq(erc721.ownerOf(tokenId), buyer);

        assertEq(erc20.balanceOf(buyer), price - (price / 2));
        assertEq(erc20.balanceOf(seller), price / 2);
    }

    function getPermitSignature(
        address owner_,
        address spender_,
        uint256 value_,
        uint256 nonce_,
        uint256 deadline_
    ) internal returns (uint8, bytes32, bytes32) {
        // Retrieve the EIP-712 domain separator from the token contract
        bytes32 DOMAIN_SEPARATOR = erc20.DOMAIN_SEPARATOR();

        // Define the EIP-712 Permit typehash
        bytes32 PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

        // Compute the struct hash for the Permit struct
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner_,
                spender_,
                value_,
                nonce_,
                deadline_
            )
        );

        // Compute the final EIP-712 digest by combining the domain separator and struct hash
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );

        // Sign the digest using the owner's private key to generate the signature components
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerPrivateKey, digest);

        // Return the signature components
        return (v, r, s);
    }
}