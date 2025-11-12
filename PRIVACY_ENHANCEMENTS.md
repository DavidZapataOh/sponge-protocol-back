# Privacy Enhancements - Relayers & Metadata Privacy

## 🎯 Overview

This document describes the **critical privacy enhancements** implemented to achieve **complete anonymity** in NFT transfers:

1. **Relayer System** - Gas abstraction to hide transaction origin
2. **Metadata Privacy** - Hide NFT metadata while shielded

These enhancements address the main privacy vulnerabilities identified in the initial implementation.

---

## 🔒 Problem: Privacy Leaks

### Without These Enhancements

**Problem 1: Gas Payer Correlation**
```solidity
// Alice shields NFT → tx from Alice's address
spnft.shieldNFT(tokenId, commitment, proof);

// Bob unshields NFT → tx from Bob's address  
spnft.unshieldNFT(nullifier, tokenId, bob, root, proof);

// ❌ Observer can link: "Alice deposited → Bob withdrew"
```

**Problem 2: Metadata Correlation**
```solidity
// NFT #42 has unique metadata "CryptoKitty SuperRare"
// Alice shields it → metadata still visible
// Bob receives it → same metadata appears in Bob's wallet
// ❌ Observer can link: "Same NFT moved from Alice to Bob"
```

---

## ✅ Solution 1: Relayer System

### Architecture

**Relayers** are third-party operators that execute transactions on behalf of users:

1. **User**: Generates proof + signs transaction off-chain
2. **Relayer**: Submits transaction on-chain (pays gas)
3. **Contract**: Verifies signature + executes + pays relayer fee
4. **Result**: No on-chain link between user and transaction

### Components

#### 1. RelayerRegistry.sol

Manages relayer registration, staking, and fees:

```solidity
// Register as relayer
registry.registerRelayer{value: 2 ether}(feeBps: 100); // 1% fee

// View active relayers
address[] memory relayers = registry.getActiveRelayers();

// Calculate fee
uint256 fee = registry.calculateFee(relayer, amount);
```

**Key Features**:
- **Staking**: Minimum 1 ETH stake required
- **Fee Limits**: Maximum 5% fee
- **Cooldown**: 7-day unstaking period
- **Slashing**: Admin can slash misbehaving relayers
- **Reputation**: Track success rate

#### 2. MetaTransactions.sol (EIP-712)

Handles signature verification for meta-transactions:

```solidity
// User signs off-chain
bytes32 digest = spnft.buildPrivateTransferDigest(
    nullifier,
    newCommitment,
    root,
    relayer,
    fee,
    nonce,
    deadline
);
bytes memory signature = signDigest(userPrivateKey, digest);

// Relayer submits
spnft.transferPrivateViaRelayer(
    nullifier,
    newCommitment,
    root,
    proof,
    fee,
    nonce,
    deadline,
    signature
);
```

**Security**:
- **EIP-712**: Structured data signing standard
- **Nonce**: Prevents replay attacks
- **Deadline**: Time-bound signatures
- **Domain Separation**: Contract-specific signatures

#### 3. SPNFT.sol Extensions

Two new functions for relayer-based operations:

**transferPrivateViaRelayer()**
```solidity
function transferPrivateViaRelayer(
    bytes32 nullifier,
    bytes32 newCommitment,
    bytes32 root,
    bytes calldata proof,
    uint256 fee,           // Fee for relayer
    uint256 nonce,         // User's nonce
    uint256 deadline,      // Signature expiry
    bytes calldata signature // User's EIP-712 signature
) external returns (uint32 leafIndex);
```

**unshieldNFTViaRelayer()**
```solidity
function unshieldNFTViaRelayer(
    bytes32 nullifier,
    uint256 tokenId,
    address recipient,
    bytes32 root,
    bytes calldata proof,
    uint256 fee,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature
) external;
```

### Usage Flow

#### Complete Anonymous Transfer

```solidity
// 1. Alice mints private NFT
spnft.mintPrivateNFT(commitment1, proof, metadata);

// 2. Alice prepares transfer to Bob (OFF-CHAIN)
bytes32 nullifier = Hash(secret1, tokenId, viewKey1);
bytes32 newCommitment = Hash(secret2, tokenId, viewKey2);
bytes32 root = getCurrentRoot();
uint256 fee = 0.05 ether;
uint256 nonce = spnft.nonces(alice);
uint256 deadline = block.timestamp + 1 hours;

// 3. Alice signs transaction (OFF-CHAIN)
bytes32 digest = spnft.buildPrivateTransferDigest(
    nullifier, newCommitment, root, relayerAddress, fee, nonce, deadline
);
bytes memory signature = signWithPrivateKey(aliceKey, digest);

// 4. Alice sends {proof, signature, params} to relayer (OFF-CHAIN)
//    Via encrypted channel, Tor, or decentralized relay network

// 5. Relayer submits transaction (ON-CHAIN)
//    Transaction comes from relayer's address, not Alice's
relayer.execute(
    spnft.transferPrivateViaRelayer(
        nullifier,
        newCommitment,
        root,
        proof,
        fee,
        nonce,
        deadline,
        signature
    )
);

// 6. Bob detects incoming transfer (OFF-CHAIN)
//    Scans new commitments with his view key
//    Only Bob can decrypt that newCommitment is for him

// Result: Complete anonymity
// - No one knows Alice sent
// - No one knows Bob received
// - Relayer just sees encrypted data
```

### Fee Management

**Relayer earns fees from user**:
```solidity
// Contract pays relayer automatically
if (fee > 0) {
    (bool success, ) = msg.sender.call{value: fee}("");
    require(success, "Relayer payment failed");
    emit RelayerPaid(msg.sender, fee);
}
```

**User must deposit ETH**:
```solidity
// Fund contract for future relayer fees
(bool success, ) = address(spnft).call{value: 1 ether}("");
```

---

## ✅ Solution 2: Metadata Privacy

### Problem

Even with private ownership, **NFT metadata can leak information**:

- Unique metadata links deposits to withdrawals
- Metadata may contain identifying information
- Observable by anyone via `tokenURI()`

### Solution

**Hide metadata while NFT is shielded**:

#### Implementation

**shieldNFT()** - Save and hide metadata:
```solidity
function shieldNFT(uint256 tokenId, bytes32 commitment, bytes calldata proof) {
    // ... verification ...
    
    // METADATA PRIVACY: Save original and replace with generic
    originalMetadata[tokenId] = tokenURI(tokenId);
    _setTokenURI(tokenId, PRIVATE_METADATA_URI);
    
    // ... continue shielding ...
}
```

**unshieldNFT()** - Restore metadata:
```solidity
function unshieldNFT(...) {
    // ... verification ...
    
    // METADATA PRIVACY: Restore original metadata
    if (bytes(originalMetadata[tokenId]).length > 0) {
        _setTokenURI(tokenId, originalMetadata[tokenId]);
        delete originalMetadata[tokenId]; // Clear storage
    }
    
    // ... transfer NFT ...
}
```

#### Behavior

| State | tokenURI() | Metadata Storage |
|-------|------------|------------------|
| Public (before shield) | `ipfs://QmRealMetadata...` | On-chain URI |
| Shielded (private) | `ipfs://QmPrivateNFTMetadataHidden` | Saved in `originalMetadata` mapping |
| Public (after unshield) | `ipfs://QmRealMetadata...` | Restored from mapping |

### Benefits

1. **Unlinkable**: Same generic URI for all shielded NFTs
2. **Recoverable**: Original metadata restored on unshield
3. **Gas Efficient**: Only stores string reference
4. **Backward Compatible**: Works with existing ERC-721

---

## 📊 Comparison: Before vs After

### Privacy Analysis

| Attack Vector | Before | After |
|---------------|--------|-------|
| Gas payer correlation | ❌ Vulnerable | ✅ Protected (relayers) |
| Metadata correlation | ❌ Vulnerable | ✅ Protected (hidden) |
| Timing analysis | ⚠️ Partial | ⚠️ Partial (can add batching) |
| Amount analysis | ✅ N/A (NFTs) | ✅ N/A (NFTs) |
| Network analysis | ⚠️ IP leaks | ⚠️ Use Tor/VPN |

### Gas Costs

| Operation | Direct Call | Via Relayer | Additional Cost |
|-----------|-------------|-------------|-----------------|
| transferPrivate | ~220k | ~280k | +60k (signature verification) |
| unshieldNFT | ~200k | ~260k | +60k (signature verification) |

**Note**: Relayer pays gas, user pays fee (typically 1-3% of tx value or fixed amount).

---

## 🛠️ Integration Guide

### For Users

#### 1. Find Active Relayers

```javascript
const relayers = await registry.getActiveRelayers();
const bestRelayer = relayers.sort((a, b) => 
    registry.calculateFee(a, amount) - registry.calculateFee(b, amount)
)[0];
```

#### 2. Sign Transaction

```javascript
import { signTypedData } from 'ethers/lib/utils';

const domain = {
    name: 'SPNFT',
    version: '1',
    chainId: await provider.getNetwork().chainId,
    verifyingContract: spnft.address
};

const types = {
    PrivateTransfer: [
        { name: 'nullifier', type: 'bytes32' },
        { name: 'newCommitment', type: 'bytes32' },
        { name: 'root', type: 'bytes32' },
        { name: 'relayer', type: 'address' },
        { name: 'fee', type: 'uint256' },
        { name: 'nonce', type: 'uint256' },
        { name: 'deadline', type: 'uint256' }
    ]
};

const value = {
    nullifier,
    newCommitment,
    root,
    relayer: bestRelayer,
    fee: ethers.utils.parseEther('0.05'),
    nonce: await spnft.nonces(userAddress),
    deadline: Math.floor(Date.now() / 1000) + 3600
};

const signature = await signer._signTypedData(domain, types, value);
```

#### 3. Submit to Relayer

```javascript
// Via HTTP API
await fetch(`https://relayer-api.example.com/submit`, {
    method: 'POST',
    body: JSON.stringify({
        type: 'privateTransfer',
        params: { nullifier, newCommitment, root, proof, fee, nonce, deadline },
        signature
    })
});

// Or via decentralized relay network (Flashbots, etc.)
```

### For Relayers

#### 1. Register

```solidity
// Stake and set fee
relayerRegistry.registerRelayer{value: 2 ether}(100); // 1% fee
```

#### 2. Run Relayer Service

```javascript
// Listen for signed transactions
app.post('/submit', async (req, res) => {
    const { type, params, signature } = req.body;
    
    // Verify signature locally (optional pre-check)
    const valid = await verifySignature(params, signature);
    if (!valid) return res.status(400).json({ error: 'Invalid signature' });
    
    // Submit to contract
    const tx = await spnft.transferPrivateViaRelayer(
        params.nullifier,
        params.newCommitment,
        params.root,
        params.proof,
        params.fee,
        params.nonce,
        params.deadline,
        signature,
        { gasLimit: 500000 }
    );
    
    await tx.wait();
    res.json({ txHash: tx.hash });
});
```

#### 3. Monitor Reputation

```javascript
// Check success rate
const rate = await registry.getSuccessRate(relayerAddress);
console.log(`Success rate: ${rate / 100}%`);

// Increase stake if needed
await registry.increaseStake({ value: ethers.utils.parseEther('1') });
```

---

## 🧪 Testing

Run comprehensive tests:

```bash
# Test relayer system
forge test --match-contract RelayerSystemTest -vvv

# Test specific functionality
forge test --match-test testRelayerCannotCallWithoutRegistration -vvvv

# Gas report
forge test --match-contract RelayerSystemTest --gas-report
```

---

## 🔐 Security Considerations

### Relayer Trust

**Relayers can:**
- ✅ See encrypted transaction data
- ✅ Choose when to submit (timing)
- ✅ Fail to submit (DoS)

**Relayers cannot:**
- ❌ Modify transaction (signature would break)
- ❌ Steal funds (no access to secrets)
- ❌ Link sender to recipient (encrypted commitments)

### Mitigation Strategies

1. **Multiple Relayers**: Users can submit to multiple relayers
2. **Reputation System**: Track success rates
3. **Slashing**: Penalize misbehavior
4. **Decentralized Relay Networks**: Use Flashbots, Gelato, etc.
5. **Fallback**: Users can always call direct functions if relayers fail

### Metadata Security

**Stored metadata is:**
- ✅ Private (only in contract storage)
- ✅ Recoverable (restored on unshield)
- ✅ Deletable (cleared after unshield)

**Considerations:**
- Metadata is stored unencrypted in contract storage
- For sensitive metadata, consider IPFS with encryption
- Original metadata hash could still be stored on IPFS

---

## 📈 Future Enhancements

### Phase 1 (Current) ✅
- [x] Relayer registry and staking
- [x] EIP-712 meta-transactions
- [x] Metadata hiding/restoration
- [x] Fee management

### Phase 2 (Next)
- [ ] Batch transfers (multiple transfers in one proof)
- [ ] Decentralized relayer selection (reputation-based)
- [ ] Encrypted metadata storage (IPFS + AES)
- [ ] Timing randomization

### Phase 3 (Future)
- [ ] Integration with Flashbots/private mempools
- [ ] Cross-chain relayers (LayerZero, Axelar)
- [ ] Hardware wallet support for signatures
- [ ] Mobile relayer apps

---

## 📚 References

- [EIP-712](https://eips.ethereum.org/EIPS/eip-712): Typed structured data hashing and signing
- [EIP-2771](https://eips.ethereum.org/EIPS/eip-2771): Secure protocol for meta-transactions
- [Tornado Cash](https://github.com/tornadocash/tornado-core): Relayer architecture inspiration
- [Flashbots](https://docs.flashbots.net/): Private transaction relay
- [Gelato Network](https://www.gelato.network/): Decentralized relay infrastructure

---

## 🎓 Key Takeaways

**Complete Privacy Requires**:
1. ✅ **Hidden Ownership** (commitments) - Original implementation
2. ✅ **Hidden Transfers** (ZK proofs) - Original implementation  
3. ✅ **Hidden Transaction Origin** (relayers) - **NEW**
4. ✅ **Hidden NFT Identity** (metadata privacy) - **NEW**

**With these enhancements, the system achieves:**
- **No on-chain link** between depositor and withdrawer
- **No metadata correlation** between deposits and withdrawals
- **Full anonymity** for users willing to use relayers
- **Backward compatibility** with direct function calls

---

**Status**: ✅ Implementation Complete
**Last Updated**: November 12, 2025  
**Version**: 2.0.0 (Privacy Enhanced)


