/**
 * Calculate SHA-256 hash of a PDF file and convert to BigInt for felt252 compatibility
 */
declare function getPdfHash(pdfPath: string): Promise<bigint>;
/**
 * Sign a PDF file with your Starknet wallet address
 *
 * @param pdfPath Path to the PDF file
 * @param documentId Unique identifier for the document (as string that will be converted to felt252)
 */
declare function signPdfWithStarknet(pdfPath: string, documentId: string): Promise<any>;
export { signPdfWithStarknet, getPdfHash };
