/// Unit and integration tests for the Electronic Signature contract
use starknet::{ContractAddress};
use core::array::ArrayTrait;
use core::traits::TryInto;
use core::option::OptionTrait;
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
use crate::contracts::esg::{QES_LEVEL, AES_LEVEL, SES_LEVEL};
use crate::interfaces::iesg::{IElectronicSignatureDispatcher, IElectronicSignatureDispatcherTrait};

/// Helper function to convert felt252 values to ContractAddress type
fn contract_address_const(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}

/// Helper function to deploy a new contract instance for testing
fn deploy_contract() -> (ContractAddress, IElectronicSignatureDispatcher) {
    let owner = contract_address_const(0x1);
    let contract_name = 'ElectronicSignature';
    let contract_version = 'v1.0.0';
    let chain_id = 1;

    // Declare and deploy the contract
    let contract = declare("ElectronicSignature").unwrap().contract_class();
    let constructor_calldata = array![
        owner.into(), 
        contract_name, 
        contract_version, 
        chain_id
    ];
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    // Create a dispatcher to interact with the contract
    let dispatcher = IElectronicSignatureDispatcher { contract_address };
    
    (contract_address, dispatcher)
}

#[test]
fn test_contract_deployment() {
    // Deploy a new contract instance
    let (_, dispatcher) = deploy_contract();
    
    // Test basic functionality - verify a non-existent signature should be expired
    let test_address = contract_address_const(0x123);
    let is_expired = dispatcher.is_signature_expired('nonexistent', test_address);
    assert(is_expired, 'Non-existent should be expired');
}

#[test]
fn test_signature_levels() {
    // Deploy a new contract instance
    let (_, dispatcher) = deploy_contract();
    
    // Verify different hash values for different signature levels
    let document_id = 'test_hash';
    let document_hash = 0x1234567890abcdef;
    let signer = contract_address_const(0x123);
    
    // Generate hashes with different security levels
    let hash_qes = dispatcher.hash_typed_data(document_id, document_hash, signer, QES_LEVEL);
    let hash_aes = dispatcher.hash_typed_data(document_id, document_hash, signer, AES_LEVEL);
    let hash_ses = dispatcher.hash_typed_data(document_id, document_hash, signer, SES_LEVEL);
    
    // Different signature levels should produce different hashes
    assert(hash_qes != hash_aes, 'QES and AES should differ');
    assert(hash_qes != hash_ses, 'QES and SES should differ');
    assert(hash_aes != hash_ses, 'AES and SES should differ');
    
    // Same inputs should produce same hash (deterministic)
    let hash_qes2 = dispatcher.hash_typed_data(document_id, document_hash, signer, QES_LEVEL);
    assert(hash_qes == hash_qes2, 'Hash should be deterministic');
}

#[test]
fn test_typed_data_security() {
    // Deploy a new contract instance
    let (_, dispatcher) = deploy_contract();
    
    // Setup test data
    let document_id = 'test_doc';
    let document_hash = 0x1234567890abcdef;
    
    // Test with different signers
    let signer1 = contract_address_const(0x123);
    let signer2 = contract_address_const(0x456);
    
    // Generate hash for same document with different signers
    let hash1 = dispatcher.hash_typed_data(document_id, document_hash, signer1, QES_LEVEL);
    let hash2 = dispatcher.hash_typed_data(document_id, document_hash, signer2, QES_LEVEL);
    
    // Different signers should produce different hashes (signer protection)
    assert(hash1 != hash2, 'Signer protection'); 
    
    // Test with different document IDs
    let document_id2 = 'test_doc2';
    let hash3 = dispatcher.hash_typed_data(document_id2, document_hash, signer1, QES_LEVEL);
    
    // Different document IDs should produce different hashes (document uniqueness)
    assert(hash1 != hash3, 'Document uniqueness');
}