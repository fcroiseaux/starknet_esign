import { Account, Contract, RpcProvider, shortString, constants, ec } from 'starknet';

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
    
    // Get provider from wallet
    const provider = starknetWallet.provider;
    
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
    contract.connect(starknetWallet);
    
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
    const verification = await contract.call("verify_document_signature", [
      documentIdFelt,
      starknetWallet.address,
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
      signer_address: starknetWallet.address,
      signature_verified: isValid
    };
  } catch (error) {
    console.error("Error signing document:", error);
    throw error;
  }
}