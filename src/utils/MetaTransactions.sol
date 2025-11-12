// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/**
 * @title MetaTransactions
 * @notice EIP-712 signature verification for meta-transactions
 * @dev Enables relayers to execute transactions on behalf of users
 * 
 * Users sign transactions off-chain, relayers submit them on-chain.
 * This breaks the link between the user's address and on-chain activity.
 */
abstract contract MetaTransactions is EIP712 {
    using ECDSA for bytes32;
    
    // Nonce tracking to prevent replay attacks
    mapping(address => uint256) private _nonces;
    
    // Typehash for PrivateTransfer meta-transaction
    bytes32 public constant PRIVATE_TRANSFER_TYPEHASH = keccak256(
        "PrivateTransfer(bytes32 nullifier,bytes32 newCommitment,bytes32 root,address relayer,uint256 fee,uint256 nonce,uint256 deadline)"
    );
    
    // Typehash for Unshield meta-transaction
    bytes32 public constant UNSHIELD_TYPEHASH = keccak256(
        "Unshield(bytes32 nullifier,uint256 tokenId,address recipient,bytes32 root,address relayer,uint256 fee,uint256 nonce,uint256 deadline)"
    );
    
    error InvalidSignature();
    error SignatureExpired();
    error InvalidNonce();
    
    constructor(string memory name, string memory version) EIP712(name, version) {}
    
    /**
     * @notice Get current nonce for an address
     * @param user Address to check
     * @return Current nonce
     */
    function nonces(address user) public view returns (uint256) {
        return _nonces[user];
    }
    
    /**
     * @notice Increment nonce (internal)
     */
    function _incrementNonce(address user) internal {
        _nonces[user]++;
    }
    
    /**
     * @notice Verify signature for private transfer meta-transaction
     * @param nullifier The nullifier being spent
     * @param newCommitment The new commitment
     * @param root The Merkle root
     * @param relayer Address of the relayer
     * @param fee Fee to pay the relayer
     * @param nonce User's current nonce
     * @param deadline Transaction deadline
     * @param signature User's signature
     * @return signer The address that signed the transaction
     */
    function verifyPrivateTransferSignature(
        bytes32 nullifier,
        bytes32 newCommitment,
        bytes32 root,
        address relayer,
        uint256 fee,
        uint256 nonce,
        uint256 deadline,
        bytes memory signature
    ) internal view returns (address signer) {
        // Check deadline
        if (block.timestamp > deadline) revert SignatureExpired();
        
        // Build struct hash
        bytes32 structHash = keccak256(
            abi.encode(
                PRIVATE_TRANSFER_TYPEHASH,
                nullifier,
                newCommitment,
                root,
                relayer,
                fee,
                nonce,
                deadline
            )
        );
        
        // Get digest
        bytes32 digest = _hashTypedDataV4(structHash);
        
        // Recover signer
        signer = digest.recover(signature);
        
        // Verify nonce
        if (nonce != _nonces[signer]) revert InvalidNonce();
        
        return signer;
    }
    
    /**
     * @notice Verify signature for unshield meta-transaction
     * @param nullifier The nullifier being spent
     * @param tokenId The token ID to unshield
     * @param recipient Address to receive the NFT
     * @param root The Merkle root
     * @param relayer Address of the relayer
     * @param fee Fee to pay the relayer
     * @param nonce User's current nonce
     * @param deadline Transaction deadline
     * @param signature User's signature
     * @return signer The address that signed the transaction
     */
    function verifyUnshieldSignature(
        bytes32 nullifier,
        uint256 tokenId,
        address recipient,
        bytes32 root,
        address relayer,
        uint256 fee,
        uint256 nonce,
        uint256 deadline,
        bytes memory signature
    ) internal view returns (address signer) {
        // Check deadline
        if (block.timestamp > deadline) revert SignatureExpired();
        
        // Build struct hash
        bytes32 structHash = keccak256(
            abi.encode(
                UNSHIELD_TYPEHASH,
                nullifier,
                tokenId,
                recipient,
                root,
                relayer,
                fee,
                nonce,
                deadline
            )
        );
        
        // Get digest
        bytes32 digest = _hashTypedDataV4(structHash);
        
        // Recover signer
        signer = digest.recover(signature);
        
        // Verify nonce
        if (nonce != _nonces[signer]) revert InvalidNonce();
        
        return signer;
    }
    
    /**
     * @notice Get domain separator (for off-chain signing)
     */
    function getDomainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }
    
    /**
     * @notice Build PrivateTransfer digest for signing (helper for off-chain)
     * @dev This is a view function to help users generate signatures off-chain
     */
    function buildPrivateTransferDigest(
        bytes32 nullifier,
        bytes32 newCommitment,
        bytes32 root,
        address relayer,
        uint256 fee,
        uint256 nonce,
        uint256 deadline
    ) external view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(
                PRIVATE_TRANSFER_TYPEHASH,
                nullifier,
                newCommitment,
                root,
                relayer,
                fee,
                nonce,
                deadline
            )
        );
        return _hashTypedDataV4(structHash);
    }
    
    /**
     * @notice Build Unshield digest for signing (helper for off-chain)
     */
    function buildUnshieldDigest(
        bytes32 nullifier,
        uint256 tokenId,
        address recipient,
        bytes32 root,
        address relayer,
        uint256 fee,
        uint256 nonce,
        uint256 deadline
    ) external view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(
                UNSHIELD_TYPEHASH,
                nullifier,
                tokenId,
                recipient,
                root,
                relayer,
                fee,
                nonce,
                deadline
            )
        );
        return _hashTypedDataV4(structHash);
    }
}


