use starknet::ContractAddress;
use dojo_starter::models::{TEdge, Tile, GameState, TileStruct};

#[derive(Drop, Serde, Debug)]
#[dojo::event]
pub struct BoardCreated {
    #[key]
    pub board_id: felt252,
    pub initial_state: Array<TEdge>,
    pub random_deck: Array<Tile>,
    pub tiles: Array<Option<TileStruct>>,
    pub player1: ContractAddress,
    pub player2: ContractAddress,
    pub last_move_id: Option<felt252>,
    pub state: GameState,
}

#[derive(Drop, Serde, Debug)]
#[dojo::event]
pub struct RulesCreated {
    #[key]
    pub rules_id: felt252,
    pub deck: Array<u8>,
    pub edges: (u8, u8),
    pub joker_number: u8,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::event]
pub struct Move {
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