// StarkNet Electronic Signature - Main Module
// This module organizes the project structure and exports public interfaces

/// Utility modules containing common functionality used throughout the project
mod utils {
    /// Constants defining signature types according to eIDAS regulations
    pub mod constants;
    
    /// TypedData structures for structured document signing (inspired by EIP-712)
    pub mod typed_data;
    
    /// Document signature structure and related functionality
    pub mod signature;
    
    /// Event definitions for contract actions (signing, revocation)
    pub mod events;
}

/// Contract interfaces that define the public API
mod interfaces {
    /// Interface for the Electronic Signature contract
    pub mod iesg;
}

/// Contract implementations
mod contracts {
    /// Main Electronic Signature contract implementation
    pub mod esg;
}


// Re-export the main contract and interface for easier imports by consumers
pub use contracts::esg::ElectronicSignature;
pub use interfaces::iesg::IElectronicSignature;

/// Test modules for verifying functionality
mod tests {
    /// Tests for the Electronic Signature contract
    pub mod test_esg;
}

// Make sure tests are picked up by the Cairo test runner
// This trick ensures test modules are included in the binary even in release builds
#[cfg(test)]
pub use tests::test_esg;