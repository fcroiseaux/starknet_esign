/// Unit and integration tests for the Electronic Signature contract
#[cfg(test)]
mod tests {
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
    
    /// Helper to create document data array
    fn create_document_data(content: felt252) -> Array<felt252> {
        let mut data = ArrayTrait::new();
        data.append(content);
        data
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
    
    #[test]
    fn test_domain_separator() {
        // Deploy two separate contract instances with different parameters
        let owner = contract_address_const(0x1);
        
        // First contract with version 1.0.0
        let contract_name1 = 'ElectronicSignature';
        let contract_version1 = 'v1.0.0';
        let chain_id1 = 1;
    
        let contract1 = declare("ElectronicSignature").unwrap().contract_class();
        let constructor_calldata1 = array![
            owner.into(), 
            contract_name1, 
            contract_version1, 
            chain_id1
        ];
        let (contract_address1, _) = contract1.deploy(@constructor_calldata1).unwrap();
        let dispatcher1 = IElectronicSignatureDispatcher { contract_address: contract_address1 };
    
        // Second contract with different version
        let contract_name2 = 'ElectronicSignature';
        let contract_version2 = 'v2.0.0';  // Different version
        let chain_id2 = 1;
    
        let contract2 = declare("ElectronicSignature").unwrap().contract_class();
        let constructor_calldata2 = array![
            owner.into(), 
            contract_name2, 
            contract_version2, 
            chain_id2
        ];
        let (contract_address2, _) = contract2.deploy(@constructor_calldata2).unwrap();
        let dispatcher2 = IElectronicSignatureDispatcher { contract_address: contract_address2 };
        
        // Now test if the domain separator correctly prevents cross-contract signature replay
        let document_id = 'same_document';
        let document_hash = 0x1234567890abcdef;
        let signer = contract_address_const(0x123);
        
        // Hash the same document data on both contracts
        let hash1 = dispatcher1.hash_typed_data(document_id, document_hash, signer, QES_LEVEL);
        let hash2 = dispatcher2.hash_typed_data(document_id, document_hash, signer, QES_LEVEL);
        
        // Hashes should differ due to different domain separators (prevents replay attacks)
        assert(hash1 != hash2, 'Domain separation failed');
    }
    
    #[test]
    fn test_get_signature() {
        // Deploy contract instance
        let (_, dispatcher) = deploy_contract();
        
        // Check non-existent signature
        let nonexistent_id = 'nonexistent';
        let signer_address = contract_address_const(0x123);
        
        // Query signature that doesn't exist
        let empty_sig = dispatcher.get_signature(nonexistent_id, signer_address);
        
        // Non-existent signatures should have default values
        assert(empty_sig.document_hash == 0, 'Empty hash');
        assert(empty_sig.is_revoked == false, 'Not marked revoked');
        assert(empty_sig.document_id == 0, 'Empty document ID');
    }
    
    #[test]
    fn test_hash_inputs() {
        // Deploy contract instance
        let (_, dispatcher) = deploy_contract();
        
        // Test data
        let document_id = 'test_doc';
        let signer1 = contract_address_const(0x123);
        let signer2 = contract_address_const(0x456);
        
        // Test with different document hashes
        let hash1 = 0x1111111111111111;
        let hash2 = 0x2222222222222222;
        
        // Generate typed data hashes
        let typed_hash1 = dispatcher.hash_typed_data(document_id, hash1, signer1, QES_LEVEL);
        let typed_hash2 = dispatcher.hash_typed_data(document_id, hash2, signer1, QES_LEVEL);
        
        // Different document hashes should result in different typed data hashes
        assert(typed_hash1 != typed_hash2, 'Document hash influence');
        
        // Test with different signers (valid addresses)
        let hash_signer1 = dispatcher.hash_typed_data(document_id, hash1, signer1, QES_LEVEL);
        let hash_signer2 = dispatcher.hash_typed_data(document_id, hash1, signer2, QES_LEVEL);
        
        // Different signers should produce different hashes
        assert(hash_signer1 != hash_signer2, 'Signer influence');
    }
    
    #[test]
    fn test_domain_chain_id() {
        // Deploy two contracts with different chain IDs
        let owner = contract_address_const(0x1);
        let contract_name = 'ElectronicSignature';
        let contract_version = 'v1.0.0';
        
        // First contract with chain ID 1 (e.g., mainnet)
        let chain_id1 = 1;
        let contract1 = declare("ElectronicSignature").unwrap().contract_class();
        let constructor_calldata1 = array![
            owner.into(), 
            contract_name, 
            contract_version, 
            chain_id1
        ];
        let (contract_address1, _) = contract1.deploy(@constructor_calldata1).unwrap();
        let dispatcher1 = IElectronicSignatureDispatcher { contract_address: contract_address1 };
    
        // Second contract with chain ID 5 (e.g., testnet)
        let chain_id2 = 5;
        let contract2 = declare("ElectronicSignature").unwrap().contract_class();
        let constructor_calldata2 = array![
            owner.into(), 
            contract_name, 
            contract_version, 
            chain_id2
        ];
        let (contract_address2, _) = contract2.deploy(@constructor_calldata2).unwrap();
        let dispatcher2 = IElectronicSignatureDispatcher { contract_address: contract_address2 };
        
        // Test data
        let document_id = 'test_chain_id';
        let document_hash = 0x1234567890abcdef;
        let signer = contract_address_const(0x123);
        
        // Generate hashes on both contracts
        let hash1 = dispatcher1.hash_typed_data(document_id, document_hash, signer, QES_LEVEL);
        let hash2 = dispatcher2.hash_typed_data(document_id, document_hash, signer, QES_LEVEL);
        
        // Hashes should differ due to different chain IDs (prevents cross-chain replay)
        assert(hash1 != hash2, 'Chain ID separation failed');
    }
    
    #[test]
    fn test_contract_address_isolation() {
        // Deploy two instances with the same parameters to different addresses
        let owner = contract_address_const(0x1);
        let contract_name = 'ElectronicSignature';
        let contract_version = 'v1.0.0';
        let chain_id = 1;
    
        // First contract instance
        let contract1 = declare("ElectronicSignature").unwrap().contract_class();
        let constructor_calldata = array![
            owner.into(), 
            contract_name, 
            contract_version, 
            chain_id
        ];
        let (contract_address1, _) = contract1.deploy(@constructor_calldata).unwrap();
        let dispatcher1 = IElectronicSignatureDispatcher { contract_address: contract_address1 };
        
        // Second contract instance
        let contract2 = declare("ElectronicSignature").unwrap().contract_class();
        let (contract_address2, _) = contract2.deploy(@constructor_calldata).unwrap();
        let dispatcher2 = IElectronicSignatureDispatcher { contract_address: contract_address2 };
        
        // Test data
        let document_id = 'test_contract_address';
        let document_hash = 0x1234567890abcdef;
        let signer = contract_address_const(0x123);
        
        // Generate hashes on both contract instances
        let hash1 = dispatcher1.hash_typed_data(document_id, document_hash, signer, QES_LEVEL);
        let hash2 = dispatcher2.hash_typed_data(document_id, document_hash, signer, QES_LEVEL);
        
        // Hashes should be different due to different contract addresses in domain
        assert(hash1 != hash2, 'Contract address isolation');
    }
    
    #[test]
    fn test_hash_security_properties() {
        // Deploy contract instance
        let (_, dispatcher) = deploy_contract();
        
        // Test data
        let document_id = 'test_security';
        let signer = contract_address_const(0x123);
        
        // Slightly different document hashes
        let hash1 = 0x1234567890abcdef;
        let hash2 = 0x1234567890abcdee; // Only differs in last hex digit
        
        // Generate typed data hashes
        let typed_hash1 = dispatcher.hash_typed_data(document_id, hash1, signer, QES_LEVEL);
        let typed_hash2 = dispatcher.hash_typed_data(document_id, hash2, signer, QES_LEVEL);
        
        // Even a small change in the document hash should result in a completely different hash
        // This tests the avalanche effect of the hashing function
        assert(typed_hash1 != typed_hash2, 'Hash avalanche effect');
        
        // Test different document IDs
        let id1 = 'test_id_1';
        let id2 = 'test_id_2';
        
        let hash_id1 = dispatcher.hash_typed_data(id1, hash1, signer, QES_LEVEL);
        let hash_id2 = dispatcher.hash_typed_data(id2, hash1, signer, QES_LEVEL);
        
        // Different document IDs should produce different hashes
        assert(hash_id1 != hash_id2, 'ID uniqueness');
    }
    
    #[test]
    fn test_signature_level_validation() {
        // Deploy contract instance
        let (_, dispatcher) = deploy_contract();
        
        // Standard valid levels should work
        let document_id = 'test_validation';
        let document_hash = 0x1234567890abcdef;
        let signer = contract_address_const(0x123);
        
        // All these should succeed
        let _hash_qes = dispatcher.hash_typed_data(document_id, document_hash, signer, QES_LEVEL);
        let _hash_aes = dispatcher.hash_typed_data(document_id, document_hash, signer, AES_LEVEL);
        let _hash_ses = dispatcher.hash_typed_data(document_id, document_hash, signer, SES_LEVEL);
        
        // Each level should produce unique hash
        assert(_hash_qes != _hash_aes, 'QES != AES');
        assert(_hash_qes != _hash_ses, 'QES != SES');
        assert(_hash_aes != _hash_ses, 'AES != SES');
    }
}