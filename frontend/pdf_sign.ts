import { Account, Contract, RpcProvider } from 'starknet';

// Import core modules
import { SignatureResult, SignatureLevel } from './src/core/types';
import { CONTRACT_CONFIG } from './src/core/constants';
import { signDocument } from './src/core/signature';

// Import Node.js-specific adapter
import { calculateDocumentHash, loadContractABI } from './src/adapters/node';

// Configuration constants
const CONFIG = {
  // Contract address
  CONTRACT_ADDRESS: CONTRACT_CONFIG.address,
  
  // Account credentials
  PRIVATE_KEY: "0x48b8761cf8f5036c285242ecff21554fc3e2ef72b9e64efb4639020e50b1a73",
  ACCOUNT_ADDRESS: "0x34921f4dd82fe344decaa8de1367c4d7dbf8a4ba463133cc7d889b277c597a2",
  
  // Network configuration
  PROVIDER_URL: CONTRACT_CONFIG.providerUrl,
  
  // Default validity period
  DEFAULT_VALIDITY_PERIOD: CONTRACT_CONFIG.defaultValidityPeriod
};

/**
 * Calculate SHA-256 hash of a PDF file and convert to BigInt for felt252 compatibility
 * 
 * @param pdfPath Path to the PDF file
 * @returns BigInt representation of the document hash
 */
async function getPdfHash(pdfPath: string): Promise<bigint> {
  return calculateDocumentHash(pdfPath);
}

/**
 * Sign a PDF file with your Starknet wallet
 * 
 * @param pdfPath Path to the PDF file
 * @param signatureLevel Type of electronic signature (QES, AES, or SES)
 * @param validityPeriod How long the signature remains valid in seconds (0 = 1 year)
 * @returns Object containing signature details
 */
async function signPdfWithStarknet(
  pdfPath: string, 
  signatureLevel: SignatureLevel = 'SES',
  validityPeriod: number = 0
): Promise<SignatureResult> {
  try {
    // Initialize Starknet provider
    const provider = new RpcProvider({ nodeUrl: CONFIG.PROVIDER_URL });
    
    // Initialize account
    const account = new Account(
      provider,
      CONFIG.ACCOUNT_ADDRESS,
      CONFIG.PRIVATE_KEY
    );
    
    // Calculate document hash
    const documentHash = await calculateDocumentHash(pdfPath);
    console.log(`Document hash: 0x${documentHash.toString(16)}`);
    
    // Load contract ABI
    const contractABI = await loadContractABI();
    
    // Set validity period
    const validityPeriodBigInt = validityPeriod > 0 
      ? BigInt(validityPeriod) 
      : BigInt(CONFIG.DEFAULT_VALIDITY_PERIOD);
    
    // Use the core signDocument function
    return await signDocument(
      documentHash,
      signatureLevel,
      validityPeriodBigInt,
      contractABI,
      CONFIG.CONTRACT_ADDRESS,
      provider,
      account
    );
  } catch (error) {
    console.error("Error signing document:", error);
    throw error;
  }
}

// Run the CLI app if invoked directly
if (require.main === module) {
  // Check command line arguments
  if (process.argv.length < 3) {
    console.log("Usage: ts-node pdf_sign.ts [pdf_path] [signature_level] [validity_period]");
    console.log("  pdf_path:        Path to the PDF file to sign");
    console.log("  signature_level: (Optional) QES, AES, or SES (default: SES)");
    console.log("  validity_period: (Optional) Duration in seconds (default: 1 year)");
    process.exit(1);
  }
  
  // Parse command line arguments
  const pdfPath = process.argv[2];
  const signatureLevel = (process.argv[3] || 'SES') as SignatureLevel;
  const validityPeriod = process.argv[4] ? parseInt(process.argv[4]) : 0;
  
  // Validate signature level
  if (!['QES', 'AES', 'SES'].includes(signatureLevel)) {
    console.error(`Invalid signature level: ${signatureLevel}. Must be QES, AES, or SES.`);
    process.exit(1);
  }
  
  // Sign the document
  console.log(`Signing ${pdfPath} with ${signatureLevel} level, validity: ${validityPeriod || 'default (1 year)'}`);
  signPdfWithStarknet(pdfPath, signatureLevel, validityPeriod)
    .then(result => {
      console.log("\nSignature details:");
      console.table(result);
    })
    .catch(error => {
      console.error("Failed to sign document:", error);
      process.exit(1);
    });
}

// Export functions for use in other modules
export { signPdfWithStarknet, getPdfHash };