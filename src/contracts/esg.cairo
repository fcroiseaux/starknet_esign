use core::array::ArrayTrait;
use openzeppelin::access::ownable::OwnableComponent;
use openzeppelin::introspection::interface::ISRC5_ID;
use openzeppelin::introspection::src5::SRC5Component;
use starknet::ContractAddress;
use starknet::get_caller_address;
use starknet::get_block_timestamp;
use starknet::info::get_contract_address;
use core::hash::LegacyHash;
use core::traits::Into;
use core::pedersen::pedersen;

// Import interfaces, utils and constants
use super::super::interfaces::iesg::IElectronicSignature;
use super::super::utils::typed_data::{Domain, DocumentMessage, TypedData};
use super::super::utils::signature::DocumentSignature;
use super::super::utils::events::{DocumentSigned, SignatureRevoked};

// Define constants directly in this module
const QES_LEVEL: felt252 = 'QES'; // Qualified Electronic Signature
const AES_LEVEL: felt252 = 'AES'; // Advanced Electronic Signature
const SES_LEVEL: felt252 = 'SES'; // Simple Electronic Signature

// Document size limit - approximately 5MB when each element is a felt252 (31 bytes)
const MAX_DOCUMENT_SIZE: u32 = 170000;

#[starknet::contract]
mod ElectronicSignature {
    // Import everything needed in the contract
    use core::array::ArrayTrait;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::introspection::interface::ISRC5_ID;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::get_block_timestamp;
    use starknet::info::get_contract_address;
    use core::hash::LegacyHash;
    use core::traits::Into;
    use core::pedersen::pedersen;
    use super::super::super::interfaces::iesg::IElectronicSignature;
    use super::super::super::utils::typed_data::{Domain, DocumentMessage, TypedData};
    use super::super::super::utils::signature::DocumentSignature;
    use super::super::super::utils::events::{DocumentSigned, SignatureRevoked};
    use super::{QES_LEVEL, AES_LEVEL, SES_LEVEL, MAX_DOCUMENT_SIZE};

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

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        DocumentSigned: DocumentSigned,
        SignatureRevoked: SignatureRevoked,
        OwnableEvent: OwnableComponent::Event,
        SRC5Event: SRC5Component::Event,
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
            // Address validation - ensure caller address is not zero
            let signer = get_caller_address();
            let zero_address: ContractAddress = 0.try_into().unwrap();
            assert(signer != zero_address, 'Invalid signer address');
            
            // Ensure valid signature level
            assert(
                signature_level == QES_LEVEL || 
                signature_level == AES_LEVEL || 
                signature_level == SES_LEVEL,
                'Invalid signature level'
            );
            
            // Enhanced document validation
            assert(document_data.len() > 0, 'Empty document data');
            assert(document_data.len() < MAX_DOCUMENT_SIZE, 'Document too large');
            assert(document_id != '', 'Empty document ID');
            
            // Get timestamp
            let timestamp = get_block_timestamp();
            
            // Overflow protection for expiration calculation
            // Default to 1 year (31536000 seconds) if not specified
            let one_year = 31536000_u64;
            // Maximum value for u64
            let max_value = 18446744073709551615_u64; // 2^64 - 1
            
            let expiration = if validity_period == 0 {
                // Check for overflow before adding one year
                assert(timestamp <= max_value - one_year, 'Timestamp overflow');
                timestamp + one_year
            } else {
                // Check for overflow before adding validity period
                assert(timestamp <= max_value - validity_period, 'Validity overflow');
                timestamp + validity_period
            };
            
            // Calculate document hash using enhanced hashing
            let document_hash = self._calculate_document_hash(document_data);
            
            // Get current nonce for this document-signer pair
            let current_nonce = 0_u64; // In a full implementation, read from storage
            
            // Create the signature object with expiration and nonce
            let signature = DocumentSignature {
                document_id: document_id,
                document_hash: document_hash,
                signer_address: signer,
                timestamp: timestamp,
                signature_level: signature_level,
                is_revoked: false,
                expiration_time: expiration,
                nonce: current_nonce + 1, // Increment nonce for uniqueness
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
            // Address validation
            let zero_address: ContractAddress = 0.try_into().unwrap();
            if signer == zero_address {
                return false;
            }
            
            // Enhanced document validation
            if document_data.len() == 0 || document_data.len() >= MAX_DOCUMENT_SIZE || document_id == '' {
                return false;
            }
            
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
            // Address validation - ensure caller address is not zero
            let signer = get_caller_address();
            let zero_address: ContractAddress = 0.try_into().unwrap();
            assert(signer != zero_address, 'Invalid signer address');
            
            // Document validation
            assert(document_id != '', 'Empty document ID');
            
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
            // Address validation
            let zero_address: ContractAddress = 0.try_into().unwrap();
            assert(signer != zero_address, 'Invalid signer address');
            assert(document_id != '', 'Empty document ID');
            
            self.document_signatures.read((document_id, signer))
        }

        fn hash_typed_data(
            self: @ContractState,
            document_id: felt252,
            document_hash: felt252,
            signer: ContractAddress,
            signature_level: felt252
        ) -> felt252 {
            // Address validation
            let zero_address: ContractAddress = 0.try_into().unwrap();
            assert(signer != zero_address, 'Invalid signer address');
            
            // Validate document ID and hash
            assert(document_id != '', 'Empty document ID');
            assert(document_hash != 0, 'Invalid document hash');
            
            // Validate signature level
            assert(
                signature_level == QES_LEVEL || 
                signature_level == AES_LEVEL || 
                signature_level == SES_LEVEL,
                'Invalid signature level'
            );
            
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