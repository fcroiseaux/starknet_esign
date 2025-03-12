use starknet::ContractAddress;

// Events for document operations
#[derive(Drop, starknet::Event)]
struct DocumentSigned {
    document_id: felt252,
    document_hash: felt252,
    signer: ContractAddress,
    timestamp: u64,
    signature_level: felt252
}

#[derive(Drop, starknet::Event)]
struct SignatureRevoked {
    document_id: felt252,
    signer: ContractAddress,
    timestamp: u64
}