mod utils {
    pub mod constants;
    pub mod typed_data;
    pub mod signature;
    pub mod events;
}

mod interfaces {
    pub mod iesg;
}

mod contracts {
    pub mod esg;
}

mod tests {
    pub mod test_esg;
}

// Re-export the main contract and interface
pub use contracts::esg::ElectronicSignature;
pub use interfaces::iesg::IElectronicSignature;

// Make sure tests are picked up
// This trick ensures test modules are included in the binary
#[cfg(test)]
pub use tests::test_esg;