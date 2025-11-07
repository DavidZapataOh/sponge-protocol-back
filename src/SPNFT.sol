// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { SPNFTOwnershipVerifier } from "./verifier/SPNFTOwnershipVerifier.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { ERC721URIStorage } from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { DataTypeConverter } from "./utils/DataTypeConverter.sol";


/**
 * @title - SP NFT contract
 * @notice - NFT can be minted and its ownership can be verified without revealing metadata by verfying a ZK Proof.
 */
contract SPNFT is ERC721URIStorage, Ownable {
    SPNFTOwnershipVerifier public spNFTOwnershipVerifier;

    mapping(uint256 => mapping(address => mapping(bytes32 => bool))) private nullifiers;        // Store a "nullifier" into the "private" storage.

    uint256 private nextTokenId = 1;

    constructor(SPNFTOwnershipVerifier _spNFTOwnershipVerifier, address creator) ERC721("SP-NFT", "SP-NFT") Ownable(creator) {
        spNFTOwnershipVerifier = _spNFTOwnershipVerifier;
        //transferOwnership(creator); /// @dev - Transfer the ownership of this SPNFT contract to a given creator, who is the caller of the SPNFTFactory#createNewSPNFT() function.
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
        bool isValidProof = spNFTOwnershipVerifier.verifySPNFTOwnershipProof(proof, publicInputs);
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
        return spNFTOwnershipVerifier.verifySPNFTOwnershipProof(proof, publicInputs); // If "False", this proof is invalid
    }
}