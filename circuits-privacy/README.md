# Privacy Circuits for Anonymous NFT Transfers

This directory contains three Noir circuits that enable anonymous NFT transfers using zero-knowledge proofs.

## Circuits

### 1. Deposit Circuit (`deposit/`)
**Purpose**: Shield an existing NFT into the privacy pool

**Private Inputs**:
- `secret`: Random secret chosen by the depositor
- `token_id`: The NFT token ID being shielded
- `view_key`: Recipient's view key (for stealth addresses)

**Public Inputs**:
- `commitment`: Hash(secret, tokenId, viewKey)
- `token_id_public`: The NFT token ID (to verify ownership on-chain)

**Proves**: The commitment was correctly generated from the secret, token ID, and view key.

### 2. Transfer Circuit (`transfer/`)
**Purpose**: Anonymously transfer an NFT commitment to a new owner

**Private Inputs**:
- `old_secret`, `token_id`, `old_view_key`: Sender's note
- `merkle_proof[20]`, `leaf_index`: Merkle proof of ownership
- `new_secret`, `new_view_key`: Recipient's note

**Public Inputs**:
- `old_root`: Merkle root containing the sender's commitment
- `nullifier`: Unique ID to prevent double-spending
- `new_commitment`: New commitment for the recipient

**Proves**: 
1. The sender owns a valid commitment in the Merkle tree
2. The nullifier is correctly computed
3. The new commitment is valid

### 3. Withdraw Circuit (`withdraw/`)
**Purpose**: Unshield an NFT from the privacy pool to a public address

**Private Inputs**:
- `secret`, `token_id`, `view_key`: Owner's note
- `merkle_proof[20]`, `leaf_index`: Merkle proof

**Public Inputs**:
- `root`: Merkle root containing the commitment
- `nullifier`: Unique ID to prevent double-spending
- `token_id_public`: The NFT token ID being withdrawn
- `recipient`: The address to receive the NFT

**Proves**: The owner controls a valid commitment and wants to withdraw to a specific address.

## Building the Circuits

### Prerequisites
- Nargo (Noir compiler) version >= 0.31.0
- Run `curl -L https://raw.githubusercontent.com/noir-lang/noirup/main/install | bash` to install
- Then run `noirup` to get the latest version

### Build All Circuits
```bash
cd circuits-privacy
chmod +x build_all.sh
./build_all.sh
```

This will:
1. Compile each circuit
2. Generate Solidity verifiers
3. Copy verifier contracts to `src/verifier/privacy/`

### Build Individual Circuits
```bash
# Build deposit circuit
cd deposit
nargo compile
nargo codegen-verifier

# Build transfer circuit
cd ../transfer
nargo compile
nargo codegen-verifier

# Build withdraw circuit
cd ../withdraw
nargo compile
nargo codegen-verifier
```

## Testing Circuits

Each circuit includes unit tests. Run them with:

```bash
# Test deposit circuit
cd deposit
nargo test

# Test transfer circuit
cd transfer
nargo test

# Test withdraw circuit
cd withdraw
nargo test
```

## Integration with Smart Contracts

After building, the generated verifier contracts are used by `SPNFT.sol`:

- `DepositVerifier.sol`: Used by `shieldNFT()` and `mintPrivateNFT()`
- `TransferVerifier.sol`: Used by `transferPrivate()`
- `WithdrawVerifier.sol`: Used by `unshieldNFT()`

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Public NFT Layer                      │
│  (ERC-721 standard transfers - visible on-chain)        │
└─────────────────┬───────────────────────────────────────┘
                  │
                  │ shieldNFT() / mintPrivateNFT()
                  ▼
┌─────────────────────────────────────────────────────────┐
│                   Privacy Pool                           │
│  - Merkle tree of commitments                            │
│  - Anonymous transfers via ZK proofs                     │
│  - No visible token IDs or owners                        │
│                                                           │
│  transferPrivate() ──────────────────────────────────►   │
│  (nullifier, newCommitment, proof)                       │
└─────────────────┬───────────────────────────────────────┘
                  │
                  │ unshieldNFT()
                  ▼
┌─────────────────────────────────────────────────────────┐
│                    Public NFT Layer                      │
│  (NFT exits privacy mode to public address)             │
└─────────────────────────────────────────────────────────┘
```

## Key Concepts

### Commitment
A commitment is a hash that represents ownership of an NFT in the privacy pool:
```
commitment = Hash(secret, tokenId, viewKey)
```

### Nullifier
A nullifier prevents double-spending of a commitment:
```
nullifier = Hash(secret, tokenId, viewKey, 1)
```
Once used, the contract tracks nullifiers to prevent reuse.

### Merkle Tree
All commitments are stored in an incremental Merkle tree (height 20, ~1M capacity).
To prove ownership, users provide a Merkle proof showing their commitment is in the tree.

### Stealth Addresses
Recipients generate view keys. Senders use ECDH to derive one-time addresses,
allowing the recipient to detect and spend incoming commitments without revealing
their identity.

## Security Considerations

1. **Secret Management**: Users must securely store their secrets. Loss of secret = loss of NFT.
2. **Nullifier Tracking**: The contract must track all used nullifiers to prevent double-spending.
3. **Merkle Root History**: The contract maintains a history of valid roots for asynchronous transfers.
4. **View Key Privacy**: View keys should be kept private to maintain anonymity.

## Development Status

- [x] Circuit design and implementation
- [x] Unit tests for all circuits
- [ ] Generate actual verifiers (run build_all.sh)
- [ ] Integration tests with smart contracts
- [ ] Gas optimization
- [ ] Audit


