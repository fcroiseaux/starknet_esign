use starknet::ContractAddress;

// EIP-712 inspired typed data structures
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct Domain {
    pub name: felt252,
    pub version: felt252,
    pub chain_id: felt252,
    pub verifying_contract: ContractAddress,
    pub salt: felt252,
}

#[derive(Drop, Copy, Serde)]
pub struct DocumentMessage {
    pub document_id: felt252,
    pub document_hash: felt252,
    pub timestamp: u64,
    pub signer: ContractAddress,
    pub signature_level: felt252,
}

#[derive(Drop, Copy, Serde)]
pub struct TypedData {
    pub domain: Domain,
    pub message: DocumentMessage,
}