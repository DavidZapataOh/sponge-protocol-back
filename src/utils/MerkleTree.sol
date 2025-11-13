// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import { Poseidon2 } from "./Poseidon2.sol";
import { Field } from "./Field.sol";

/**
 * @title MerkleTree
 * @notice Incremental Merkle tree for storing NFT commitments
 * @dev Inspired by Tornado Cash's MerkleTreeWithHistory, optimized for NFT privacy
 */
library MerkleTree {
    uint8 public constant TREE_HEIGHT = 20;
    uint32 public constant MAX_LEAVES = 1048576; // 2^20 = ~1M commitments

    struct TreeData {
        uint32 nextLeafIndex;
        mapping(uint32 => bytes32) leaves;
        mapping(uint8 => bytes32) filledSubtrees;
        bytes32[] roots;
        mapping(bytes32 => bool) rootHistory;
    }

    error MerkleTreeFull();
    error InvalidMerkleProof();

    /**
     * @notice Initialize the tree with zero values
     * @dev Precomputes zero values for each level: H(0,0), H(H(0,0), H(0,0)), etc.
     */
    function initialize(TreeData storage tree) internal {
        // Store initial root (all zeros)
        bytes32 currentZero = bytes32(0);
        tree.filledSubtrees[0] = currentZero;
        
        // Precompute zero values for each level
        for (uint8 i = 1; i <= TREE_HEIGHT; i++) {
            currentZero = hashLeftRight(currentZero, currentZero);
            tree.filledSubtrees[i] = currentZero;
        }
        
        // Store initial root
        tree.roots.push(currentZero);
        tree.rootHistory[currentZero] = true;
    }

    /**
     * @notice Insert a new commitment leaf into the tree
     * @param tree The tree data structure
     * @param leaf The commitment to insert
     * @return The leaf index where the commitment was inserted
     */
    function insert(TreeData storage tree, bytes32 leaf) internal returns (uint32) {
        uint32 index = tree.nextLeafIndex;
        if (index >= MAX_LEAVES) revert MerkleTreeFull();

        tree.leaves[index] = leaf;
        
        bytes32 currentHash = leaf;
        uint32 currentIndex = index;
        
        bytes32 left;
        bytes32 right;

        // Update the tree from bottom to top
        for (uint8 level = 0; level < TREE_HEIGHT; level++) {
            if (currentIndex % 2 == 0) {
                // Current node is left child
                left = currentHash;
                right = tree.filledSubtrees[level];
                tree.filledSubtrees[level] = currentHash;
            } else {
                // Current node is right child
                left = tree.filledSubtrees[level];
                right = currentHash;
            }
            
            currentHash = hashLeftRight(left, right);
            currentIndex /= 2;
        }

        // Store new root
        tree.roots.push(currentHash);
        tree.rootHistory[currentHash] = true;
        tree.nextLeafIndex++;

        return index;
    }

    /**
     * @notice Verify a Merkle proof
     * @param root The root to verify against
     * @param leaf The leaf to verify
     * @param proof The Merkle proof path (20 sibling hashes)
     * @param leafIndex The index of the leaf
     * @return True if the proof is valid
     */
    function verify(
        bytes32 root,
        bytes32 leaf,
        bytes32[TREE_HEIGHT] memory proof,
        uint32 leafIndex
    ) internal pure returns (bool) {
        bytes32 computedHash = leaf;
        uint32 index = leafIndex;

        for (uint8 i = 0; i < TREE_HEIGHT; i++) {
            bytes32 proofElement = proof[i];
            
            if (index % 2 == 0) {
                // Current node is left child
                computedHash = hashLeftRight(computedHash, proofElement);
            } else {
                // Current node is right child
                computedHash = hashLeftRight(proofElement, computedHash);
            }
            
            index /= 2;
        }

        return computedHash == root;
    }

    /**
     * @notice Check if a root exists in the history
     * @param tree The tree data structure
     * @param root The root to check
     * @return True if the root is valid (exists in history)
     */
    function isKnownRoot(TreeData storage tree, bytes32 root) internal view returns (bool) {
        return tree.rootHistory[root];
    }

    /**
     * @notice Get the current root
     * @param tree The tree data structure
     * @return The current Merkle root
     */
    function getLastRoot(TreeData storage tree) internal view returns (bytes32) {
        return tree.roots[tree.roots.length - 1];
    }

    /**
     * @notice Get the number of leaves in the tree
     * @param tree The tree data structure
     * @return The number of leaves
     */
    function getNextLeafIndex(TreeData storage tree) internal view returns (uint32) {
        return tree.nextLeafIndex;
    }

    /**
     * @notice Hash two child nodes
     * @dev Uses Poseidon2 so on-chain hashing matches the Noir circuits
     * @param left The left child hash
     * @param right The right child hash
     * @return The parent hash
     */
    function hashLeftRight(bytes32 left, bytes32 right) internal pure returns (bytes32) {
        Field.Type leftField = Field.toFieldReduce(left);
        Field.Type rightField = Field.toFieldReduce(right);
        Field.Type hashed = Poseidon2.hash_2(leftField, rightField);
        return Field.toBytes32(hashed);
    }

    /**
     * @notice Compute the Merkle root from a leaf and proof
     * @param leaf The leaf value
     * @param proof The Merkle proof path
     * @param leafIndex The index of the leaf
     * @return The computed root
     */
    function computeRoot(
        bytes32 leaf,
        bytes32[TREE_HEIGHT] memory proof,
        uint32 leafIndex
    ) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        uint32 index = leafIndex;

        for (uint8 i = 0; i < TREE_HEIGHT; i++) {
            if (index % 2 == 0) {
                computedHash = hashLeftRight(computedHash, proof[i]);
            } else {
                computedHash = hashLeftRight(proof[i], computedHash);
            }
            index /= 2;
        }

        return computedHash;
    }
}

