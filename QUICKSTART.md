# Quick Start Guide - Anonymous NFT Transfers

This guide will help you get started with the anonymous NFT transfer system in under 10 minutes.

## Prerequisites

```bash
# Foundry (Solidity)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Nargo (Noir circuits)
curl -L https://raw.githubusercontent.com/noir-lang/noirup/main/install | bash
noirup
```

## Step 1: Build Circuits (5 minutes)

```bash
cd circuits-privacy

# Make build script executable
chmod +x build_all.sh

# Build all three privacy circuits
./build_all.sh
```

This generates three ZK verifier contracts:
- `src/verifier/privacy/DepositVerifier.sol`
- `src/verifier/privacy/TransferVerifier.sol`
- `src/verifier/privacy/WithdrawVerifier.sol`

## Step 2: Run Tests (2 minutes)

```bash
cd ..

# Run all privacy tests
forge test --match-contract SPNFTPrivacy -vvv

# See gas costs
forge test --match-contract SPNFTPrivacy --gas-report
```

Expected output: All tests passing ✅

## Step 3: Try the Privacy Flow

### Example: Mint → Transfer → Unshield

```solidity
// 1. Alice mints a private NFT
uint256 tokenId = 1;
bytes32 aliceSecret = bytes32(uint256(12345));
bytes32 aliceViewKey = bytes32(uint256(11111));
bytes32 commitment1 = Hash(aliceSecret, tokenId, aliceViewKey);

(uint256 id, uint32 idx) = spnft.mintPrivateNFT(
    commitment1,
    proof,
    metadataCidHash
);

// 2. Alice transfers to Bob (anonymously)
bytes32 bobSecret = bytes32(uint256(54321));
bytes32 bobViewKey = bytes32(uint256(22222));
bytes32 commitment2 = Hash(bobSecret, tokenId, bobViewKey);
bytes32 nullifier1 = Hash(aliceSecret, tokenId, aliceViewKey, 1);

spnft.transferPrivate(
    nullifier1,
    commitment2,
    currentRoot,
    proof
);

// 3. Bob unshields to his address
bytes32 nullifier2 = Hash(bobSecret, tokenId, bobViewKey, 1);

spnft.unshieldNFT(
    nullifier2,
    tokenId,
    bobAddress,
    currentRoot,
    proof
);

// Bob now owns the NFT publicly!
```

## Step 4: Deploy (Optional)

Create a deployment script:

```solidity
// script/DeployPrivacy.s.sol
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/SPNFT.sol";
import "../src/verifier/privacy/DepositVerifier.sol";
import "../src/verifier/privacy/TransferVerifier.sol";
import "../src/verifier/privacy/WithdrawVerifier.sol";

contract DeployPrivacy is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy verifiers
        DepositVerifier deposit = new DepositVerifier();
        TransferVerifier transfer = new TransferVerifier();
        WithdrawVerifier withdraw = new WithdrawVerifier();

        // Deploy SPNFT
        SPNFT spnft = new SPNFT(
            ownershipVerifier,
            msg.sender,
            address(deposit),
            address(transfer),
            address(withdraw)
        );

        vm.stopBroadcast();
    }
}
```

Deploy:
```bash
forge script script/DeployPrivacy.s.sol --rpc-url <RPC_URL> --broadcast
```

## Understanding the System

### Key Concepts (2 minutes)

**Commitment**: A hash that represents private ownership
```
commitment = Hash(secret, tokenId, viewKey)
```

**Nullifier**: Prevents double-spending
```
nullifier = Hash(secret, tokenId, viewKey, 1)
```

**Merkle Tree**: Stores all commitments, proves membership

**View Key**: Allows recipients to detect incoming transfers

### Privacy Flow

```
┌─────────────┐
│ Public NFT  │
└──────┬──────┘
       │ shieldNFT()
       ▼
┌─────────────┐
│Privacy Pool │ ◄──── transferPrivate() ─────┐
│ (Hidden)    │                              │
└──────┬──────┘                              │
       │ unshieldNFT()                       │
       ▼                                     │
┌─────────────┐                              │
│ Public NFT  │                              │
│ (revealed)  │                              │
└─────────────┘                              │
                                             │
         Multiple anonymous transfers ───────┘
```

## Common Operations

### Check if NFT is Private
```solidity
bool isPrivate = spnft.isShielded(tokenId);
```

### Get Current Merkle Root
```solidity
bytes32 root = spnft.getCurrentRoot();
```

### Check if Nullifier is Used
```solidity
bool used = spnft.isNullifierUsed(nullifier);
```

### Get Tree Size
```solidity
uint32 size = spnft.getNextLeafIndex();
```

## Troubleshooting

### Circuit Build Fails
```bash
# Update Nargo
noirup --version 0.34.0

# Check Nargo version
nargo --version
```

### Tests Fail
```bash
# Clean and rebuild
forge clean
forge build

# Run specific test with verbose output
forge test --match-test testMintPrivateNFT -vvvv
```

### Out of Gas
- Real ZK proofs use ~1M gas per operation
- Use placeholder verifiers for testing
- Consider Layer 2 deployment for production

## Next Steps

1. **Read Full Documentation**: See `PRIVACY_IMPLEMENTATION.md`
2. **Understand Circuits**: See `circuits-privacy/README.md`
3. **Integrate with Frontend**: Build UI for proof generation
4. **Add Relayer**: Enable gasless transfers
5. **Implement Scanning**: Detect incoming transfers

## Example Use Cases

### Use Case 1: Private NFT Marketplace
```solidity
// 1. Seller lists NFT (private)
// 2. Buyer purchases (generates transfer proof)
// 3. Transfer executes anonymously
// 4. Seller receives payment, buyer receives NFT
```

### Use Case 2: Anonymous Voting
```solidity
// 1. DAO mints voting NFTs (private)
// 2. Members transfer votes (anonymous)
// 3. Votes are counted without revealing voters
```

### Use Case 3: Private Collectibles
```solidity
// 1. Artist mints collectible (private)
// 2. Collectors trade anonymously
// 3. Optionally unshield to display publicly
```

## Resources

- **Technical Docs**: `PRIVACY_IMPLEMENTATION.md`
- **Implementation Summary**: `IMPLEMENTATION_SUMMARY.md`
- **Circuit Docs**: `circuits-privacy/README.md`
- **Tests**: `test/SPNFTPrivacy.t.sol`

## Support

Questions? Check:
- GitHub Issues
- Noir Discord: https://discord.gg/noir
- Foundry Discord: https://discord.gg/foundry

---

**Ready to build private NFT applications!** 🚀🔒


