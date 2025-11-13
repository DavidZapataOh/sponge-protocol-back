// Deposit Circuit: Shield an NFT by creating a commitment
// This circuit proves that the user knows the secret and recipient public key for a commitment

use poseidon::poseidon2::Poseidon2;

/**
 * @notice Deposit circuit for shielding NFTs
 * @dev SECURITY FIX: commitment = Hash(secret, tokenId, recipientPubKey)
 * @dev This BINDS the commitment to the recipient's public key, preventing griefing attacks
 * 
 * Private inputs:
 * - secret: Random secret chosen by the depositor
 * - recipient_pub_key: Recipient's public key (CRITICAL: binds note to recipient)
 * 
 * Public inputs:
 * - commitment: The commitment to be inserted into the Merkle tree
 * - token_id: The NFT token ID being shielded (needed to verify ownership on-chain)
 * 
 * SECURITY: The commitment binds the secret, token ID, and recipient_pub_key together.
 * Only someone who knows all three AND controls the private key for recipient_pub_key can spend it.
 * This prevents relayers or attackers from re-routing the NFT to themselves.
 */
fn main(
    // Private inputs
    secret: Field,
    token_id: Field,
    recipient_pub_key: Field,  // SECURITY FIX: Bind to recipient
    
    // Public inputs
    commitment: pub Field,
    token_id_public: pub Field
) {
    // Constraint 1: Verify that the private token_id matches the public token_id
    // This ensures the commitment corresponds to the correct NFT
    assert(token_id == token_id_public, "Token ID mismatch");
    
    // Constraint 2: Compute the commitment WITH recipient_pub_key
    // SECURITY FIX: commitment = Poseidon(secret, token_id, recipient_pub_key)
    let commitment_inputs: [Field; 3] = [secret, token_id, recipient_pub_key];
    let computed_commitment = Poseidon2::hash(
        commitment_inputs,
        commitment_inputs.len()
    );
    
    // Constraint 3: Verify the commitment matches the public input
    // This ensures the commitment is properly bound to the recipient
    assert(computed_commitment == commitment, "Invalid commitment");
}

#[test]
fn test_deposit_valid() {
    let secret = 12345;
    let token_id = 1;
    let view_key = 67890;
    
    // Compute expected commitment
    let commitment_inputs: [Field; 3] = [secret, token_id, view_key];
    let commitment = Poseidon2::hash(
        commitment_inputs,
        commitment_inputs.len()
    );
    
    // Should pass with valid inputs
    main(secret, token_id, view_key, commitment, token_id);
}

#[test(should_fail)]
fn test_deposit_wrong_commitment() {
    let secret = 12345;
    let token_id = 1;
    let view_key = 67890;
    
    // Use wrong commitment
    let wrong_commitment = 99999;
    
    // Should fail because commitment doesn't match
    main(secret, token_id, view_key, wrong_commitment, token_id);
}

#[test(should_fail)]
fn test_deposit_token_id_mismatch() {
    let secret = 12345;
    let token_id = 1;
    let view_key = 67890;
    
    let commitment_inputs: [Field; 3] = [secret, token_id, view_key];
    let commitment = Poseidon2::hash(
        commitment_inputs,
        commitment_inputs.len()
    );
    
    // Use wrong public token_id
    let wrong_token_id = 2;
    
    // Should fail because token IDs don't match
    main(secret, token_id, view_key, commitment, wrong_token_id);
}

