import fs from 'fs';
import { createHash } from 'crypto';
import { Account, Contract, RpcProvider, shortString, constants, ec } from 'starknet';

// Constants
const CONTRACT_ADDRESS = "0x01234567890123456789012345678901234567890123456789"; // Replace with your contract address
const PRIVATE_KEY = "0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"; // Replace with your private key
const ACCOUNT_ADDRESS = "0x0123456789abcdef0123456789abcdef0123456789abcdef"; // Replace with your account address
const PROVIDER_URL = "http://localhost:5050"; // Or mainnet: "https://alpha-mainnet.starknet.io"

// Signature level constants
const QES_LEVEL = BigInt(shortString.encodeShortString("QES")); // Qualified Electronic Signature
const AES_LEVEL = BigInt(shortString.encodeShortString("AES")); // Advanced Electronic Signature
const SES_LEVEL = BigInt(shortString.encodeShortString("SES")); // Simple Electronic Signature

/**
 * Calculate SHA-256 hash of a PDF file and convert to BigInt for felt252 compatibility
 */
async function getPdfHash(pdfPath: string): Promise<bigint> {
  // Check if file exists
  if (!fs.existsSync(pdfPath)) {
    throw new Error(`PDF file not found: ${pdfPath}`);
  }
  
  // Read file and calculate hash
  const pdfContent = fs.readFileSync(pdfPath);
  const hash = createHash('sha256').update(pdfContent).digest('hex');
  
  // Convert to BigInt for felt252 compatibility
  const hashBigInt = BigInt('0x' + hash);
  
  // Ensure the hash fits within felt252 range (252 bits)
  const maxFelt = BigInt(2)**BigInt(251) - BigInt(1);
  if (hashBigInt > maxFelt) {
    return hashBigInt % maxFelt;
  }
  
  return hashBigInt;
}

/**
 * Sign a PDF file with your Starknet wallet address
 * 
 * @param pdfPath Path to the PDF file
 * @param documentId Unique identifier for the document (as string that will be converted to felt252)
 */
async function signPdfWithStarknet(pdfPath: string, documentId: string): Promise<any> {
  try {
    // Initialize Starknet provider
    const provider = new RpcProvider({ nodeUrl: PROVIDER_URL });
    
    // Initialize account
    const account = new Account(
      provider,
      ACCOUNT_ADDRESS,
      PRIVATE_KEY
    );
    
    // Calculate PDF hash
    const pdfHash = await getPdfHash(pdfPath);
    console.log(`PDF hash: ${pdfHash.toString()}`);
    
    // Convert hash to an array of felt252 values
    // This simplified version just puts the hash in a single element array
    const documentData = [pdfHash];
    
    // Get contract ABI (typically you'd load this from a file)
    // For this example, we'll just define the function we need
    const contractInterface = [
      {
        name: "sign_document",
        type: "function",
        inputs: [
          { name: "document_id", type: "felt252" },
          { name: "document_data", type: "felt252*" },
          { name: "signature_level", type: "felt252" },
          { name: "validity_period", type: "u64" }
        ],
        outputs: []
      },
      {
        name: "verify_document_signature",
        type: "function",
        inputs: [
          { name: "document_id", type: "felt252" },
          { name: "signer", type: "felt252" },
          { name: "document_data", type: "felt252*" }
        ],
        outputs: [{ name: "is_valid", type: "bool" }]
      }
    ];
    
    // Create contract instance
    const contract = new Contract(
      contractInterface,
      CONTRACT_ADDRESS,
      provider
    );
    contract.connect(account);
    
    // Set signature parameters
    const signatureLevel = SES_LEVEL; // Simple Electronic Signature level
    const validityPeriod = BigInt(31536000); // 1 year in seconds
    
    // Convert document ID to felt252
    const documentIdFelt = BigInt(shortString.encodeShortString(documentId));
    
    // Sign document with your Starknet account
    console.log("Signing document with Starknet address...");
    const signResult = await contract.invoke("sign_document", [
      documentIdFelt,
      documentData,
      signatureLevel,
      validityPeriod
    ]);
    
    // Wait for transaction
    const receipt = await provider.waitForTransaction(signResult.transaction_hash);
    
    console.log(`Document signed successfully! Transaction hash: ${signResult.transaction_hash}`);
    
    // Verify signature
    console.log("Verifying signature...");
    const verification = await contract.call("verify_document_signature", [
      documentIdFelt,
      ACCOUNT_ADDRESS,
      documentData
    ]);
    
    // In newer versions, the result is returned differently
    const isValid = Array.isArray(verification) && verification.length > 0
        ? Boolean(verification[0]) 
        : Boolean((verification as any).is_valid)
    
    if (isValid) {
      console.log("✅ Signature verified successfully!");
    } else {
      console.log("❌ Signature verification failed!");
    }
    
    return {
      document_id: documentId,
      transaction_hash: signResult.transaction_hash,
      signer_address: ACCOUNT_ADDRESS,
      signature_verified: isValid
    };
  } catch (error) {
    console.error("Error signing document:", error);
    throw error;
  }
}

// Run the example
if (require.main === module) {
  // Check command line arguments
  if (process.argv.length !== 4) {
    console.log("Usage: ts-node pdf_sign.ts [pdf_path] [document_id]");
    process.exit(1);
  }
  
  const pdfPath = process.argv[2];
  const documentId = process.argv[3];
  
  signPdfWithStarknet(pdfPath, documentId)
    .then(result => {
      console.log("\nResult:");
      Object.entries(result).forEach(([key, value]) => {
        console.log(`${key}: ${value}`);
      });
    })
    .catch(error => {
      console.error("Failed to sign document:", error);
      process.exit(1);
    });
}

export { signPdfWithStarknet, getPdfHash };