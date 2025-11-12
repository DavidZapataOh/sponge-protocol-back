// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { SPNFTOwnershipVerifier } from "./verifier/SPNFTOwnershipVerifier.sol";
import { SPNFT } from "./SPNFT.sol";


/**
 * SP NFT Factory contract
 * @notice Factory for deploying SPNFT contracts with privacy support
 */
contract SPNFTFactory {
    SPNFTOwnershipVerifier public spNFTOwnershipVerifier;
    address public depositVerifier;
    address public transferVerifier;
    address public withdrawVerifier;
    SPNFT public spNFT;

    mapping(address => address) public ownerOfSPNFTs; // Deployer of a SPNFT contract.

    event SPNFTCreated(address indexed creator, address indexed spnftAddress);

    address public relayerRegistry;
    
    constructor(
        SPNFTOwnershipVerifier _spNFTOwnershipVerifier,
        address _depositVerifier,
        address _transferVerifier,
        address _withdrawVerifier,
        address _relayerRegistry
    ) {
        spNFTOwnershipVerifier = _spNFTOwnershipVerifier;
        depositVerifier = _depositVerifier;
        transferVerifier = _transferVerifier;
        withdrawVerifier = _withdrawVerifier;
        relayerRegistry = _relayerRegistry;
    }

    /**
     * Create a new SPNFT with privacy support and relayer system
     * @return spNFT The newly created SPNFT contract
     */
    function createNewSPNFT() public returns (SPNFT spNFT) {
        SPNFT newSPNFT = new SPNFT(
            spNFTOwnershipVerifier,
            msg.sender,
            depositVerifier,
            transferVerifier,
            withdrawVerifier,
            relayerRegistry
        );
        ownerOfSPNFTs[msg.sender] = address(newSPNFT);
        
        emit SPNFTCreated(msg.sender, address(newSPNFT));
        
        return newSPNFT;
    }

}