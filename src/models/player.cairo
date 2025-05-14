use starknet::ContractAddress;
// --------------------------------------
// Player Profile Models
// --------------------------------------

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
    pub role: u8, // 0: Guest, 1: Controller, 2: Bot
}

#[generate_trait]
pub impl PlayerImpl of PlayerTrait {
    fn is_bot(self: @Player) -> bool {
        *self.role == 2
    } 

    fn is_controller(self: @Player) -> bool {
        *self.role == 1
    }

    fn is_guest(self: @Player) -> bool {
        *self.role == 0
    }
}

