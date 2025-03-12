#[starknet::contract]
mod ElectronicSignature {
    use core::array::ArrayTrait;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::introspection::interface::ISRC5_ID;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::interface::IERC20;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::get_block_timestamp;
    use starknet::info::get_contract_address;
    use starknet::class_hash::ClassHash;
    use core::hash::LegacyHash;
    use core::traits::Into;
    use core::traits::TryInto;
    use core::pedersen::pedersen;

    // Component Declarations
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // Interface implementations
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;

    // eIDAS Electronic Signature Levels
    const QES_LEVEL: felt252 = 'QES'; // Qualified Electronic Signature
    const AES_LEVEL: felt252 = 'AES'; // Advanced Electronic Signature
    const SES_LEVEL: felt252 = 'SES'; // Simple Electronic Signature

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

    // Document signature structure
    #[derive(Drop, Copy, Serde, starknet::Store)]
    struct DocumentSignature {
        document_id: felt252,
        document_hash: felt252,
        signer_address: ContractAddress,
        timestamp: u64,
        signature_level: felt252,
        is_revoked: bool,
        expiration_time: u64, // Added expiration timestamp for security
    }

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        DocumentSigned: DocumentSigned,
        SignatureRevoked: SignatureRevoked,
        OwnableEvent: OwnableComponent::Event,
        SRC5Event: SRC5Component::Event,
    }

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

    // Storage
    #[storage]
    struct Storage {
        document_signatures: starknet::storage::Map::<(felt252, ContractAddress), DocumentSignature>,
        domain_separator: Domain,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    // Constructor
    #[constructor]
    fn constructor(
        ref self: ContractState,
        initial_owner: ContractAddress,
        contract_name: felt252,
        contract_version: felt252,
        chain_id: felt252
    ) {
        // Initialize components
        self.ownable.initializer(initial_owner);
        self.src5.register_interface(ISRC5_ID);

        // Set domain separator with configurable chain_id
        let domain_value = Domain {
            name: contract_name,
            version: contract_version,
            chain_id: chain_id,
            verifying_contract: get_contract_address(),
            salt: 0,
        };
        self.domain_separator.write(domain_value);
    }

    // Contract functions
    #[abi(embed_v0)]
    impl ElectronicSignatureImpl of super::IElectronicSignature<ContractState> {
        // Check if a signature is expired
        fn is_signature_expired(
            self: @ContractState,
            document_id: felt252,
            signer: ContractAddress
        ) -> bool {
            let signature = self.document_signatures.read((document_id, signer));
            
            // If signature doesn't exist or has no hash, consider it expired
            if signature.document_hash == 0 {
                return true;
            }
            
            let current_time = get_block_timestamp();
            current_time > signature.expiration_time
        }
        fn sign_document(
            ref self: ContractState,
            document_id: felt252, 
            document_data: Array<felt252>,
            signature_level: felt252,
            validity_period: u64
        ) -> DocumentSignature {
            // Ensure valid signature level
            assert(
                signature_level == QES_LEVEL || 
                signature_level == AES_LEVEL || 
                signature_level == SES_LEVEL,
                'Invalid signature level'
            );
            
            // Validate document data
            assert(document_data.len() > 0, 'Empty document data');
            
            // Get caller as signer
            let signer = get_caller_address();
            let timestamp = get_block_timestamp();
            
            // Set expiration time based on validity period
            // Default to 1 year (31536000 seconds) if not specified
            let expiration = if validity_period == 0 {
                timestamp + 31536000_u64
            } else {
                timestamp + validity_period
            };
            
            // Calculate document hash using enhanced hashing
            let document_hash = self._calculate_document_hash(document_data);
            
            // Create the signature object with expiration
            let signature = DocumentSignature {
                document_id: document_id,
                document_hash: document_hash,
                signer_address: signer,
                timestamp: timestamp,
                signature_level: signature_level,
                is_revoked: false,
                expiration_time: expiration,
            };
            
            // Store the signature
            self.document_signatures.write((document_id, signer), signature);
            
            // Emit event
            self.emit(
                DocumentSigned {
                    document_id: document_id,
                    document_hash: document_hash,
                    signer: signer,
                    timestamp: timestamp,
                    signature_level: signature_level
                }
            );
            
            signature
        }

        fn verify_document_signature(
            self: @ContractState,
            document_id: felt252,
            signer: ContractAddress,
            document_data: Array<felt252>
        ) -> bool {
            // Get stored signature
            let signature = self.document_signatures.read((document_id, signer));
            
            // Validate document exists (non-zero hash)
            if signature.document_hash == 0 {
                return false;
            }
            
            // Check if signature is revoked
            if signature.is_revoked {
                return false;
            }
            
            // Check if signature is expired
            let current_time = get_block_timestamp();
            if current_time > signature.expiration_time {
                return false;
            }
            
            // Calculate hash of provided data
            let computed_hash = self._calculate_document_hash(document_data);
            
            // Compare with the stored hash
            computed_hash == signature.document_hash
        }

        fn revoke_signature(
            ref self: ContractState,
            document_id: felt252
        ) {
            // Get the signer (caller)
            let signer = get_caller_address();
            
            // Get stored signature
            let mut signature = self.document_signatures.read((document_id, signer));
            
            // Ensure signature exists
            assert(signature.document_hash != 0, 'Signature does not exist');
            
            // Ensure signature is not already revoked
            assert(!signature.is_revoked, 'Already revoked');
            
            // Revoke the signature
            signature.is_revoked = true;
            
            // Update storage
            self.document_signatures.write((document_id, signer), signature);
            
            // Emit event
            self.emit(
                SignatureRevoked {
                    document_id: document_id,
                    signer: signer,
                    timestamp: get_block_timestamp()
                }
            );
        }

        fn get_signature(
            self: @ContractState,
            document_id: felt252,
            signer: ContractAddress
        ) -> DocumentSignature {
            self.document_signatures.read((document_id, signer))
        }

        fn hash_typed_data(
            self: @ContractState,
            document_id: felt252,
            document_hash: felt252,
            signer: ContractAddress,
            signature_level: felt252
        ) -> felt252 {
            let domain = self.domain_separator.read();
            
            let message = DocumentMessage {
                document_id: document_id,
                document_hash: document_hash,
                timestamp: get_block_timestamp(),
                signer: signer,
                signature_level: signature_level
            };
            
            let typed_data = TypedData { domain, message };
            self._hash_typed_data(typed_data)
        }
    }

    // Internal functions
    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _calculate_document_hash(self: @ContractState, data: Array<felt252>) -> felt252 {
            // Enhanced security hash implementation
            // 1. Use a domain separator as prefix to prevent cross-domain attacks
            let domain = self.domain_separator.read();
            let domain_name_hash = LegacyHash::hash('DOCUMENT_HASH', domain.name);
            
            // 2. Include length as part of hash to prevent length extension attacks
            let data_length_felt: felt252 = data.len().into();
            let length_hash = LegacyHash::hash(domain_name_hash, data_length_felt);
            
            // 3. Use multi-round hashing with non-linear combination
            let mut hash: felt252 = length_hash;
            let mut i: u32 = 0;
            
            // First round - sequential hashing
            loop {
                if i >= data.len() {
                    break;
                }
                
                // Apply Pedersen hash for each element
                hash = pedersen(hash, *data.at(i));
                i += 1;
            };
            
            // Second round - fold hash with domain information for additional security
            hash = LegacyHash::hash(hash, domain.chain_id);
            
            // Final mixing step
            let contract_felt: felt252 = domain.verifying_contract.into();
            hash = LegacyHash::hash(hash, contract_felt);
            
            hash
        }

        fn _hash_domain(self: @ContractState, domain: Domain) -> felt252 {
            let mut state = LegacyHash::hash('EIP712Domain', 0);
            state = LegacyHash::hash(state, domain.name);
            state = LegacyHash::hash(state, domain.version);
            state = LegacyHash::hash(state, domain.chain_id);
            // Convert ContractAddress to felt252 using TryInto
            let contract_felt: felt252 = domain.verifying_contract.into();
            state = LegacyHash::hash(state, contract_felt);
            state = LegacyHash::hash(state, domain.salt);
            state
        }
        
        fn _hash_message(self: @ContractState, message: DocumentMessage) -> felt252 {
            let mut state = LegacyHash::hash('DocumentMessage', 0);
            state = LegacyHash::hash(state, message.document_id);
            state = LegacyHash::hash(state, message.document_hash);
            let timestamp_felt: felt252 = message.timestamp.into();
            state = LegacyHash::hash(state, timestamp_felt);
            // Convert ContractAddress to felt252 using TryInto
            let signer_felt: felt252 = message.signer.into();
            state = LegacyHash::hash(state, signer_felt);
            state = LegacyHash::hash(state, message.signature_level);
            state
        }
        
        fn _hash_typed_data(self: @ContractState, data: TypedData) -> felt252 {
            let domain_hash = self._hash_domain(data.domain);
            let message_hash = self._hash_message(data.message);
            LegacyHash::hash(domain_hash, message_hash)
        }
    }
}

// Contract interface
#[starknet::interface]
trait IElectronicSignature<TContractState> {
    fn sign_document(
        ref self: TContractState,
        document_id: felt252, 
        document_data: Array<felt252>,
        signature_level: felt252,
        validity_period: u64
    ) -> ElectronicSignature::DocumentSignature;

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
    ) -> ElectronicSignature::DocumentSignature;
    
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

#[cfg(test)]
mod tests {
    use super::{ElectronicSignature, IElectronicSignature};
    use super::ElectronicSignature::{QES_LEVEL, AES_LEVEL, SES_LEVEL, DocumentSignature};
    use starknet::{ContractAddress, testing};
    use core::array::ArrayTrait;
    use core::traits::TryInto;
    use core::option::OptionTrait;
    use starknet::testing::set_caller_address;
    
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
