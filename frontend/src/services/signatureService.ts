import { Contract, RpcProvider } from 'starknet';

// Import core modules
import { SignatureResult, SignatureLevel, VerificationResult } from '../core/types';
import { CONTRACT_CONFIG, NETWORKS, SIGNATURE_LEVELS } from '../core/constants';
import { signDocument as signDocumentCore } from '../core/signature';

// Import browser-specific adapter
import { 
  calculateDocumentHash, 
  fetchContractABI, 
  getProviderFromWallet, 
  connectWalletToContract,
  verifySignature as verifySignatureCore
} from '../adapters/browser';

// Add typings for window object to include StarkNet wallet
declare global {
  interface Window {
    starknet: any;
  }
}

// Configuration constants
const CONFIG = {
  // Contract address for the electronic signature contract
  CONTRACT_ADDRESS: CONTRACT_CONFIG.address,
  
  // Network configurations
  NETWORK: NETWORKS,
  
  // Active network
  ACTIVE_NETWORK: "SEPOLIA",
  
  // Default signature validity period (1 year in seconds)
  DEFAULT_VALIDITY_PERIOD: CONTRACT_CONFIG.defaultValidityPeriod,
  
  // Path to ABI file
  ABI_PATH: '../abi/ElectronicSignature.json'
};

/**
 * Calculate SHA-256 hash of PDF file data for StarkNet felt252 compatibility
 * 
 * @param pdfData - ArrayBuffer containing the PDF binary data
 * @returns A BigInt representation of the document hash
 */
export async function getPdfHash(pdfData: ArrayBuffer): Promise<bigint> {
  return calculateDocumentHash(pdfData);
}

/**
 * Sign a PDF document with a StarkNet wallet
 * 
 * @param pdfData - ArrayBuffer containing the PDF data
 * @param signatureLevel - eIDAS signature level (QES, AES, or SES)
 * @param validityPeriod - How long the signature remains valid in seconds (0 = 1 year default)
 * @param starknetWallet - Connected StarkNet wallet object
 * @returns Object containing signature details
 */
export async function signPdfWithStarknet(
  pdfData: ArrayBuffer, 
  signatureLevel: SignatureLevel = 'SES',
  validityPeriod: number = 0,
  starknetWallet: any
): Promise<SignatureResult> {
  // Validate wallet connection
  if (!starknetWallet) {
    throw new Error("StarkNet wallet not connected. Please connect your wallet first.");
  }
  
  // Perform additional checks on the wallet object to ensure it's valid
  console.log("Wallet for signing:", starknetWallet);
  
  // Check if wallet is an empty object or array
  if (
    (typeof starknetWallet === 'object' && !Array.isArray(starknetWallet) && Object.keys(starknetWallet).length === 0) ||
    (Array.isArray(starknetWallet) && starknetWallet.length === 0)
  ) {
    throw new Error("StarkNet wallet appears to be empty. Please reconnect your wallet.");
  }
  
  // If wallet is an array with addresses, that's valid for ArgentX
  if (Array.isArray(starknetWallet) && starknetWallet.length > 0) {
    console.log("Wallet is an array with addresses, using ArgentX format");
  }
  
  try {
    // Calculate document hash
    console.log("Calculating document hash...");
    const documentHash = await calculateDocumentHash(pdfData);
    console.log(`Document hash: 0x${documentHash.toString(16)}`);
    
    // Load ABI
    const contractABI = await fetchContractABI(CONFIG.ABI_PATH);
    
    // Get provider and connect wallet
    const network = CONFIG.NETWORK[CONFIG.ACTIVE_NETWORK as keyof typeof CONFIG.NETWORK];
    
    // Check for common wallet types and adapt if needed
    let adaptedWallet = starknetWallet;
    
    // Check for ArgentX specifics
    if (starknetWallet.isArgent === true) {
      console.log("Detected ArgentX wallet - using appropriate structure");
    }
    
    // Check for Braavos specifics
    if (starknetWallet.isBraavos === true) {
      console.log("Detected Braavos wallet - using appropriate structure");
    }
    
    // Additional starknet.js v5 specific check
    if (Array.isArray(starknetWallet) && starknetWallet.length > 0) {
      console.log("Wallet appears to be an array of accounts - using first account");
      if (starknetWallet[0]) {
        adaptedWallet = {
          account: window.starknet.account,
          selectedAddress: starknetWallet[0]
        };
      }
    }
    
    // Get a provider from the adapted wallet
    const provider = getProviderFromWallet(adaptedWallet, network.nodeUrl);
    
    // Set validity period
    const validityPeriodBigInt = validityPeriod > 0 
      ? BigInt(validityPeriod) 
      : BigInt(CONFIG.DEFAULT_VALIDITY_PERIOD);
    
    // Use the core signDocument function
    return await signDocumentCore(
      documentHash,
      signatureLevel,
      validityPeriodBigInt,
      contractABI,
      CONFIG.CONTRACT_ADDRESS,
      provider,
      adaptedWallet
    );
  } catch (error) {
    console.error("Error signing document:", error);
    throw new Error(`Error signing document: ${error instanceof Error ? error.message : String(error)}`);
  }
}

/**
 * Verify a PDF document signature on StarkNet
 * 
 * @param documentId - ID of the document to verify
 * @param signerAddress - Address of the claimed signer
 * @param pdfData - ArrayBuffer containing the PDF data to verify
 * @param starknetWallet - Optional Connected StarkNet wallet object
 * @returns Object containing verification result and details
 */
export async function verifyPdfSignature(
  documentId: string,
  signerAddress: string,
  pdfData: ArrayBuffer,
  starknetWallet?: any
): Promise<VerificationResult> {
  try {
    // Calculate document hash
    console.log("Calculating document hash for verification...");
    const documentHash = await calculateDocumentHash(pdfData);
    console.log(`Document hash: 0x${documentHash.toString(16)}`);
    
    // Load contract ABI
    const contractABI = await fetchContractABI(CONFIG.ABI_PATH);
    
    // Use wallet's provider if provided, otherwise use a default provider
    const network = CONFIG.NETWORK[CONFIG.ACTIVE_NETWORK as keyof typeof CONFIG.NETWORK];
    let provider: RpcProvider;
    
    try {
      if (starknetWallet) {
        provider = getProviderFromWallet(starknetWallet, network.nodeUrl);
      } else {
        // Create a read-only provider using the network's node URL
        console.log("Creating new RpcProvider with URL:", network.nodeUrl);
        provider = new RpcProvider({ nodeUrl: network.nodeUrl });
      }
    } catch (error) {
      console.warn("Error creating provider:", error);
      console.log("Creating fallback provider object");
      
      // Create a minimal provider that will trigger the fallback contract implementation
      provider = {
        nodeUrl: network.nodeUrl
      } as any;
    }
    
    // Call the verification function
    return await verifySignatureCore(
      documentId,
      signerAddress,
      documentHash,
      contractABI,
      CONFIG.CONTRACT_ADDRESS,
      provider
    );
  } catch (error) {
    console.error("Error verifying document:", error);
    throw new Error(`Error verifying document: ${error instanceof Error ? error.message : String(error)}`);
  }
}

/**
 * Sign a PDF document with a StarkNet wallet
 * 
 * @param pdfData ArrayBuffer containing the PDF data
 * @param signatureLevel eIDAS signature level (QES, AES, or SES)
 * @param validityPeriod How long the signature remains valid in seconds (0 = 1 year default)
 * @param starknetWallet Connected StarkNet wallet object
 * @returns Object containing signature details
 */
export async function signDocument(
  pdfData: ArrayBuffer,
  signatureLevel: SignatureLevel,
  validityPeriod: number,
  starknetWallet: any
): Promise<SignatureResult> {
  if (!starknetWallet) {
    throw new Error("StarkNet wallet not connected. Please connect your wallet first.");
  }
  
  // Additional check to make sure wallet is valid
  // ArgentX wallet can return an array of addresses
  if (Array.isArray(starknetWallet)) {
    if (starknetWallet.length === 0) {
      console.error("Wallet array is empty:", starknetWallet);
      throw new Error("Invalid StarkNet wallet. Please reconnect your wallet.");
    }
    console.log("Wallet appears to be an array of addresses, which is valid for ArgentX:", starknetWallet);
    // This is valid - array of addresses from ArgentX wallet
  } else if (
    typeof starknetWallet !== 'object' || 
    (!starknetWallet.account && !starknetWallet.provider && typeof starknetWallet.enable !== 'function')
  ) {
    console.error("Invalid wallet object:", starknetWallet);
    throw new Error("Invalid StarkNet wallet. Please reconnect your wallet.");
  }
  
  try {
    return await signPdfWithStarknet(
      pdfData,
      signatureLevel,
      validityPeriod,
      starknetWallet
    );
  } catch (error) {
    console.error("Error signing document:", error);
    throw new Error(`Error signing document: ${error instanceof Error ? error.message : String(error)}`);
  }
}

/**
 * Verify a document signature on StarkNet
 * 
 * @param documentId Document ID from the original signature
 * @param signerAddress Original signer's address
 * @param pdfData PDF file data as ArrayBuffer
 * @param starknetWallet Connected StarkNet wallet object (optional, will use provider only)
 * @returns Verification result with validity status and details
 */
export async function verifySignature(
  documentId: string,
  signerAddress: string,
  pdfData: ArrayBuffer,
  starknetWallet?: any
): Promise<VerificationResult> {
  try {
    return await verifyPdfSignature(
      documentId,
      signerAddress,
      pdfData,
      starknetWallet
    );
  } catch (error) {
    console.error("Error verifying signature:", error);
    throw new Error(`Error verifying signature: ${error instanceof Error ? error.message : String(error)}`);
  }
}