use starknet::{ContractAddress};
use evolute_duel::packing::{GameState, GameStatus, PlayerSide};


#[derive(Drop, Serde, Debug, Introspect, Clone)]
#[dojo::model]
pub struct Board {
    #[key]
    pub id: felt252,
    pub initial_edge_state: Array<u8>,
    pub available_tiles_in_deck: Array<u8>,
    pub top_tile: Option<u8>,
    // (u8, u8, u8) => (tile_number, rotation, side)
    pub state: Array<(u8, u8, u8)>,
    //(address, side, joker_number)
    pub player1: (ContractAddress, PlayerSide, u8),
    //(address, side, joker_number)
    pub player2: (ContractAddress, PlayerSide, u8),
    // (u16, u16) => (city_score, road_score)
    pub blue_score: (u16, u16),
    // (u16, u16) => (city_score, road_score)
    pub red_score: (u16, u16),
    pub last_move_id: Option<felt252>,
    pub game_state: GameState,
}

#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::model]
pub struct Move {
    #[key]
    pub id: felt252,
    pub player_side: PlayerSide,
    pub prev_move_id: Option<felt252>,
    pub tile: Option<u8>,
    // 0 - if no rotation
    pub rotation: u8,
    pub col: u8,
    pub row: u8,
    pub is_joker: bool,
}

#[derive(Drop, Serde, Introspect, Debug)]
pub enum MoveTypes {
    Move,
    Skip,
}

#[derive(Drop, Introspect, Serde)]
#[dojo::model]
pub struct Rules {
    #[key]
    pub id: felt252,
    // How many tiles of each type in the deck. The index of the array is the tile type, according
    // to Tile enum.
    // 0 => CCCC
    // 1 => FFFF
    // 2 => RRRR
    pub deck: Array<u8>,
    // How many (cities, roads) at the beginning of the game for each edge
    pub edges: (u8, u8),
    // How many jokers for each player
    pub joker_number: u8,
    pub joker_price: u16,
}

#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::model]
pub struct Game {
    #[key]
    pub player: ContractAddress,
    pub status: GameStatus,
    pub board_id: Option<felt252>,
}


#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::model]
pub struct Snapshot {
    #[key]
    pub snapshot_id: felt252,
    pub player: ContractAddress,
    pub board_id: felt252,
    pub move_number: u8,
}


// --------------------------------------
// Scoring Models
// --------------------------------------

#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::model]
pub struct PotentialCityContests {
    #[key]
    pub board_id: felt252,
    pub roots: Array<u8>,
}

#[derive(Drop, Serde, IntrospectPacked, Debug)]
#[dojo::model]
pub struct CityNode {
    #[key]
    pub board_id: felt252,
    //It is a number of TEdge position in the board
    // tile pos = tedge_position / 4 {
    // col = tile_pos % 8
    // row = tile_pos / 8
    //}
    // edge diraction = tedge_position % 4
    #[key]
    pub position: u8,
    pub parent: u8,
    pub rank: u8,
    pub blue_points: u16,
    pub red_points: u16,
    pub open_edges: u8,
    pub contested: bool,
}

#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::model]
pub struct PotentialRoadContests {
    #[key]
    pub board_id: felt252,
    pub roots: Array<u8>,
}

#[derive(Drop, Serde, IntrospectPacked, Debug)]
#[dojo::model]
pub struct RoadNode {
    #[key]
    pub board_id: felt252,
    //It is a number of TEdge position in the board
    // tile pos = tedge_position / 4 {
    // col = tile_pos % 8
    // row = tile_pos / 8
    //}
    // edge diraction = tedge_position % 4
    #[key]
    pub position: u8,
    pub parent: u8,
    pub rank: u8,
    pub blue_points: u16,
    pub red_points: u16,
    pub open_edges: u8,
    pub contested: bool,
}

// --------------------------------------
// Player Profile Models
// --------------------------------------

#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::model]
pub struct Player {
    #[key]
    pub player_id: ContractAddress,
    pub username: felt252,
    pub balance: u16,
    pub games_played: felt252,
    pub active_skin: u8,
}

#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::model]
pub struct Shop {
    #[key]
    pub shop_id: felt252,
    pub skin_prices: Array<u16>,
}

