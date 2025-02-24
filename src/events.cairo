use starknet::ContractAddress;
use evolute_duel::packing::{GameState, GameStatus, PlayerSide};

#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct BoardCreated {
    #[key]
    pub board_id: felt252,
    pub initial_edge_state: Array<u8>,
    pub top_tile: Option<u8>,
    pub state: Array<(u8, u8, u8)>,
    //(address, side, joker_number)
    pub player1: (ContractAddress, PlayerSide, u8),
    //(address, side, joker_number)
    pub player2: (ContractAddress, PlayerSide, u8),
    pub last_move_id: Option<felt252>,
    pub game_state: GameState,
}

#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct BoardCreatedFromSnapshot {
    #[key]
    pub board_id: felt252,
    pub old_board_id: felt252,
    pub move_number: u8,
    pub initial_edge_state: Array<u8>,
    pub available_tiles_in_deck: Array<u8>,
    pub top_tile: Option<u8>,
    pub state: Array<(u8, u8, u8)>,
    //(address, side, joker_number)
    pub player1: (ContractAddress, PlayerSide, u8),
    //(address, side, joker_number)
    pub player2: (ContractAddress, PlayerSide, u8),
    pub last_move_id: Option<felt252>,
    pub game_state: GameState,
}

#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct BoardCreateFromSnapshotFalied {
    #[key]
    pub player: ContractAddress,
    pub old_board_id: felt252,
    pub move_number: u8,
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
    pub available_tiles_in_deck: Array<u8>,
    pub top_tile: Option<u8>,
    pub state: Array<(u8, u8, u8)>,
    //(address, side, joker_number)
    pub player1: (ContractAddress, PlayerSide, u8),
    //(address, side, joker_number)
    pub player2: (ContractAddress, PlayerSide, u8),
    pub last_move_id: Option<felt252>,
    pub first_move_id: Option<felt252>,
    pub game_state: GameState,
}

#[derive(Drop, Serde, Introspect)]
#[dojo::event]
pub struct RulesCreated {
    #[key]
    pub rules_id: felt252,
    // pub deck: Array<(Tile, u8)>,
    pub edges: (u8, u8),
    pub joker_number: u8,
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
}

#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct Skiped {
    #[key]
    pub move_id: felt252,
    pub player: ContractAddress,
    pub prev_move_id: Option<felt252>,
    pub board_id: felt252,
}


#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct InvalidMove {
    #[key]
    pub move_id: felt252,
    pub player: ContractAddress,
}


#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct GameFinished {
    #[key]
    pub host_player: ContractAddress,
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


#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct GameIsAlreadyFinished {
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
    pub root: u8,
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
    pub root: u8,
    pub red_points: u16,
    pub blue_points: u16,
}

#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct RoadContestWon {
    #[key]
    pub board_id: felt252,
    #[key]
    pub root: u8,
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
    pub root: u8,
    pub red_points: u16,
    pub blue_points: u16,
}

// --------------------------------------
// Player Profile Events
// --------------------------------------

#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct CurrentPlayerBalance {
    #[key]
    pub player_id: ContractAddress,
    pub balance: u16,
}

#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct CurrentPlayerUsername {
    #[key]
    pub player_id: ContractAddress,
    pub username: felt252,
}

#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct CurrentPlayerActiveSkin {
    #[key]
    pub player_id: ContractAddress,
    pub active_skin: u8,
}

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
    pub skin_price: u16,
    pub balance: u16,
}
