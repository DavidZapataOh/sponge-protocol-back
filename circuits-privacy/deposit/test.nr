use poseidon::poseidon2::Poseidon2;

fn main() {
    let data = [1, 2, 3];
    let hash_inputs = [1, 2];
    let hash = Poseidon2::hash(hash_inputs, hash_inputs.len());
}
