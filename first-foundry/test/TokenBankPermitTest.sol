// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Import Foundry's Test framework for writing and running tests
import "forge-std/Test.sol";

// Import the TokenBank contract to be tested
import "../src/tokenBankContract/tokenBankContract.sol";

// Import the MyToken ERC20 contract used in testing
import "../src/tokenBankContract/MyToken.sol";

// Define the test contract inheriting from Foundry's Test framework
contract TokenBankPermitTest is Test {
    // Declare an instance of the MyToken contract
    MyToken token;

    // Declare an instance of the TokenBank contract
    TokenBank tokenBank;

    // Define the private key for the owner (whitelist signer)
    uint256 ownerPrivateKey = 0xA11CE;

    // Declare the owner's address
    address owner;

    /**
     * @dev Setup function called before each test to deploy contracts and initialize state
     */
    function setUp() public {
        // Generate the owner's address from the private key using Foundry's vm.addr cheatcode
        owner = vm.addr(ownerPrivateKey);

        // Deploy the MyToken ERC20 contract
        token = new MyToken();

        // Deploy the TokenBank contract with the address of the deployed MyToken contract
        tokenBank = new TokenBank(address(token));

        // Start impersonating the current contract's address to perform actions on its behalf
        vm.startPrank(address(this));

        // Transfer 1000 tokens (adjusted for decimals) from the contract to the owner
        token.transfer(owner, 1000 * 10 ** token.decimals());

        // Stop impersonating the current contract's address
        vm.stopPrank();
    }

    /**
     * @dev Helper function to generate EIP-712 compliant permit signatures
     * @param owner_ The address of the token owner
     * @param spender_ The address authorized to spend the tokens
     * @param value_ The amount of tokens to approve
     * @param nonce_ The current nonce for the owner to prevent replay attacks
     * @param deadline_ The timestamp until which the permit is valid
     * @return v The recovery byte of the signature
     * @return r Half of the ECDSA signature pair
     * @return s Half of the ECDSA signature pair
     */
    function getPermitSignature(
        address owner_,
        address spender_,
        uint256 value_,
        uint256 nonce_,
        uint256 deadline_
    ) internal returns (uint8, bytes32, bytes32) {
        // Retrieve the EIP-712 domain separator from the token contract
        bytes32 DOMAIN_SEPARATOR = token.DOMAIN_SEPARATOR();

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
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        // Return the signature components
        return (v, r, s);
    }

    /**
     * @dev Test function to verify that a permit-based deposit works correctly
     */
    function testPermitDeposit() public {
        // Define the amount to deposit (adjusted for token decimals)
        uint256 depositAmount = 100 * 10 ** token.decimals();

        // Define the allowance amount (greater than or equal to depositAmount)
        uint256 allowanceAmount = 200 * 10 ** token.decimals();

        // Define the deadline for the permit (1 hour from the current block timestamp)
        uint256 deadline = block.timestamp + 1 hours;

        // Retrieve the current nonce for the owner from the token contract
        uint256 nonce = token.nonces(owner);

        // Generate the permit signature using the helper function
        (uint8 v, bytes32 r, bytes32 s) = getPermitSignature(
            owner,               // Owner's address
            address(tokenBank),  // Spender's address (TokenBank contract)
            allowanceAmount,     // Amount to approve
            nonce,               // Current nonce
            deadline             // Deadline for the permit
        );

        // Call the permitDeposit function on the TokenBank contract using the generated signature
        tokenBank.permitDeposit(
            owner,              // Owner's address
            address(tokenBank), // Spender's address (TokenBank contract)
            allowanceAmount,    // Amount approved
            deadline,           // Deadline for the permit
            v,                  // Signature component v
            r,                  // Signature component r
            s,                  // Signature component s
            depositAmount       // Amount to deposit
        );

        // Retrieve the TokenBank's balance for the owner to verify the deposit
        uint256 bankBalance = tokenBank.balanceOf(owner);
        // Assert that the bank balance matches the deposit amount
        assertEq(bankBalance, depositAmount, "Deposit amount mismatch");

        // Retrieve the TokenBank contract's token balance to verify the transfer
        uint256 contractBalance = token.balanceOf(address(tokenBank));
        // Assert that the contract balance matches the deposit amount
        assertEq(contractBalance, depositAmount, "Contract balance mismatch");

        // Retrieve the owner's token balance to verify the deduction
        uint256 ownerBalance = token.balanceOf(owner);
        // Assert that the owner's balance has decreased by the deposit amount
        assertEq(ownerBalance, 1000 * 10 ** token.decimals() - depositAmount, "Owner balance mismatch");

        // Retrieve the remaining allowance to verify the deduction
        uint256 remainingAllowance = token.allowance(owner, address(tokenBank));
        // Assert that the remaining allowance has decreased by the deposit amount
        assertEq(remainingAllowance, allowanceAmount - depositAmount, "Remaining allowance mismatch");
    }

}