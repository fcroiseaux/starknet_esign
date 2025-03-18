use starknet::ContractAddress;

/// DocumentSignature represents a signed document with cryptographic proof and metadata
/// This structure contains all information needed to verify and validate a document signature
/// It is stored on-chain and can be retrieved to verify a document was properly signed
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct DocumentSignature {
    /// Unique identifier for the document (usually a document name or reference ID)
    pub document_id: felt252,
    
    /// Cryptographic hash of the document content to ensure integrity
    /// When verifying signatures, the same hash function must be applied to the document data
    pub document_hash: felt252,
    
    /// StarkNet address of the account that signed the document
    /// Used to verify that the correct party signed the document
    pub signer_address: ContractAddress,
    
    /// UNIX timestamp (in seconds) when the document was signed
    /// Useful for audit trails and determining signature order
    pub timestamp: u64,
    
    /// Level of signature security based on eIDAS standards (QES, AES, or SES)
    /// Determines the legal weight and security requirements of the signature
    pub signature_level: felt252,
    
    /// Flag indicating if the signature has been revoked by the signer
    /// Revoked signatures are considered invalid regardless of other parameters
    pub is_revoked: bool,
    
    /// UNIX timestamp (in seconds) when the signature becomes invalid
    /// After this time, verification calls will return false
    pub expiration_time: u64,
    
    /// Unique number to prevent signature replay attacks and ensure uniqueness
    /// Incremented each time a user signs a document to prevent signature reuse
    pub nonce: u64,
}