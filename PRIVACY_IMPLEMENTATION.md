# Anonymous NFT Transfer Implementation

This document describes the implementation of anonymous NFT transfers for the Sponge Protocol, enabling users to shield, transfer, and unshield NFTs without revealing ownership on-chain.

## Overview

The privacy system allows NFTs to exist in two modes:

1. **Public Mode** (Standard ERC-721): Visible ownership and transfers on-chain
2. **Private Mode** (Shielded): Hidden ownership using zero-knowledge proofs, commitments, and nullifiers

## Architecture

### Core Components

#### 1. Smart Contracts

- **SPNFT.sol** (Extended): Main contract with privacy pool functionality
- **MerkleTree.sol**: Incremental Merkle tree for storing commitments
- **StealthAddress.sol**: ECDH-based stealth address system
- **DepositVerifier.sol**: Verifies proofs for shielding NFTs
- **TransferVerifier.sol**: Verifies proofs for anonymous transfers
- **WithdrawVerifier.sol**: Verifies proofs for unshielding NFTs

#### 2. ZK Circuits (Noir)

Located in `circuits-privacy/`:
- **deposit.nr**: Proves commitment generation for shielding
- **transfer.nr**: Proves ownership and creates new commitment
- **withdraw.nr**: Proves ownership and reveals NFT

#### 3. Cryptographic Primitives

- **Commitments**: `Hash(secret, tokenId, viewKey)` - represents private ownership
- **Nullifiers**: `Hash(secret, tokenId, viewKey, 1)` - prevents double-spending
- **Merkle Tree**: Stores all commitments, proves membership
- **Stealth Addresses**: One-time addresses derived via ECDH

## User Flows

### Flow 1: Mint Private NFT (Standalone Mode)

User mints an NFT directly into the privacy pool:

```solidity
// 1. Generate commitment off-chain
secret = randomBytes32();
viewKey = userViewKey;
tokenId = nextTokenId; // Known in advance
commitment = Hash(secret, tokenId, viewKey);

// 2. Generate ZK proof (off-chain)
proof = generateDepositProof(secret, tokenId, viewKey, commitment);

// 3. Mint private NFT
(tokenId, leafIndex) = spnft.mintPrivateNFT(commitment, proof, metadataCidHash);

// NFT now exists in privacy pool, ownership is hidden
```

### Flow 2: Shield Existing NFT (Converter Mode)

User converts an existing public NFT to private:

```solidity
// 1. User owns a public NFT
require(spnft.ownerOf(tokenId) == msg.sender);

// 2. Generate commitment
secret = randomBytes32();
viewKey = userViewKey;
commitment = Hash(secret, tokenId, viewKey);

// 3. Generate proof
proof = generateDepositProof(secret, tokenId, viewKey, commitment);

// 4. Shield the NFT
leafIndex = spnft.shieldNFT(tokenId, commitment, proof);

// NFT is now in privacy pool
```

### Flow 3: Anonymous Transfer

Transfer private NFT to another user without revealing sender or recipient:

```solidity
// Sender (Alice) has: oldSecret, tokenId, oldViewKey
// Recipient (Bob) shares: newViewKey (via stealth address)

// 1. Alice generates new note for Bob
newSecret = randomBytes32();
newCommitment = Hash(newSecret, tokenId, bobViewKey);

// 2. Alice gets Merkle proof for her commitment
merkleProof = getMerkleProof(oldCommitment, leafIndex);
oldRoot = getCurrentRoot();

// 3. Alice computes nullifier
nullifier = Hash(oldSecret, tokenId, oldViewKey, 1);

// 4. Alice generates transfer proof
proof = generateTransferProof(
    oldSecret, tokenId, oldViewKey,
    merkleProof, leafIndex,
    newSecret, bobViewKey,
    oldRoot, nullifier, newCommitment
);

// 5. Anyone can submit the transfer (even a relayer)
newLeafIndex = spnft.transferPrivate(nullifier, newCommitment, oldRoot, proof);

// Bob now owns the NFT (in private)
```

### Flow 4: Unshield NFT

Exit privacy mode and receive NFT at a public address:

```solidity
// User (Charlie) has: secret, tokenId, viewKey

// 1. Get Merkle proof
merkleProof = getMerkleProof(commitment, leafIndex);
root = getCurrentRoot();

// 2. Compute nullifier
nullifier = Hash(secret, tokenId, viewKey, 1);

// 3. Generate withdraw proof
recipient = charliePublicAddress;
proof = generateWithdrawProof(
    secret, tokenId, viewKey,
    merkleProof, leafIndex,
    root, nullifier, tokenId, recipient
);

// 4. Unshield NFT
spnft.unshieldNFT(nullifier, tokenId, recipient, root, proof);

// Charlie now owns NFT publicly
```

## Privacy Guarantees

### What is Hidden

- **Ownership**: Commitments don't reveal who owns the NFT
- **Transfer History**: Can't link transfers (different nullifiers/commitments)
- **Recipient Identity**: Stealth addresses hide the recipient
- **Token ID**: Only revealed when unshielding

### What is Visible

- **Commitment Insertions**: New commitments are added to the tree
- **Nullifier Usage**: Nullifiers are public (but unlinkable to users)
- **Tree Size**: Number of notes in the system
- **Root Changes**: Merkle root updates with each operation

### Anonymity Set

- The anonymity set is all commitments in the Merkle tree
- Larger anonymity set = better privacy
- Withdraw reveals token ID but not previous history

## Security Considerations

### User Responsibilities

1. **Secret Management**: Users must securely store secrets
   - Loss of secret = loss of NFT access
   - Exposure of secret = loss of privacy

2. **View Key Security**: Keep view keys private
   - Anyone with view key can detect incoming transfers
   - Cannot spend without secret

3. **Backup**: Maintain backups of:
   - Secrets for all owned commitments
   - View keys
   - Merkle proofs (can be regenerated)

### Contract Security

1. **Nullifier Tracking**: Prevents double-spending
2. **Root History**: Allows asynchronous transfers
3. **Access Control**: Only proof holders can spend
4. **Reentrancy Protection**: Use checks-effects-interactions pattern

### Known Limitations

1. **Front-Running**: Transfers can be front-run (use private mempools if needed)
2. **Timing Attacks**: Transfer timing may leak information
3. **Network Analysis**: IP addresses may be correlated (use Tor/VPN)
4. **Stealth Address Scanning**: Recipients must scan for incoming transfers

## Gas Costs

Approximate gas costs (with placeholder verifiers):

| Operation | Gas Cost | Notes |
|-----------|----------|-------|
| mintPrivateNFT | ~250k | Includes Merkle insertion |
| shieldNFT | ~280k | Includes transfer + Merkle insertion |
| transferPrivate | ~220k | Merkle verification + insertion |
| unshieldNFT | ~200k | Merkle verification + transfer |

Actual costs will increase with real ZK verifiers (~500k-1M gas per operation).

## Development Workflow

### Setup

```bash
# Install dependencies
forge install

# Install Nargo (Noir compiler)
curl -L https://raw.githubusercontent.com/noir-lang/noirup/main/install | bash
noirup

# Build circuits
cd circuits-privacy
chmod +x build_all.sh
./build_all.sh
```

### Testing

```bash
# Run privacy tests
forge test --match-contract SPNFTPrivacyTest -vvv

# Run specific test
forge test --match-test testFullPrivacyFlow -vvvv

# Check gas costs
forge test --gas-report
```

### Deployment

```bash
# 1. Deploy verifiers
forge script script/DeployVerifiers.s.sol --rpc-url <RPC_URL> --broadcast

# 2. Deploy SPNFT with verifier addresses
forge script script/DeploySPNFT.s.sol --rpc-url <RPC_URL> --broadcast

# 3. Verify contracts
forge verify-contract <ADDRESS> SPNFT --chain <CHAIN>
```

## Integration Guide

### For Wallets/DApps

1. **Generate Commitments**:
   ```javascript
   const commitment = poseidon([secret, tokenId, viewKey]);
   ```

2. **Generate Proofs**:
   ```javascript
   const proof = await noir.generateProof(inputs);
   ```

3. **Submit Transactions**:
   ```javascript
   const tx = await spnft.transferPrivate(nullifier, newCommitment, root, proof);
   await tx.wait();
   ```

4. **Scan for Incoming Transfers**:
   ```javascript
   // Monitor PrivateTransfer events
   const events = await spnft.queryFilter(spnft.filters.PrivateTransfer());
   
   // Try to derive secret for each commitment
   for (const event of events) {
     const myCommitment = tryDeriveCommitment(event.newCommitment, myViewKey);
     if (myCommitment) {
       // This transfer is for me!
     }
   }
   ```

### For Relayers

Relayers can submit transfers on behalf of users:

```javascript
// User generates proof off-chain and gives it to relayer
const { nullifier, newCommitment, root, proof } = userGeneratedData;

// Relayer submits transaction
const tx = await spnft.transferPrivate(nullifier, newCommitment, root, proof);

// Relayer pays gas, user maintains privacy
```

## Future Improvements

1. **Optimizations**:
   - Batch transfers (multiple transfers in one proof)
   - Compressed Merkle proofs
   - Gas-optimized hash functions (Poseidon2 on-chain)

2. **Features**:
   - Time-locked transfers
   - Multi-sig commitments
   - Conditional transfers (atomic swaps)
   - Private metadata

3. **Privacy Enhancements**:
   - Decoy commitments
   - Ring signatures for extra anonymity
   - Private mempools integration
   - Zero-knowledge identity proofs

4. **User Experience**:
   - Automatic Merkle proof generation
   - Wallet integration
   - Mobile apps
   - Hardware wallet support

## References

- [Tornado Cash](https://github.com/tornadocash/tornado-core): Inspiration for Merkle tree and nullifier design
- [Aztec Protocol](https://aztec.network): Advanced privacy architecture
- [zk-NFT (0xPARC)](https://github.com/fvictorio/zk-nft): Reference implementation
- [ERC-5564](https://eips.ethereum.org/EIPS/eip-5564): Stealth address standard
- [Noir Language](https://noir-lang.org): ZK circuit language

## Support

For questions or issues:
- Open an issue on GitHub
- Join our Discord community
- Check the documentation wiki

## License

MIT License - see LICENSE file for details


