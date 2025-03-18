/// IElectronicSignature defines the standard interface for document e-signatures on StarkNet
/// This interface outlines all public functions that an electronic signature contract must implement
#[starknet::interface]
pub trait IElectronicSignature<TContractState> {
    /// Creates a cryptographic signature for a document with automatic document ID generation
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
        ref self: TContractState,
        document_data: Array<felt252>,
        signature_level: felt252,
        validity_period: u64
    ) -> (felt252, crate::utils::signature::DocumentSignature);

    /// Verifies if a document signature is valid
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
        self: @TContractState,
        document_id: felt252,
        signer: starknet::ContractAddress,
        document_data: Array<felt252>
    ) -> bool;

    /// Revokes a previously created signature
    /// Only callable by the original signer
    /// 
    /// # Arguments
    ///
    /// * `document_id` - Identifier of the document whose signature should be revoked
    fn revoke_signature(ref self: TContractState, document_id: felt252);
    
    /// Retrieves a stored signature record
    /// 
    /// # Arguments
    ///
    /// * `document_id` - Identifier of the signed document
    /// * `signer` - Address of the signer whose signature to retrieve
    ///
    /// # Returns
    ///
    /// * `DocumentSignature` - The complete signature record with metadata
    fn get_signature(
        self: @TContractState, 
        document_id: felt252, 
        signer: starknet::ContractAddress
    ) -> crate::utils::signature::DocumentSignature;
    
    /// Creates a cryptographic hash of typed data for external verification
    /// Follows a similar pattern to EIP-712 for Ethereum
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
    fn hash_typed_data(
        self: @TContractState,
        document_id: felt252,
        document_hash: felt252,
        signer: starknet::ContractAddress,
        signature_level: felt252
    ) -> felt252;
    
    /// Checks if a signature has expired based on its validity period
    /// 
    /// # Arguments
    ///
    /// * `document_id` - Identifier of the signed document
    /// * `signer` - Address of the signer whose signature to check
    ///
    /// # Returns
    ///
    /// * `bool` - True if the signature has expired or doesn't exist
    fn is_signature_expired(
        self: @TContractState,
        document_id: felt252,
        signer: starknet::ContractAddress
    ) -> bool;
}