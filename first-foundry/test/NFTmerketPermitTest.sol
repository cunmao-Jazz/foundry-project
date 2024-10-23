// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Import Foundry's Test framework for writing and running tests
import "forge-std/Test.sol";

// Import the NFTMarketPermit contract to be tested
import "../src/NFTmarket/NFTmerketpermit.sol";

// Import mock ERC20 and ERC721 contracts for testing purposes
import "../src/NFTmarket/ERC20.sol";
import "../src/NFTmarket/ERC721.sol";

// Import OpenZeppelin's ECDSA library for cryptographic operations
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

// Define the test contract inheriting from Foundry's Test framework
contract NFTmarketTest is StdInvariant, Test {

    // Define the seller and buyer addresses
    address public seller = address(1);
    address public buyer = address(2);

    // Define the private key for the whitelist signer
    uint256 whitelistPrivateKey = 0xA11CE;

    // Generate the whitelist signer address from the private key using Foundry's vm.addr cheatcode
    address public whitelistSigner = vm.addr(whitelistPrivateKey);

    // Declare instances of the mock ERC20, ERC721, and NFTMarketPermit contracts
    BaseERC20  public erc20;
    BaseERC721 public erc721;
    NFTMarketPermit  public market;

    // Define the token ID and price for the NFT
    uint256 public tokenId = 1;
    uint256 public price = 100;

    // Define constants for EIP-712 domain name and version
    string public constant NAME = "NFTMarket";
    string public constant VERSION = "1";

    // Define the type hash for the PermitBuy struct used in EIP-712 signing
    bytes32 public constant PERMIT_TYPEHASH = keccak256("PermitBuy(address buyer,uint256 tokenId,uint256 price,uint256 nonce)");
    
    bytes32 public constant DOMAIN_TYPEHASH =  keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    /**
     * @dev Setup function called before each test to deploy contracts and initialize state
     */
    function setUp() public {
        // Deploy the mock ERC20 token contract
        erc20 = new BaseERC20();

        // Deploy the mock ERC721 token contract with name "cat", symbol "cat", and a base URI
        erc721 = new BaseERC721("cat","cat","ipfs://QmPMKdsqJCUMnnAHVsvzR9kqzrR3dRZxiwwEHSfdQ1gvtt");

        // Deploy the NFTMarketPermit contract with the addresses of ERC20, ERC721, and the whitelist signer
        market = new NFTMarketPermit(address(erc20),address(erc721),whitelistSigner);

        // Allocate ERC20 tokens to the buyer for testing
        deal(address(erc20), buyer, price);
        // Assert that the buyer's ERC20 balance is correctly set
        assertEq(erc20.balanceOf(buyer), price);

        // Simulate the buyer approving the marketplace to spend their ERC20 tokens
        vm.prank(buyer);
        erc20.approve(address(market), price);
        // Assert that the allowance is correctly set
        assertEq(erc20.allowance(buyer, address(market)), 100);

        // Simulate the seller minting an NFT with the specified tokenId
        vm.prank(seller); 
        erc721.mint(seller, tokenId);
        // Assert that the seller is the owner of the newly minted NFT
        assertEq(erc721.ownerOf(tokenId), seller);

        // Simulate the seller approving the marketplace to transfer the NFT
        vm.prank(seller);
        erc721.approve(address(market), tokenId);
        // Assert that the marketplace is approved to manage the NFT
        assertEq(erc721.getApproved(tokenId), address(market));

        // Simulate the seller listing the NFT for sale on the marketplace at the specified price
        vm.prank(seller);
        market.list(tokenId, price);
    }

    /**
     * @dev Helper function to generate an EIP-712 compliant signature for PermitBuy
     * @param _buyer Address of the buyer
     * @param _tokenId ID of the NFT to purchase
     * @param _price Price of the NFT in ERC20 tokens
     * @param _nonce Current nonce of the buyer to prevent replay attacks
     * @return bytes Memory array containing the generated signature
     */
    function getPermitBuySignature(
        address _buyer,
        uint256 _tokenId,
        uint256 _price,
        uint256 _nonce
    ) internal view returns (bytes memory) {
        // Create the struct hash for the PermitBuy struct
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                _buyer,
                _tokenId,
                _price,
                _nonce
            )
        );

        // Create the EIP-712 domain separator
        bytes32 DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(NAME)),
                keccak256(bytes(VERSION)),
                block.chainid,
                address(market)
            )
        );

        // Compute the final digest to be signed
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );

        // Sign the digest using the whitelist signer's private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(whitelistPrivateKey, digest);
        // Return the concatenated signature
        return abi.encodePacked(r, s, v);
    }

    /**
     * @dev Test function to verify a successful permit-based NFT purchase
     */
    function testPermitBuySuccess() public {
        // Retrieve the current nonce for the buyer from the marketplace contract
        uint256 nonce = market.nonces(buyer);
        // Generate a valid signature for the permitBuy function
        bytes memory signature = getPermitBuySignature(buyer, tokenId, price, nonce);

        // Check that the seller is the current owner of the NFT before purchase
        address previousOwner = erc721.ownerOf(tokenId);
        assertEq(previousOwner, seller, "Seller should own the NFT before purchase");

        // Record the ERC20 token balances of the buyer and seller before the purchase
        uint256 buyerBalanceBefore = erc20.balanceOf(buyer);
        uint256 sellerBalanceBefore = erc20.balanceOf(seller);

        // Simulate the buyer calling permitBuy to purchase the NFT using the generated signature
        vm.prank(buyer);
        market.permitBuy(tokenId, price, signature);

        // Verify that the buyer is now the owner of the NFT after purchase
        address newOwner = erc721.ownerOf(tokenId);
        assertEq(newOwner, buyer, "Buyer should own the NFT after purchase");

        // Record the ERC20 token balances of the buyer and seller after the purchase
        uint256 buyerBalanceAfter = erc20.balanceOf(buyer);
        uint256 sellerBalanceAfter = erc20.balanceOf(seller);

        // Assert that the buyer's balance has decreased by the purchase price
        assertEq(buyerBalanceAfter, buyerBalanceBefore - price, "Buyer balance should decrease by price");
        // Assert that the seller's balance has increased by the purchase price
        assertEq(sellerBalanceAfter, sellerBalanceBefore + price, "Seller balance should increase by price");

        // Verify that the NFT listing has been removed from the marketplace after purchase
        (, uint256 listedPrice) = market.listings(tokenId);
        assertEq(listedPrice, 0, "Listing should be removed after purchase");
    }

}