// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { UltraVerifier } from "./plonk_vk.sol";

contract IPNFTOwnershipVerifier {
    UltraVerifier public verifier;

    constructor(UltraVerifier _verifier) {
        verifier = _verifier;
    }

    function verifyIPNFTOwnershipProof(bytes calldata proof, bytes32[] calldata publicInputs) public view returns (bool) {
        bool proofResult = verifier.verify(proof, publicInputs);
        require(proofResult, "Proof is not valid");
        return proofResult;
    }
}