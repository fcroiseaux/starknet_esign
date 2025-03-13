declare global {
    interface Window {
        starknet: any;
    }
}
/**
 * Calculate SHA-256 hash of PDF file data and convert to BigInt for felt252 compatibility
 */
export declare function getPdfHash(pdfData: ArrayBuffer): Promise<bigint>;
/**
 * Sign a PDF file with your Starknet wallet address
 *
 * @param pdfData ArrayBuffer containing the PDF data
 * @param documentId Unique identifier for the document
 * @param signatureLevel Signature level (QES, AES, or SES)
 * @param starknetWallet Connected wallet object from starknet.js
 */
export declare function signPdfWithStarknet(pdfData: ArrayBuffer, documentId: string, signatureLevel: string | undefined, starknetWallet: any): Promise<any>;
