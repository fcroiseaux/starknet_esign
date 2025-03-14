/// Unit and integration tests for the Electronic Signature contract
/// Tests in this module validate core functionality and edge cases
#[cfg(test)]
mod tests {
use starknet::{ContractAddress};
use core::array::ArrayTrait;
use core::traits::TryInto;
use core::option::OptionTrait;
use starknet::testing::set_caller_address;
use crate::contracts::esg::ElectronicSignature;
use crate::contracts::esg::{QES_LEVEL, AES_LEVEL};

/// Helper function to convert felt252 values to ContractAddress type
/// This simplifies creating test addresses without manual conversions
fn contract_address_const(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}

/// Tests the core document signing and verification workflow
#[test]
fn test_document_signing() {
    // Setup test environment with mock addresses and contract parameters
    let caller = contract_address_const(0x10);
    let owner = contract_address_const(0x1);
    let contract_name = 'ElectronicSignature';
    let contract_version = 'v1.0.0';
    let chain_id = 1;
    
    // Deploy the contract in test mode
    let mut state = ElectronicSignature::contract_state_for_testing();
    ElectronicSignature::constructor(ref state, owner, contract_name, contract_version, chain_id);
    
    // Create a sample document with text content 
    let document_id = 'test_contract_1';
    let mut document_data = ArrayTrait::new();
    document_data.append('This');
    document_data.append('is');
    document_data.append('a');
    document_data.append('test');
    document_data.append('document');
    
    // Set the transaction sender to the test account
    set_caller_address(caller);
    
    // Sign the document with highest security level (QES) and short validity period
    let validity_period = 3600_u64; // 1 hour in seconds
    let _signature = ElectronicSignature::ElectronicSignatureImpl::sign_document(
        ref state, document_id, document_data.clone(), QES_LEVEL, validity_period
    );
    
    // Verify signature is valid when checked with matching document data
    let is_valid = ElectronicSignature::ElectronicSignatureImpl::verify_document_signature(
        @state, document_id, caller, document_data.clone()
    );
    assert(is_valid, 'Valid signature');
    
    // Confirm signature has not yet expired (as expected)
    let is_expired = ElectronicSignature::ElectronicSignatureImpl::is_signature_expired(
        @state, document_id, caller
    );
    assert(!is_expired, 'Not expired');
    
    // Test tamper detection by modifying the original document
    let mut modified_data = document_data.clone();
    modified_data.append('modified'); // Add unauthorized content
    
    // Verification should fail when document content doesn't match original
    let is_modified_valid = ElectronicSignature::ElectronicSignatureImpl::verify_document_signature(
        @state, document_id, caller, modified_data
    );
    assert(!is_modified_valid, 'Modified doc check');
}

/// Tests signature revocation functionality
#[test]
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
    
    // Create a test document for revocation testing
    let document_id = 'test_revoke';
    let mut document_data = ArrayTrait::new();
    document_data.append('Revocable');
    document_data.append('Document');
    
    // Set the transaction sender
    set_caller_address(caller);
    
    // Sign document with AES level and medium-term validity
    let validity_period = 172800_u64; // 2 days in seconds
    let _signature = ElectronicSignature::ElectronicSignatureImpl::sign_document(
        ref state, document_id, document_data.clone(), AES_LEVEL, validity_period
    );
    
    // Verify signature starts in non-revoked state
    let stored_signature = ElectronicSignature::ElectronicSignatureImpl::get_signature(
        @state, document_id, caller
    );
    assert(!stored_signature.is_revoked, 'Not revoked');
    
    // Confirm signature initially passes verification
    let is_valid = ElectronicSignature::ElectronicSignatureImpl::verify_document_signature(
        @state, document_id, caller, document_data.clone()
    );
    assert(is_valid, 'Valid pre-revoke');
    
    // Perform signature revocation
    ElectronicSignature::ElectronicSignatureImpl::revoke_signature(
        ref state, document_id
    );
    
    // Verify signature is now marked as revoked in storage
    let revoked_signature = ElectronicSignature::ElectronicSignatureImpl::get_signature(
        @state, document_id, caller
    );
    assert(revoked_signature.is_revoked, 'Is revoked');
    
    // Confirm revoked signature fails verification
    let is_valid_after = ElectronicSignature::ElectronicSignatureImpl::verify_document_signature(
        @state, document_id, caller, document_data.clone()
    );
    assert(!is_valid_after, 'Invalid post-revoke');
}

/// Tests the EIP-712 inspired typed data hashing functionality
#[test]
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
    
    // Prepare test data for hashing
    let document_id = 'test_hash';
    let document_hash = 0x1234567890abcdef; // Pre-calculated document hash
    let signer = contract_address_const(0x30);
    
    // Generate hash with QES signature level (highest security)
    let hash_qes = ElectronicSignature::ElectronicSignatureImpl::hash_typed_data(
        @state, document_id, document_hash, signer, QES_LEVEL
    );
    
    // Generate hash with AES signature level (medium security)
    let hash_aes = ElectronicSignature::ElectronicSignatureImpl::hash_typed_data(
        @state, document_id, document_hash, signer, AES_LEVEL
    );
    
    // Verify that different signature levels produce different hashes
    assert(hash_qes != hash_aes, 'Diff hashes');
    
    // Verify deterministic behavior - same inputs produce same hash
    let hash_qes2 = ElectronicSignature::ElectronicSignatureImpl::hash_typed_data(
        @state, document_id, document_hash, signer, QES_LEVEL
    );
    assert(hash_qes == hash_qes2, 'Consistent hash');
}
}