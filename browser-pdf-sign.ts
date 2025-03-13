import { Account, Contract, RpcProvider, shortString, constants, ec } from 'starknet';

// Add typings for window object to include Starknet
declare global {
  interface Window {
    starknet: any;
  }
}

// Constants - replace with your actual values
const CONTRACT_ADDRESS = "0x01234567890123456789012345678901234567890123456789";
const NODE_URL = "http://localhost:5050"; // Or mainnet: "https://alpha-mainnet.starknet.io"

// Signature level constants
const QES_LEVEL = BigInt(shortString.encodeShortString("QES")); // Qualified Electronic Signature
const AES_LEVEL = BigInt(shortString.encodeShortString("AES")); // Advanced Electronic Signature
const SES_LEVEL = BigInt(shortString.encodeShortString("SES")); // Simple Electronic Signature

/**
 * Calculate SHA-256 hash of PDF file data and convert to BigInt for felt252 compatibility
 */
export async function getPdfHash(pdfData: ArrayBuffer): Promise<bigint> {
  // Convert ArrayBuffer to Uint8Array
  const pdfUint8Array = new Uint8Array(pdfData);
  
  // Calculate SHA-256 hash
  const hashBuffer = await crypto.subtle.digest('SHA-256', pdfUint8Array);
  
  // Convert to hex string
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
  
  // Convert to BigInt for felt252 compatibility
  const hashBigInt = BigInt('0x' + hashHex);
  
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
 * @param pdfData ArrayBuffer containing the PDF data
 * @param documentId Unique identifier for the document
 * @param signatureLevel Signature level (QES, AES, or SES)
 * @param starknetWallet Connected wallet object from starknet.js 
 */
export async function signPdfWithStarknet(
  pdfData: ArrayBuffer, 
  documentId: string,
  signatureLevel: string = "SES",
  starknetWallet: any
): Promise<any> {
  try {
    if (!starknetWallet) {
      throw new Error("Starknet wallet not connected");
    }
    
    // Calculate PDF hash
    const pdfHash = await getPdfHash(pdfData);
    console.log(`PDF hash: ${pdfHash.toString()}`);
    
    // Convert hash to an array of felt252 values
    const documentData = [pdfHash];
    
    // Get provider from wallet, handling different wallet structures
    let provider;
    
    // Check if provider is directly available
    if (starknetWallet.provider) {
      provider = starknetWallet.provider;
    } else if (starknetWallet.account && starknetWallet.account.provider) {
      // Some wallets have provider within account object
      provider = starknetWallet.account.provider;
    } else {
      // If no provider found, create a default provider
      console.log("No provider found in wallet, creating default provider...");
      provider = new RpcProvider({ nodeUrl: NODE_URL });
    }
    
    // Get contract ABI (in a real implementation, you'd fetch this)
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
    // Handle different wallet connection types (Argent or other wallets)
    if (starknetWallet.account) {
      // Connect with account property (newer wallet style)
      contract.connect(starknetWallet.account);
    } else {
      // Connect with the wallet directly (older wallet style)
      contract.connect(starknetWallet);
    }
    
    // Determine signature level
    let sigLevelValue: bigint;
    switch (signatureLevel) {
      case "QES":
        sigLevelValue = QES_LEVEL;
        break;
      case "AES":
        sigLevelValue = AES_LEVEL;
        break;
      case "SES":
      default:
        sigLevelValue = SES_LEVEL;
        break;
    }
    
    // Set validity period (1 year in seconds)
    const validityPeriod = BigInt(31536000);
    
    // Convert document ID to felt252
    const documentIdFelt = BigInt(shortString.encodeShortString(documentId));
    
    // Sign document with your Starknet account
    console.log("Signing document with Starknet address...");
    const signResult = await contract.invoke("sign_document", [
      documentIdFelt,
      documentData,
      sigLevelValue,
      validityPeriod
    ]);
    
    // Wait for transaction
    const receipt = await provider.waitForTransaction(signResult.transaction_hash);
    
    console.log(`Document signed successfully! Transaction hash: ${signResult.transaction_hash}`);
    
    // Verify signature
    console.log("Verifying signature...");
    // Get wallet address based on wallet type, with more exhaustive checks
    let walletAddress;
    
    if (starknetWallet.selectedAddress) {
      walletAddress = starknetWallet.selectedAddress;
    } else if (starknetWallet.account?.address) {
      walletAddress = starknetWallet.account.address;
    } else if (starknetWallet.address) {
      walletAddress = starknetWallet.address;
    } else if (Array.isArray(starknetWallet.accounts) && starknetWallet.accounts.length > 0) {
      walletAddress = starknetWallet.accounts[0];
    } else if (typeof starknetWallet.getAccountAddress === 'function') {
      try {
        walletAddress = await starknetWallet.getAccountAddress();
      } catch (err) {
        console.error("Error calling getAccountAddress:", err);
      }
    } else {
      // Last resort - look for any property that might be an address
      for (const prop in starknetWallet) {
        if (typeof starknetWallet[prop] === 'string' && 
            starknetWallet[prop].startsWith('0x') && 
            starknetWallet[prop].length > 40) {
          console.log(`Using ${prop} as wallet address:`, starknetWallet[prop]);
          walletAddress = starknetWallet[prop];
          break;
        }
      }
    }
    
    if (!walletAddress) {
      throw new Error("Could not determine wallet address from wallet object");
    }
    
    const verification = await contract.call("verify_document_signature", [
      documentIdFelt,
      walletAddress,
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
      signer_address: walletAddress,
      signature_verified: isValid
    };
  } catch (error) {
    console.error("Error signing document:", error);
    throw error;
  }
}