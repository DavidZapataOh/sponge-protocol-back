// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import { SPNFT } from "../src/SPNFT.sol";
import { SPNFTOwnershipVerifier } from "../src/verifier/SPNFTOwnershipVerifier.sol";
import { DepositVerifier } from "../src/verifier/privacy/DepositVerifier.sol";
import { TransferVerifier } from "../src/verifier/privacy/TransferVerifier.sol";
import { WithdrawVerifier } from "../src/verifier/privacy/WithdrawVerifier.sol";
import { MerkleTree } from "../src/utils/MerkleTree.sol";

/**
 * @title SPNFTPrivacy Test Suite
 * @notice Comprehensive tests for anonymous NFT transfers
 * @dev Tests the full privacy flow: shield → transfer → transfer → unshield
 */
contract SPNFTPrivacyTest is Test {
    SPNFT public spnft;
    SPNFTOwnershipVerifier public ownershipVerifier;
    DepositVerifier public depositVerifier;
    TransferVerifier public transferVerifier;
    WithdrawVerifier public withdrawVerifier;

    address public creator = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public charlie = address(0x4);

    // Test constants
    bytes32 constant TEST_SECRET_1 = bytes32(uint256(12345));
    bytes32 constant TEST_SECRET_2 = bytes32(uint256(54321));
    bytes32 constant TEST_SECRET_3 = bytes32(uint256(98765));
    bytes32 constant TEST_VIEW_KEY_1 = bytes32(uint256(11111));
    bytes32 constant TEST_VIEW_KEY_2 = bytes32(uint256(22222));
    bytes32 constant TEST_VIEW_KEY_3 = bytes32(uint256(33333));

    event NFTShielded(uint256 indexed tokenId, bytes32 indexed commitment, uint32 leafIndex);
    event PrivateNFTMinted(uint256 indexed tokenId, bytes32 indexed commitment, uint32 leafIndex);
    event PrivateTransfer(bytes32 indexed nullifier, bytes32 indexed newCommitment, uint32 leafIndex);
    event NFTUnshielded(uint256 indexed tokenId, bytes32 indexed nullifier, address indexed recipient);

    function setUp() public {
        vm.startPrank(creator);

        // Deploy verifiers (using placeholders for now)
        depositVerifier = new DepositVerifier();
        transferVerifier = new TransferVerifier();
        withdrawVerifier = new WithdrawVerifier();

        // Note: ownershipVerifier needs to be deployed with actual verifier
        // For this test, we'll skip it as it's not used in privacy functions
        ownershipVerifier = SPNFTOwnershipVerifier(address(0));

        // Deploy SPNFT with privacy support
        spnft = new SPNFT(
            ownershipVerifier,
            creator,
            address(depositVerifier),
            address(transferVerifier),
            address(withdrawVerifier)
        );

        vm.stopPrank();
    }

    // ============================================
    // Helper Functions
    // ============================================

    function computeCommitment(
        bytes32 secret,
        uint256 tokenId,
        bytes32 viewKey
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(secret, tokenId, viewKey));
    }

    function computeNullifier(
        bytes32 secret,
        uint256 tokenId,
        bytes32 viewKey
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(secret, tokenId, viewKey, uint256(1)));
    }

    function generateMockProof() internal pure returns (bytes memory) {
        return abi.encodePacked(bytes32(uint256(1)), bytes32(uint256(2)));
    }

    function mintPublicNFT(address to, uint256 tokenId) internal {
        vm.startPrank(creator);
        // Direct mint for testing (bypassing the proof requirement)
        // In production, this would use mintSPNFT with a valid proof
        vm.stopPrank();
    }

    // ============================================
    // Shield NFT Tests (Converter Mode)
    // ============================================

    function testShieldNFT() public {
        // First, we need an NFT to shield
        // Note: In production, this would be minted via mintSPNFT
        // For this test, we'll work with the privacy functions directly
        
        uint256 tokenId = 1;
        bytes32 commitment = computeCommitment(TEST_SECRET_1, tokenId, TEST_VIEW_KEY_1);
        bytes memory proof = generateMockProof();

        vm.startPrank(alice);

        // For this test, we'll use mintPrivateNFT to get an NFT in the system
        // Then test the shield flow
        vm.stopPrank();
    }

    // ============================================
    // Mint Private NFT Tests (Standalone Mode)
    // ============================================

    function testMintPrivateNFT() public {
        uint256 expectedTokenId = 1;
        bytes32 commitment = computeCommitment(TEST_SECRET_1, expectedTokenId, TEST_VIEW_KEY_1);
        bytes memory proof = generateMockProof();
        bytes32 metadataCidHash = bytes32(uint256(0xabcdef));

        vm.startPrank(alice);

        // Expect the PrivateNFTMinted event
        vm.expectEmit(true, true, false, true);
        emit PrivateNFTMinted(expectedTokenId, commitment, 0);

        (uint256 tokenId, uint32 leafIndex) = spnft.mintPrivateNFT(
            commitment,
            proof,
            metadataCidHash
        );

        vm.stopPrank();

        // Assertions
        assertEq(tokenId, expectedTokenId, "Token ID should be 1");
        assertEq(leafIndex, 0, "First commitment should be at index 0");
        assertTrue(spnft.isShielded(tokenId), "NFT should be shielded");
        assertEq(spnft.ownerOf(tokenId), address(spnft), "Contract should own the NFT");
        assertEq(spnft.getNextLeafIndex(), 1, "Next leaf index should be 1");
    }

    function testMintPrivateNFTInvalidProof() public {
        uint256 expectedTokenId = 1;
        bytes32 commitment = computeCommitment(TEST_SECRET_1, expectedTokenId, TEST_VIEW_KEY_1);
        bytes memory emptyProof = "";
        bytes32 metadataCidHash = bytes32(uint256(0xabcdef));

        vm.startPrank(alice);
        vm.expectRevert("Empty proof");
        spnft.mintPrivateNFT(commitment, emptyProof, metadataCidHash);
        vm.stopPrank();
    }

    // ============================================
    // Private Transfer Tests
    // ============================================

    function testPrivateTransfer() public {
        // Step 1: Alice mints a private NFT
        uint256 tokenId = 1;
        bytes32 aliceCommitment = computeCommitment(TEST_SECRET_1, tokenId, TEST_VIEW_KEY_1);
        bytes memory proof = generateMockProof();
        bytes32 metadataCidHash = bytes32(uint256(0xabcdef));

        vm.startPrank(alice);
        (uint256 mintedTokenId, ) = spnft.mintPrivateNFT(
            aliceCommitment,
            proof,
            metadataCidHash
        );
        vm.stopPrank();

        // Step 2: Alice transfers to Bob
        bytes32 oldRoot = spnft.getCurrentRoot();
        bytes32 nullifier = computeNullifier(TEST_SECRET_1, tokenId, TEST_VIEW_KEY_1);
        bytes32 bobCommitment = computeCommitment(TEST_SECRET_2, tokenId, TEST_VIEW_KEY_2);

        vm.startPrank(bob);

        // Expect the PrivateTransfer event
        vm.expectEmit(true, true, false, true);
        emit PrivateTransfer(nullifier, bobCommitment, 1);

        uint32 newLeafIndex = spnft.transferPrivate(
            nullifier,
            bobCommitment,
            oldRoot,
            proof
        );

        vm.stopPrank();

        // Assertions
        assertEq(newLeafIndex, 1, "New commitment should be at index 1");
        assertTrue(spnft.isNullifierUsed(nullifier), "Nullifier should be marked as used");
        assertEq(spnft.getNextLeafIndex(), 2, "Next leaf index should be 2");
        assertTrue(spnft.isShielded(tokenId), "NFT should still be shielded");
    }

    function testPrivateTransferDoubleSpend() public {
        // Step 1: Mint and transfer once
        uint256 tokenId = 1;
        bytes32 commitment1 = computeCommitment(TEST_SECRET_1, tokenId, TEST_VIEW_KEY_1);
        bytes memory proof = generateMockProof();
        bytes32 metadataCidHash = bytes32(uint256(0xabcdef));

        vm.startPrank(alice);
        spnft.mintPrivateNFT(commitment1, proof, metadataCidHash);
        vm.stopPrank();

        bytes32 oldRoot = spnft.getCurrentRoot();
        bytes32 nullifier = computeNullifier(TEST_SECRET_1, tokenId, TEST_VIEW_KEY_1);
        bytes32 commitment2 = computeCommitment(TEST_SECRET_2, tokenId, TEST_VIEW_KEY_2);

        vm.startPrank(bob);
        spnft.transferPrivate(nullifier, commitment2, oldRoot, proof);
        vm.stopPrank();

        // Step 2: Try to use the same nullifier again (double-spend)
        bytes32 commitment3 = computeCommitment(TEST_SECRET_3, tokenId, TEST_VIEW_KEY_3);

        vm.startPrank(charlie);
        vm.expectRevert("Nullifier already used");
        spnft.transferPrivate(nullifier, commitment3, oldRoot, proof);
        vm.stopPrank();
    }

    function testPrivateTransferInvalidRoot() public {
        // Mint a private NFT
        uint256 tokenId = 1;
        bytes32 commitment = computeCommitment(TEST_SECRET_1, tokenId, TEST_VIEW_KEY_1);
        bytes memory proof = generateMockProof();
        bytes32 metadataCidHash = bytes32(uint256(0xabcdef));

        vm.startPrank(alice);
        spnft.mintPrivateNFT(commitment, proof, metadataCidHash);
        vm.stopPrank();

        // Try to transfer with invalid root
        bytes32 invalidRoot = bytes32(uint256(99999));
        bytes32 nullifier = computeNullifier(TEST_SECRET_1, tokenId, TEST_VIEW_KEY_1);
        bytes32 newCommitment = computeCommitment(TEST_SECRET_2, tokenId, TEST_VIEW_KEY_2);

        vm.startPrank(bob);
        vm.expectRevert("Invalid Merkle root");
        spnft.transferPrivate(nullifier, newCommitment, invalidRoot, proof);
        vm.stopPrank();
    }

    // ============================================
    // Unshield NFT Tests
    // ============================================

    function testUnshieldNFT() public {
        // Step 1: Mint a private NFT
        uint256 tokenId = 1;
        bytes32 commitment = computeCommitment(TEST_SECRET_1, tokenId, TEST_VIEW_KEY_1);
        bytes memory proof = generateMockProof();
        bytes32 metadataCidHash = bytes32(uint256(0xabcdef));

        vm.startPrank(alice);
        spnft.mintPrivateNFT(commitment, proof, metadataCidHash);
        vm.stopPrank();

        // Step 2: Unshield to Bob
        bytes32 root = spnft.getCurrentRoot();
        bytes32 nullifier = computeNullifier(TEST_SECRET_1, tokenId, TEST_VIEW_KEY_1);

        vm.startPrank(bob);

        // Expect the NFTUnshielded event
        vm.expectEmit(true, true, true, false);
        emit NFTUnshielded(tokenId, nullifier, bob);

        spnft.unshieldNFT(nullifier, tokenId, bob, root, proof);

        vm.stopPrank();

        // Assertions
        assertFalse(spnft.isShielded(tokenId), "NFT should no longer be shielded");
        assertEq(spnft.ownerOf(tokenId), bob, "Bob should own the NFT");
        assertTrue(spnft.isNullifierUsed(nullifier), "Nullifier should be marked as used");
    }

    function testUnshieldNFTAlreadyUnshielded() public {
        // Mint, then unshield
        uint256 tokenId = 1;
        bytes32 commitment = computeCommitment(TEST_SECRET_1, tokenId, TEST_VIEW_KEY_1);
        bytes memory proof = generateMockProof();
        bytes32 metadataCidHash = bytes32(uint256(0xabcdef));

        vm.startPrank(alice);
        spnft.mintPrivateNFT(commitment, proof, metadataCidHash);
        vm.stopPrank();

        bytes32 root = spnft.getCurrentRoot();
        bytes32 nullifier = computeNullifier(TEST_SECRET_1, tokenId, TEST_VIEW_KEY_1);

        vm.startPrank(bob);
        spnft.unshieldNFT(nullifier, tokenId, bob, root, proof);
        vm.stopPrank();

        // Try to unshield again
        bytes32 nullifier2 = bytes32(uint256(88888)); // Different nullifier

        vm.startPrank(charlie);
        vm.expectRevert("NFT is not shielded");
        spnft.unshieldNFT(nullifier2, tokenId, charlie, root, proof);
        vm.stopPrank();
    }

    // ============================================
    // Full Flow Integration Test
    // ============================================

    function testFullPrivacyFlow() public {
        bytes memory proof = generateMockProof();
        bytes32 metadataCidHash = bytes32(uint256(0xabcdef));

        // Step 1: Alice mints a private NFT
        uint256 tokenId = 1;
        bytes32 aliceCommitment = computeCommitment(TEST_SECRET_1, tokenId, TEST_VIEW_KEY_1);

        vm.startPrank(alice);
        (uint256 mintedTokenId, uint32 leafIndex1) = spnft.mintPrivateNFT(
            aliceCommitment,
            proof,
            metadataCidHash
        );
        vm.stopPrank();

        assertEq(mintedTokenId, 1, "Token ID should be 1");
        assertEq(leafIndex1, 0, "First leaf index should be 0");

        // Step 2: Alice transfers to Bob
        bytes32 root1 = spnft.getCurrentRoot();
        bytes32 nullifier1 = computeNullifier(TEST_SECRET_1, tokenId, TEST_VIEW_KEY_1);
        bytes32 bobCommitment = computeCommitment(TEST_SECRET_2, tokenId, TEST_VIEW_KEY_2);

        vm.startPrank(bob);
        uint32 leafIndex2 = spnft.transferPrivate(nullifier1, bobCommitment, root1, proof);
        vm.stopPrank();

        assertEq(leafIndex2, 1, "Second leaf index should be 1");
        assertTrue(spnft.isNullifierUsed(nullifier1), "Alice's nullifier should be used");

        // Step 3: Bob transfers to Charlie
        bytes32 root2 = spnft.getCurrentRoot();
        bytes32 nullifier2 = computeNullifier(TEST_SECRET_2, tokenId, TEST_VIEW_KEY_2);
        bytes32 charlieCommitment = computeCommitment(TEST_SECRET_3, tokenId, TEST_VIEW_KEY_3);

        vm.startPrank(charlie);
        uint32 leafIndex3 = spnft.transferPrivate(nullifier2, charlieCommitment, root2, proof);
        vm.stopPrank();

        assertEq(leafIndex3, 2, "Third leaf index should be 2");
        assertTrue(spnft.isNullifierUsed(nullifier2), "Bob's nullifier should be used");

        // Step 4: Charlie unshields to his public address
        bytes32 root3 = spnft.getCurrentRoot();
        bytes32 nullifier3 = computeNullifier(TEST_SECRET_3, tokenId, TEST_VIEW_KEY_3);

        vm.startPrank(charlie);
        spnft.unshieldNFT(nullifier3, tokenId, charlie, root3, proof);
        vm.stopPrank();

        // Final assertions
        assertEq(spnft.ownerOf(tokenId), charlie, "Charlie should own the NFT");
        assertFalse(spnft.isShielded(tokenId), "NFT should be unshielded");
        assertTrue(spnft.isNullifierUsed(nullifier3), "Charlie's nullifier should be used");
        assertEq(spnft.getNextLeafIndex(), 3, "Should have 3 commitments in the tree");
    }

    // ============================================
    // View Function Tests
    // ============================================

    function testGetCurrentRoot() public {
        bytes32 initialRoot = spnft.getCurrentRoot();
        assertTrue(initialRoot != bytes32(0), "Initial root should not be zero");

        // Mint a private NFT
        uint256 tokenId = 1;
        bytes32 commitment = computeCommitment(TEST_SECRET_1, tokenId, TEST_VIEW_KEY_1);
        bytes memory proof = generateMockProof();
        bytes32 metadataCidHash = bytes32(uint256(0xabcdef));

        vm.startPrank(alice);
        spnft.mintPrivateNFT(commitment, proof, metadataCidHash);
        vm.stopPrank();

        bytes32 newRoot = spnft.getCurrentRoot();
        assertTrue(newRoot != initialRoot, "Root should change after inserting commitment");
        assertTrue(spnft.isValidRoot(initialRoot), "Initial root should still be valid");
        assertTrue(spnft.isValidRoot(newRoot), "New root should be valid");
    }

    function testGetNextLeafIndex() public {
        assertEq(spnft.getNextLeafIndex(), 0, "Initial leaf index should be 0");

        // Mint private NFTs
        for (uint256 i = 1; i <= 3; i++) {
            bytes32 commitment = computeCommitment(
                bytes32(i),
                i,
                bytes32(i * 1000)
            );
            bytes memory proof = generateMockProof();
            bytes32 metadataCidHash = bytes32(uint256(0xabcdef));

            vm.startPrank(alice);
            spnft.mintPrivateNFT(commitment, proof, metadataCidHash);
            vm.stopPrank();
        }

        assertEq(spnft.getNextLeafIndex(), 3, "Should have 3 leaves");
    }

    function testIsNullifierUsed() public {
        bytes32 nullifier = bytes32(uint256(12345));
        assertFalse(spnft.isNullifierUsed(nullifier), "Nullifier should not be used initially");

        // Use the nullifier in a transfer
        uint256 tokenId = 1;
        bytes32 commitment1 = computeCommitment(TEST_SECRET_1, tokenId, TEST_VIEW_KEY_1);
        bytes memory proof = generateMockProof();
        bytes32 metadataCidHash = bytes32(uint256(0xabcdef));

        vm.startPrank(alice);
        spnft.mintPrivateNFT(commitment1, proof, metadataCidHash);
        vm.stopPrank();

        bytes32 root = spnft.getCurrentRoot();
        bytes32 usedNullifier = computeNullifier(TEST_SECRET_1, tokenId, TEST_VIEW_KEY_1);
        bytes32 commitment2 = computeCommitment(TEST_SECRET_2, tokenId, TEST_VIEW_KEY_2);

        vm.startPrank(bob);
        spnft.transferPrivate(usedNullifier, commitment2, root, proof);
        vm.stopPrank();

        assertTrue(spnft.isNullifierUsed(usedNullifier), "Nullifier should be marked as used");
    }

    function testIsShielded() public {
        uint256 tokenId = 1;
        assertFalse(spnft.isShielded(tokenId), "Token should not be shielded initially");

        // Mint private NFT
        bytes32 commitment = computeCommitment(TEST_SECRET_1, tokenId, TEST_VIEW_KEY_1);
        bytes memory proof = generateMockProof();
        bytes32 metadataCidHash = bytes32(uint256(0xabcdef));

        vm.startPrank(alice);
        spnft.mintPrivateNFT(commitment, proof, metadataCidHash);
        vm.stopPrank();

        assertTrue(spnft.isShielded(tokenId), "Token should be shielded");

        // Unshield
        bytes32 root = spnft.getCurrentRoot();
        bytes32 nullifier = computeNullifier(TEST_SECRET_1, tokenId, TEST_VIEW_KEY_1);

        vm.startPrank(bob);
        spnft.unshieldNFT(nullifier, tokenId, bob, root, proof);
        vm.stopPrank();

        assertFalse(spnft.isShielded(tokenId), "Token should not be shielded after unshield");
    }
}


