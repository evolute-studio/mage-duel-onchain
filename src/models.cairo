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

impl U8ToTileImpl of Into<u8, Tile> {
    fn into(self: u8) -> Tile {
        match self {
            0 => Tile::CCCC,
            1 => Tile::FFFF,
            2 => Tile::RRRR,
            3 => Tile::CCCF,
            4 => Tile::CCCR,
            5 => Tile::CCRR,
            6 => Tile::CFFF,
            7 => Tile::FFFR,
            8 => Tile::CRRR,
            9 => Tile::FRRR,
            10 => Tile::CCFF,
            11 => Tile::CFCF,
            12 => Tile::CRCR,
            13 => Tile::FFRR,
            14 => Tile::FRFR,
            15 => Tile::CCFR,
            16 => Tile::CCRF,
            17 => Tile::CFCR,
            18 => Tile::CFFR,
            19 => Tile::CFRF,
            20 => Tile::CRFF,
            21 => Tile::CRRF,
            22 => Tile::CRFR,
            23 => Tile::CFRR,
            _ => panic!("Unsupported Tile"),
        }
    }
}

impl TileToU8 of Into<Tile, u8> {
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


#[derive(Drop, Serde, Debug, Introspect, Clone)]
#[dojo::model]
pub struct Board {
    #[key]
    pub id: felt252,
    pub initial_edge_state: Array<TEdge>,
    pub available_tiles_in_deck: Array<Tile>,
    pub state: Array<Option<Tile>>,
    pub player1: ContractAddress,
    pub player2: ContractAddress,
    pub last_move_id: Option<felt252>,
    pub game_state: GameState,
}

#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::model]
pub struct Move {
    #[key]
    pub id: felt252,
    // pub player: ContractAddress,
    // pub prev_move_id: felt252,
    pub tile: Option<Tile>,
    // pub rotation: Option<u8>,
// pub is_joker: bool,
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
}
// impl PointSerde of Serde<[u8; 24]> {
//     fn serialize(self: @[u8; 24], ref output: Array<felt252>) {
//         for el in self.span() {
//             let felt_el: felt252 = (*el).into();
//             output.append(felt_el);
//         };
//     }

//     fn deserialize(ref serialized: Span<felt252>) -> Option<[u8; 24]> {
//         let mut output: [u8; 24] = [0; 24];

//         for mut el in output.span() {
//             let converted: u8 = (*serialized.pop_front().unwrap()).try_into().unwrap();
//             el = @converted;
//         };

//         Option::Some(output)
//     }
// }


