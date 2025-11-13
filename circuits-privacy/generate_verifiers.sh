#!/bin/bash

# Script to generate Solidity verifiers from compiled Noir circuits
# Uses bb (Barretenberg) backend to generate verification keys and contracts

set -e

echo "Generating Solidity verifiers for privacy circuits..."

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Add bb to PATH
export PATH="$HOME/.bb:$PATH"

# Check if bb is installed
if ! command -v bb &> /dev/null; then
    echo -e "${YELLOW}bb not found. Installing...${NC}"
    curl -L https://raw.githubusercontent.com/AztecProtocol/aztec-packages/master/barretenberg/cpp/installation/install | bash
    export PATH="$HOME/.bb:$PATH"
    bbup -v 0.63.0
fi

# Circuit directories
CIRCUITS=("deposit" "transfer" "withdraw")

# Create output directory for verifiers
mkdir -p ../src/verifier/privacy

for circuit in "${CIRCUITS[@]}"; do
    echo -e "${BLUE}Generating verifier for $circuit circuit...${NC}"
    
    cd "$circuit"
    
    # Generate verification key
    echo "  Generating verification key..."
    bb write_vk -b ./target/sp_nft_${circuit}.json -o ./target/
    
    # Generate Solidity verifier contract
    echo "  Generating Solidity contract..."
    bb contract -k ./target/vk -o ./target/${circuit}_verifier.sol
    
    # Copy to src/verifier directory
    if [ -f "./target/${circuit}_verifier.sol" ]; then
        cp "./target/${circuit}_verifier.sol" "../../src/verifier/privacy/${circuit^}Verifier.sol"
        echo -e "${GREEN}✓ $circuit verifier generated successfully${NC}"
    else
        echo -e "${YELLOW}⚠ Warning: Verifier not found for $circuit${NC}"
    fi
    
    cd ..
done

echo -e "${GREEN}All verifiers generated successfully!${NC}"
echo ""
echo "Verifier contracts saved to: src/verifier/privacy/"
ls -1 ../src/verifier/privacy/*.sol 2>/dev/null || echo "No verifier files found"


