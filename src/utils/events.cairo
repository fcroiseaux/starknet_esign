use starknet::ContractAddress;

/// Events emitted by the Electronic Signature contract
/// These events allow off-chain applications to track and respond to on-chain signatures

/// DocumentSigned is emitted when a user successfully signs a document
/// This event creates an immutable record of signature details on the blockchain
#[derive(Drop, starknet::Event)]
pub struct DocumentSigned {
    /// Unique identifier for the document that was signed
    pub document_id: felt252,
    
    /// Cryptographic hash of the document content at signing time
    /// Can be used to verify document integrity hasn't changed
    pub document_hash: felt252,
    
    /// StarkNet address of the account that signed the document
    pub signer: ContractAddress,
    
    /// UNIX timestamp (in seconds) when the signature was created
    pub timestamp: u64,
    
    /// eIDAS signature level used (QES, AES, or SES)
    /// Indicates the security and legal standing of the signature
    pub signature_level: felt252
}

/// SignatureRevoked is emitted when a user revokes their previously created signature
/// Revocation invalidates the signature but keeps a record that it once existed
#[derive(Drop, starknet::Event)]
pub struct SignatureRevoked {
    /// Unique identifier for the document whose signature was revoked
    pub document_id: felt252,
    
    /// StarkNet address of the signer who revoked their signature
    pub signer: ContractAddress,
    
    /// UNIX timestamp (in seconds) when the revocation occurred
    pub timestamp: u64
}