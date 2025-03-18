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

## Project Structure

```
starknet_esign/
├── abi/                    # Contract ABI files
├── frontend/               # Web interface files
│   ├── browser-pdf-sign.ts # Browser-specific integration
│   ├── index.html          # Web user interface
│   ├── pdf_sign.ts         # Node.js client
│   ├── src/                # TypeScript source files
│   │   ├── adapters/       # Platform-specific adapters
│   │   └── core/           # Core business logic
│   └── webpack.config.js   # Frontend build configuration
├── src/                    # Cairo smart contract source code
│   ├── contracts/          # Main contract implementation
│   ├── interfaces/         # Contract interfaces
│   ├── tests/              # Contract tests
│   └── utils/              # Cairo utilities
├── Scarb.toml              # Cairo project configuration
└── scripts/                # Deployment and utility scripts
    ├── declarecontract.sh  # Declare contract on StarkNet
    ├── deploycontract.sh   # Deploy contract on StarkNet
    └── generate_abi.sh     # Generate ABI from compiled contract
```

## Setup

### Prerequisites

- Node.js 16+
- StarkNet wallet (like ArgentX or Braavos) for browser client
- Access to a StarkNet node (or use a public RPC provider)
- Scarb (Cairo package manager) for smart contract development

### Smart Contract Development

```bash
# Install Scarb (if not already installed)
curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | sh

# Compile the contract
scarb build

# Run tests
scarb test

# Generate ABI
./generate_abi.sh
```

### Frontend Development

```bash
# Install dependencies
npm install

# Build the project
npm run build

# Start the development server
npm run start
```

### Contract Deployment

The contract can be deployed to StarkNet using Starknet Foundry and the provided scripts:

```bash
# Declare the contract
./declarecontract.sh

# Deploy the contract
./deploycontract.sh
```

## Browser Client Usage

1. Open the application in your browser
2. Connect your StarkNet wallet (ArgentX or Braavos)
3. Select a PDF file to sign
4. Choose a signature level (SES, AES, QES)
5. Submit the transaction with your wallet
6. View and save the signature details

The browser client uses version 5.14.1 of the Starknet.js library for better wallet compatibility.

## Node.js Client Usage

```typescript
import { signPdfWithStarknet } from './frontend/pdf_sign';

// Sign a document
const result = await signPdfWithStarknet(
  '/path/to/document.pdf',
  'SES',  // Signature level: SES, AES, or QES
  31536000  // Validity period in seconds (1 year)
);

console.log('Document ID:', result.document_id);
console.log('Transaction hash:', result.transaction_hash);
```

The Node.js client uses version 6.23.1 of the Starknet.js library for server-side signing.

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

## Contract Addresses

### Sepolia Testnet
```
0x0784ba229bb245ebf3322f9cb637d67551afd677fe47aae6ad46ddb3818f7ed7
```

## Development and Contributing

To contribute to this project:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Make your changes
4. Run tests to ensure functionality
5. Commit your changes (`git commit -m 'Add some feature'`)
6. Push to the branch (`git push origin feature/your-feature`)
7. Create a new Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.