import React from 'react';
import WalletConnection from './WalletConnection';
import SignatureForm from './SignatureForm';

const App: React.FC = () => {
  return (
    <div className="page-container">
      {/* Left Sidebar for Wallet Connection */}
      <div className="sidebar">
        <div className="logo">
          <h2>StarkNet<br/>eSign</h2>
        </div>
        
        <div className="nav-links">
          <a href="#" className="active">Sign Document</a>
        </div>
        
        <WalletConnection />
      </div>
      
      {/* Main Content */}
      <div className="main-content">
        <h1>Sign PDF Document</h1>
        <SignatureForm />
      </div>
    </div>
  );
};

export default App;