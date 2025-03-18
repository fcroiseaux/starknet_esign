# StarkNet Electronic Signature (StarkNet eSign)

A decentralized application for creating and verifying electronic signatures for PDF documents on StarkNet.

## Overview

StarkNet eSign is a secure electronic signature solution that leverages the security and transparency of StarkNet, a Layer 2 scaling solution for Ethereum. It enables users to create cryptographically verifiable signatures for PDF documents with different levels of security based on the European eIDAS regulation.

## Features

- **Document Signing**: Sign PDF documents with your StarkNet wallet
- **Signature Verification**: Verify document signatures on-chain
- **Security Levels**: Support for different eIDAS signature levels (SES, AES, QES)
- **Automatic Document ID**: Secure automatic generation of unique document IDs
- **Tamper Detection**: Cryptographic verification of document integrity
- **Expiration Support**: Configurable validity periods for signatures
- **Revocation**: Ability to revoke signatures if needed

## Architecture

The application consists of three main components:

1. **Smart Contract**: A Cairo contract deployed on StarkNet that handles the signature logic and storage
2. **Browser Client**: A TypeScript/HTML client for connecting wallets and signing documents in the browser
3. **Node.js Client**: A TypeScript client for server-side document signing

## Setup

### Prerequisites

- Node.js 16+
- StarkNet wallet (like ArgentX or Braavos) for browser client
- Access to a StarkNet node (or use a public RPC provider)

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/starknet_esign.git
cd starknet_esign

# Install dependencies
npm install

# Build the project
npm run build
```

### Running

```bash
# Run the development server
npm run start

# Using the Node.js client
ts-node pdf_sign.ts /path/to/your/document.pdf [SES|AES|QES] [validity_period_in_seconds]
```

## Browser Client Usage

1. Open the application in your browser
2. Connect your StarkNet wallet
3. Select a PDF file to sign
4. Choose a signature level (SES, AES, QES)
5. Submit the transaction with your wallet
6. View and save the signature details

## Node.js Client Usage

```typescript
import { signPdfWithStarknet } from './pdf_sign';

// Sign a document
const result = await signPdfWithStarknet(
  '/path/to/document.pdf',
  'SES',  // Signature level: SES, AES, or QES
  31536000  // Validity period in seconds (1 year)
);

console.log('Document ID:', result.document_id);
console.log('Transaction hash:', result.transaction_hash);
```

## Technical Details

### Smart Contract

The smart contract implements the IElectronicSignature interface and provides the following functions:

- `sign_document`: Creates a cryptographic signature for a document
- `verify_document_signature`: Verifies if a document signature is valid
- `revoke_signature`: Revokes a previously created signature
- `get_signature`: Retrieves a stored signature record
- `hash_typed_data`: Creates a cryptographic hash of typed data for external verification
- `is_signature_expired`: Checks if a signature has expired

### Document Hashing

Documents are hashed using SHA-256 in the client, and the hash is stored on-chain. This ensures:

1. Document contents aren't stored on-chain (for privacy)
2. Documents can be verified without uploading the original again
3. Any modifications to the document will invalidate the signature

### Security Considerations

- Document IDs are automatically generated to ensure uniqueness
- Multiple signature security levels (QES, AES, SES) for different use cases
- Signatures include expiration times to prevent indefinite validity
- Signatures can be revoked by the original signer if needed
- Domain separation prevents signature replay across different contracts/chains

## Contract Address

The contract is deployed on StarkNet Sepolia testnet at:

```
0x0784ba229bb245ebf3322f9cb637d67551afd677fe47aae6ad46ddb3818f7ed7
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.