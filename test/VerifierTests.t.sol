// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

import { DepositVerifier } from "../src/verifier/privacy/DepositVerifier.sol";
import { TransferVerifier } from "../src/verifier/privacy/TransferVerifier.sol";
import { WithdrawVerifier } from "../src/verifier/privacy/WithdrawVerifier.sol";
import { SPNFTOwnershipVerifier } from "../src/verifier/SPNFTOwnershipVerifier.sol";

contract VerifierTests is Test {
    DepositVerifier private depositVerifier;
    TransferVerifier private transferVerifier;
    WithdrawVerifier private withdrawVerifier;
    SPNFTOwnershipVerifier private ownershipVerifier;

    function setUp() public {
        depositVerifier = new DepositVerifier();
        transferVerifier = new TransferVerifier();
        withdrawVerifier = new WithdrawVerifier();
        ownershipVerifier = new SPNFTOwnershipVerifier();
    }

    function testDepositVerifierAcceptsProof() public {
        bytes memory proof = _readBinary("test/data/deposit/proof.bin");
        bytes32[] memory publicInputs = _readPublicInputs("test/data/deposit/public_inputs.bin", 2);

        assertTrue(depositVerifier.verify(proof, publicInputs), "deposit proof should verify");
    }

    function testTransferVerifierAcceptsProof() public {
        bytes memory proof = _readBinary("test/data/transfer/proof.bin");
        bytes32[] memory publicInputs = _readPublicInputs("test/data/transfer/public_inputs.bin", 3);

        assertTrue(transferVerifier.verify(proof, publicInputs), "transfer proof should verify");
    }

    function testWithdrawVerifierAcceptsProof() public {
        bytes memory proof = _readBinary("test/data/withdraw/proof.bin");
        bytes32[] memory publicInputs = _readPublicInputs("test/data/withdraw/public_inputs.bin", 4);

        assertTrue(withdrawVerifier.verify(proof, publicInputs), "withdraw proof should verify");
    }

    function testOwnershipVerifierAcceptsProof() public {
        bytes memory proof = _readBinary("test/data/ownership/proof.bin");
        bytes32[] memory publicInputs = _readPublicInputs("test/data/ownership/public_inputs.bin", 3);

        assertTrue(ownershipVerifier.verify(proof, publicInputs), "ownership proof should verify");
    }

    function testDepositVerifierRejectsTamperedInput() public {
        bytes memory proof = _readBinary("test/data/deposit/proof.bin");
        bytes32[] memory publicInputs = _readPublicInputs("test/data/deposit/public_inputs.bin", 2);
        publicInputs[0] = bytes32(uint256(publicInputs[0]) + 1);

        vm.expectRevert();
        depositVerifier.verify(proof, new bytes32[](1)); // wrong length

        vm.expectRevert();
        depositVerifier.verify(proof, publicInputs);
    }

    // ---------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------

    function _readBinary(string memory path) private view returns (bytes memory data) {
        data = vm.readFileBinary(path);
        require(data.length != 0, "empty file");
    }

    function _readPublicInputs(string memory path, uint256 expectedCount) private view returns (bytes32[] memory result) {
        bytes memory raw = _readBinary(path);
        require(raw.length == expectedCount * 32, "unexpected input length");

        result = new bytes32[](expectedCount);
        for (uint256 i = 0; i < expectedCount; ++i) {
            bytes32 word;
            assembly {
                word := mload(add(add(raw, 0x20), mul(i, 0x20)))
            }
            result[i] = word;
        }
    }
}
