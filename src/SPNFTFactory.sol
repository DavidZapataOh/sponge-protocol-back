// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { SPNFTOwnershipVerifier } from "./verifier/SPNFTOwnershipVerifier.sol";
import { SPNFT } from "./SPNFT.sol";


/**
 * SP NFT Factory contract
 */
contract SPNFTFactory {
    SPNFTOwnershipVerifier public spNFTOwnershipVerifier;
    SPNFT public spNFT;

    mapping(address => address) public ownerOfSPNFTs; // Deployer of a SPNFT contract.

    constructor(SPNFTOwnershipVerifier _spNFTOwnershipVerifier) {
        spNFTOwnershipVerifier = _spNFTOwnershipVerifier;
    }

    /**
     * Mint a new SPNFT
     */
    function createNewSPNFT() public returns (SPNFT spNFT) {
        SPNFT newSPNFT = new SPNFT(spNFTOwnershipVerifier, msg.sender);
        ownerOfSPNFTs[msg.sender] = address(newSPNFT);
        return newSPNFT;
    }

}