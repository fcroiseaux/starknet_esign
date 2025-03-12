use starknet::{ContractAddress, testing};
use core::array::ArrayTrait;
use core::traits::TryInto;
use core::option::OptionTrait;
use starknet::testing::set_caller_address;

// Import contract and interfaces
use super::super::contracts::esg::ElectronicSignature;
use super::super::interfaces::iesg::IElectronicSignature;
use super::super::contracts::esg::{QES_LEVEL, AES_LEVEL, SES_LEVEL};
use super::super::utils::signature::DocumentSignature;

#[cfg(test)]
mod tests {
    use starknet::{ContractAddress, testing};
    use core::array::ArrayTrait;
    use core::traits::TryInto;
    use core::option::OptionTrait;
    use starknet::testing::set_caller_address;
    use super::super::super::contracts::esg::ElectronicSignature;
    use super::super::super::interfaces::iesg::IElectronicSignature;
    use super::super::super::contracts::esg::{QES_LEVEL, AES_LEVEL, SES_LEVEL};

    // Helper function to create a contract address for testing
    fn contract_address_const(value: felt252) -> ContractAddress {
        value.try_into().unwrap()
    }

    #[test]
    #[available_gas(2000000)]
    fn test_document_signing() {
        // Setup test environment
        let caller = contract_address_const(0x10);
        let owner = contract_address_const(0x1);
        let contract_name = 'ElectronicSignature';
        let contract_version = 'v1.0.0';
        let chain_id = 1;
        
        // Deploy the contract
        let mut state = ElectronicSignature::contract_state_for_testing();
        ElectronicSignature::constructor(ref state, owner, contract_name, contract_version, chain_id);
        
        // Create a sample document
        let document_id = 'test_contract_1';
        let mut document_data = ArrayTrait::new();
        document_data.append('This');
        document_data.append('is');
        document_data.append('a');
        document_data.append('test');
        document_data.append('document');
        
        // Set the caller as a signer
        set_caller_address(caller);
        
        // Sign the document with QES level and 1 hour validity (3600 seconds)
        let validity_period = 3600_u64;
        let _signature = ElectronicSignature::ElectronicSignatureImpl::sign_document(
            ref state, document_id, document_data.clone(), QES_LEVEL, validity_period
        );
        
        // Verify the signature
        let is_valid = ElectronicSignature::ElectronicSignatureImpl::verify_document_signature(
            @state, document_id, caller, document_data.clone()
        );
        assert(is_valid, 'Signature should be valid');
        
        // Check expiration status
        let is_expired = ElectronicSignature::ElectronicSignatureImpl::is_signature_expired(
            @state, document_id, caller
        );
        assert(!is_expired, 'Signature should not be expired');
        
        // Modify the document data
        let mut modified_data = document_data.clone();
        modified_data.append('modified');
        
        // Verify the modified document (should fail)
        let is_modified_valid = ElectronicSignature::ElectronicSignatureImpl::verify_document_signature(
            @state, document_id, caller, modified_data
        );
        assert(!is_modified_valid, 'Should not verify');
    }

    #[test]
    #[available_gas(2000000)]
    fn test_signature_revocation() {
        // Setup test environment
        let caller = contract_address_const(0x20);
        let owner = contract_address_const(0x1);
        let contract_name = 'ElectronicSignature';
        let contract_version = 'v1.0.0';
        let chain_id = 1;
        
        // Deploy the contract
        let mut state = ElectronicSignature::contract_state_for_testing();
        ElectronicSignature::constructor(ref state, owner, contract_name, contract_version, chain_id);
        
        // Create and sign a document
        let document_id = 'test_revoke';
        let mut document_data = ArrayTrait::new();
        document_data.append('Revocable');
        document_data.append('Document');
        
        // Set the caller as a signer
        set_caller_address(caller);
        
        // Sign with AES level and 2 day validity (172800 seconds)
        let validity_period = 172800_u64;
        let _signature = ElectronicSignature::ElectronicSignatureImpl::sign_document(
            ref state, document_id, document_data.clone(), AES_LEVEL, validity_period
        );
        
        // Verify initial validity
        let stored_signature = ElectronicSignature::ElectronicSignatureImpl::get_signature(
            @state, document_id, caller
        );
        assert(!stored_signature.is_revoked, 'Should not be revoked');
        
        let is_valid = ElectronicSignature::ElectronicSignatureImpl::verify_document_signature(
            @state, document_id, caller, document_data.clone()
        );
        assert(is_valid, 'Should be valid');
        
        // Revoke the signature
        ElectronicSignature::ElectronicSignatureImpl::revoke_signature(
            ref state, document_id
        );
        
        // Check revocation status
        let revoked_signature = ElectronicSignature::ElectronicSignatureImpl::get_signature(
            @state, document_id, caller
        );
        assert(revoked_signature.is_revoked, 'Should be revoked');
        
        // Verify document after revocation (should fail)
        let is_valid_after = ElectronicSignature::ElectronicSignatureImpl::verify_document_signature(
            @state, document_id, caller, document_data.clone()
        );
        assert(!is_valid_after, 'Should be invalid');
    }

    #[test]
    #[available_gas(2000000)]
    fn test_hash_typed_data() {
        // Setup test environment
        let _caller = contract_address_const(0x30);
        let owner = contract_address_const(0x1);
        let contract_name = 'ElectronicSignature';
        let contract_version = 'v1.0.0';
        let chain_id = 1;
        
        // Deploy the contract
        let mut state = ElectronicSignature::contract_state_for_testing();
        ElectronicSignature::constructor(ref state, owner, contract_name, contract_version, chain_id);
        
        // Create test data
        let document_id = 'test_hash';
        let document_hash = 0x1234567890abcdef;
        let signer = contract_address_const(0x30);
        
        // Generate hash for QES level
        let hash_qes = ElectronicSignature::ElectronicSignatureImpl::hash_typed_data(
            @state, document_id, document_hash, signer, QES_LEVEL
        );
        
        // Generate hash for AES level - should be different from QES
        let hash_aes = ElectronicSignature::ElectronicSignatureImpl::hash_typed_data(
            @state, document_id, document_hash, signer, AES_LEVEL
        );
        
        // Verify hashes are different for different signature levels
        assert(hash_qes != hash_aes, 'Hashes should be different');
        
        // Verify consistency - hashing same data twice produces same result
        let hash_qes2 = ElectronicSignature::ElectronicSignatureImpl::hash_typed_data(
            @state, document_id, document_hash, signer, QES_LEVEL
        );
        assert(hash_qes == hash_qes2, 'Hash should be consistent');
    }
}