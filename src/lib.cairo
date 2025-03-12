mod utils {
    mod constants;
    mod typed_data;
    mod signature;
    mod events;
}

mod interfaces {
    mod iesg;
}

mod contracts {
    mod esg;
}

mod tests {
    mod test_esg;
}

// Re-export the main contract and interface
use contracts::esg::ElectronicSignature;
use interfaces::iesg::IElectronicSignature;

// Make sure tests are picked up
// This trick ensures test modules are included in the binary
#[cfg(test)]
pub use tests::test_esg;