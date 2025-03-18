import { RpcProvider, Contract } from 'starknet';
import { MAX_FELT_VALUE } from '../core/constants';
import { NetworkConfig } from '../core/types';

/**
 * Calculate SHA-256 hash of PDF file data using Web Crypto API
 * 
 * @param pdfData - ArrayBuffer containing the PDF binary data
 * @returns A BigInt representation of the document hash
 */
export async function calculateDocumentHash(pdfData: ArrayBuffer): Promise<bigint> {
  try {
    // Convert ArrayBuffer to Uint8Array for hashing
    const pdfUint8Array = new Uint8Array(pdfData);
    
    // Calculate SHA-256 hash using Web Crypto API
    const hashBuffer = await crypto.subtle.digest('SHA-256', pdfUint8Array);
    
    // Convert to hex string
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
    
    // Convert to BigInt for felt252 compatibility
    const hashBigInt = BigInt('0x' + hashHex);
    
    // Ensure the hash fits within StarkNet's felt252 range
    return hashBigInt > MAX_FELT_VALUE ? hashBigInt % MAX_FELT_VALUE : hashBigInt;
  } catch (error) {
    console.error("Error calculating document hash:", error);
    throw new Error(`Failed to calculate document hash: ${error instanceof Error ? error.message : String(error)}`);
  }
}

/**
 * Fetch contract ABI from a URL or path
 * 
 * @param abiPath - Path or URL to the ABI file
 * @returns The contract ABI
 */
export async function fetchContractABI(abiPath: string): Promise<any> {
  console.log(`Fetching contract ABI from: ${abiPath}`);
  const response = await fetch(abiPath);
  
  if (!response.ok) {
    throw new Error(`Failed to fetch ABI: ${response.status} ${response.statusText}`);
  }
  
  const data = await response.json();
  
  // Extract ABI from the response (handle different formats)
  const abi = data.abi || data;
  
  if (!abi || abi.length === 0) {
    throw new Error(`ABI is empty or missing in the response`);
  }
  
  console.log(`Successfully loaded ABI with ${abi.length} entries`);
  return abi;
}

/**
 * Get provider from wallet or create a new one
 * 
 * @param wallet - StarkNet wallet instance
 * @param defaultNodeUrl - Default RPC endpoint if wallet doesn't provide one
 * @returns RPC Provider
 */
export function getProviderFromWallet(wallet: any, defaultNodeUrl: string): RpcProvider {
  console.log("Getting provider from wallet:", wallet);
  
  // Try all possible paths to find a provider
  
  // Direct provider property (most common)
  if (wallet.provider) {
    console.log("Using wallet.provider");
    return wallet.provider;
  } 
  
  // Account's provider (common in v5+)
  if (wallet.account?.provider) {
    console.log("Using wallet.account.provider");
    return wallet.account.provider;
  }
  
  // Provider in wallet.provider.provider (nested structure in some wallets)
  if (wallet.provider?.provider) {
    console.log("Using wallet.provider.provider");
    return wallet.provider.provider;
  }
  
  // Check if wallet itself is a provider
  if (typeof wallet.getChainId === 'function' && typeof wallet.getBlock === 'function') {
    console.log("Wallet itself appears to be a provider");
    return wallet;
  }
  
  // ArgentX specific structure
  if (wallet.starknet?.provider) {
    console.log("Using wallet.starknet.provider (ArgentX structure)");
    return wallet.starknet.provider;
  }
  
  // Last resort - create a new provider with the default URL
  console.log(`No provider found in wallet. Using default RPC provider: ${defaultNodeUrl}`);
  const provider = new RpcProvider({ nodeUrl: defaultNodeUrl });
  
  // Try to attach the provider to the wallet for future use
  try {
    if (!wallet.provider) {
      wallet.provider = provider;
    }
  } catch (err) {
    console.warn("Could not attach provider to wallet:", err);
  }
  
  return provider;
}

/**
 * Connect wallet to contract
 * 
 * @param contract - Contract instance
 * @param wallet - StarkNet wallet
 */
export function connectWalletToContract(contract: any, wallet: any): void {
  if (wallet.account) {
    contract.connect(wallet.account);
  } else {
    contract.connect(wallet);
  }
}

/**
 * Verify a document signature on StarkNet
 * 
 * @param documentId - Document ID for the signature to verify
 * @param signerAddress - Address of the original signer
 * @param documentHash - Hash of the document content
 * @param contractAbi - Contract ABI
 * @param contractAddress - Contract address
 * @param provider - StarkNet provider
 * @returns Verification result including validity and details
 */
export async function verifySignature(
  documentId: string | bigint,
  signerAddress: string,
  documentHash: bigint,
  contractAbi: any,
  contractAddress: string,
  provider: any
): Promise<{
  isValid: boolean,
  details?: {
    signatureLevel?: string,
    timestamp?: Date,
    expiration?: Date,
    isRevoked?: boolean
  }
}> {
  console.log(`Verifying signature for document ID: ${documentId}`);
  console.log(`Signer address: ${signerAddress}`);
  console.log(`Document hash: ${documentHash}`);
  console.log(`Contract address: ${contractAddress}`);
  console.log(`Provider:`, provider);
  
  // Create contract instance
  let contract;
  
  // Use the starknet.js Contract constructor directly if available
  if (typeof Contract !== 'undefined') {
    console.log("Using imported Contract constructor");
    contract = new Contract(contractAbi, contractAddress, provider);
  } else {
    // Try with RpcProvider's method
    try {
      console.log("Using provider.getContract method");
      // Check if provider has callContract method
      if (typeof provider.callContract === 'function') {
        contract = {
          call: async (method: string, args: any[]) => {
            return await provider.callContract({
              contractAddress,
              entrypoint: method,
              calldata: args.map(arg => arg.toString())
            });
          }
        };
      } else {
        // No fallback implementation - simply throw an error if blockchain connection fails
        console.log("No blockchain connection available - refusing to provide fallback verification");
        throw new Error("Cannot connect to blockchain. Please check your internet connection and try again.");
      }
    } catch (err) {
      console.error("Error creating contract interface:", err);
      throw new Error("Could not create Contract interface");
    }
  }
  
  // Convert documentId to BigInt if it's a string
  const documentIdBigInt = typeof documentId === 'string'
    ? (documentId.startsWith('0x') ? BigInt(documentId) : BigInt(parseInt(documentId)))
    : documentId;
  
  // Call the verification function with better error handling
  let result;
  try {
    console.log("Calling contract.call with verify_document_signature");
    console.log("Args:", [documentIdBigInt.toString(), signerAddress, [documentHash.toString()]]);
    
    result = await contract.call("verify_document_signature", [
      documentIdBigInt,
      signerAddress,
      [documentHash]
    ]);
    
    console.log("Raw verification result:", result);
  } catch (error) {
    console.error("Error calling verify_document_signature:", error);
    throw new Error(`Blockchain verification failed: ${error instanceof Error ? error.message : String(error)}`);
  }
  
  // Process result based on StarkNet.js versions
  const isValid = result;
      
  console.log("Processed verification result, isValid:", isValid);
  
  // Try to get additional signature details
  try {
    console.log("Calling get_signature for additional details");
    console.log("Args:", [documentIdBigInt.toString(), signerAddress]);
    
    const signatureDetails = await contract.call("get_signature", [
      documentIdBigInt,
      signerAddress
    ]);
    
    console.log("Raw signature details:", signatureDetails);
    
    if (signatureDetails) {
      let details: any = {};
      
      // Parse details based on response format
      if (Array.isArray(signatureDetails)) {
        console.log("Parsing array signature details format");
        details = {
          signatureLevel: signatureDetails[4] ? hexToString(signatureDetails[4].toString(16)) : undefined,
          timestamp: signatureDetails[3] ? new Date(Number(signatureDetails[3]) * 1000) : undefined,
          expiration: signatureDetails[6] ? new Date(Number(signatureDetails[6]) * 1000) : undefined,
          isRevoked: Boolean(signatureDetails[5])
        };
      } else {
        console.log("Parsing object signature details format");
        details = {
          signatureLevel: signatureDetails.signature_level ? hexToString(signatureDetails.signature_level.toString(16)) : undefined,
          timestamp: signatureDetails.timestamp ? new Date(Number(signatureDetails.timestamp) * 1000) : undefined,
          expiration: signatureDetails.expiration_time ? new Date(Number(signatureDetails.expiration_time) * 1000) : undefined,
          isRevoked: Boolean(signatureDetails.is_revoked)
        };
      }
      
      console.log("Processed signature details:", details);
      return { isValid, details };
    }
  } catch (error) {
    console.error("Error getting signature details:", error);
    // Continue even if signature details fail - we already have the validation result
  }
  
  // Return basic result if details couldn't be fetched
  return { isValid };
}

/**
 * Convert hex string to ASCII string
 */
function hexToString(hex: string): string {
  if (!hex.startsWith('0x')) {
    hex = '0x' + hex;
  }
  
  try {
    let str = '';
    for (let i = 2; i < hex.length; i += 2) {
      const charCode = parseInt(hex.substr(i, 2), 16);
      if (charCode === 0) break;
      str += String.fromCharCode(charCode);
    }
    return str;
  } catch (err) {
    console.error('Error converting hex to string:', err);
    return hex;
  }
}