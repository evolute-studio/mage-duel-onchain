use starknet::{ContractAddress};

use core::dict::Felt252Dict;

#[derive(Serde, Drop, Introspect, PartialEq, Debug, Destruct, Clone)]
pub enum TEdge {
    C,
    R,
    M,
    F,
}

impl TEdgeIntoU8 of Into<TEdge, u8> {
    fn into(self: TEdge) -> u8 {
        match self {
            TEdge::C => 0,
            TEdge::R => 1,
            TEdge::M => 2,
            TEdge::F => 3,
        }
    }
}

impl U8IntoTEdge of Into<u8, TEdge> {
    fn into(self: u8) -> TEdge {
        match self {
            0 => TEdge::C,
            1 => TEdge::R,
            2 => TEdge::M,
            _ => TEdge::F,
        }
    }
}

#[derive(Serde, Copy, Drop, IntrospectPacked, PartialEq, Debug)]
pub enum Tile {
    CCCC,
    FFFF,
    RRRR,
    CCCF,
    CCCR,
    CFFF,
    FFFR,
    CRRR,
    FRRR,
    CCFF,
    CFCF,
    CCRR,
    CRCR,
    FFRR,
    FRFR,
    CCFR,
    CCRF,
    CFCR,
    CFFR,
    CFRF,
    CRFF,
    CRRF,
    CRFR,
    CFRR,
}

impl TilesToByte31Impl of Into<Tile, u8> {
    fn into(self: Tile) -> u8 {
        let value = match self {
            Tile::CCCC => 0,
            Tile::FFFF => 1,
            Tile::RRRR => 2,
            Tile::CCCF => 3,
            Tile::CCCR => 4,
            Tile::CCRR => 5,
            Tile::CFFF => 6,
            Tile::FFFR => 7,
            Tile::CRRR => 8,
            Tile::FRRR => 9,
            Tile::CCFF => 10,
            Tile::CFCF => 11,
            Tile::CRCR => 12,
            Tile::FFRR => 13,
            Tile::FRFR => 14,
            Tile::CCFR => 15,
            Tile::CCRF => 16,
            Tile::CFCR => 17,
            Tile::CFFR => 18,
            Tile::CFRF => 19,
            Tile::CRFF => 20,
            Tile::CRRF => 21,
            Tile::CRFR => 22,
            Tile::CFRR => 23,
        };
        value.try_into().unwrap()
    }
}

#[derive(Copy, Drop, Serde, Debug, IntrospectPacked, PartialEq)]
pub enum GameState {
    InProgress,
    Finished,
}


#[derive(Drop, Serde, Debug, Clone)]
#[dojo::model]
pub struct Board {
    #[key]
    pub id: felt252,
    pub initial_state: Array<TEdge>,
    pub random_deck: Array<Tile>,
    pub state: Array<Option<Tile>>,
    pub player1: ContractAddress,
    pub player2: ContractAddress,
    pub last_move_id: Option<felt252>,
    pub game_state: GameState,
}

#[derive(Drop, Serde, Debug)]
#[dojo::model]
pub struct Move {
    #[key]
    pub id: felt252,
    pub player: ContractAddress,
    pub prev_move_id: felt252,
    pub tile: Option<Tile>,
    pub rotation: Option<u8>,
    pub is_joker: bool,
}

#[derive(Drop, Serde)]
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
}

