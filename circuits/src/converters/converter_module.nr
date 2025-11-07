//mod test_inputs; // test_inputs.nr
use std::hash::poseidon2;


/** 
 * @notice - Test: Convert IPFS CID (sha256) -> bytes -> Field -> Poseidon2 Hash
 */
pub fn convert_nft_metadata_cid_to_poseidon_hash(metadata_cid: str<46>) -> Field {
    let metadata_cid: str<46> = metadata_cid;
    println(metadata_cid);

    let metadata_cid_bytes: [u8; 46] = metadata_cid.as_bytes();
    println(metadata_cid_bytes);

    let metadata_cid_field = Field::from_be_bytes::<46>(metadata_cid_bytes);
    println(metadata_cid_field);

    let inputs_for_metadata_cid_field: [Field; 1] = [metadata_cid_field];
    let metadata_cid_hash = poseidon2::Poseidon2::hash(inputs_for_metadata_cid_field, inputs_for_metadata_cid_field.len());
    println(metadata_cid_hash);

    metadata_cid_hash
}
