pub const CREATING_TIME: u64 = 65; // 1 min
pub const REVEAL_TIME: u64 = 65; // 1 min
pub const MOVE_TIME: u64 = 65; // 1 min
pub const ETH_TO_WEI: u256 = 1_000_000_000_000_000_000;


pub mod METADATA {
    pub fn EXTERNAL_LINK() -> ByteArray {
        ("https://mageduel.evolute.network/")
    }
    // pub fn CONTRACT_IMAGE(base_uri: ByteArray) -> ByteArray {
//     format!("{}/pistols/logo.png", base_uri)
// }
// pub fn CONTRACT_BANNER_IMAGE(base_uri: ByteArray) -> ByteArray {
//     format!("{}/pistols/splash.png", base_uri)
// }
// pub fn CONTRACT_FEATURED_IMAGE(base_uri: ByteArray) -> ByteArray {
//     format!("{}/pistols/splash_og.png", base_uri)
// }

}
