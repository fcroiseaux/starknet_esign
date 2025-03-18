import React, { useState } from 'react';
import WalletConnection from './WalletConnection';
import SignatureForm from './SignatureForm';
import VerifySignature from './VerifySignature';

const App: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'sign' | 'verify'>('sign');
  
  return (
    <div className="page-container">
      {/* Left Sidebar for Wallet Connection */}
      <div className="sidebar">
        <div className="logo">
          <h2>StarkNet<br/>eSign</h2>
        </div>
        
        <div className="nav-links">
          <a 
            href="#" 
            className={activeTab === 'sign' ? 'active' : ''}
            onClick={(e) => {
              e.preventDefault();
              setActiveTab('sign');
            }}
          >
            Sign Document
          </a>
          <a 
            href="#" 
            className={activeTab === 'verify' ? 'active' : ''}
            onClick={(e) => {
              e.preventDefault();
              setActiveTab('verify');
            }}
          >
            Verify Signature
          </a>
        </div>
        
        <WalletConnection />
      </div>
      
      {/* Main Content */}
      <div className="main-content">
        {activeTab === 'sign' ? (
          <>
            <h1>Sign PDF Document</h1>
            <SignatureForm />
          </>
        ) : (
          <>
            <h1>Verify Document Signature</h1>
            <VerifySignature />
          </>
        )}
      </div>
    </div>
  );
};

export default App;