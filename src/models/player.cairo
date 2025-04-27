use starknet::{ContractAddress};

/// Represents a player profile, tracking in-game identity and statistics.
///
/// - `player_id`: Unique identifier for the player.
/// - `username`: Player's chosen in-game name.
/// - `balance`: Current balance of in-game currency or points.
/// - `games_played`: Total number of games played by the player.
/// - `active_skin`: The currently equipped skin or avatar.
#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::model]
pub struct Player {
    #[key]
    pub player_id: ContractAddress,
    pub username: felt252,
    pub balance: u16,
    pub games_played: felt252,
    pub active_skin: u8,
    pub is_bot: bool,
}

/// Represents a shop where players can purchase in-game items.
///
/// - `shop_id`: Unique identifier for the shop.
/// - `skin_prices`: List of prices for different skins available in the shop.
#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::model]
pub struct Shop {
    #[key]
    pub shop_id: felt252,
    pub skin_prices: Array<u16>,
}