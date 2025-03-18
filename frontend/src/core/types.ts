/**
 * Common type definitions for the StarkNet Electronic Signature application
 */

/**
 * Result of a document signing operation
 */
export interface SignatureResult {
  document_id: string;
  transaction_hash: string;
  signer_address: string;
  signature_verified: boolean;
  
  // Whether transaction was successfully monitored
  // If false, the user should check the explorer
  monitored?: boolean;
}

/**
 * Result of a signature verification operation
 */
export interface VerificationResult {
  isValid: boolean;
  details?: {
    signatureLevel?: string;
    timestamp?: Date;
    expiration?: Date;
    isRevoked?: boolean;
  };
  // Flag to indicate verification was done in offline mode
  // This means blockchain verification was not possible
  offlineMode?: boolean;
}

/**
 * Configuration for contract interaction
 */
export interface ContractConfig {
  // Contract address
  address: string;
  
  // Provider URL for RPC connection
  providerUrl: string;
  
  // Optional explorer URL for transaction viewing
  explorerUrl?: string;
  
  // Default validity period in seconds (1 year)
  defaultValidityPeriod: number;
}

/**
 * Available signature levels following the eIDAS regulation
 */
export type SignatureLevel = 'QES' | 'AES' | 'SES';

/**
 * Supported networks for StarkNet
 */
export interface NetworkConfig {
  nodeUrl: string;
  explorerUrl: string;
  chainId: string;
  name: string;
}

/**
 * Transaction receipt with events
 * This extends the StarkNet.js types which may not include events in all versions
 */
export interface TransactionReceiptWithEvents {
  events?: Array<{
    keys?: string[];
    data?: string[];
    name?: string;
    args?: {
      document_id?: string;
      document_hash?: string;
      signer?: string;
      timestamp?: string;
      signature_level?: string;
      [key: string]: any;
    };
    [key: string]: any;
  }>;
  [key: string]: any;
}