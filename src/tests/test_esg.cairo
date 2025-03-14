/// Unit and integration tests for the Electronic Signature contract
/// Tests in this module validate core functionality and edge cases
#[cfg(test)]
mod tests {
    use starknet::{ContractAddress, testing};
    use core::array::ArrayTrait;
    use core::traits::TryInto;
    use core::option::OptionTrait;
    use starknet::testing::set_caller_address;
    use crate::contracts::esg::ElectronicSignature;
    use crate::interfaces::iesg::IElectronicSignature;
    use crate::contracts::esg::{QES_LEVEL, AES_LEVEL, SES_LEVEL};

    /// Helper function to convert felt252 values to ContractAddress type
    /// This simplifies creating test addresses without manual conversions
    fn contract_address_const(value: felt252) -> ContractAddress {
        value.try_into().unwrap()
    }

    /// Tests the core document signing and verification workflow
    /// Validates that:
    /// - Documents can be signed with proper metadata
    /// - Valid signatures can be successfully verified
    /// - Document tampering is detected through hash verification 
    /// - Signature expiration state is correctly tracked
    #[test]
    #[available_gas(2000000)]
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
        assert(is_valid, 'Signature should be valid');
        
        // Confirm signature has not yet expired (as expected)
        let is_expired = ElectronicSignature::ElectronicSignatureImpl::is_signature_expired(
            @state, document_id, caller
        );
        assert(!is_expired, 'Signature should not be expired');
        
        // Test tamper detection by modifying the original document
        let mut modified_data = document_data.clone();
        modified_data.append('modified'); // Add unauthorized content
        
        // Verification should fail when document content doesn't match original
        let is_modified_valid = ElectronicSignature::ElectronicSignatureImpl::verify_document_signature(
            @state, document_id, caller, modified_data
        );
        assert(!is_modified_valid, 'Should detect modified document');
    }

    /// Tests signature revocation functionality
    /// Validates that:
    /// - Signatures can be successfully revoked by the original signer
    /// - Revocation status is properly recorded in storage
    /// - Revoked signatures are properly invalidated for verification
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
        assert(!stored_signature.is_revoked, 'Should start non-revoked');
        
        // Confirm signature initially passes verification
        let is_valid = ElectronicSignature::ElectronicSignatureImpl::verify_document_signature(
            @state, document_id, caller, document_data.clone()
        );
        assert(is_valid, 'Should be valid before revocation');
        
        // Perform signature revocation
        ElectronicSignature::ElectronicSignatureImpl::revoke_signature(
            ref state, document_id
        );
        
        // Verify signature is now marked as revoked in storage
        let revoked_signature = ElectronicSignature::ElectronicSignatureImpl::get_signature(
            @state, document_id, caller
        );
        assert(revoked_signature.is_revoked, 'Should be marked revoked');
        
        // Confirm revoked signature fails verification
        let is_valid_after = ElectronicSignature::ElectronicSignatureImpl::verify_document_signature(
            @state, document_id, caller, document_data.clone()
        );
        assert(!is_valid_after, 'Should fail after revocation');
    }

    /// Tests the EIP-712 inspired typed data hashing functionality
    /// Validates that:
    /// - Hash generation is cryptographically deterministic
    /// - Different signature levels result in distinct hashes
    /// - Domain separation prevents cross-context attacks
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
        // This ensures signature level is properly incorporated in the hash
        assert(hash_qes != hash_aes, 'Signature levels should affect hash');
        
        // Verify deterministic behavior - same inputs produce same hash
        let hash_qes2 = ElectronicSignature::ElectronicSignatureImpl::hash_typed_data(
            @state, document_id, document_hash, signer, QES_LEVEL
        );
        assert(hash_qes == hash_qes2, 'Hashing should be deterministic');
    }
}