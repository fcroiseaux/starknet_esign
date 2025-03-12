use starknet::ContractAddress;

// EIP-712 inspired typed data structures
#[derive(Drop, Copy, Serde, starknet::Store)]
struct Domain {
    name: felt252,
    version: felt252,
    chain_id: felt252,
    verifying_contract: ContractAddress,
    salt: felt252,
}

#[derive(Drop, Copy, Serde)]
struct DocumentMessage {
    document_id: felt252,
    document_hash: felt252,
    timestamp: u64,
    signer: ContractAddress,
    signature_level: felt252,
}

#[derive(Drop, Copy, Serde)]
struct TypedData {
    domain: Domain,
    message: DocumentMessage,
}