import React, { useEffect } from 'react';
import { useWallet } from '../hooks/useWallet';

const WalletConnection: React.FC = () => {
  const { 
    isConnected, 
    isConnecting, 
    address, 
    wallet,
    walletDetails, 
    error, 
    connect, 
    disconnect 
  } = useWallet();
  
  // Debug logging for connection state
  useEffect(() => {
    console.log("WalletConnection state:", { isConnected, wallet: !!wallet, address });
  }, [isConnected, wallet, address]);

  const handleConnectClick = async () => {
    try {
      // Clear any existing wallet data first to ensure a fresh connection
      localStorage.removeItem('walletConnected');
      localStorage.removeItem('walletAddress');
      
      // Attempt connection
      const walletInstance = await connect();
      
      // Log the wallet instance to ensure it's properly initialized
      console.log('Connected wallet instance:', walletInstance);
      
      if (!walletInstance) {
        console.error('No wallet instance returned from connect');
      }
    } catch (error) {
      console.error('Error in connect button handler:', error);
    }
  };

  return (
    <div className="wallet-section">
      <h3>Wallet Connection</h3>
      <p>Connect your wallet to sign documents on StarkNet.</p>
      
      {!isConnected ? (
        <button 
          id="connectWalletBtn" 
          className="connect-btn" 
          onClick={handleConnectClick}
          disabled={isConnecting}
        >
          {isConnecting ? 'Connecting...' : 'Connect Wallet'}
        </button>
      ) : (
        <div id="walletInfo">
          <div className="wallet-info">
            <p><strong>Connected:</strong></p>
            <span id="walletAddress" className="wallet-address">{address}</span>
            <button id="disconnectWalletBtn" className="disconnect-btn" onClick={disconnect}>
              Disconnect
            </button>
          </div>
          
          {walletDetails && (
            <div id="walletDetails" style={{ marginTop: '15px' }}>
              <h3>Network Details</h3>
              <div className="wallet-detail-item">
                <strong>Network:</strong> <span id="walletNetwork">{walletDetails.network}</span>
              </div>
              <div className="wallet-detail-item">
                <strong>Chain ID:</strong> <span id="walletChainId">{walletDetails.chainId}</span>
              </div>
              <div className="wallet-detail-item">
                <strong>Network Name:</strong> <span id="walletNetworkName" style={{ fontWeight: 500, color: '#1a73e8' }}>
                  {walletDetails.networkName}
                </span>
              </div>
              <div className="wallet-detail-item">
                <strong>Wallet Provider:</strong> <span id="walletProviderName">
                  {walletDetails.providerName}
                </span>
              </div>
              <div className="wallet-detail-item">
                <strong>Account Type:</strong> <span id="walletAccountType">
                  {walletDetails.accountType}
                </span>
              </div>
            </div>
          )}
        </div>
      )}
      
      {error && <div className="status error">{error}</div>}
    </div>
  );
};

export default WalletConnection;