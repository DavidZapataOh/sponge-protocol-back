// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { SPNFTOwnershipVerifier } from "./verifier/SPNFTOwnershipVerifier.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { ERC721URIStorage } from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { DataTypeConverter } from "./utils/DataTypeConverter.sol";
import { MerkleTree } from "./utils/MerkleTree.sol";
import { MetaTransactions } from "./utils/MetaTransactions.sol";
import { RelayerRegistry } from "./RelayerRegistry.sol";


// Interface for privacy verifiers
interface IDepositVerifier {
    function verify(bytes calldata proof, bytes32[] calldata publicInputs) external view returns (bool);
}

interface ITransferVerifier {
    function verify(bytes calldata proof, bytes32[] calldata publicInputs) external view returns (bool);
}

interface IWithdrawVerifier {
    function verify(bytes calldata proof, bytes32[] calldata publicInputs) external view returns (bool);
}

/**
 * @title - SP NFT contract
 * @notice - NFT can be minted and its ownership can be verified without revealing metadata by verfying a ZK Proof.
 * @notice - Extended with privacy pool for anonymous NFT transfers using ZK proofs, Merkle trees, and stealth addresses.
 * @notice - Supports relayer-based gas abstraction for complete privacy.
 */
contract SPNFT is ERC721URIStorage, Ownable, MetaTransactions {
    using MerkleTree for MerkleTree.TreeData;

    // Original verifier for minting
    SPNFTOwnershipVerifier public spNFTOwnershipVerifier;

    // Privacy verifiers
    IDepositVerifier public depositVerifier;
    ITransferVerifier public transferVerifier;
    IWithdrawVerifier public withdrawVerifier;

    // Original nullifiers for minting
    mapping(uint256 => mapping(address => mapping(bytes32 => bool))) private nullifiers;

    // Privacy pool state
    MerkleTree.TreeData private commitmentTree;
    mapping(bytes32 => bool) public usedNullifiers; // Track spent commitments
    mapping(bytes32 => bool) public commitments; // Track valid commitments
    mapping(uint256 => bool) public shieldedTokens; // Track which tokens are in privacy mode
    
    // Metadata privacy - SECURITY FIX: Never store actual metadata on-chain
    // Only store hash for optional verification
    mapping(uint256 => bytes32) private metadataCommitment; // Hash of original metadata
    string public constant PRIVATE_METADATA_URI = "ipfs://QmPrivateNFTMetadataHidden"; // Generic URI for privacy
    
    // Relayer system
    RelayerRegistry public relayerRegistry;
    
    uint256 private nextTokenId = 1;

    // Events for privacy operations
    event NFTShielded(uint256 indexed tokenId, bytes32 indexed commitment, uint32 leafIndex);
    event PrivateNFTMinted(uint256 indexed tokenId, bytes32 indexed commitment, uint32 leafIndex);
    event PrivateTransfer(bytes32 indexed nullifier, bytes32 indexed newCommitment, uint32 leafIndex, address indexed relayer);
    event NFTUnshielded(uint256 indexed tokenId, bytes32 indexed nullifier, address indexed recipient);
    event RelayerPaid(address indexed relayer, uint256 fee);

    constructor(
        SPNFTOwnershipVerifier _spNFTOwnershipVerifier,
        address creator,
        address _depositVerifier,
        address _transferVerifier,
        address _withdrawVerifier,
        address _relayerRegistry
    ) 
        ERC721("SP-NFT", "SP-NFT") 
        Ownable(creator)
        MetaTransactions("SPNFT", "1")
    {
        spNFTOwnershipVerifier = _spNFTOwnershipVerifier;
        depositVerifier = IDepositVerifier(_depositVerifier);
        transferVerifier = ITransferVerifier(_transferVerifier);
        withdrawVerifier = IWithdrawVerifier(_withdrawVerifier);
        relayerRegistry = RelayerRegistry(_relayerRegistry);
        
        // Initialize the Merkle tree
        commitmentTree.initialize();
    }

    /**
     * @notice - Mint a new SP-NFT
     * @dev - A given metadata URI is stored in the tokenURI mapping of the ERC721 contract.
     * @dev - A given metadata URI includes a CID (IPFS Hash), where a proof is stored (instead of that its actual metadata is stored)
     * param metadataURI - The URI of the metadata associated with the NFT (i.e. IPFS Hash, which is called "CID")
     */
    function mintSPNFT(bytes calldata proof, bytes32 merkleRoot, bytes32 nullifierHash, bytes32 metadataCidHash) public returns (uint256 tokenId) {
        /// @dev - Convert the data type of a given metadataCidHash from bytes32 to string
        string memory metadataCidHashString = DataTypeConverter.bytes32ToString(metadataCidHash); // Convert bytes32 to string

        /// @dev - Check before/after converting a given metadataCidHash. 
        /// @dev - [NOTE]: We could confirm this check was passed. Hence, the following validation code is commented out for the moment.
        // bytes32 metadataCidHashReversed = DataTypeConverter.stringToBytes32(metadataCidHashString);
        // require(metadataCidHash == metadataCidHashReversed, "metadataCidHash and metadataCidHashReversed must be the same value");
        // console.logBytes32(metadataCidHash);          // [Log]: 0x0c863c512eaa011ffa5d0f8b8cfe26c5dfa6c0e102a4594a3e40af8f68d86dd0        
        // console.logBytes32(metadataCidHashReversed);  // [Log]: 0x0c863c512eaa011ffa5d0f8b8cfe26c5dfa6c0e102a4594a3e40af8f68d86dd0
        
        /// @dev - Mint a new SP-NFT
        uint256 tokenId = nextTokenId;
        _mint(msg.sender, tokenId);
        _setTokenURI(tokenId, metadataCidHashString);    /// @dev - Store a given metadataCidHash, which is a hashed-metadataURI, instead of storing a given metadataURI directly.
        //_setTokenURI(tokenId, metadataURI);   /// @dev - A given metadata URI includes a CID (IPFS Hash), where a proof is stored (instead of that its actual metadata is stored)

        /// @dev - Verify the proof
        bytes32[] memory publicInputs = new bytes32[](3);
        publicInputs[0] = merkleRoot;
        publicInputs[1] = nullifierHash;
        publicInputs[2] = metadataCidHash; // [NOTE]: The tokenId is used as a public input to verify the proof.
        bool isValidProof = spNFTOwnershipVerifier.verify(proof, publicInputs);
        require(isValidProof, "Invalid proof");
        //require(spNFTOwnershipVerifier.verifySPNFTOwnershipProof(proof, publicInputs), "Invalid proof");  
        // console.logBool(isValidProof); // [Log]: true

        /// @dev - Save a nullifier to prevent double-spending of a proof.
        nullifiers[tokenId][ownerOf(tokenId)][nullifierHash] = true;
        
        nextTokenId++;

        return tokenId;
    }

    /** 
     * @notice - Check whether or not a given proof is valid without revealing metadata
     */
    function verifySPNFTOwnershipProof(uint256 tokenId, bytes calldata proof, bytes32 merkleRoot, bytes32 nullifierHash) public view returns (bool isValidProof) {
        require(ownerOf(tokenId) != address(0), "This SPNFT does not exist");
        
        require(!nullifiers[tokenId][ownerOf(tokenId)][nullifierHash], "This ZK Proof has already been submitted"); // Prevent from 'double-spending' of a ZK Proof.
        //nullifiers[nullifierHash] = true;

        bytes32[] memory publicInputs = new bytes32[](2);
        publicInputs[0] = merkleRoot;
        publicInputs[1] = nullifierHash;
        return spNFTOwnershipVerifier.verify(proof, publicInputs); // If "False", this proof is invalid
    }

    // ============================================
    // PRIVACY POOL FUNCTIONS
    // ============================================

    /**
     * @notice Shield an existing NFT into the privacy pool (Converter mode)
     * @dev The NFT is transferred to this contract and a commitment is created
     * @dev METADATA PRIVACY: Original metadata is hidden and replaced with generic URI
     * @dev SECURITY: Metadata is NOT stored on-chain. Client must encrypt and store off-chain.
     * @param tokenId The NFT token ID to shield
     * @param commitment The commitment Hash(secret, tokenId, recipientPubKey)
     * @param proof The ZK proof that the commitment is valid
     */
    function shieldNFT(
        uint256 tokenId,
        bytes32 commitment,
        bytes calldata proof
    ) external returns (uint32 leafIndex) {
        // Verify the caller owns the NFT
        require(ownerOf(tokenId) == msg.sender, "Not the owner of this NFT");
        require(!shieldedTokens[tokenId], "NFT already shielded");
        
        // Verify the deposit proof
        // Public inputs: commitment, tokenId
        bytes32[] memory publicInputs = new bytes32[](2);
        publicInputs[0] = commitment;
        publicInputs[1] = bytes32(tokenId);
        require(depositVerifier.verify(proof, publicInputs), "Invalid deposit proof");
        
        // METADATA PRIVACY FIX: Only store hash, never actual metadata
        // Client must:
        // 1. Save original metadata locally
        // 2. Encrypt with key = keccak256(secret)
        // 3. Upload encrypted to IPFS
        // 4. Share IPFS CID with recipient via ECDH
        string memory originalURI = tokenURI(tokenId);
        metadataCommitment[tokenId] = keccak256(bytes(originalURI));
        _setTokenURI(tokenId, PRIVATE_METADATA_URI);
        
        // Transfer NFT to this contract (escrow)
        _transfer(msg.sender, address(this), tokenId);
        
        // Mark token as shielded
        shieldedTokens[tokenId] = true;
        
        // Insert commitment into Merkle tree
        leafIndex = commitmentTree.insert(commitment);
        commitments[commitment] = true;
        
        emit NFTShielded(tokenId, commitment, leafIndex);
        
        return leafIndex;
    }

    /**
     * @notice Mint a new NFT directly into the privacy pool (Standalone mode)
     * @dev Creates a new NFT that starts in private mode
     * @param commitment The commitment Hash(secret, tokenId, viewKey)
     * @param proof The ZK proof that the commitment is valid
     * @param metadataCidHash The metadata CID hash
     */
    function mintPrivateNFT(
        bytes32 commitment,
        bytes calldata proof,
        bytes32 metadataCidHash
    ) external returns (uint256 tokenId, uint32 leafIndex) {
        // Get next token ID
        tokenId = nextTokenId;
        
        // Verify the deposit proof
        // Public inputs: commitment, tokenId
        bytes32[] memory publicInputs = new bytes32[](2);
        publicInputs[0] = commitment;
        publicInputs[1] = bytes32(tokenId);
        require(depositVerifier.verify(proof, publicInputs), "Invalid deposit proof");
        
        // Mint the NFT to this contract (starts in privacy pool)
        string memory metadataCidHashString = DataTypeConverter.bytes32ToString(metadataCidHash);
        _mint(address(this), tokenId);
        _setTokenURI(tokenId, metadataCidHashString);
        
        // Mark token as shielded
        shieldedTokens[tokenId] = true;
        
        // Insert commitment into Merkle tree
        leafIndex = commitmentTree.insert(commitment);
        commitments[commitment] = true;
        
        nextTokenId++;
        
        emit PrivateNFTMinted(tokenId, commitment, leafIndex);
        
        return (tokenId, leafIndex);
    }

    /**
     * @notice Transfer an NFT commitment anonymously (direct call)
     * @dev Spends one commitment and creates a new one for the recipient
     * @dev WARNING: This function reveals the caller address. Use transferPrivateViaRelayer for full privacy.
     * @param nullifier The nullifier of the commitment being spent
     * @param newCommitment The new commitment for the recipient
     * @param root The Merkle root containing the old commitment
     * @param proof The ZK proof of valid transfer
     */
    function transferPrivate(
        bytes32 nullifier,
        bytes32 newCommitment,
        bytes32 root,
        bytes calldata proof
    ) external returns (uint32 leafIndex) {
        // Verify nullifier hasn't been used
        require(!usedNullifiers[nullifier], "Nullifier already used");
        
        // Verify root is valid (exists in history)
        require(commitmentTree.isKnownRoot(root), "Invalid Merkle root");
        
        // Verify the transfer proof
        // Public inputs: oldRoot, nullifier, newCommitment
        bytes32[] memory publicInputs = new bytes32[](3);
        publicInputs[0] = root;
        publicInputs[1] = nullifier;
        publicInputs[2] = newCommitment;
        require(transferVerifier.verify(proof, publicInputs), "Invalid transfer proof");
        
        // Mark nullifier as used (prevents double-spending)
        usedNullifiers[nullifier] = true;
        
        // Insert new commitment into Merkle tree
        leafIndex = commitmentTree.insert(newCommitment);
        commitments[newCommitment] = true;
        
        emit PrivateTransfer(nullifier, newCommitment, leafIndex, address(0));
        
        return leafIndex;
    }
    
    /**
     * @notice Transfer an NFT commitment anonymously via relayer (GAS ABSTRACTION)
     * @dev User signs transaction off-chain, relayer submits it
     * @dev This breaks the link between user address and on-chain activity
     * @param nullifier The nullifier of the commitment being spent
     * @param newCommitment The new commitment for the recipient
     * @param root The Merkle root containing the old commitment
     * @param proof The ZK proof of valid transfer
     * @param fee Fee to pay the relayer (in wei)
     * @param nonce User's current nonce
     * @param deadline Transaction deadline timestamp
     * @param signature User's EIP-712 signature
     */
    function transferPrivateViaRelayer(
        bytes32 nullifier,
        bytes32 newCommitment,
        bytes32 root,
        bytes calldata proof,
        uint256 fee,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) external returns (uint32 leafIndex) {
        // Verify relayer is active
        require(relayerRegistry.isActiveRelayer(msg.sender), "Not an active relayer");
        
        // Verify signature and get signer
        address signer = verifyPrivateTransferSignature(
            nullifier,
            newCommitment,
            root,
            msg.sender, // relayer
            fee,
            nonce,
            deadline,
            signature
        );
        
        // Increment nonce to prevent replay
        _incrementNonce(signer);
        
        // Verify nullifier hasn't been used
        require(!usedNullifiers[nullifier], "Nullifier already used");
        
        // Verify root is valid
        require(commitmentTree.isKnownRoot(root), "Invalid Merkle root");
        
        // Verify the transfer proof
        bytes32[] memory publicInputs = new bytes32[](3);
        publicInputs[0] = root;
        publicInputs[1] = nullifier;
        publicInputs[2] = newCommitment;
        require(transferVerifier.verify(proof, publicInputs), "Invalid transfer proof");
        
        // Mark nullifier as used
        usedNullifiers[nullifier] = true;
        
        // Insert new commitment into Merkle tree
        leafIndex = commitmentTree.insert(newCommitment);
        commitments[newCommitment] = true;
        
        // Pay relayer fee
        if (fee > 0) {
            (bool success, ) = msg.sender.call{value: fee}("");
            require(success, "Relayer payment failed");
            emit RelayerPaid(msg.sender, fee);
        }
        
        // Record transaction in registry
        relayerRegistry.recordTransaction(msg.sender, true);
        
        emit PrivateTransfer(nullifier, newCommitment, leafIndex, msg.sender);
        
        return leafIndex;
    }

    /**
     * @notice Unshield an NFT from the privacy pool to a public address (direct call)
     * @dev Spends a commitment and transfers the NFT to the recipient
     * @dev METADATA PRIVACY: Client must restore metadata from encrypted off-chain storage
     * @dev WARNING: This function reveals the caller address. Use unshieldNFTViaRelayer for full privacy.
     * @param nullifier The nullifier of the commitment being spent
     * @param tokenId The NFT token ID to withdraw
     * @param recipient The address to receive the NFT
     * @param root The Merkle root containing the commitment
     * @param proof The ZK proof of ownership
     * @param metadataURI The original metadata URI (optional, to restore publicly)
     */
    function unshieldNFT(
        bytes32 nullifier,
        uint256 tokenId,
        address recipient,
        bytes32 root,
        bytes calldata proof,
        string calldata metadataURI
    ) external {
        // Verify nullifier hasn't been used
        require(!usedNullifiers[nullifier], "Nullifier already used");
        
        // Verify root is valid
        require(commitmentTree.isKnownRoot(root), "Invalid Merkle root");
        
        // Verify the NFT is shielded
        require(shieldedTokens[tokenId], "NFT is not shielded");
        
        // Verify the withdraw proof
        // Public inputs: root, nullifier, tokenId, recipient
        bytes32[] memory publicInputs = new bytes32[](4);
        publicInputs[0] = root;
        publicInputs[1] = nullifier;
        publicInputs[2] = bytes32(tokenId);
        publicInputs[3] = bytes32(uint256(uint160(recipient)));
        require(withdrawVerifier.verify(proof, publicInputs), "Invalid withdraw proof");
        
        // Mark nullifier as used
        usedNullifiers[nullifier] = true;
        
        // Mark token as unshielded
        shieldedTokens[tokenId] = false;
        
        // METADATA PRIVACY FIX: Only restore if user wants to make it public
        // Verify metadata matches commitment if provided
        if (bytes(metadataURI).length > 0) {
            bytes32 providedHash = keccak256(bytes(metadataURI));
            require(
                metadataCommitment[tokenId] == bytes32(0) || 
                metadataCommitment[tokenId] == providedHash,
                "Metadata mismatch"
            );
            _setTokenURI(tokenId, metadataURI);
            delete metadataCommitment[tokenId];
        }
        // else: metadata stays hidden (PRIVATE_METADATA_URI)
        
        // Transfer NFT from contract to recipient
        _transfer(address(this), recipient, tokenId);
        
        emit NFTUnshielded(tokenId, nullifier, recipient);
    }
    
    /**
     * @notice Unshield an NFT via relayer (GAS ABSTRACTION)
     * @dev User signs transaction off-chain, relayer submits it
     * @dev This breaks the link between user address and withdrawal
     * @param nullifier The nullifier of the commitment being spent
     * @param tokenId The NFT token ID to withdraw
     * @param recipient The address to receive the NFT
     * @param root The Merkle root containing the commitment
     * @param proof The ZK proof of ownership
     * @param metadataURI The original metadata URI (optional, to restore publicly)
     * @param fee Fee to pay the relayer (in wei)
     * @param nonce User's current nonce
     * @param deadline Transaction deadline timestamp
     * @param signature User's EIP-712 signature
     */
    function unshieldNFTViaRelayer(
        bytes32 nullifier,
        uint256 tokenId,
        address recipient,
        bytes32 root,
        bytes calldata proof,
        string calldata metadataURI,
        uint256 fee,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) external {
        // Verify relayer is active
        require(relayerRegistry.isActiveRelayer(msg.sender), "Not an active relayer");
        
        // Verify signature and get signer
        address signer = verifyUnshieldSignature(
            nullifier,
            tokenId,
            recipient,
            root,
            msg.sender, // relayer
            fee,
            nonce,
            deadline,
            signature
        );
        
        // Increment nonce to prevent replay
        _incrementNonce(signer);
        
        // Verify nullifier hasn't been used
        require(!usedNullifiers[nullifier], "Nullifier already used");
        
        // Verify root is valid
        require(commitmentTree.isKnownRoot(root), "Invalid Merkle root");
        
        // Verify the NFT is shielded
        require(shieldedTokens[tokenId], "NFT is not shielded");
        
        // Verify the withdraw proof
        bytes32[] memory publicInputs = new bytes32[](4);
        publicInputs[0] = root;
        publicInputs[1] = nullifier;
        publicInputs[2] = bytes32(tokenId);
        publicInputs[3] = bytes32(uint256(uint160(recipient)));
        require(withdrawVerifier.verify(proof, publicInputs), "Invalid withdraw proof");
        
        // Mark nullifier as used
        usedNullifiers[nullifier] = true;
        
        // Mark token as unshielded
        shieldedTokens[tokenId] = false;
        
        // METADATA PRIVACY FIX: Only restore if user wants to make it public
        if (bytes(metadataURI).length > 0) {
            bytes32 providedHash = keccak256(bytes(metadataURI));
            require(
                metadataCommitment[tokenId] == bytes32(0) || 
                metadataCommitment[tokenId] == providedHash,
                "Metadata mismatch"
            );
            _setTokenURI(tokenId, metadataURI);
            delete metadataCommitment[tokenId];
        }
        
        // Transfer NFT from contract to recipient
        _transfer(address(this), recipient, tokenId);
        
        // Pay relayer fee
        if (fee > 0) {
            (bool success, ) = msg.sender.call{value: fee}("");
            require(success, "Relayer payment failed");
            emit RelayerPaid(msg.sender, fee);
        }
        
        // Record transaction in registry
        relayerRegistry.recordTransaction(msg.sender, true);
        
        emit NFTUnshielded(tokenId, nullifier, recipient);
    }
    
    /**
     * @notice Allow contract to receive ETH for relayer fees
     */
    receive() external payable {}

    // ============================================
    // VIEW FUNCTIONS FOR PRIVACY POOL
    // ============================================

    /**
     * @notice Get the current Merkle root
     */
    function getCurrentRoot() external view returns (bytes32) {
        return commitmentTree.getLastRoot();
    }

    /**
     * @notice Get the next leaf index in the Merkle tree
     */
    function getNextLeafIndex() external view returns (uint32) {
        return commitmentTree.getNextLeafIndex();
    }

    /**
     * @notice Check if a nullifier has been used
     */
    function isNullifierUsed(bytes32 nullifier) external view returns (bool) {
        return usedNullifiers[nullifier];
    }

    /**
     * @notice Check if a root is valid (exists in history)
     */
    function isValidRoot(bytes32 root) external view returns (bool) {
        return commitmentTree.isKnownRoot(root);
    }

    /**
     * @notice Check if an NFT is in the privacy pool
     */
    function isShielded(uint256 tokenId) external view returns (bool) {
        return shieldedTokens[tokenId];
    }
}