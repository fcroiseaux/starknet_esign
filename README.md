# StarkNet eSign

A blockchain-based electronic signature platform built on StarkNet that provides legally compliant document signing and verification.

## Overview

StarkNet eSign is a decentralized application (dApp) that enables secure document signing and verification using the StarkNet blockchain. The platform implements the European eIDAS regulation signature levels, providing a legally compliant framework for electronic signatures with different security levels.

## Key Features

- **Blockchain-Backed Signatures**: Immutable proof of document signatures stored on StarkNet
- **eIDAS Compliance**: Three signature security levels following European regulations:
  - **SES (Simple Electronic Signature)**: Basic signature for low-risk scenarios
  - **AES (Advanced Electronic Signature)**: Enhanced security with signer authentication
  - **QES (Qualified Electronic Signature)**: Highest security level, legally equivalent to handwritten signatures
- **Document Privacy**: Only document hashes are stored on-chain, not the actual content
- **Multi-Wallet Support**: Compatible with ArgentX and Braavos StarkNet wallets
- **Signature Lifecycle Management**: Includes expiration dates and revocation capabilities
- **Tamper Detection**: Cryptographic verification that documents haven't been modified
- **Modern React UI**: User-friendly interface for signing and verifying documents

## Architecture

StarkNet eSign follows a modern blockchain architecture with two primary components:

1. **Smart Contract Layer**: Cairo smart contracts deployed on StarkNet that handle:
   - Document signature creation and storage
   - Cryptographic verification
   - Signature lifecycle management

2. **Frontend Layer**: React-based web application that provides:
   - Wallet connection and management
   - Document hash generation
   - Interaction with smart contracts
   - User interface for signing and verification

## Project Structure

```
starknet_esign/
│
├── src/                                # Cairo smart contract code
│   ├── contracts/                      # Contract implementations
│   │   └── esg.cairo                   # Electronic Signature main contract
│   ├── interfaces/                     # Contract interfaces
│   │   └── iesg.cairo                  # Electronic Signature interface
│   ├── tests/                          # Contract test suite
│   │   └── test_esg.cairo              # Contract tests
│   ├── utils/                          # Utility modules
│   │   ├── constants.cairo             # Contract constants
│   │   ├── events.cairo                # Event definitions
│   │   ├── signature.cairo             # Signature utilities
│   │   └── typed_data.cairo            # EIP-712 style typed data
│   └── lib.cairo                       # Library exports
│
├── frontend/                           # React web application
│   ├── src/                            # Frontend source code
│   │   ├── components/                 # React components
│   │   │   ├── App.tsx                 # Main application component
│   │   │   ├── SignatureForm.tsx       # Document signing form
│   │   │   ├── VerifySignature.tsx     # Signature verification component
│   │   │   └── WalletConnection.tsx    # Wallet connection component
│   │   ├── services/                   # Service layer
│   │   │   ├── signatureService.ts     # Signature operations service
│   │   │   └── walletService.ts        # Wallet management service
│   │   ├── hooks/                      # Custom React hooks
│   │   │   └── useWallet.ts            # Wallet state management hook
│   │   ├── adapters/                   # Platform adapters
│   │   │   ├── browser.ts              # Browser-specific implementations
│   │   │   └── node.ts                 # Node.js specific implementations
│   │   ├── core/                       # Core business logic
│   │   │   ├── constants.ts            # Application constants
│   │   │   ├── signature.ts            # Signature handling logic
│   │   │   └── types.ts                # TypeScript type definitions
│   │   ├── index.tsx                   # Application entry point
│   │   ├── index.html                  # HTML template
│   │   └── styles.css                  # Global styles
│   ├── tsconfig.json                   # TypeScript configuration
│   ├── package.json                    # Frontend dependencies
│   └── webpack.config.js               # Build configuration
│
├── abi/                                # Contract Application Binary Interface
│   └── ElectronicSignature.json        # ABI for the main contract
│
├── scripts/                            # Deployment scripts
│   ├── declarecontract.sh              # Script to declare contract
│   ├── deploycontract.sh               # Script to deploy contract
│   └── generate_abi.sh                 # Script to generate ABI
│
├── Scarb.toml                          # Cairo project configuration
├── snfoundry.toml                      # StarkNet Foundry configuration
├── package.json                        # Root package dependencies
└── README.md                           # Project documentation
```

## Getting Started

### Prerequisites

- Node.js 16+ 
- Scarb (Cairo package manager)
- StarkNet wallet (ArgentX or Braavos) 
- Access to a StarkNet node (Infura, Alchemy, or other RPC provider)

### Smart Contract Development

```bash
# Install Scarb
curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | sh

# Build the Cairo contracts
scarb build

# Run contract tests
scarb test

# Generate contract ABI
./generate_abi.sh
```

### Frontend Development

```bash
# Navigate to frontend directory
cd frontend

# Install dependencies
npm install

# Start development server
npm run dev

# Build for production
npm run build
```

### Deploying the Contract

```bash
# Declare contract (makes it available on StarkNet)
./declarecontract.sh

# Deploy an instance of the contract
./deploycontract.sh
```

## Using the Application

### Signing a Document

1. Visit the application and connect your StarkNet wallet
2. Navigate to the "Sign Document" tab
3. Upload a PDF document
4. Select the signature security level (SES, AES, or QES)
5. Confirm the transaction in your wallet
6. Save the returned document ID for future verification

### Verifying a Signature

1. Navigate to the "Verify Signature" tab
2. Upload the previously signed PDF document
3. Enter the document ID and signer's address
4. Click "Verify Signature"
5. View the verification results showing signature status and details

## Technical Details

### Document Signing Process

1. The document is hashed client-side using SHA-256
2. A unique document ID is generated on-chain based on multiple factors
3. The document hash, signer address, signature level, and expiration time are stored on-chain
4. A blockchain transaction is created and signed by the user's wallet
5. The smart contract emits a DocumentSigned event

### Signature Verification

1. The document is hashed client-side using the same algorithm
2. The smart contract retrieves the stored signature data using the document ID
3. The contract verifies:
   - The stored hash matches the provided document hash
   - The signature has not expired
   - The signature has not been revoked
4. Verification results are returned to the user

## Contract Address

**Sepolia Testnet**
```
0x0784ba229bb245ebf3322f9cb637d67551afd677fe47aae6ad46ddb3818f7ed7
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License