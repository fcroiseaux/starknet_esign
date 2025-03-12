# eIDAS-Compliant Electronic Document Signing on Starknet

## Project Description

This project implements a Starknet smart contract for electronic document signing with eIDAS compliance, using an approach inspired by Ethereum's EIP-712 structured data signing. It allows for secure, verifiable digital signatures on documents with multiple levels of legal compliance as defined by the European Union's electronic IDentification, Authentication and trust Services (eIDAS) regulation.

### Key Features

- **eIDAS Compliance**: Supports all three qualification levels:
  - QES (Qualified Electronic Signature) - highest level of trust
  - AES (Advanced Electronic Signature) - medium level
  - SES (Simple Electronic Signature) - basic level

- **Document Management**:
  - Sign documents with verifiable hashes
  - Verify document integrity
  - Revoke signatures when needed
  - Track document ownership

- **Security Features**:
  - Multi-round hashing for stronger security
  - Domain separation to prevent cross-domain attacks
  - Comprehensive revocation mechanism
  - Configurable signature validity periods
  - Signature nonce to prevent malleability

- **Access Control**:
  - Owner-managed system of authorized signers
  - Only authorized signers can create signatures
  - Only document owner or contract owner can revoke signatures

## Code Structure

### Smart Contract Components

- `src/utils/`: Utility modules:
  - `constants.cairo`: Common constants used throughout the project
  - `typed_data.cairo`: EIP-712 inspired data structures
  - `signature.cairo`: Document signature data structure
  - `events.cairo`: Event definitions

- `src/interfaces/`: Contract interfaces:
  - `iesg.cairo`: Electronic signature interface definitions

- `src/contracts/`: Contract implementations:
  - `esg.cairo`: Main electronic signature contract

- `src/tests/`: Test modules:
  - `test_esg.cairo`: Comprehensive test suite

### Client-Side Components

- `pdf_sign.ts`: Node.js TypeScript client for document signing
- `browser-pdf-sign.ts`: Browser-compatible TypeScript client
- `index.html`: Demo web interface for PDF signing
- `webpack.config.js`: Webpack configuration for bundling TypeScript code

## Testing and Deployment

### Testing the Smart Contract

1. Install Scarb (Cairo package manager):
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | sh
   ```

2. Clone the repository and navigate to the project directory:
   ```bash
   git clone https://github.com/yourusername/starknet_esign.git
   cd starknet_esign
   ```

3. Run the test suite:
   ```bash
   scarb test
   ```

### Deploying the Contract on Starknet

1. Build the smart contract:
   ```bash
   scarb build
   ```

2. Deploy to Starknet testnet using Starkli (or your preferred deployment tool):
   ```bash
   # First, set up your account and environment
   starkli declare target/dev/starknet_esign_ESG.sierra.json
   starkli deploy <CLASS_HASH> <CONSTRUCTOR_ARGS>
   ```

3. Make note of the contract address after deployment for client-side integration.

### Testing the Web Interface

1. Install Node.js dependencies:
   ```bash
   npm install
   ```

2. Update the contract address in `browser-pdf-sign.ts` and `pdf_sign.ts`:
   ```typescript
   const CONTRACT_ADDRESS = "0x..."; // Your deployed contract address
   ```

3. Build the TypeScript files:
   ```bash
   npm run build
   ```

4. Serve the application:
   ```bash
   npm run serve
   ```

5. Navigate to `http://localhost:8080` in your browser to use the interface.

## Usage Examples

### Smart Contract Usage (Cairo)

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

### Node.js Client Usage

```typescript
import { signPdfWithStarknet } from './pdf_sign';

// Sign a PDF document
const result = await signPdfWithStarknet(
  '/path/to/document.pdf',   // Path to PDF file
  'contract_2023_001'        // Document ID
);

console.log(`Transaction hash: ${result.transaction_hash}`);
console.log(`Signature verified: ${result.signature_verified}`);
```

### Browser Client Usage

```typescript
import { signPdfWithStarknet } from './browser-pdf-sign';

// File input from a form
const fileInput = document.getElementById('fileInput');
const file = fileInput.files[0];
const documentId = 'contract_2023_001';

// Convert file to ArrayBuffer
const arrayBuffer = await file.arrayBuffer();

// Sign the document (requires a connected Starknet wallet)
const result = await signPdfWithStarknet(
  arrayBuffer,
  documentId, 
  'QES',           // Signature level (QES, AES, or SES)
  starknetWallet   // Connected wallet from starknet.js
);

// Display the results
console.log(`Transaction hash: ${result.transaction_hash}`);
console.log(`Signature verified: ${result.signature_verified}`);
```

## Web Interface

The project includes a simple HTML interface (`index.html`) that demonstrates how to use the browser client:

1. Upload a PDF document
2. Enter a unique document ID
3. Select signature level (QES, AES, or SES)
4. Sign the document using a Starknet wallet
5. View transaction details and verification status

## Additional Information

### Dependencies

- **Starknet**: v2.3.0
- **OpenZeppelin**: v1.0.0 
- **Cairo**: v2.9.2
- **Node.js**: v16.0.0+
- **TypeScript**: v4.5.0+
- **Webpack**: v5.0.0+

### Security Considerations

- Always verify the contract address before signing documents
- Use appropriate eIDAS levels based on the document's legal requirements
- Consider the expiration time for signatures based on document relevance
- Be aware that document hashes are stored on-chain and are publicly visible

### Legal Disclaimer

This project is intended as a technical implementation of eIDAS-compliant electronic signatures. For actual legal compliance, please consult with a legal expert familiar with eIDAS regulations in your jurisdiction.

## Compatibility Notes

This project is built with Cairo 2023_01 edition for maximum stability and is fully compatible with OpenZeppelin for Cairo v1.0.0. The code follows the component-based architecture pattern recommended for Starknet contract development.