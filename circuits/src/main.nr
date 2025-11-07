mod tests;      // tests/mod.nr
mod data_types; // data_types.nr
mod converters; // converters.nr 

use std::hash::poseidon2;
use data_types::{ IPNftData, RevealedData }; // @dev - IPNftData struct


fn main(
    root: pub Field,
    hash_path: [Field; 2],
    index: Field,
    secret: Field,
    expected_nullifier: Field,
    expected_nft_metadata_cid_hash: Field,
    ip_nft_data: IPNftData
//) -> pub Field {
) -> pub RevealedData {
    let nft_metadata_cid_hash: Field = converters::converter_module::convert_nft_metadata_cid_to_poseidon_hash(ip_nft_data.nft_metadata_cid);
    println(nft_metadata_cid_hash); 

    // Constraint: nft_metadata_cid_hash == expected_nft_metadata_hash
    assert(nft_metadata_cid_hash == expected_nft_metadata_cid_hash);

    println(expected_nullifier);

    let inputs_for_note_commitment: [Field; 1] = [secret];
    let note_commitment = poseidon2::Poseidon2::hash(inputs_for_note_commitment, inputs_for_note_commitment.len());

    //let inputs_for_nullifier: [Field; 1] = [ip_nft_data.nft_token_id];
    let inputs_for_nullifier: [Field; 5] = [root, secret, ip_nft_data.nft_owner, ip_nft_data.nft_token_id, expected_nft_metadata_cid_hash];
    let nullifier = poseidon2::Poseidon2::hash(inputs_for_nullifier, inputs_for_nullifier.len());
    println(nullifier);
    assert(nullifier == expected_nullifier);

    RevealedData {
        nullifier,
        nft_metadata_cid_hash,
    }
}