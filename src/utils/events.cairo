use starknet::ContractAddress;

// Events for document operations
#[derive(Drop, starknet::Event)]
pub struct DocumentSigned {
    pub document_id: felt252,
    pub document_hash: felt252,
    pub signer: ContractAddress,
    pub timestamp: u64,
    pub signature_level: felt252
}

#[derive(Drop, starknet::Event)]
pub struct SignatureRevoked {
    pub document_id: felt252,
    pub signer: ContractAddress,
    pub timestamp: u64
}