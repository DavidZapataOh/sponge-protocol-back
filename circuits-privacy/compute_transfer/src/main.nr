use poseidon::poseidon2::Poseidon2;

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

fn main(
    old_secret: Field,
    token_id: Field,
    old_pub_key: Field,
    proof: [Field; 20],
    leaf_index: Field,
    new_secret: Field,
    new_pub_key: Field,
) -> pub [Field; 3] {
    let old_commitment_inputs: [Field; 3] = [old_secret, token_id, old_pub_key];
    let old_commitment = Poseidon2::hash(old_commitment_inputs, old_commitment_inputs.len());

    let nullifier_inputs: [Field; 4] = [old_secret, token_id, old_pub_key, 1];
    let nullifier = Poseidon2::hash(nullifier_inputs, nullifier_inputs.len());

    let new_commitment_inputs: [Field; 3] = [new_secret, token_id, new_pub_key];
    let new_commitment = Poseidon2::hash(new_commitment_inputs, new_commitment_inputs.len());

    let root = compute_merkle_root(old_commitment, proof, leaf_index);

    [root, nullifier, new_commitment]
}
