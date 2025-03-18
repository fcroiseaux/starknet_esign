// Types for global starknet object
declare global {
  interface Window {
    starknet: any;
  }
}

export interface WalletInfo {
  address: string;
  network: string;
  chainId: string;
  networkName: string;
  providerName: string;
  accountType: string;
}

/**
 * Connect to StarkNet wallet
 */
export async function connectWallet(): Promise<any> {
  if (!window.starknet) {
    throw new Error('StarkNet.js library not loaded. Please check your internet connection or reload the page.');
  }

  console.log('Trying to connect with starknet.enable()...');
  const result = await window.starknet.enable();
  console.log('Connected using starknet.enable(), result:', result);
  
  return result;
}

/**
 * Detect wallet details
 */
export async function getWalletDetails(wallet: any, address: string): Promise<WalletInfo> {
  let network = 'Unknown';
  let chainId = 'Unknown';
  let providerName = 'Unknown';
  let accountType = 'Unknown';
  
  try {
    // Try to determine network
    const networkInfo = await detectArgentXNetwork();
    chainId = networkInfo.chainId;
    network = networkInfo.network;
    
    // If still unknown, try generic detection
    if (network === 'Unknown') {
      if (wallet.provider) {
        if (wallet.provider.chainId) {
          chainId = wallet.provider.chainId;
          network = getNetworkName(chainId);
        } else if (wallet.provider.baseUrl) {
          // Try to guess from provider URL
          const baseUrl = wallet.provider.baseUrl;
          if (baseUrl.includes('mainnet')) {
            network = 'Mainnet';
            chainId = 'mainnet-alpha';
          } else if (baseUrl.includes('goerli') || baseUrl.includes('testnet')) {
            network = 'Goerli Testnet';
            chainId = 'goerli-alpha';
          } else if (baseUrl.includes('sepolia')) {
            network = 'Sepolia Testnet';
            chainId = 'sepolia-alpha';
          }
        }
      } else if (wallet.chainId) {
        chainId = wallet.chainId;
        network = getNetworkName(chainId);
      }
    }
    
    // Determine wallet provider name
    if (typeof window.starknet !== 'undefined') {
      if (window.starknet.walletName) {
        providerName = window.starknet.walletName;
      } else if (window.starknet.isArgent === true) {
        providerName = 'Argent';
      } else if (window.starknet.isBraavos === true) {
        providerName = 'Braavos';
      } else if (window.starknet.version) {
        const versionStr = window.starknet.version;
        if (versionStr.toLowerCase().includes('argent')) {
          providerName = 'Argent';
        } else if (versionStr.toLowerCase().includes('braavos')) {
          providerName = 'Braavos';
        }
      }
    }
    
    // Determine account type
    if (Array.isArray(wallet)) {
      if (window.starknet && window.starknet.isArgent) {
        accountType = 'ArgentX Wallet';
      } else if (window.starknet && window.starknet.isBraavos) {
        accountType = 'Braavos Wallet';
      } else {
        accountType = 'Address Array';
      }
      
      if (window.starknet && window.starknet.account && window.starknet.account.type) {
        accountType += ` (${window.starknet.account.type})`;
      }
    } else if (wallet.account && wallet.account.constructor && wallet.account.constructor.name) {
      accountType = wallet.account.constructor.name;
    } else if (wallet.constructor && wallet.constructor.name) {
      accountType = wallet.constructor.name;
    }
    
    if (providerName === 'Argent' && (accountType === 'Unknown' || accountType === 'Object')) {
      accountType = 'ArgentX Wallet';
    }
    
    if (accountType === 'Unknown' && window.starknet) {
      if (window.starknet.isArgent) {
        accountType = 'ArgentX Wallet';
      } else if (window.starknet.isBraavos) {
        accountType = 'Braavos Wallet';
      } else if (window.starknet.version) {
        accountType = `StarkNet v${window.starknet.version}`;
      }
    }
  } catch (error) {
    console.error('Error getting wallet details:', error);
  }
  
  // Get a network name that's more human readable
  const networkName = getNetworkName(chainId);
  
  return {
    address,
    network,
    chainId,
    networkName: networkName !== chainId ? networkName : 'Unknown',
    providerName,
    accountType,
  };
}

/**
 * Detect network for ArgentX wallet
 */
async function detectArgentXNetwork() {
  try {
    if (window.starknet && window.starknet.provider) {
      // Method 1: Get chain ID
      try {
        const chainId = await window.starknet.provider.getChainId();
        if (chainId) {
          return {
            chainId: chainId,
            network: getNetworkName(chainId)
          };
        }
      } catch (err) {
        console.error('Error getting chainId:', err);
      }
      
      // Method 2: Check network property
      if (window.starknet.network) {
        return {
          chainId: window.starknet.network,
          network: getNetworkName(window.starknet.network)
        };
      }
      
      // Method 3: Try to extract from provider.baseUrl
      if (window.starknet.provider.baseUrl) {
        const baseUrl = window.starknet.provider.baseUrl;
        if (baseUrl.includes('mainnet')) {
          return {
            chainId: 'mainnet-alpha',
            network: 'Mainnet'
          };
        } else if (baseUrl.includes('goerli')) {
          return {
            chainId: 'goerli-alpha',
            network: 'Goerli Testnet'
          };
        } else if (baseUrl.includes('sepolia')) {
          return {
            chainId: 'sepolia-alpha',
            network: 'Sepolia Testnet'
          };
        }
      }
    }
  } catch (err) {
    console.error('Error detecting ArgentX network:', err);
  }
  
  return {
    chainId: 'Unknown',
    network: 'Unknown'
  };
}

/**
 * Get network name from chain ID
 */
function getNetworkName(chainId: string): string {
  const networks: { [key: string]: string } = {
    'SN_MAIN': 'Mainnet',
    'mainnet-alpha': 'Mainnet',
    'SN_GOERLI': 'Goerli Testnet',
    'goerli-alpha': 'Goerli Testnet',
    'SN_SEPOLIA': 'Sepolia Testnet',
    'sepolia-alpha': 'Sepolia Testnet',
    // Add common hex values
    '0x534e5f4d41494e': 'Mainnet (SN_MAIN)',
    '0x534e5f474f45524c49': 'Goerli Testnet (SN_GOERLI)',
    '0x534e5f5345504f4c4941': 'Sepolia Testnet (SN_SEPOLIA)'
  };
  
  return networks[chainId] || chainId;
}