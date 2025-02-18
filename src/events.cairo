use starknet::ContractAddress;
use evolute_duel::models::{TEdge, Tile, GameState, GameStatus};

#[derive(Drop, Serde, Debug)]
#[dojo::event]
pub struct BoardCreated {
    #[key]
    pub board_id: felt252,
    pub initial_state: Array<TEdge>,
    pub random_deck: Array<Tile>,
    pub state: Array<Option<Tile>>,
    pub player1: ContractAddress,
    pub player2: ContractAddress,
    pub last_move_id: Option<felt252>,
    pub game_state: GameState,
}

#[derive(Drop, Serde)]
#[dojo::event]
pub struct RulesCreated {
    #[key]
    pub rules_id: felt252,
    // pub deck: Array<(Tile, u8)>,
    pub edges: (u8, u8),
    pub joker_number: u8,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::event]
pub struct Moved {
    #[key]
    pub move_id: felt252,
    pub player: ContractAddress,
    pub prev_move_id: felt252,
    pub tile: Option<Tile>,
    pub rotation: Option<u8>,
    pub is_joker: bool,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::event]
pub struct InvalidMove {
    #[key]
    pub move_id: felt252,
    pub player: ContractAddress,
}


#[derive(Copy, Drop, Serde, Debug)]
#[dojo::event]
pub struct GameFinished {
    #[key]
    pub host_player: ContractAddress,
    pub board_id: felt252,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::event]
pub struct GameStarted {
    #[key]
    pub host_player: ContractAddress,
    pub guest_player: ContractAddress,
    pub board_id: felt252,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::event]
pub struct GameCreated {
    #[key]
    pub host_player: ContractAddress,
    pub status: GameStatus,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::event]
pub struct GameCreateFailed {
    #[key]
    pub host_player: ContractAddress,
    pub status: GameStatus,
}


#[derive(Copy, Drop, Serde, Debug)]
#[dojo::event]
pub struct GameJoinFailed {
    #[key]
    pub host_player: ContractAddress,
    pub guest_player: ContractAddress,
    pub status: GameStatus,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::event]
pub struct GameCanceled {
    #[key]
    pub host_player: ContractAddress,
    pub status: GameStatus,
}
