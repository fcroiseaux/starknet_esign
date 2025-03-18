import { useState, useEffect } from 'react';
import { connectWallet, getWalletDetails, WalletInfo } from '../services/walletService';

interface WalletState {
  wallet: any | null;
  address: string;
  isConnected: boolean;
  isConnecting: boolean;
  walletDetails: WalletInfo | null;
  error: string | null;
}

export function useWallet() {
  const [state, setState] = useState<WalletState>({
    wallet: null,
    address: '',
    isConnected: false,
    isConnecting: false,
    walletDetails: null,
    error: null
  });

  // Check for wallet connection on mount
  useEffect(() => {
    const checkSavedWallet = async () => {
      const isWalletConnected = localStorage.getItem('walletConnected') === 'true';
      const savedWalletAddress = localStorage.getItem('walletAddress');
      
      if (isWalletConnected && savedWalletAddress && window.starknet) {
        console.log('Attempting to restore wallet connection from localStorage');
        
        // Don't update state until we actually have the wallet object
        try {
          // Directly handle connection here instead of calling handleConnect to avoid cycles
          setState(prev => ({ ...prev, isConnecting: true, error: null }));
          
          const result = await window.starknet.enable();
          console.log('Reconnected wallet result:', result);
          
          // Get the address
          let address;
          if (Array.isArray(result) && result.length > 0) {
            address = result[0];
          } else if (result && result.account && result.account.address) {
            address = result.account.address;
          } else if (result && result.selectedAddress) {
            address = result.selectedAddress;
          } else if (window.starknet.selectedAddress) {
            address = window.starknet.selectedAddress;
            // In this case, we should use window.starknet as the wallet
            result = window.starknet;
          }
          
          if (!address) {
            throw new Error('Failed to get wallet address on reconnect');
          }
          
          // Get wallet details
          const walletDetails = await getWalletDetails(result, address);
          
          // Update state with the actual wallet object
          setState({
            wallet: result,
            address,
            isConnected: true,
            isConnecting: false,
            walletDetails,
            error: null
          });
        } catch (error) {
          console.error('Error reconnecting to wallet:', error);
          // Clear stored wallet connection info since reconnection failed
          localStorage.removeItem('walletConnected');
          localStorage.removeItem('walletAddress');
          setState(prev => ({
            ...prev,
            isConnecting: false,
            error: `Error reconnecting wallet: ${error instanceof Error ? error.message : String(error)}`
          }));
        }
      }
    };
    
    checkSavedWallet();
  }, []);

  // Connect wallet function
  const handleConnect = async () => {
    console.log("Starting wallet connection process");
    setState(prev => ({ ...prev, isConnecting: true, error: null }));
    
    try {
      // Connect to wallet
      console.log("Calling connectWallet()");
      const result = await connectWallet();
      console.log("connectWallet() returned:", result);
      
      // Get the address
      let address;
      if (Array.isArray(result) && result.length > 0) {
        address = result[0];
        console.log("Got address from array result:", address);
      } else if (result && result.account && result.account.address) {
        address = result.account.address;
        console.log("Got address from result.account.address:", address);
      } else if (result && result.selectedAddress) {
        address = result.selectedAddress;
        console.log("Got address from result.selectedAddress:", address);
      } else if (window.starknet && window.starknet.selectedAddress) {
        address = window.starknet.selectedAddress;
        console.log("Got address from window.starknet.selectedAddress:", address);
        // In this case, we should use window.starknet as the wallet
        result = window.starknet;
      }
      
      if (!address) {
        console.error("Failed to extract address from result:", result);
        throw new Error('Failed to get wallet address');
      }
      
      // Get wallet details
      console.log("Getting wallet details");
      const walletDetails = await getWalletDetails(result, address);
      console.log("Wallet details:", walletDetails);
      
      // Update state
      console.log("Updating state with connected wallet");
      const newState = {
        wallet: result,
        address,
        isConnected: true,
        isConnecting: false,
        walletDetails,
        error: null
      };
      console.log("New wallet state:", newState);
      setState(newState);
      
      // Save wallet connection info to localStorage
      localStorage.setItem('walletConnected', 'true');
      localStorage.setItem('walletAddress', address);
      
      // Wait a moment to ensure state is updated
      setTimeout(() => {
        console.log("Current wallet state after update:", {
          wallet: !!result,
          address,
          isConnected: true
        });
      }, 100);
      
      return result;
    } catch (error) {
      console.error('Error connecting wallet:', error);
      setState(prev => ({
        ...prev,
        isConnecting: false,
        error: `Error connecting wallet: ${error instanceof Error ? error.message : String(error)}`
      }));
      throw error;
    }
  };

  // Disconnect wallet function
  const handleDisconnect = () => {
    // Reset wallet state
    setState({
      wallet: null,
      address: '',
      isConnected: false,
      isConnecting: false,
      walletDetails: null,
      error: null
    });
    
    // Clear localStorage
    localStorage.removeItem('walletConnected');
    localStorage.removeItem('walletAddress');
  };

  return {
    ...state,
    connect: handleConnect,
    disconnect: handleDisconnect
  };
}