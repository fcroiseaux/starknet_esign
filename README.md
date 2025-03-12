# eIDAS-Compliant Electronic Document Signing on Starknet

This project implements a Starknet smart contract for electronic document signing with eIDAS compliance, using an approach inspired by Ethereum's EIP-712 structured data signing.

## Features

- **eIDAS Levels Support**: Implements all three qualification levels:
  - QES (Qualified Electronic Signature) - highest level of trust
  - AES (Advanced Electronic Signature) - medium level
  - SES (Simple Electronic Signature) - basic level

- **Document Management**:
  - Sign documents with verifiable hashes
  - Verify document integrity
  - Revoke signatures when needed
  - Track document ownership

- **Access Control**:
  - Owner-managed system of authorized signers using OpenZeppelin Ownable component
  - Only authorized signers can create signatures
  - Only document owner or contract owner can revoke signatures

- **EIP-712 Inspired Design**:
  - Structured data signing approach
  - Domain separation to prevent signature replay
  - Typed data structures for document information

- **OpenZeppelin Integration**:
  - Uses Cairo 1.0.0 compatible OpenZeppelin components
  - Implements Ownable for access control
  - Includes SRC5 (Cairo's version of ERC165) for interface detection

## Project Structure

- `src/lib.cairo`: The complete implementation including:
  - EIP-712 inspired typed data structures 
  - Core document signature functionality
  - Comprehensive test suite

## How It Works

1. **Document Signing**:
   - Documents are represented as arrays of felt252 values
   - Each document gets a unique ID
   - Signatures include the document hash, signer address, and qualification level

2. **Verification**:
   - Documents are verified by recomputing their hash and comparing to stored value
   - System also checks if signature has been revoked

3. **Authorization**:
   - Contract owner can authorize trusted signers
   - Only authorized signers can create valid document signatures

## Usage Example

```cairo
// Create a document
let document_id = 'contract_2023_001';
let document_data = array!['Contract', 'Content'];
let signer_address = 'signer_1';

// Sign the document with QES level (highest level of trust)
// Set validity period to 90 days (7,776,000 seconds)
let signature = sign_document(
    document_id,
    document_data,
    QES_LEVEL,
    7776000_u64
);

// Verify the document 
let is_valid = verify_document_signature(
    document_id,
    signer_address,
    document_data
);

// Check if signature is expired
let is_expired = is_signature_expired(document_id, signer_address);

// Revoke the signature if needed
revoke_signature(document_id);
```

## Building and Testing

1. Install Scarb: https://docs.swmansion.com/scarb/
2. Build the project:
   ```
   scarb build
   ```
3. Run tests:
   ```
   scarb test
   ```

## Dependencies

- **Starknet**: v2.3.0
- **OpenZeppelin**: v1.0.0 
- **Cairo Test**: v2.9.2 (for testing)

## Security Features

- **Enhanced Cryptographic Hash Function**:
  - Multi-round hashing for stronger security
  - Domain separation to prevent cross-domain attacks
  - Length prefixing to prevent length extension attacks
  - Contract and domain binding to prevent replay attacks

- **Signature Expiration**:
  - Configurable validity periods for all signatures
  - Default 1-year expiration if not explicitly set
  - Automatic validation of expiration during verification

- **Document Validation**:
  - Empty document prevention
  - Comprehensive hash validation
  - Signature existence verification

- **Access Controls**:
  - Owner-managed system via OpenZeppelin's Ownable component
  - Proper revocation controls
  
## Compatibility Notes

This project is built with Cairo 2023_01 edition for maximum stability and is fully compatible with OpenZeppelin for Cairo v1.0.0. The code follows the component-based architecture pattern recommended for Starknet contract development.