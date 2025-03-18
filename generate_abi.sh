#!/bin/bash
# Script to generate ABI from a StarkNet ESG contract

# Ensure the abi directory exists
mkdir -p abi

echo "Compiling contract with Scarb..."
scarb build

# The target directory where Scarb outputs compiled contracts
TARGET_DIR="target"

# Find the contract class JSON file (could be in dev/ or release/)
ABI_FILE_DEV="${TARGET_DIR}/dev/starknet_esign_ElectronicSignature.contract_class.json"
ABI_FILE_RELEASE="${TARGET_DIR}/release/starknet_esign_ElectronicSignature.contract_class.json"

if [ -f "$ABI_FILE_DEV" ]; then
  ABI_FILE="$ABI_FILE_DEV"
elif [ -f "$ABI_FILE_RELEASE" ]; then
  ABI_FILE="$ABI_FILE_RELEASE"
else
  echo "Error: Could not find compiled contract file. Make sure the contract compiles successfully."
  exit 1
fi

echo "Found compiled contract at: $ABI_FILE"

# Extract the ABI section from the contract class file
echo "Extracting ABI..."
jq '.abi' "$ABI_FILE" > "abi/ElectronicSignature.json"

echo "ABI generated successfully at: abi/ElectronicSignature.json"
echo "✅ Complete"

# Make script executable
chmod +x generate_abi.sh