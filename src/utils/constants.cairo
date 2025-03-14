// Electronic Signature Levels based on EU eIDAS regulation
// https://www.eidas.org/electronic-signatures/

/// QES (Qualified Electronic Signature):
/// The highest security level defined by eIDAS, legally equivalent to handwritten signatures.
/// Requires a qualified certificate issued by a trusted provider and created using a qualified
/// signature creation device. Offers the strongest legal certainty across EU member states.
const QES_LEVEL: felt252 = 'QES'; // Qualified Electronic Signature

/// AES (Advanced Electronic Signature):
/// Medium security level that uniquely identifies the signer and detects any changes
/// made to the document after signing. Requires security features like PKI but doesn't 
/// need qualified certificates or hardware.
const AES_LEVEL: felt252 = 'AES'; // Advanced Electronic Signature

/// SES (Simple Electronic Signature):
/// Basic security level for any data in electronic form attached to other data
/// and used by a signer to sign. Offers minimal legal protection and is used for
/// low-risk scenarios where strong authentication isn't critical.
const SES_LEVEL: felt252 = 'SES'; // Simple Electronic Signature