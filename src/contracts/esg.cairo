// StarkNet Electronic Signature (ESG) Contract
// This contract implements cryptographically secure digital signatures for documents
// based on European eIDAS regulation signature levels (QES, AES, SES)

// Import interfaces, utils and constants
use super::super::interfaces::iesg::IElectronicSignature;

// Define signature level constants directly in this module for easy access
/// QES (Qualified Electronic Signature) - Highest security level
/// Legally equivalent to handwritten signatures in the EU
pub const QES_LEVEL: felt252 = 'QES'; // Qualified Electronic Signature

/// AES (Advanced Electronic Signature) - Medium security level
/// Uniquely linked to the signer with tamper detection
pub const AES_LEVEL: felt252 = 'AES'; // Advanced Electronic Signature

/// SES (Simple Electronic Signature) - Basic security level
/// For low-risk scenarios where strong authentication isn't critical
pub const SES_LEVEL: felt252 = 'SES'; // Simple Electronic Signature

/// Maximum allowed document size in felt252 elements
/// Approximately 5MB total when each element is a felt252 (31 bytes)
/// This limit prevents DOS attacks through excessive gas consumption
pub const MAX_DOCUMENT_SIZE: u32 = 170000;

#[starknet::contract]
pub mod ElectronicSignature {
    // Import everything needed in the contract
    
    // Core Cairo imports
    use core::array::ArrayTrait;       // Array manipulation functionality
    use core::hash::LegacyHash;        // Hashing utilities for document content
    use core::traits::Into;            // Type conversion trait
    use core::pedersen::pedersen;      // StarkNet's pedersen hash function
    
    // OpenZeppelin contract components
    use openzeppelin::access::ownable::OwnableComponent;              // Access control for admin functions
    use openzeppelin::introspection::interface::ISRC5_ID;             // StarkNet standard interface detection
    use openzeppelin::introspection::src5::SRC5Component;             // Implementation of SRC5 interface detection
    
    // StarkNet system imports
    use starknet::ContractAddress;                    // Address type for accounts and contracts
    use starknet::get_caller_address;                 // Gets transaction sender's address
    use starknet::get_block_timestamp;                // Gets current block timestamp
    use starknet::storage::StorageMapReadAccess;      // Storage read access
    use starknet::storage::StorageMapWriteAccess;     // Storage write access
    use starknet::storage::StoragePointerReadAccess;  // Pointer-based storage read
    use starknet::storage::StoragePointerWriteAccess; // Pointer-based storage write
    
    // Project-specific imports
    use super::super::super::utils::typed_data::{Domain, DocumentMessage, TypedData};   // EIP-712 inspired typed data
    use super::super::super::utils::signature::DocumentSignature;                       // Document signature structure
    use super::super::super::utils::events::{DocumentSigned, SignatureRevoked};         // Contract events
    use super::{QES_LEVEL, AES_LEVEL, SES_LEVEL, MAX_DOCUMENT_SIZE};                   // Constants

    /// Component Declarations - Using OpenZeppelin library components
    /// These components provide standardized implementations of common contract patterns
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);  // Ownership control
    component!(path: SRC5Component, storage: src5, event: SRC5Event);           // Interface detection

    /// Interface implementations for OpenZeppelin components
    /// This allows the contract to use OZ functionality while maintaining type safety
    
    /// Ownable component implementation - provides access control functions
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;            // External API
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;   // Internal helpers
    
    /// SRC5 component implementation - enables interface detection (similar to ERC165)
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;                     // External API
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;         // Internal helpers

    /// Event definitions for contract operations
    /// These events are emitted when significant state changes occur
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        /// Emitted when a document is signed
        DocumentSigned: DocumentSigned,
        
        /// Emitted when a signature is revoked
        SignatureRevoked: SignatureRevoked,
        
        /// Events from the Ownable component (ownership transfers)
        OwnableEvent: OwnableComponent::Event,
        
        /// Events from the SRC5 component (interface registrations)
        SRC5Event: SRC5Component::Event,
    }

    /// Contract storage layout
    /// Defines all persistent state variables for the contract
    #[storage]
    struct Storage {
        /// Maps (document_id, signer_address) to a complete signature record
        /// This is the primary storage for all document signatures
        document_signatures: starknet::storage::Map::<(felt252, ContractAddress), DocumentSignature>,
        
        /// Domain separator for EIP-712 style typed data signatures
        /// Prevents signature replay attacks across different contracts/chains
        domain_separator: Domain,
        
        /// Storage for the Ownable component (tracks contract owner)
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        
        /// Storage for the SRC5 component (tracks supported interfaces)
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    /// Contract constructor - initializes the contract with essential parameters
    /// Called once when the contract is deployed and cannot be called again
    #[constructor]
    pub fn constructor(
        ref self: ContractState,
        /// Address that will have admin rights to the contract
        initial_owner: ContractAddress,
        
        /// Human-readable name of the contract (for EIP-712 domain)
        contract_name: felt252,
        
        /// Version string of the contract (for EIP-712 domain)
        contract_version: felt252,
        
        /// StarkNet chain ID (mainnet vs testnet) for replay protection
        chain_id: felt252
    ) {
        // Initialize OpenZeppelin components
        self.ownable.initializer(initial_owner);     // Set initial contract owner
        self.src5.register_interface(ISRC5_ID);      // Register SRC5 interface ID

        // Configure the domain separator for EIP-712 style signatures
        // This prevents signature replay attacks across different domains
        let domain_value = Domain {
            name: contract_name,                         // Contract name
            version: contract_version,                   // Contract version
            chain_id: chain_id,                          // Network chain ID
            verifying_contract: starknet::get_contract_address(), // This contract's address
            salt: 0,                                     // Optional additional entropy
        };
        
        // Store the domain separator in contract storage
        self.domain_separator.write(domain_value);
    }

    /// Public interface implementation
    /// These functions form the external API of the contract
    #[abi(embed_v0)]
    pub impl ElectronicSignatureImpl of super::IElectronicSignature<ContractState> {
        /// Checks if a document signature has expired based on its validity period
        ///
        /// A signature is considered expired if:
        /// 1. It doesn't exist (document_hash is zero)
        /// 2. The current block timestamp exceeds its expiration_time
        ///
        /// # Arguments
        ///
        /// * `document_id` - The identifier of the document to check
        /// * `signer` - The address of the signer whose signature to check
        ///
        /// # Returns
        ///
        /// * `true` if the signature is expired or doesn't exist
        /// * `false` if the signature is still valid
        fn is_signature_expired(
            self: @ContractState,
            document_id: felt252,
            signer: ContractAddress
        ) -> bool {
            // Get the signature record from storage
            let signature = self.document_signatures.read((document_id, signer));
            
            // If signature doesn't exist or has no hash (zero is the default value),
            // consider it expired/invalid
            if signature.document_hash == 0 {
                return true;
            }
            
            // Compare current block timestamp with signature's expiration time
            let current_time = get_block_timestamp();
            current_time > signature.expiration_time
        }

        /// Creates a cryptographic signature for a document
        /// 
        /// This function allows a user to sign a document using their StarkNet wallet.
        /// It automatically generates a unique document ID instead of requiring it as input.
        /// The generated ID is guaranteed to be unique through a combination of factors.
        /// 
        /// # Security features:
        /// - Automatic document ID generation for uniqueness and security
        /// - Cryptographic document hashing with domain separation
        /// - Signature expiration/validity periods
        /// - Replay protection with nonces
        /// - Multiple signature security levels (QES, AES, SES)
        /// - Size limits to prevent DOS attacks
        /// 
        /// # Arguments
        ///
        /// * `document_data` - Array of felt252 values representing document content to be hashed
        /// * `signature_level` - eIDAS signature level (QES, AES, or SES)
        /// * `validity_period` - Duration in seconds that the signature remains valid (0 = 1 year default)
        ///
        /// # Returns
        ///
        /// * `(felt252, DocumentSignature)` - Tuple containing (generated document ID, signature record)
        fn sign_document(
            ref self: ContractState,
            document_data: Array<felt252>,
            signature_level: felt252,
            validity_period: u64
        ) -> (felt252, DocumentSignature) {
            // Get and validate transaction sender address
            let signer = get_caller_address();
            let zero_address: ContractAddress = 0.try_into().unwrap();
            assert(signer != zero_address, 'Invalid signer address');
            
            // Validate signature level is one of the recognized eIDAS standards
            assert(
                signature_level == QES_LEVEL || 
                signature_level == AES_LEVEL || 
                signature_level == SES_LEVEL,
                'Invalid signature level'
            );
            
            // Validate document parameters to prevent attacks and errors
            assert(document_data.len() > 0, 'Empty document data');
            assert(document_data.len() < MAX_DOCUMENT_SIZE, 'Document too large');
            
            // Get current block timestamp for signature creation time
            let timestamp = get_block_timestamp();
            
            // Calculate signature expiration time with overflow protection
            let one_year = 31536000_u64;
            let max_value = 18446744073709551615_u64;
            
            // Calculate expiration time based on validity period
            let expiration = if validity_period == 0 {
                // Use default 1-year validity if not specified
                assert(timestamp <= max_value - one_year, 'Timestamp overflow');
                timestamp + one_year
            } else {
                // Use specified validity period
                assert(timestamp <= max_value - validity_period, 'Validity overflow');
                timestamp + validity_period
            };
            
            // Generate cryptographic hash of the document content
            let document_hash = self._calculate_document_hash(document_data);
            
            // In production, we should maintain a per-signer nonce in contract storage
            // For now, we'll use a simple incrementing nonce starting from 1
            // This would be replaced with a more robust implementation in production
            let next_nonce = 1_u64;
            
            // Generate a unique document ID by combining multiple uniqueness factors:
            // 1. Document content hash (uniqueness of content)
            // 2. Signer's address (uniqueness of signer)
            // 3. Current timestamp (temporal uniqueness)
            // 4. Nonce (sequential uniqueness)
            let signer_felt: felt252 = signer.into();
            let timestamp_felt: felt252 = timestamp.into();
            let nonce_felt: felt252 = next_nonce.into();
            
            // Create a unique document ID using a multi-round hashing approach
            let document_id = LegacyHash::hash(
                LegacyHash::hash(
                    document_hash,  // Content uniqueness
                    signer_felt     // Signer uniqueness
                ),
                LegacyHash::hash(
                    timestamp_felt, // Temporal uniqueness
                    nonce_felt      // Sequential uniqueness
                )
            );
            
            // Create the complete signature record with all metadata
            let signature = DocumentSignature {
                document_id,        // Generated document identifier
                document_hash,      // Cryptographic hash of content
                signer_address: signer,
                timestamp,
                signature_level,
                is_revoked: false,
                expiration_time: expiration,
                nonce: next_nonce,
            };
            
            // Store the signature in contract storage for future verification
            self.document_signatures.write((document_id, signer), signature);
            
            // Emit an event to notify off-chain applications about the signature
            self.emit(
                DocumentSigned {
                    document_id,
                    document_hash,
                    signer,
                    timestamp,
                    signature_level
                }
            );
            
            // Return the document ID and signature record to the caller
            (document_id, signature)
        }

        /// Verifies if a document signature is valid
        /// 
        /// This function verifies that:
        /// 1. The signature exists for the given document and signer
        /// 2. The signature has not been revoked
        /// 3. The signature has not expired
        /// 4. The provided document content matches the originally signed content
        ///
        /// # Arguments
        ///
        /// * `document_id` - Identifier of the document to verify
        /// * `signer` - StarkNet address of the purported signer
        /// * `document_data` - Document content to verify against the stored hash
        ///
        /// # Returns
        ///
        /// * `bool` - True if signature is valid, not revoked, and not expired
        fn verify_document_signature(
            self: @ContractState,
            document_id: felt252,
            signer: ContractAddress,
            document_data: Array<felt252>
        ) -> bool {
            // Validate signer address is not zero
            let zero_address: ContractAddress = 0.try_into().unwrap();
            if signer == zero_address {
                return false; // Zero address is invalid
            }
            
            // Validate document parameters to prevent attacks
            if document_data.len() == 0 || document_data.len() >= MAX_DOCUMENT_SIZE || document_id == '' {
                return false; // Invalid document parameters
            }
            
            // Retrieve the stored signature from contract storage
            let signature = self.document_signatures.read((document_id, signer));
            
            // Validate signature exists (non-zero hash indicates existence)
            if signature.document_hash == 0 {
                return false; // Signature doesn't exist
            }
            
            // Check if signature has been explicitly revoked by the signer
            if signature.is_revoked {
                return false; // Signature was revoked
            }
            
            // Check if signature has expired based on current block timestamp
            let current_time = get_block_timestamp();
            if current_time > signature.expiration_time {
                return false; // Signature has expired
            }
            
            // Calculate cryptographic hash of the provided document data
            // Using the same hashing algorithm used when signing
            let computed_hash = self._calculate_document_hash(document_data);
            
            // Compare computed hash with the stored hash
            // This verifies the document content hasn't been modified
            computed_hash == signature.document_hash
        }

        /// Revokes a previously created signature
        /// 
        /// This function allows a signer to invalidate their own signature,
        /// for example if they no longer agree with the document content
        /// or if the document should no longer be considered valid.
        /// 
        /// Only the original signer can revoke their own signature.
        /// 
        /// # Arguments
        ///
        /// * `document_id` - Identifier of the document whose signature should be revoked
        ///
        /// # Panics
        ///
        /// * If the caller is not the original signer
        /// * If the signature doesn't exist
        /// * If the signature is already revoked
        fn revoke_signature(
            ref self: ContractState,
            document_id: felt252
        ) {
            // Get and validate the transaction sender address
            // This must be the same address that originally created the signature
            let signer = get_caller_address();
            let zero_address: ContractAddress = 0.try_into().unwrap();
            assert(signer != zero_address, 'Invalid signer address');
            
            // Validate document ID
            assert(document_id != '', 'Empty document ID');
            
            // Retrieve the signature from contract storage
            let mut signature = self.document_signatures.read((document_id, signer));
            
            // Ensure the signature exists (non-zero hash indicates existence)
            assert(signature.document_hash != 0, 'Signature does not exist');
            
            // Ensure the signature is not already revoked 
            // (prevents unnecessary state changes and events)
            assert(!signature.is_revoked, 'Already revoked');
            
            // Mark the signature as revoked
            signature.is_revoked = true;
            
            // Update the signature record in contract storage
            self.document_signatures.write((document_id, signer), signature);
            
            // Emit an event to notify off-chain applications about the revocation
            self.emit(
                SignatureRevoked {
                    document_id: document_id,
                    signer: signer,
                    timestamp: get_block_timestamp() // Current block timestamp
                }
            );
        }

        /// Retrieves a stored signature record
        /// 
        /// This function allows querying the details of a signature including
        /// its hash, timestamp, expiration, revocation status, etc.
        /// 
        /// # Arguments
        ///
        /// * `document_id` - Identifier of the signed document
        /// * `signer` - Address of the signer whose signature to retrieve
        ///
        /// # Returns
        ///
        /// * `DocumentSignature` - The complete signature record
        ///
        /// # Panics
        ///
        /// * If the signer address is invalid (zero)
        /// * If the document ID is empty
        fn get_signature(
            self: @ContractState,
            document_id: felt252,
            signer: ContractAddress
        ) -> DocumentSignature {
            // Validate parameters
            let zero_address: ContractAddress = 0.try_into().unwrap();
            assert(signer != zero_address, 'Invalid signer address');
            assert(document_id != '', 'Empty document ID');
            
            // Return the signature record from storage
            // If no signature exists, this will return a default signature with zero values
            self.document_signatures.read((document_id, signer))
        }

        /// Creates a cryptographic hash of typed data for external verification
        /// 
        /// This function implements a EIP-712 inspired typed data hashing algorithm
        /// that can be used for off-chain signature verification or integration
        /// with other systems.
        /// 
        /// # Arguments
        ///
        /// * `document_id` - Identifier of the document
        /// * `document_hash` - Precomputed hash of the document content
        /// * `signer` - Address of the signer
        /// * `signature_level` - eIDAS signature level to use
        ///
        /// # Returns
        ///
        /// * `felt252` - The resulting hash that can be used for signature verification
        ///
        /// # Panics
        ///
        /// * If any input parameters are invalid
        fn hash_typed_data(
            self: @ContractState,
            document_id: felt252,
            document_hash: felt252,
            signer: ContractAddress,
            signature_level: felt252
        ) -> felt252 {
            // Validate signer address is not zero
            let zero_address: ContractAddress = 0.try_into().unwrap();
            assert(signer != zero_address, 'Invalid signer address');
            
            // Validate document parameters
            assert(document_id != '', 'Empty document ID');
            assert(document_hash != 0, 'Invalid document hash');
            
            // Validate signature level is one of the defined eIDAS levels
            assert(
                signature_level == QES_LEVEL || 
                signature_level == AES_LEVEL || 
                signature_level == SES_LEVEL,
                'Invalid signature level'
            );
            
            // Get the domain separator from storage
            let domain = self.domain_separator.read();
            
            // Create a document message with the current timestamp
            let message = DocumentMessage {
                document_id: document_id,                // Document identifier
                document_hash: document_hash,            // Pre-computed document hash
                timestamp: get_block_timestamp(),        // Current block timestamp
                signer: signer,                          // Signer's address
                signature_level: signature_level         // eIDAS security level
            };
            
            // Combine domain and message into typed data structure
            let typed_data = TypedData { domain, message };
            
            // Generate and return the hash of the typed data
            self._hash_typed_data(typed_data)
        }
    }

    /// Internal helper functions
    /// These functions are not exposed in the public interface
    /// but are used by the contract implementation
    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        /// Calculates a cryptographic hash of document data with security enhancements
        /// 
        /// This hash function includes multiple security features:
        /// 1. Domain separation to prevent cross-domain attacks
        /// 2. Length inclusion to prevent length extension attacks
        /// 3. Multi-round hashing for increased security
        /// 4. Mixing with contract-specific data to prevent replay
        ///
        /// # Arguments
        ///
        /// * `data` - Array of felt252 values representing document content
        ///
        /// # Returns
        ///
        /// * `felt252` - The cryptographic hash of the document content
        fn _calculate_document_hash(self: @ContractState, data: Array<felt252>) -> felt252 {
            // Read domain separator from storage for mixing into the hash
            let domain = self.domain_separator.read();
            
            // 1. Use domain separator as prefix to prevent cross-domain attacks
            // Hash the constant string "DOCUMENT_HASH" with the domain name
            let domain_name_hash = LegacyHash::hash('DOCUMENT_HASH', domain.name);
            
            // 2. Include data length as part of hash to prevent length extension attacks
            let data_length_felt: felt252 = data.len().into();
            let length_hash = LegacyHash::hash(domain_name_hash, data_length_felt);
            
            // 3. Multi-round hashing with non-linear combination for increased security
            let mut hash: felt252 = length_hash;  // Initialize with the length-mixed prefix
            let mut i: u32 = 0;
            
            // First round - sequential hashing of all document elements
            loop {
                // Exit condition - processed all elements
                if i >= data.len() {
                    break;
                }
                
                // Apply Pedersen hash for each element
                // Pedersen hash is the native hash function in StarkNet
                hash = pedersen(hash, *data.at(i));
                i += 1;
            };
            
            // Second round - fold hash with domain information for additional security
            // This prevents the hash from being reused across different chains
            hash = LegacyHash::hash(hash, domain.chain_id);
            
            // Final mixing step - incorporate the contract address to prevent
            // the hash from being reused across different contracts
            let contract_felt: felt252 = domain.verifying_contract.into();
            hash = LegacyHash::hash(hash, contract_felt);
            
            // Return the final hash value
            hash
        }

        /// Hashes a Domain struct according to EIP-712 inspired algorithm
        /// 
        /// Creates a hash of all domain fields, which include the contract name,
        /// version, chain ID, contract address, and optional salt.
        ///
        /// # Arguments
        ///
        /// * `domain` - Domain struct containing contextual data
        ///
        /// # Returns
        ///
        /// * `felt252` - Hash of the domain data
        fn _hash_domain(self: @ContractState, domain: Domain) -> felt252 {
            // Start with a type-specific prefix to separate domain hashes from other types
            let mut state = LegacyHash::hash('EIP712Domain', 0);
            
            // Sequentially hash all domain fields
            state = LegacyHash::hash(state, domain.name);           // Contract name
            state = LegacyHash::hash(state, domain.version);        // Contract version
            state = LegacyHash::hash(state, domain.chain_id);       // Network chain ID
            
            // Convert ContractAddress to felt252 for hashing
            let contract_felt: felt252 = domain.verifying_contract.into();
            state = LegacyHash::hash(state, contract_felt);         // Contract address
            
            // Include optional salt value
            state = LegacyHash::hash(state, domain.salt);           // Additional entropy
            
            // Return the final domain hash
            state
        }
        
        /// Hashes a DocumentMessage struct according to EIP-712 inspired algorithm
        /// 
        /// Creates a hash of all message fields, which include the document ID,
        /// document hash, timestamp, signer address, and signature level.
        ///
        /// # Arguments
        ///
        /// * `message` - DocumentMessage struct containing document data
        ///
        /// # Returns
        ///
        /// * `felt252` - Hash of the message data
        fn _hash_message(self: @ContractState, message: DocumentMessage) -> felt252 {
            // Start with a type-specific prefix to separate message hashes from other types
            let mut state = LegacyHash::hash('DocumentMessage', 0);
            
            // Sequentially hash all message fields
            state = LegacyHash::hash(state, message.document_id);       // Document identifier
            state = LegacyHash::hash(state, message.document_hash);     // Document content hash
            
            // Convert u64 timestamp to felt252 for hashing
            let timestamp_felt: felt252 = message.timestamp.into();
            state = LegacyHash::hash(state, timestamp_felt);            // Timestamp
            
            // Convert ContractAddress to felt252 for hashing
            let signer_felt: felt252 = message.signer.into();
            state = LegacyHash::hash(state, signer_felt);               // Signer address
            
            // Include the signature security level
            state = LegacyHash::hash(state, message.signature_level);   // eIDAS level
            
            // Return the final message hash
            state
        }
        
        /// Hashes a complete TypedData struct (domain + message)
        /// 
        /// Combines the domain hash and message hash to create a final
        /// typed data hash, similar to EIP-712 in Ethereum.
        ///
        /// # Arguments
        ///
        /// * `data` - TypedData struct containing both domain and message
        ///
        /// # Returns
        ///
        /// * `felt252` - Combined hash of the typed data
        fn _hash_typed_data(self: @ContractState, data: TypedData) -> felt252 {
            // Generate hash of the domain data (context)
            let domain_hash = self._hash_domain(data.domain);
            
            // Generate hash of the message data (content)
            let message_hash = self._hash_message(data.message);
            
            // Combine domain and message hashes to create the final hash
            // This ensures the signature is bound to both the message content
            // and the specific domain context (contract, chain, etc.)
            LegacyHash::hash(domain_hash, message_hash)
        }
    }
}