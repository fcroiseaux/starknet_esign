#[starknet::interface]
pub trait IElectronicSignature<TContractState> {
    fn sign_document(
        ref self: TContractState,
        document_id: felt252, 
        document_data: Array<felt252>,
        signature_level: felt252,
        validity_period: u64
    ) -> crate::utils::signature::DocumentSignature;

    fn verify_document_signature(
        self: @TContractState,
        document_id: felt252,
        signer: starknet::ContractAddress,
        document_data: Array<felt252>
    ) -> bool;

    fn revoke_signature(ref self: TContractState, document_id: felt252);
    
    fn get_signature(
        self: @TContractState, 
        document_id: felt252, 
        signer: starknet::ContractAddress
    ) -> crate::utils::signature::DocumentSignature;
    
    fn hash_typed_data(
        self: @TContractState,
        document_id: felt252,
        document_hash: felt252,
        signer: starknet::ContractAddress,
        signature_level: felt252
    ) -> felt252;
    
    // Check if a signature is expired
    fn is_signature_expired(
        self: @TContractState,
        document_id: felt252,
        signer: starknet::ContractAddress
    ) -> bool;
}