use poseidon::poseidon2::Poseidon2;

fn main(secret: Field, token_id: Field, recipient: Field) -> pub Field {
    let inputs: [Field; 3] = [secret, token_id, recipient];
    Poseidon2::hash(inputs, inputs.len())
}
