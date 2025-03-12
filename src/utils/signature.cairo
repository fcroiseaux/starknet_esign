use starknet::ContractAddress;

// Document signature structure
#[derive(Drop, Copy, Serde, starknet::Store)]
struct DocumentSignature {
    document_id: felt252,
    document_hash: felt252,
    signer_address: ContractAddress,
    timestamp: u64,
    signature_level: felt252,
    is_revoked: bool,
    expiration_time: u64,
    nonce: u64, // Added for signature malleability protection
}