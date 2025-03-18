import { signPdfWithStarknet, verifyPdfSignature } from '../../browser-pdf-sign';
import type { SignatureLevel } from '../core/types';

export interface SignatureResult {
  document_id: string;
  transaction_hash: string;
  signer_address: string;
  signature_verified: boolean;
  monitored?: boolean;
}

export interface VerificationResult {
  isValid: boolean;
  details?: {
    signatureLevel?: string;
    timestamp?: Date;
    expiration?: Date;
    isRevoked?: boolean;
  };
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