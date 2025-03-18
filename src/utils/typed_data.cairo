use starknet::ContractAddress;

/// Typed data structures inspired by Ethereum's EIP-712 standard
/// These structures help create structured data for cryptographic signing and verification
/// They ensure signatures cannot be reused across different domains or contracts

/// Domain separates signature contexts to prevent cross-contract replay attacks
/// Similar to EIP-712's domain separator concept but adapted for StarkNet
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct Domain {
    /// Human-readable name of the signing application/contract
    pub name: felt252,
    
    /// Version string to allow signature scheme upgrades
    pub version: felt252,
    
    /// StarkNet chain ID (e.g., mainnet vs. testnet) to prevent cross-chain replays
    pub chain_id: felt252,
    
    /// Address of the contract that will verify the signature
    pub verifying_contract: ContractAddress,
    
    /// Optional random value for additional security when needed
    pub salt: felt252,
}

/// DocumentMessage contains the core information about a document signature
/// These are the specific message parameters that will be signed/verified
#[derive(Drop, Copy, Serde)]
pub struct DocumentMessage {
    /// Unique identifier for the document being signed
    pub document_id: felt252,
    
    /// Cryptographic hash of the document content (ensures content integrity)
    pub document_hash: felt252,
    
    /// UNIX timestamp when the signature was created
    pub timestamp: u64,
    
    /// Address of the account signing the document
    pub signer: ContractAddress,
    
    /// Level of electronic signature (QES, AES, SES) as defined by eIDAS
    pub signature_level: felt252,
}

/// TypedData combines domain and message for complete signature context
/// Similar to EIP-712's typed data structure but simplified for StarkNet
#[derive(Drop, Copy, Serde)]
pub struct TypedData {
    /// Domain context to prevent signature replay across different applications
    pub domain: Domain,
    
    /// Document-specific data being signed
    pub message: DocumentMessage,
}