import fs from 'fs';
import path from 'path';
import { createHash } from 'crypto';
import { MAX_FELT_VALUE } from '../core/constants';

/**
 * Calculate SHA-256 hash of a PDF file using Node.js crypto
 * 
 * @param pdfPath - Path to the PDF file
 * @returns A BigInt representation of the document hash
 */
export async function calculateDocumentHash(pdfPath: string): Promise<bigint> {
  // Check if file exists
  if (!fs.existsSync(pdfPath)) {
    throw new Error(`PDF file not found: ${pdfPath}`);
  }
  
  // Read file and calculate hash
  const pdfContent = fs.readFileSync(pdfPath);
  const hash = createHash('sha256').update(pdfContent).digest('hex');
  
  // Convert to BigInt for felt252 compatibility
  const hashBigInt = BigInt('0x' + hash);
  
  // Ensure the hash fits within felt252 range
  return hashBigInt > MAX_FELT_VALUE ? hashBigInt % MAX_FELT_VALUE : hashBigInt;
}

/**
 * Loads contract ABI from filesystem
 * 
 * @returns The contract ABI
 * @throws Error if the ABI cannot be loaded
 */
export async function loadContractABI(): Promise<any> {
  // Possible locations for the ABI file
  const abiPaths = [
    path.join(process.cwd(), 'target/dev/starknet_esign_ElectronicSignature.contract_class.json'),
    path.join(process.cwd(), 'target/release/starknet_esign_ElectronicSignature.contract_class.json'),
    path.join(process.cwd(), '.scarb/target/starknet_esign_ElectronicSignature.contract_class.json'),
    path.join(process.cwd(), 'build/starknet_esign_ElectronicSignature.contract_class.json'),
    path.join(process.cwd(), 'abi/ElectronicSignature.json')
  ];
  
  // Try each location
  for (const abiPath of abiPaths) {
    if (fs.existsSync(abiPath)) {
      try {
        // Read and parse the contract class JSON
        const contractClassJson = JSON.parse(fs.readFileSync(abiPath, 'utf8'));
        
        // Extract the ABI (different formats possible)
        const abi = contractClassJson.abi || contractClassJson.contract_class_abi;
        
        if (abi && abi.length > 0) {
          console.log(`Successfully loaded ABI from ${abiPath}`);
          return abi;
        }
      } catch (error) {
        console.warn(`Error parsing ABI from ${abiPath}:`, error);
      }
    }
  }
  
  // If we get here, no valid ABI was found
  throw new Error(
    `Contract ABI file not found. Tried the following paths:\n` +
    abiPaths.map(p => `- ${p}`).join('\n') +
    `\nPlease ensure the contract is compiled with Scarb before running.`
  );
}