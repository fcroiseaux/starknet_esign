import React, { useState, useRef, useEffect } from 'react';
import { signDocument, SignatureResult } from '../services/signatureService';
import { useWallet } from '../hooks/useWallet';

const SignatureForm: React.FC = () => {
  const { wallet, isConnected, connect } = useWallet();
  const [file, setFile] = useState<File | null>(null);
  const [signatureLevel, setSignatureLevel] = useState<'SES' | 'AES' | 'QES'>('SES');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [statusMessage, setStatusMessage] = useState('');
  const [statusType, setStatusType] = useState<'info' | 'success' | 'error'>('info');
  const [signatureResult, setSignatureResult] = useState<SignatureResult | null>(null);
  
  // Debug logging for button state
  useEffect(() => {
    console.log("Button state debug:", { 
      isConnected, 
      hasFile: !!file, 
      isSubmitting,
      wallet: !!wallet,
      buttonDisabled: !isConnected || !file || isSubmitting
    });
  }, [isConnected, file, isSubmitting, wallet]);
  
  const fileInputRef = useRef<HTMLInputElement>(null);
  
  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files.length > 0) {
      setFile(e.target.files[0]);
    }
  };
  
  const handleSignatureLevelChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    setSignatureLevel(e.target.value as 'SES' | 'AES' | 'QES');
  };
  
  const resetForm = () => {
    setFile(null);
    setSignatureLevel('SES');
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
  };
  
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!isConnected) {
      setStatusMessage('Please connect your wallet first');
      setStatusType('error');
      return;
    }
    
    if (!wallet) {
      setStatusMessage('Wallet is not properly initialized. Please reconnect your wallet');
      setStatusType('error');
      return;
    }
    
    if (!file) {
      setStatusMessage('Please select a PDF file');
      setStatusType('error');
      return;
    }
    
    setIsSubmitting(true);
    setStatusMessage('Preparing to sign document...');
    setStatusType('info');
    
    try {
      // Ensure wallet is properly connected by checking values
      console.log('Wallet object before signing:', wallet);
      
      if (!wallet || (typeof wallet === 'object' && Object.keys(wallet).length === 0)) {
        throw new Error('Wallet not properly initialized. Please reconnect your wallet.');
      }
      
      // Read file as ArrayBuffer
      const arrayBuffer = await file.arrayBuffer();
      
      setStatusMessage('Calculating document hash...');
      setStatusMessage('Sending transaction to Starknet...');
      
      // Sign the document
      const result = await signDocument(
        arrayBuffer,
        signatureLevel,
        0, // Default validity period (1 year)
        wallet
      );
      
      // Handle success
      setSignatureResult(result);
      setStatusMessage('Document signed successfully!');
      setStatusType('success');
      resetForm();
    } catch (error) {
      console.error('Error:', error);
      setStatusMessage(`Error signing document: ${error instanceof Error ? error.message : String(error)}`);
      setStatusType('error');
    } finally {
      setIsSubmitting(false);
    }
  };
  
  const EXPLORER_URL = 'https://sepolia.voyager.online/tx/';
  
  return (
    <>
      <div className="card">
        <h2>Sign a PDF Document</h2>
        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label htmlFor="fileInput">Select PDF File</label>
            <input 
              type="file" 
              id="fileInput" 
              accept=".pdf" 
              onChange={handleFileChange}
              ref={fileInputRef}
              disabled={isSubmitting}
            />
          </div>
          
          <div className="form-group">
            <label htmlFor="signatureLevel">Signature Level</label>
            <select 
              id="signatureLevel" 
              value={signatureLevel}
              onChange={handleSignatureLevelChange}
              disabled={isSubmitting}
            >
              <option value="SES">Simple Electronic Signature (SES)</option>
              <option value="AES">Advanced Electronic Signature (AES)</option>
              <option value="QES">Qualified Electronic Signature (QES)</option>
            </select>
          </div>
          
          <div className="form-group">
            <button 
              type="submit" 
              disabled={!isConnected || !file || isSubmitting}
              title={!isConnected ? "Connect wallet first" : !file ? "Select a file first" : ""}
            >
              {isSubmitting ? (
                <>
                  <span className="loader"></span> Signing...
                </>
              ) : 'Sign Document'}
            </button>
            {isConnected ? null : (
              <div className="button-hint">
                Please connect your wallet first
                <button 
                  className="connect-btn-inline" 
                  onClick={(e) => {
                    e.preventDefault();
                    connect();
                  }}
                >
                  Connect now
                </button>
              </div>
            )}
            {isConnected && !file ? <div className="button-hint">Please select a PDF file</div> : null}
          </div>
          
          {statusMessage && (
            <div className={`status ${statusType}`}>{statusMessage}</div>
          )}
        </form>
      </div>
      
      {signatureResult && (
        <div className="card signature-details">
          <h2>Signature Details</h2>
          <div className="copyable-field">
            <strong>Document ID:</strong> <span>{signatureResult.document_id}</span>
            <button 
              className="copy-button"
              onClick={() => {
                navigator.clipboard.writeText(signatureResult.document_id);
                alert('Document ID copied to clipboard!');
              }}
            >
              Copy
            </button>
          </div>
          <div>
            <strong>Transaction Hash:</strong> <span>{signatureResult.transaction_hash}</span>
          </div>
          <div>
            <strong>Signer Address:</strong> <span>{signatureResult.signer_address}</span>
          </div>
          <div>
            <strong>Signature Status:</strong> <span>
              {signatureResult.signature_verified ? '✅ Verified' : '❌ Failed'}
            </span>
          </div>
          <div>
            <strong>Verification Link:</strong> <a 
              href={EXPLORER_URL + signatureResult.transaction_hash}
              target="_blank" 
              rel="noopener noreferrer"
            >
              View on Starknet Explorer
            </a>
          </div>
          
          {signatureResult.monitored === false && (
            <div style={{ marginTop: '10px', padding: '10px', borderRadius: '4px', backgroundColor: '#fff8e1' }}>
              <strong>Note:</strong> If transaction monitoring fails due to network issues, the signature is still likely valid. 
              You can check the status of your transaction on the explorer link above.
            </div>
          )}
        </div>
      )}
      
      <div className="card">
        <h3>How It Works</h3>
        <ol>
          <li>Connect your wallet using the sidebar</li>
          <li>Select your PDF document</li>
          <li>Choose a signature level (SES, AES, or QES)</li>
          <li>Click "Sign Document"</li>
          <li>Confirm the transaction in your wallet</li>
          <li>Wait for transaction confirmation</li>
          <li>View your signature details with the auto-generated document ID</li>
        </ol>
        <p><strong>Note:</strong> This application requires a StarkNet-compatible wallet and connection to the StarkNet network.</p>
      </div>
    </>
  );
};

export default SignatureForm;