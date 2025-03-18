import React, { useState, useRef, useEffect } from 'react';
import { verifySignature, VerificationResult } from '../services/signatureService';
import { useWallet } from '../hooks/useWallet';

const VerifySignature: React.FC = () => {
  const { wallet, address, isConnected } = useWallet();
  const [file, setFile] = useState<File | null>(null);
  const [documentId, setDocumentId] = useState('');
  const [signerAddress, setSignerAddress] = useState('');
  const [isVerifying, setIsVerifying] = useState(false);
  const [statusMessage, setStatusMessage] = useState('');
  const [statusType, setStatusType] = useState<'info' | 'success' | 'error'>('info');
  const [verificationResult, setVerificationResult] = useState<VerificationResult | null>(null);
  
  // Initialize signer address with connected wallet address
  useEffect(() => {
    if (isConnected && address) {
      setSignerAddress(address);
    }
  }, [isConnected, address]);
  
  const fileInputRef = useRef<HTMLInputElement>(null);
  
  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files.length > 0) {
      setFile(e.target.files[0]);
    }
  };
  
  const resetForm = () => {
    setFile(null);
    setDocumentId('');
    setSignerAddress('');
    setVerificationResult(null);
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
  };
  
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!file) {
      setStatusMessage('Please select a PDF file');
      setStatusType('error');
      return;
    }
    
    if (!documentId) {
      setStatusMessage('Please enter the document ID');
      setStatusType('error');
      return;
    }
    
    if (!signerAddress) {
      setStatusMessage('Please enter the signer address');
      setStatusType('error');
      return;
    }
    
    setIsVerifying(true);
    setStatusMessage('Verifying document signature...');
    setStatusType('info');
    
    try {
      // Read file as ArrayBuffer
      const arrayBuffer = await file.arrayBuffer();
      
      // Verify the document signature
      const result = await verifySignature(
        documentId,
        signerAddress,
        arrayBuffer,
        wallet // Optional, pass wallet if available
      );
      
      // Handle success
      setVerificationResult(result);
      if (result.isValid) {
        setStatusMessage('Signature verified successfully!');
        setStatusType('success');
      } else {
        setStatusMessage('Signature verification failed!');
        setStatusType('error');
      }
    } catch (error) {
      console.error('Error:', error);
      
      // Create a helpful error message
      let errorMessage = `Error verifying signature: ${error instanceof Error ? error.message : String(error)}`;
      
      // Check for common issues related to network connectivity
      if (errorMessage.includes("token") || errorMessage.includes("401") || errorMessage.includes("API") || 
          errorMessage.includes("network") || errorMessage.includes("provider") || errorMessage.includes("connection")) {
        
        // Clear any partial verification result
        setVerificationResult(null);
        
        // Set a clear error message about blockchain connectivity
        setStatusMessage("Error: Cannot connect to blockchain. Please check your internet connection and try again.");
        setStatusType('error');
      } else {
        // For other types of errors
        setStatusMessage(errorMessage);
        setVerificationResult(null);
        setStatusType('error');
      }
      // Don't overwrite the status type if it was already set in the conditional blocks
    } finally {
      setIsVerifying(false);
    }
  };
  
  const formatDate = (date?: Date) => {
    if (!date) return 'N/A';
    return new Date(date).toLocaleString();
  };
  
  return (
    <>
      <div className="card">
        <h2>Verify PDF Document Signature</h2>
        {isConnected && (
          <div className="connected-wallet-info">
            <p>Connected with wallet: <span className="wallet-pill">{address.substring(0, 6)}...{address.substring(address.length - 4)}</span></p>
          </div>
        )}
        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label htmlFor="fileInput">Select PDF File</label>
            <input 
              type="file" 
              id="fileInput" 
              accept=".pdf" 
              onChange={handleFileChange}
              ref={fileInputRef}
              disabled={isVerifying}
            />
          </div>
          
          <div className="form-group">
            <label htmlFor="documentId">Document ID</label>
            <input 
              type="text" 
              id="documentId" 
              value={documentId}
              onChange={(e) => setDocumentId(e.target.value)}
              placeholder="0x123..."
              disabled={isVerifying}
            />
          </div>
          
          <div className="form-group">
            <label htmlFor="signerAddress">Signer Address</label>
            <input 
              type="text" 
              id="signerAddress" 
              value={signerAddress}
              onChange={(e) => setSignerAddress(e.target.value)}
              placeholder="0x456..."
              disabled={isVerifying}
            />
          </div>
          
          <div className="form-group">
            <button 
              type="submit" 
              disabled={!file || !documentId || !signerAddress || isVerifying}
            >
              {isVerifying ? (
                <>
                  <span className="loader"></span> Verifying...
                </>
              ) : 'Verify Signature'}
            </button>
            <button 
              type="button" 
              className="reset-button" 
              onClick={resetForm}
              disabled={isVerifying}
            >
              Reset
            </button>
          </div>
          
          {statusMessage && (
            <div className={`status ${statusType}`}>{statusMessage}</div>
          )}
        </form>
      </div>
      
      {verificationResult && (
        <div className="card verification-details">
          <h2>Verification Details</h2>
          
          <div>
            <strong>Signature Valid:</strong> 
            <span className={verificationResult.isValid ? 'valid' : 'invalid'}>
              {verificationResult.isValid ? '✅ Valid' : '❌ Invalid'}
            </span>
          </div>
          
          {verificationResult.details && (
            <>
              <div>
                <strong>Signature Level:</strong> <span>{verificationResult.details.signatureLevel || 'N/A'}</span>
              </div>
              <div>
                <strong>Signed On:</strong> <span>{formatDate(verificationResult.details.timestamp)}</span>
              </div>
              <div>
                <strong>Expires On:</strong> <span>{formatDate(verificationResult.details.expiration)}</span>
              </div>
              <div>
                <strong>Revocation Status:</strong> 
                <span className={verificationResult.details.isRevoked ? 'invalid' : 'valid'}>
                  {verificationResult.details.isRevoked ? '⚠️ Revoked' : '✅ Not Revoked'}
                </span>
              </div>
            </>
          )}
        </div>
      )}
      
      <div className="card">
        <h3>How It Works</h3>
        <ol>
          <li>Enter the Document ID from the original signature (e.g., 0x06277019e1461aaade87a9d4ad5edcdb148025555bc56a10ce7ba1a13ab8ed6a)</li>
          <li>Enter the Signer's StarkNet address (e.g., 0x02be141e1576ea4f666b9c0e2e0d2dc25e4f65590f36c381c4ad282baef7bc81)</li>
          <li>Upload the PDF document</li>
          <li>Click "Verify Signature"</li>
          <li>The system will verify the document against the blockchain record</li>
        </ol>
        <p><strong>Note:</strong> Document hash is calculated client-side. Your document is never uploaded to any server.</p>
        <div className="tech-info">
          <h4>Technical Information</h4>
          <p>Verification requires:</p>
          <ul>
            <li>The original Document ID (a unique identifier on the blockchain)</li>
            <li>The original signer's StarkNet address</li>
            <li>The exact PDF file that was signed (any modification will invalidate the signature)</li>
          </ul>
          <p>The verification process calculates the document hash and compares it with the hash stored on the StarkNet blockchain.</p>
        </div>
      </div>
    </>
  );
};

export default VerifySignature;