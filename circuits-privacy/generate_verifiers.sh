#!/bin/bash

# Script to compile Noir circuits and generate Solidity verifiers using Barretenberg.
# Optional flag --with-proofs regenerates witness+proof fixtures for tests.

set -euo pipefail

WITH_PROOFS=0
if [[ "${1:-}" == "--with-proofs" ]]; then
    WITH_PROOFS=1
    shift
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "${SCRIPT_DIR}/.." && pwd)
DATA_DIR="${ROOT_DIR}/test/data"

echo "Generating Solidity verifiers for privacy circuits..."

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Add tools to PATH
export PATH="$HOME/.bb:$PATH"
export PATH="$HOME/.nargo/bin:$PATH"

# Ensure nargo is available
if ! command -v nargo &> /dev/null; then
    echo -e "${YELLOW}Nargo not found in PATH, adding it...${NC}"
    export PATH="$HOME/.nargo/bin:$PATH"
fi

# Check and install Nargo 1.0.0-beta.9
if ! command -v nargo &> /dev/null || [[ "$(nargo --version)" != *"1.0.0-beta.9"* ]]; then
    echo -e "${YELLOW}Installing Nargo 1.0.0-beta.9...${NC}"
    curl -L https://raw.githubusercontent.com/noir-lang/noirup/main/install | bash
    export PATH="$HOME/.nargo/bin:$PATH"
    noirup --version 1.0.0-beta.9
fi

# Check and install Barretenberg 0.87.0
if ! command -v bb &> /dev/null || [[ "$(bb --version)" != *"0.87.0"* ]]; then
    echo -e "${YELLOW}Installing Barretenberg 0.87.0...${NC}"
    curl -L https://raw.githubusercontent.com/AztecProtocol/aztec-packages/refs/heads/next/barretenberg/bbup/install | bash
    export PATH="$HOME/.bb:$PATH"
    source ~/.bashrc
    bbup --version 0.87.0
fi

mkdir -p "${ROOT_DIR}/src/verifier/privacy"

CIRCUITS=("deposit" "transfer" "withdraw" "ownership")

for circuit in "${CIRCUITS[@]}"; do
    echo -e "${BLUE}Generating verifier for $circuit circuit...${NC}"

    circuit_dir="${SCRIPT_DIR}/${circuit}"
    package_name="sp_nft_${circuit}"
    acir_path="${circuit_dir}/target/${package_name}.json"
    vk_dir="${circuit_dir}/target"
    verifier_path="${circuit_dir}/target/${circuit}_verifier.sol"

    pushd "${circuit_dir}" >/dev/null

    if [[ ! -f "${acir_path}" ]]; then
        echo -e "${RED}⚠ Error: ACIR file not found at ${acir_path}${NC}" >&2
        echo -e "${RED}⇢ Run 'nargo compile' inside ${circuit_dir} before executing this script.${NC}" >&2
        exit 1
    fi

    echo "  Generating verification key..."
    bb write_vk --scheme ultra_honk \
        -b "${acir_path}" \
        -o "${vk_dir}" \
        --oracle_hash keccak > /dev/null

    echo "  Generating Solidity contract..."
    bb write_solidity_verifier --scheme ultra_honk \
        -k "${vk_dir}/vk" \
        -o "${verifier_path}" > /dev/null

    if [[ "${circuit}" == "ownership" ]]; then
        cp "${verifier_path}" "${ROOT_DIR}/src/verifier/SPNFTOwnershipVerifier.sol"
    else
        cp "${verifier_path}" "${ROOT_DIR}/src/verifier/privacy/${circuit^}Verifier.sol"
    fi
    echo -e "${GREEN}✓ ${circuit} verifier generated successfully${NC}"

    if [[ ${WITH_PROOFS} -eq 1 ]]; then
        if [[ ! -f "Prover.toml" ]]; then
            echo -e "${RED}⚠ Error: Prover.toml required to generate proofs for ${circuit}${NC}" >&2
            exit 1
        fi

        witness_path="${circuit_dir}/target/${package_name}.gz"
        proof_dir="${circuit_dir}/target/proof_${circuit}"

        echo "  Generating witness..."
        nargo execute > /dev/null

        if [[ ! -f "${witness_path}" ]]; then
            echo -e "${RED}⚠ Error: Witness not produced at ${witness_path}${NC}" >&2
            exit 1
        fi

        echo "  Generating proof fixture..."
        rm -rf "${proof_dir}"
        mkdir -p "${proof_dir}"
        bb prove --scheme ultra_honk \
            -b "${acir_path}" \
            -w "${witness_path}" \
            --oracle_hash keccak \
            -o "${proof_dir}" > /dev/null

        mkdir -p "${DATA_DIR}/${circuit}"
        cp "${proof_dir}/proof" "${DATA_DIR}/${circuit}/proof.bin"
        cp "${proof_dir}/public_inputs" "${DATA_DIR}/${circuit}/public_inputs.bin"
    fi

    popd >/dev/null
 done
 
 echo -e "${GREEN}All verifiers generated successfully!${NC}"
 echo ""
 echo "Verifier contracts saved to: src/verifier/privacy/"
 ls -1 "${ROOT_DIR}/src/verifier/privacy"/*.sol 2>/dev/null || echo "No verifier files found"

 if [[ ${WITH_PROOFS} -eq 1 ]]; then
     echo ""
     echo "Proof fixtures updated in test/data/."
 fi
 
 

