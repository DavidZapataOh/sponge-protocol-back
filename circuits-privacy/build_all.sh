#!/bin/bash

# Build script for all privacy circuits
# This script compiles each circuit and generates Solidity verifiers

set -e

echo "Building privacy circuits for anonymous NFT transfers..."

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Circuit directories
CIRCUITS=("deposit" "transfer" "withdraw")

for circuit in "${CIRCUITS[@]}"; do
    echo -e "${BLUE}Building $circuit circuit...${NC}"
    
    cd "$circuit"
    
    # Compile the circuit
    echo "Compiling circuit..."
    nargo compile
    
    # Generate Solidity verifier
    echo "Generating Solidity verifier..."
    nargo codegen-verifier
    
    # Copy verifier to src/verifier directory
    if [ -f "contract/$circuit/plonk_vk.sol" ]; then
        echo "Copying verifier to src/verifier..."
        mkdir -p "../../src/verifier/privacy"
        
        # Create wrapper verifier contract
        cat > "../../src/verifier/privacy/${circuit^}Verifier.sol" << EOF
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { UltraVerifier as ${circuit^}UltraVerifier } from "./${circuit}_plonk_vk.sol";

/**
 * @title ${circuit^}Verifier
 * @notice Verifier for $circuit privacy circuit
 */
contract ${circuit^}Verifier {
    ${circuit^}UltraVerifier public verifier;

    constructor() {
        verifier = new ${circuit^}UltraVerifier();
    }

    function verify(bytes calldata proof, bytes32[] calldata publicInputs) public view returns (bool) {
        return verifier.verify(proof, publicInputs);
    }
}
EOF
        
        # Copy the actual verifier
        cp "contract/$circuit/plonk_vk.sol" "../../src/verifier/privacy/${circuit}_plonk_vk.sol"
        
        echo -e "${GREEN}✓ $circuit circuit built successfully${NC}"
    else
        echo "Warning: Verifier not found for $circuit"
    fi
    
    cd ..
done

echo -e "${GREEN}All circuits built successfully!${NC}"
echo ""
echo "Verifier contracts generated in: src/verifier/privacy/"
echo "- DepositVerifier.sol"
echo "- TransferVerifier.sol"
echo "- WithdrawVerifier.sol"


