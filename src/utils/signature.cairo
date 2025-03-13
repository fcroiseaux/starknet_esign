use starknet::ContractAddress;

// Document signature structure
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct DocumentSignature {
    pub document_id: felt252,
    pub document_hash: felt252,
    pub signer_address: ContractAddress,
    pub timestamp: u64,
    pub signature_level: felt252,
    pub is_revoked: bool,
    pub expiration_time: u64,
    pub nonce: u64, // Added for signature malleability protection
}