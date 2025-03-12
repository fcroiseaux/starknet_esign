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
  - Owner-managed system of authorized signers
  - Only authorized signers can create signatures
  - Only document owner or contract owner can revoke signatures

- **EIP-712 Inspired Design**:
  - Structured data signing approach
  - Domain separation to prevent signature replay
  - Typed data structures for document information

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
let signature = sign_document(
    document_id,
    document_data,
    signer_address,
    QES_LEVEL
);

// Verify the document
let is_valid = verify_document_signature(signature, document_data);

// Revoke the signature if needed
revoke_signature(ref signature);
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

## Security Notes

- The pedersen hash function implementation is simplified for demonstration
- In a production environment:
  - Use a cryptographically secure hash function
  - Implement strict access controls
  - Add additional document metadata validation
  - Consider implementing signature expiration