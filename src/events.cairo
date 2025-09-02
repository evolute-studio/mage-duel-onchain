use starknet::ContractAddress;
use evolute_duel::types::packing::{GameState, GameStatus, PlayerSide};

#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::event(historical = true)]
pub struct ErrorEvent {
    #[key]
    pub player_address: ContractAddress,
    pub name: felt252,
    pub message: ByteArray,
}

#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct SnapshotCreated {
    #[key]
    pub snapshot_id: felt252,
    pub player: ContractAddress,
    pub board_id: felt252,
    pub move_number: u8,
}

#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct SnapshotCreateFailed {
    #[key]
    pub player: ContractAddress,
    pub board_id: felt252,
    pub board_game_state: GameState,
    pub move_number: u8,
}

#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct BoardUpdated {
    #[key]
    pub board_id: felt252,
    pub top_tile: Option<u8>,
    //(address, side, joker_number)
    pub player1: (ContractAddress, PlayerSide, u8),
    //(address, side, joker_number)
    pub player2: (ContractAddress, PlayerSide, u8),
    // (u16, u16) => (city_score, road_score)
    pub blue_score: (u16, u16),
    // (u16, u16) => (city_score, road_score)
    pub red_score: (u16, u16),
    pub last_move_id: Option<felt252>,
    pub moves_done: u8,
    pub game_state: GameState,
}

#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct Moved {
    #[key]
    pub move_id: felt252,
    pub player: ContractAddress,
    pub prev_move_id: Option<felt252>,
    pub tile: Option<u8>,
    pub rotation: u8,
    pub col: u8,
    pub row: u8,
    pub is_joker: bool,
    pub board_id: felt252,
    pub timestamp: u64,
}

#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct Skiped {
    #[key]
    pub move_id: felt252,
    pub player: ContractAddress,
    pub prev_move_id: Option<felt252>,
    pub board_id: felt252,
    pub timestamp: u64,
}


#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct InvalidMove {
    #[key]
    pub player: ContractAddress,
    pub prev_move_id: Option<felt252>,
    pub tile: Option<u8>,
    pub rotation: u8,
    pub col: u8,
    pub row: u8,
    pub is_joker: bool,
    pub board_id: felt252,
}


#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct GameFinished {
    #[key]
    pub player: ContractAddress,
    pub board_id: felt252,
}

#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct GameStarted {
    #[key]
    pub host_player: ContractAddress,
    pub guest_player: ContractAddress,
    pub board_id: felt252,
}

#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct GameCreated {
    #[key]
    pub host_player: ContractAddress,
    pub status: GameStatus,
}


#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct GameCreateFailed {
    #[key]
    pub host_player: ContractAddress,
    pub status: GameStatus,
}


#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct GameJoinFailed {
    #[key]
    pub host_player: ContractAddress,
    pub guest_player: ContractAddress,
    pub host_game_status: GameStatus,
    pub guest_game_status: GameStatus,
}

#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct GameCanceled {
    #[key]
    pub host_player: ContractAddress,
    pub status: GameStatus,
}

#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct GameCanceleFailed {
    #[key]
    pub host_player: ContractAddress,
    pub status: GameStatus,
}

#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct PlayerNotInGame {
    #[key]
    pub player_id: ContractAddress,
    pub board_id: felt252,
}

#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct NotYourTurn {
    #[key]
    pub player_id: ContractAddress,
    pub board_id: felt252,
}

#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct NotEnoughJokers {
    #[key]
    pub player_id: ContractAddress,
    pub board_id: felt252,
}

// --------------------------------------
// Contest Events
// --------------------------------------
#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct CityContestWon {
    #[key]
    pub board_id: felt252,
    #[key]
    pub root: u32,
    pub winner: PlayerSide,
    pub red_points: u16,
    pub blue_points: u16,
}

#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct CityContestDraw {
    #[key]
    pub board_id: felt252,
    #[key]
    pub root: u32,
    pub red_points: u16,
    pub blue_points: u16,
}

#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct RoadContestWon {
    #[key]
    pub board_id: felt252,
    #[key]
    pub root: u32,
    pub winner: PlayerSide,
    pub red_points: u16,
    pub blue_points: u16,
}

#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct RoadContestDraw {
    #[key]
    pub board_id: felt252,
    #[key]
    pub root: u32,
    pub red_points: u16,
    pub blue_points: u16,
}

// --------------------------------------
// Player Profile Events
// --------------------------------------

#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct PlayerUsernameChanged {
    #[key]
    pub player_id: ContractAddress,
    pub new_username: felt252,
}

#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct PlayerSkinChanged {
    #[key]
    pub player_id: ContractAddress,
    pub new_skin: u8,
}


#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct PlayerSkinChangeFailed {
    #[key]
    pub player_id: ContractAddress,
    pub new_skin: u8,
    pub skin_price: u32,
    pub balance: u32,
}


#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct PhaseStarted {
    #[key]
    pub board_id: felt252,
    pub phase: u8, // 0 - creating, 1 - reveal, 2 -request, 3 - move
    pub top_tile: Option<u8>,
    pub commited_tile: Option<u8>,
    pub started_at: u64,
}

// --------------------------------------
// Migration Events
// --------------------------------------

#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct MigrationError {
    #[key]
    pub guest_address: ContractAddress,
    #[key]
    pub controller_address: ContractAddress,
    pub status: felt252, // 'Success' or 'Error'
    pub error_context: ByteArray, // Details about guest/controller roles
    pub error_message: ByteArray, // The error message from the failed assert
}

#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct MigrationInitiated {
    #[key]
    pub guest_address: ContractAddress,
    #[key]
    pub controller_address: ContractAddress,
    pub expires_at: u64,
}

#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct MigrationConfirmed {
    #[key]
    pub guest_address: ContractAddress,
    #[key]
    pub controller_address: ContractAddress,
    pub confirmed_at: u64,
}

#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct MigrationCompleted {
    #[key]
    pub guest_address: ContractAddress,
    #[key]
    pub controller_address: ContractAddress,
    pub balance_transferred: u32,
    pub games_transferred: felt252,
}

#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct MigrationCancelled {
    #[key]
    pub guest_address: ContractAddress,
    #[key]
    pub controller_address: ContractAddress,
    pub cancelled_at: u64,
}

#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct EmergencyMigrationCancelled {
    #[key]
    pub guest_address: ContractAddress,
    #[key]
    pub admin_address: ContractAddress,
    pub reason: ByteArray,
}

#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct TutorialCompleted {
    #[key]
    pub player_id: ContractAddress,
    pub completed_at: u64,
}

#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct GameFinishResult {
    #[key]
    pub board_id: felt252,
    pub tournament_id: u64,
    pub first_player_id: ContractAddress,
    pub first_player_rating: u32,
    pub first_player_rating_delta: i32, // может быть отрицательным
    pub second_player_id: ContractAddress, 
    pub second_player_rating: u32,
    pub second_player_rating_delta: i32, // может быть отрицательным
    pub winner: Option<u8>, // 1 если first_player выиграл, 2 если second_player, None для ничьи
}
