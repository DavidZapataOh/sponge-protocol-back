pub struct IPNftData {
    pub nft_owner: Field,
    pub nft_token_id: Field,
    pub nft_metadata_cid: str<46>,  // IPFS CID, which is not hashed yet. (i.e. "QmYwAPJzv5CZsnAzt8auVZRn5W4mBkpLsD4HaBFN6r5y6F")
    //nft_metadata_hash: Field  // IPFS CID, which is hashed (IPFS CID for the metadata of NFT, which is generated when uploading to IPFS)}
}

pub struct RevealedData {
    pub nullifier: Field,
    pub nft_metadata_cid_hash: Field,
}

// Privacy-related data structures for anonymous transfers

pub struct PrivateNote {
    pub secret: Field,
    pub token_id: Field,
    pub view_key: Field,
}

pub struct StealthAddressData {
    pub view_key_public: Field,
    pub ephemeral_public: Field,
}

pub struct DepositOutput {
    pub commitment: Field,
}

pub struct TransferOutput {
    pub nullifier: Field,
    pub new_commitment: Field,
}

pub struct WithdrawOutput {
    pub nullifier: Field,
    pub token_id: Field,
}