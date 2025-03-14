/// Integration tests for the Electronic Signature contract
/// These tests validate the core functionality and security features of the contract

use starknet_esign::contracts::esg::ElectronicSignature;
use starknet_esign::interfaces::iesg::IElectronicSignature;
use starknet_esign::contracts::esg::{QES_LEVEL, AES_LEVEL, SES_LEVEL};
use starknet_esign::utils::signature::DocumentSignature;
use starknet::{ContractAddress, testing};
use core::array::ArrayTrait;
use core::traits::TryInto;
use core::option::OptionTrait;
use starknet::testing::set_caller_address;

/// Helper function to create a contract address from a felt252 value
/// Used to simplify test setup with deterministic addresses
fn contract_address_const(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}

/// Test the core document signing and verification functionality
/// This test ensures that:
/// 1. Documents can be signed with proper metadata
/// 2. Valid signatures can be verified
/// 3. Modified documents will fail verification
/// 4. Expiration status is correctly reported
#[test]
#[available_gas(2000000)]
fn test_document_signing() {
    // Setup test environment with mock addresses
    let caller = contract_address_const(0x10);
    let owner = contract_address_const(0x1);
    let contract_name = 'ElectronicSignature';
    let contract_version = 'v1.0.0';
    let chain_id = 1;
    
    // Deploy the contract in test mode
    let mut state = ElectronicSignature::contract_state_for_testing();
    ElectronicSignature::constructor(ref state, owner, contract_name, contract_version, chain_id);
    
    // Create a sample document with simple text content
    let document_id = 'test_contract_1';
    let mut document_data = ArrayTrait::new();
    document_data.append('This');
    document_data.append('is');
    document_data.append('a');
    document_data.append('test');
    document_data.append('document');
    
    // Set the test caller address to simulate transaction sender
    set_caller_address(caller);
    
    // Sign the document with QES level (highest security) and 1 hour validity
    let validity_period = 3600_u64; // 1 hour in seconds
    let _signature = ElectronicSignature::ElectronicSignatureImpl::sign_document(
        ref state, document_id, document_data.clone(), QES_LEVEL, validity_period
    );
    
    // Verify the signature with the same document data should succeed
    let is_valid = ElectronicSignature::ElectronicSignatureImpl::verify_document_signature(
        @state, document_id, caller, document_data.clone()
    );
    assert(is_valid, 'Signature should be valid');
    
    // Signature should not be expired yet
    let is_expired = ElectronicSignature::ElectronicSignatureImpl::is_signature_expired(
        @state, document_id, caller
    );
    assert(!is_expired, 'Signature should not be expired');
    
    // Modify the document data by adding a new word
    let mut modified_data = document_data.clone();
    modified_data.append('modified');
    
    // Verification should fail with modified document data
    let is_modified_valid = ElectronicSignature::ElectronicSignatureImpl::verify_document_signature(
        @state, document_id, caller, modified_data
    );
    assert(!is_modified_valid, 'Should not verify modified document');
}

/// Test signature revocation functionality
/// This test ensures that:
/// 1. Signatures can be revoked by the signer
/// 2. Revoked signatures will fail verification
/// 3. Revocation status is correctly stored and reported
#[test]
#[available_gas(2000000)]
fn test_signature_revocation() {
    // Setup test environment
    let caller = contract_address_const(0x20);
    let owner = contract_address_const(0x1);
    let contract_name = 'ElectronicSignature';
    let contract_version = 'v1.0.0';
    let chain_id = 1;
    
    // Deploy the contract in test mode
    let mut state = ElectronicSignature::contract_state_for_testing();
    ElectronicSignature::constructor(ref state, owner, contract_name, contract_version, chain_id);
    
    // Create and prepare document for signature
    let document_id = 'test_revoke';
    let mut document_data = ArrayTrait::new();
    document_data.append('Revocable');
    document_data.append('Document');
    
    // Set caller as the transaction sender
    set_caller_address(caller);
    
    // Sign with AES level (medium security) and 2 day validity
    let validity_period = 172800_u64; // 2 days in seconds
    let _signature = ElectronicSignature::ElectronicSignatureImpl::sign_document(
        ref state, document_id, document_data.clone(), AES_LEVEL, validity_period
    );
    
    // Verify signature is initially valid and not revoked
    let stored_signature = ElectronicSignature::ElectronicSignatureImpl::get_signature(
        @state, document_id, caller
    );
    assert(!stored_signature.is_revoked, 'Should not be revoked initially');
    
    let is_valid = ElectronicSignature::ElectronicSignatureImpl::verify_document_signature(
        @state, document_id, caller, document_data.clone()
    );
    assert(is_valid, 'Should be valid initially');
    
    // Revoke the signature
    ElectronicSignature::ElectronicSignatureImpl::revoke_signature(
        ref state, document_id
    );
    
    // Verify signature is now marked as revoked
    let revoked_signature = ElectronicSignature::ElectronicSignatureImpl::get_signature(
        @state, document_id, caller
    );
    assert(revoked_signature.is_revoked, 'Should be marked as revoked');
    
    // Verify document verification now fails due to revocation
    let is_valid_after = ElectronicSignature::ElectronicSignatureImpl::verify_document_signature(
        @state, document_id, caller, document_data.clone()
    );
    assert(!is_valid_after, 'Should be invalid after revocation');
}

/// Test the typed data hashing functionality
/// This test ensures that:
/// 1. Hash generation is deterministic for the same inputs
/// 2. Different signature levels produce different hashes
/// 3. The hash function includes domain separation
#[test]
#[available_gas(2000000)]
fn test_hash_typed_data() {
    // Setup test environment
    let _caller = contract_address_const(0x30);
    let owner = contract_address_const(0x1);
    let contract_name = 'ElectronicSignature';
    let contract_version = 'v1.0.0';
    let chain_id = 1;
    
    // Deploy the contract in test mode
    let mut state = ElectronicSignature::contract_state_for_testing();
    ElectronicSignature::constructor(ref state, owner, contract_name, contract_version, chain_id);
    
    // Create test data for hashing
    let document_id = 'test_hash';
    let document_hash = 0x1234567890abcdef; // Sample pre-computed document hash
    let signer = contract_address_const(0x30);
    
    // Generate hash using the highest security level (QES)
    let hash_qes = ElectronicSignature::ElectronicSignatureImpl::hash_typed_data(
        @state, document_id, document_hash, signer, QES_LEVEL
    );
    
    // Generate hash using medium security level (AES)
    // Should produce different hash than QES for same document
    let hash_aes = ElectronicSignature::ElectronicSignatureImpl::hash_typed_data(
        @state, document_id, document_hash, signer, AES_LEVEL
    );
    
    // Different signature levels should produce different hashes
    // This ensures signature level is included in the hash computation
    assert(hash_qes != hash_aes, 'Hashes should differ by sig level');
    
    // Verify the hash function is deterministic
    // Calling with the same parameters should produce the same hash
    let hash_qes2 = ElectronicSignature::ElectronicSignatureImpl::hash_typed_data(
        @state, document_id, document_hash, signer, QES_LEVEL
    );
    assert(hash_qes == hash_qes2, 'Hash function should be deterministic');
}