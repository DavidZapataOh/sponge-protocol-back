// Withdraw Circuit: Unshield an NFT from the privacy pool
// This circuit proves ownership of a commitment and allows withdrawal to a public address

use poseidon::poseidon2::Poseidon2;

/**
 * @notice Withdraw circuit for unshielding NFTs
 * @dev SECURITY FIX: Commitment bound to public key
 * @dev Proves:
 *   1. The owner controls a valid commitment in the Merkle tree
 *   2. Generates a nullifier to mark the note as spent
 *   3. Reveals the token_id and recipient address
 * 
 * Private inputs:
 * - secret: Owner's secret
 * - owner_pub_key: Owner's public key (binds commitment)
 * - merkle_proof: Sibling path in the Merkle tree (20 levels)
 * - leaf_index: Position of the commitment in the tree
 * 
 * Public inputs:
 * - root: The Merkle root containing the commitment
 * - nullifier: Unique identifier to prevent double-spending
 * - token_id: The NFT token ID being withdrawn (revealed)
 * - recipient: The public address to receive the NFT (revealed)
 * 
 * SECURITY: Commitment is bound to owner_pub_key
 */
fn main(
    // Private inputs
    secret: Field,
    token_id: Field,
    owner_pub_key: Field,  // SECURITY FIX: Bind to owner
    merkle_proof: [Field; 20],
    leaf_index: Field,
    
    // Public inputs
    root: pub Field,
    nullifier: pub Field,
    token_id_public: pub Field,
    recipient: pub Field
) {
    // Step 1: Verify token_id matches public token_id
    assert(token_id == token_id_public, "Token ID mismatch");
    
    // Step 2: Compute the commitment WITH owner's public key
    // SECURITY FIX: commitment = Hash(secret, token_id, owner_pub_key)
    let commitment_inputs: [Field; 3] = [secret, token_id, owner_pub_key];
    let commitment = Poseidon2::hash(
        commitment_inputs,
        commitment_inputs.len()
    );
    
    // Step 3: Verify the commitment exists in the Merkle tree
    let computed_root = compute_merkle_root(commitment, merkle_proof, leaf_index);
    assert(computed_root == root, "Invalid Merkle proof");
    
    // Step 4: Compute and verify the nullifier
    // SECURITY FIX: nullifier = Hash(secret, token_id, owner_pub_key, "nullify")
    let nullifier_constant = 1; // Same constant as in transfer circuit
    let nullifier_inputs: [Field; 4] = [secret, token_id, owner_pub_key, nullifier_constant];
    let computed_nullifier = Poseidon2::hash(
        nullifier_inputs,
        nullifier_inputs.len()
    );
    assert(computed_nullifier == nullifier, "Invalid nullifier");
    
    // Step 5: No need to verify recipient - it's a public input
    // The contract will transfer the NFT to the recipient address
    // We just need to prove we own the commitment bound to owner_pub_key
}

/**
 * @notice Compute Merkle root from leaf and proof
 * @param leaf The leaf commitment
 * @param proof Sibling hashes along the path (20 levels)
 * @param index The leaf index
 * @return The computed Merkle root
 */
fn compute_merkle_root(
    leaf: Field,
    proof: [Field; 20],
    index: Field
) -> Field {
    let mut current_hash = leaf;
    let mut current_index = index;
    
    // Traverse up the tree, hashing with siblings
    for i in 0..20 {
        let sibling = proof[i];
        
        // Determine if current node is left or right child
        let is_left = (current_index % 2) == 0;
        
        // Hash with sibling in correct order
        let hash_inputs: [Field; 2] = if is_left {
            [current_hash, sibling]
        } else {
            [sibling, current_hash]
        };
        
        current_hash = Poseidon2::hash(hash_inputs, hash_inputs.len());
        
        // Move to parent node
        current_index = current_index / 2;
    }
    
    current_hash
}

#[test]
fn test_withdraw_valid() {
    // Setup owner's note
    let secret = 12345;
    let token_id = 1;
    let view_key = 67890;
    let recipient = 0x1234567890abcdef;
    
    // Compute commitment
    let commitment_inputs: [Field; 3] = [secret, token_id, view_key];
    let commitment = Poseidon2::hash(
        commitment_inputs,
        commitment_inputs.len()
    );
    
    // Create Merkle proof (all zeros for this test)
    let merkle_proof: [Field; 20] = [0; 20];
    let leaf_index = 0;
    
    // Compute root
    let root = compute_merkle_root(commitment, merkle_proof, leaf_index);
    
    // Compute nullifier
    let nullifier_constant = 1;
    let nullifier_inputs: [Field; 4] = [secret, token_id, view_key, nullifier_constant];
    let nullifier = Poseidon2::hash(
        nullifier_inputs,
        nullifier_inputs.len()
    );
    
    // Should pass with valid inputs
    main(
        secret,
        token_id,
        view_key,
        merkle_proof,
        leaf_index,
        root,
        nullifier,
        token_id,
        recipient
    );
}

#[test(should_fail)]
fn test_withdraw_invalid_root() {
    let secret = 12345;
    let token_id = 1;
    let view_key = 67890;
    let recipient = 0x1234567890abcdef;
    
    let commitment_inputs: [Field; 3] = [secret, token_id, view_key];
    let commitment = Poseidon2::hash(
        commitment_inputs,
        commitment_inputs.len()
    );
    
    let merkle_proof: [Field; 20] = [0; 20];
    let leaf_index = 0;
    
    // Use wrong root
    let wrong_root = 99999;
    
    let nullifier_constant = 1;
    let nullifier_inputs: [Field; 4] = [secret, token_id, view_key, nullifier_constant];
    let nullifier = Poseidon2::hash(
        nullifier_inputs,
        nullifier_inputs.len()
    );
    
    // Should fail with invalid root
    main(
        secret,
        token_id,
        view_key,
        merkle_proof,
        leaf_index,
        wrong_root,
        nullifier,
        token_id,
        recipient
    );
}

#[test(should_fail)]
fn test_withdraw_token_id_mismatch() {
    let secret = 12345;
    let token_id = 1;
    let view_key = 67890;
    let recipient = 0x1234567890abcdef;
    
    let commitment_inputs: [Field; 3] = [secret, token_id, view_key];
    let commitment = Poseidon2::hash(
        commitment_inputs,
        commitment_inputs.len()
    );
    
    let merkle_proof: [Field; 20] = [0; 20];
    let leaf_index = 0;
    let root = compute_merkle_root(commitment, merkle_proof, leaf_index);
    
    let nullifier_constant = 1;
    let nullifier_inputs: [Field; 4] = [secret, token_id, view_key, nullifier_constant];
    let nullifier = Poseidon2::hash(
        nullifier_inputs,
        nullifier_inputs.len()
    );
    
    // Use wrong public token_id
    let wrong_token_id = 2;
    
    // Should fail with token_id mismatch
    main(
        secret,
        token_id,
        view_key,
        merkle_proof,
        leaf_index,
        root,
        nullifier,
        wrong_token_id,
        recipient
    );
}

#[test(should_fail)]
fn test_withdraw_invalid_nullifier() {
    let secret = 12345;
    let token_id = 1;
    let view_key = 67890;
    let recipient = 0x1234567890abcdef;
    
    let commitment_inputs: [Field; 3] = [secret, token_id, view_key];
    let commitment = Poseidon2::hash(
        commitment_inputs,
        commitment_inputs.len()
    );
    
    let merkle_proof: [Field; 20] = [0; 20];
    let leaf_index = 0;
    let root = compute_merkle_root(commitment, merkle_proof, leaf_index);
    
    // Use wrong nullifier
    let wrong_nullifier = 88888;
    
    // Should fail with invalid nullifier
    main(
        secret,
        token_id,
        view_key,
        merkle_proof,
        leaf_index,
        root,
        wrong_nullifier,
        token_id,
        recipient
    );
}

