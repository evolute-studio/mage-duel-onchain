use starknet::ContractAddress;

#[derive(Drop, Serde, Copy, Introspect, PartialEq, Debug)]
#[dojo::model]
pub struct MetagamePlayerData {
    #[key]
    pub season_id: felt252, // Unique identifier for the season
    #[key]
    pub player_address: ContractAddress, // Player's address
    pub deck: Span<u8>, // Deck of tiles available to the player
    pub tiles_placed: u32, // Number of tiles placed by the player
    // pub score: u32, // Player's score (optional, can be added later)
}

#[derive(Drop, Serde, Copy, Introspect, PartialEq, Debug)]
#[dojo::model]
pub struct MetagameBoardBounds {
    #[key]
    pub season_id: felt252, // Unique identifier for the season    
    pub min_col: u32, // Minimum column index for the board
    pub max_col: u32, // Maximum column index for the board
    pub min_row: u32, // Minimum row index for the board
    pub max_row: u32, // Maximum row index for the board
    pub gap_size: u32, // Size of the gap between tiles (optional, can be added later)
}