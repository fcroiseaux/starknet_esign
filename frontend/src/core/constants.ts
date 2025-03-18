import { shortString } from 'starknet';
import { ContractConfig, NetworkConfig } from './types';

/**
 * Signature levels as StarkNet felt252 values
 */
export const SIGNATURE_LEVELS = {
  // Qualified Electronic Signature - highest security level
  QES: BigInt(shortString.encodeShortString("QES")),
  
  // Advanced Electronic Signature - medium security level
  AES: BigInt(shortString.encodeShortString("AES")),
  
  // Simple Electronic Signature - basic security level
  SES: BigInt(shortString.encodeShortString("SES"))
} as const;

/**
 * Default validity period (1 year in seconds)
 */
export const DEFAULT_VALIDITY_PERIOD = 31536000;

/**
 * Maximum felt252 value (2^251 - 1)
 */
export const MAX_FELT_VALUE = BigInt(2) ** BigInt(251) - BigInt(1);

/**
 * Contract configuration for different environments
 */
export const CONTRACT_CONFIG: ContractConfig = {
  // Contract address
  address: "0x0784ba229bb245ebf3322f9cb637d67551afd677fe47aae6ad46ddb3818f7ed7",
  
  // Default provider URL (can be overridden by environment-specific config)
  providerUrl: "https://starknet-sepolia.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161",
  
  // Default validity period
  defaultValidityPeriod: DEFAULT_VALIDITY_PERIOD
};

/**
 * Network configurations
 */
export const NETWORKS: Record<string, NetworkConfig> = {
  SEPOLIA: {
    nodeUrl: "https://starknet-sepolia.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161",
    explorerUrl: "https://sepolia.voyager.online/tx/",
    chainId: "SN_SEPOLIA",
    name: "StarkNet Sepolia"
  },
  MAINNET: {
    nodeUrl: "https://starknet-mainnet.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161",
    explorerUrl: "https://voyager.online/tx/",
    chainId: "SN_MAIN",
    name: "StarkNet Mainnet"
  }
};