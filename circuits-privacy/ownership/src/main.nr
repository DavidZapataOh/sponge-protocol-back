// Ownership circuit: prove control of an existing NFT commitment bound to a metadata hash

use poseidon::poseidon2::Poseidon2;

fn main(
    // Private inputs
    secret: Field,
    token_id: Field,
    owner_pub_key: Field,
    metadata_hash_private: Field,
    merkle_proof: [Field; 20],
    leaf_index: Field,

    // Public inputs
    root: pub Field,
    nullifier: pub Field,
    metadata_hash: pub Field,
) {
    // Ensure metadata hash matches public value
    assert(metadata_hash_private == metadata_hash, "Metadata hash mismatch");

    // Recompute commitment from private note data
    let commitment_inputs: [Field; 3] = [secret, token_id, owner_pub_key];
    let commitment = Poseidon2::hash(commitment_inputs, commitment_inputs.len());

    // Verify commitment is included in the Merkle tree under the provided root
    let computed_root = compute_merkle_root(commitment, merkle_proof, leaf_index);
    assert(computed_root == root, "Invalid Merkle proof");

    // Recompute nullifier to prevent double spending
    let nullifier_inputs: [Field; 4] = [secret, token_id, owner_pub_key, 1];
    let computed_nullifier = Poseidon2::hash(nullifier_inputs, nullifier_inputs.len());
    assert(computed_nullifier == nullifier, "Invalid nullifier");
}

fn compute_merkle_root(
    leaf: Field,
    proof: [Field; 20],
    index: Field,
) -> Field {
    let mut current_hash = leaf;
    let mut current_index = index;

    for i in 0..20 {
        let sibling = proof[i];
        let index_as_u32 = current_index as u32;
        let is_left = (index_as_u32 % 2) == 0;

        let hash_inputs: [Field; 2] = if is_left {
            [current_hash, sibling]
        } else {
            [sibling, current_hash]
        };

        current_hash = Poseidon2::hash(hash_inputs, hash_inputs.len());
        current_index = (index_as_u32 / 2) as Field;
    }

    current_hash
}
