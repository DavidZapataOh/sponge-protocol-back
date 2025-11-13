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
CIRCUITS=("deposit" "transfer" "withdraw" "ownership")

for circuit in "${CIRCUITS[@]}"; do
    echo -e "${BLUE}Building $circuit circuit...${NC}"
    
    cd "$circuit"
    
    # Compile the circuit
    echo "Compiling circuit..."
    nargo compile
    
    # Note: Verifier generation (codegen-verifier) is not available in this version of nargo
    # Verifiers need to be generated using the backend tool (bb) separately
    
    echo -e "${GREEN}✓ $circuit circuit compiled successfully${NC}"
    
    cd ..
done

echo -e "${GREEN}All circuits compiled successfully!${NC}"
echo ""
echo "Circuit artifacts generated in target/ directories"
echo "Note: To generate Solidity verifiers, use the backend tool (bb) separately"


