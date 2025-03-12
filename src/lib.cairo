// This module implements electronic document signing functionality
// with support for eIDAS compliance levels and EIP-712 inspired data structures

// EIP-712 inspired typed data structures
mod eip712 {
    // Domain separator for EIP-712 style typed data
    #[derive(Drop)]
    struct Domain {
        name: felt252,
        version: felt252,
        chain_id: felt252,
        verifying_contract: felt252,
        salt: felt252,
    }
    
    // Document message for signature
    #[derive(Drop)]
    struct DocumentMessage {
        document_id: felt252,
        document_hash: felt252,
        timestamp: felt252,
        signer: felt252,
        signature_level: felt252,
    }
    
    // Complete typed data for document signing
    #[derive(Drop)]
    struct TypedData {
        domain: Domain,
        message: DocumentMessage,
    }
    
    // Hash the domain data
    fn hash_domain(domain: Domain) -> felt252 {
        let mut hash = domain.name;
        hash = hash + domain.version;
        hash = hash + domain.chain_id;
        hash = hash + domain.verifying_contract;
        hash = hash + domain.salt;
        hash
    }
    
    // Hash the document message
    fn hash_message(message: DocumentMessage) -> felt252 {
        let mut hash = message.document_id;
        hash = hash + message.document_hash;
        hash = hash + message.timestamp;
        hash = hash + message.signer;
        hash = hash + message.signature_level;
        hash
    }
    
    // Hash the complete typed data
    fn hash_typed_data(data: TypedData) -> felt252 {
        let domain_hash = hash_domain(data.domain);
        let message_hash = hash_message(data.message);
        domain_hash + message_hash
    }
}

// eIDAS Electronic Signature Levels
const QES_LEVEL: felt252 = 'QES'; // Qualified Electronic Signature
const AES_LEVEL: felt252 = 'AES'; // Advanced Electronic Signature
const SES_LEVEL: felt252 = 'SES'; // Simple Electronic Signature

// Document signature structure
#[derive(Drop, Copy)]
struct DocumentSignature {
    document_id: felt252,
    document_hash: felt252,
    signer_address: felt252,
    timestamp: felt252,
    signature_level: felt252,
    is_revoked: bool,
}

// Calculate a simple hash for a document
fn calculate_document_hash(data: Array<felt252>) -> felt252 {
    let mut hash: felt252 = 0;
    let mut i: u32 = 0;
    
    loop {
        if i >= data.len() {
            break;
        }
        
        // Simple hash function (for demonstration only)
        hash = hash + *data.at(i);
        i += 1;
    };
    
    hash
}

// Create a document signature
fn sign_document(
    document_id: felt252, 
    document_data: Array<felt252>,
    signer_address: felt252,
    signature_level: felt252
) -> DocumentSignature {
    // Ensure valid signature level
    assert(
        signature_level == QES_LEVEL || 
        signature_level == AES_LEVEL || 
        signature_level == SES_LEVEL,
        'Invalid signature level'
    );
    
    // Calculate document hash
    let document_hash = calculate_document_hash(document_data);
    
    // Create the signature object
    DocumentSignature {
        document_id: document_id,
        document_hash: document_hash,
        signer_address: signer_address,
        timestamp: 0, // Would use block timestamp in a real contract
        signature_level: signature_level,
        is_revoked: false,
    }
}

// Verify a document signature
fn verify_document_signature(
    signature: DocumentSignature, 
    document_data: Array<felt252>
) -> bool {
    // Check if signature is revoked
    if signature.is_revoked {
        return false;
    }
    
    // Calculate hash of provided data
    let computed_hash = calculate_document_hash(document_data);
    
    // Compare with the stored hash
    computed_hash == signature.document_hash
}

// Revoke a signature
fn revoke_signature(ref signature: DocumentSignature) {
    signature.is_revoked = true;
}

#[cfg(test)]
mod tests {
    use super::{
        QES_LEVEL, AES_LEVEL, SES_LEVEL,
        calculate_document_hash, sign_document, verify_document_signature, revoke_signature
    };
    use array::ArrayTrait;
    
    #[test]
    fn test_document_signing() {
        // Create a sample document
        let document_id = 'test_contract_1';
        let mut document_data = ArrayTrait::new();
        document_data.append('This');
        document_data.append('is');
        document_data.append('a');
        document_data.append('test');
        document_data.append('document');
        
        let signer_address = 'signer_1';
        
        // Sign the document with QES level
        let signature = sign_document(
            document_id,
            document_data.clone(),
            signer_address,
            QES_LEVEL
        );
        
        // Verify the signature
        let is_valid = verify_document_signature(signature, document_data.clone());
        assert(is_valid, 'Signature should be valid');
        
        // Modify the document data
        let mut modified_data = document_data.clone();
        modified_data.append('modified');
        
        // Verify the modified document (should fail)
        let is_modified_valid = verify_document_signature(signature, modified_data);
        assert(!is_modified_valid, 'Should not verify');
    }
    
    #[test]
    fn test_signature_revocation() {
        // Create and sign a document
        let document_id = 'test_revoke';
        let mut document_data = ArrayTrait::new();
        document_data.append('Revocable');
        document_data.append('Document');
        
        let signer_address = 'signer_2';
        
        // Sign with AES level
        let mut signature = sign_document(
            document_id,
            document_data.clone(),
            signer_address,
            AES_LEVEL
        );
        
        // Verify initial validity
        assert(!signature.is_revoked, 'Should not be revoked');
        let is_valid = verify_document_signature(signature, document_data.clone());
        assert(is_valid, 'Should be valid');
        
        // Revoke the signature
        revoke_signature(ref signature);
        
        // Check revocation status
        assert(signature.is_revoked, 'Should be revoked');
        
        // Verify document after revocation (should fail)
        let is_valid_after = verify_document_signature(signature, document_data.clone());
        assert(!is_valid_after, 'Should be invalid');
    }
}
