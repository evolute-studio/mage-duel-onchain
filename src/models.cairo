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

#[derive(Serde, Drop, Introspect, PartialEq, Debug, Clone)]
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
    // CCRF,
// CCFR,
// CFRF,
// CRRF,
// CRFF,
// FFCR,
// FFRF,
// FRRF,
// FFCC,
// RRFF,
}

#[derive(Serde, Clone, Drop, Introspect, Debug)]
pub struct TileStruct {
    pub tile: Tile,
    pub edges: Array<TEdge>,
}

impl TileIntoTileStruct of Into<Tile, TileStruct> {
    fn into(self: Tile) -> TileStruct {
        match self {
            Tile::CCCC => TileStruct {
                tile: Tile::CCCC,
                edges: array![TEdge::C, TEdge::C, TEdge::C, TEdge::C],
            },
            Tile::FFFF => TileStruct {
                tile: Tile::FFFF,
                edges: array![TEdge::F, TEdge::F, TEdge::F, TEdge::F],
            },
            Tile::RRRR => TileStruct {
                tile: Tile::RRRR,
                edges: array![TEdge::R, TEdge::R, TEdge::R, TEdge::R],
            },
            Tile::CCCF => TileStruct {
                tile: Tile::CCCF,
                edges: array![TEdge::C, TEdge::C, TEdge::C, TEdge::F],
            },
            Tile::CCCR => TileStruct {
                tile: Tile::CCCR,
                edges: array![TEdge::C, TEdge::C, TEdge::C, TEdge::R],
            },
            Tile::CFFF => TileStruct {
                tile: Tile::CFFF,
                edges: array![TEdge::C, TEdge::F, TEdge::F, TEdge::F],
            },
            Tile::FFFR => TileStruct {
                tile: Tile::FFFR,
                edges: array![TEdge::F, TEdge::F, TEdge::F, TEdge::R],
            },
            Tile::CRRR => TileStruct {
                tile: Tile::CRRR,
                edges: array![TEdge::C, TEdge::R, TEdge::R, TEdge::R],
            },
            Tile::FRRR => TileStruct {
                tile: Tile::FRRR,
                edges: array![TEdge::F, TEdge::R, TEdge::R, TEdge::R],
            },
            Tile::CCFF => TileStruct {
                tile: Tile::CCFF,
                edges: array![TEdge::C, TEdge::C, TEdge::F, TEdge::F],
            },
            Tile::CFCF => TileStruct {
                tile: Tile::CFCF,
                edges: array![TEdge::C, TEdge::F, TEdge::C, TEdge::F],
            },
            Tile::CCRR => TileStruct {
                tile: Tile::CCRR,
                edges: array![TEdge::C, TEdge::C, TEdge::R, TEdge::R],
            },
            Tile::CRCR => TileStruct {
                tile: Tile::CRCR,
                edges: array![TEdge::C, TEdge::R, TEdge::C, TEdge::R],
            },
            Tile::FFRR => TileStruct {
                tile: Tile::FFRR,
                edges: array![TEdge::F, TEdge::F, TEdge::R, TEdge::R],
            },
            Tile::FRFR => TileStruct {
                tile: Tile::FRFR,
                edges: array![TEdge::F, TEdge::R, TEdge::F, TEdge::R],
            },
            Tile::CCFR => TileStruct {
                tile: Tile::CCFR,
                edges: array![TEdge::C, TEdge::C, TEdge::F, TEdge::R],
            },
            Tile::CCRF => TileStruct {
                tile: Tile::CCRF,
                edges: array![TEdge::C, TEdge::C, TEdge::R, TEdge::F],
            },
            Tile::CFCR => TileStruct {
                tile: Tile::CFCR,
                edges: array![TEdge::C, TEdge::F, TEdge::C, TEdge::R],
            },
            Tile::CFFR => TileStruct {
                tile: Tile::CFFR,
                edges: array![TEdge::C, TEdge::F, TEdge::F, TEdge::R],
            },
            Tile::CFRF => TileStruct {
                tile: Tile::CFRF,
                edges: array![TEdge::C, TEdge::F, TEdge::R, TEdge::F],
            },
            Tile::CRFF => TileStruct {
                tile: Tile::CRFF,
                edges: array![TEdge::C, TEdge::R, TEdge::F, TEdge::F],
            },
            Tile::CRRF => TileStruct {
                tile: Tile::CRRF,
                edges: array![TEdge::C, TEdge::R, TEdge::R, TEdge::F],
            },
            Tile::CRFR => TileStruct {
                tile: Tile::CRFR,
                edges: array![TEdge::C, TEdge::R, TEdge::F, TEdge::R],
            },
            Tile::CFRR => TileStruct {
                tile: Tile::CFRR,
                edges: array![TEdge::C, TEdge::F, TEdge::R, TEdge::R],
            },
        }
    }
}

impl TileStructIntoTile of Into<TileStruct, Tile> {
    fn into(self: TileStruct) -> Tile {
        self.tile
    }
}

#[derive(Copy, Drop, Serde, Debug, Introspect, PartialEq)]
pub enum GameState {
    InProgress,
    Finished,
}

//impl Partial


#[derive(Drop, Serde, Debug, Clone)]
#[dojo::model]
pub struct Board {
    #[key]
    pub id: felt252,
    pub initial_state: Array<TEdge>,
    pub random_deck: Array<Tile>,
    pub tiles: Array<TileStruct>,
    pub player1: ContractAddress,
    pub player2: ContractAddress,
    pub last_move_id: Option<felt252>,
    pub state: GameState,
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

#[derive(Drop, Serde, Debug)]
#[dojo::model]
pub struct Rules {
    #[key]
    pub id: felt252,
    pub deck: Array<u8>,
    pub edges: (u8, u8),
    pub joker_number: u8,
}
// #[derive(Copy, Drop, Serde, Debug)]
// #[dojo::model]
// pub struct Moves {
//     #[key]
//     pub player: ContractAddress,
//     pub remaining: u8,
//     pub last_direction: Option<Direction>,
//     pub can_move: bool,
// }

// #[derive(Drop, Serde, Debug)]
// #[dojo::model]
// pub struct DirectionsAvailable {
//     #[key]
//     pub player: ContractAddress,
//     pub directions: Array<Direction>,
// }

// #[derive(Copy, Drop, Serde, Debug)]
// #[dojo::model]
// pub struct Position {
//     #[key]
//     pub player: ContractAddress,
//     pub vec: Vec2,
// }

// #[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug)]
// pub enum Direction {
//     Left,
//     Right,
//     Up,
//     Down,
// }

// #[derive(Copy, Drop, Serde, IntrospectPacked, Debug)]
// pub struct Vec2 {
//     pub x: u32,
//     pub y: u32,
// }

// impl DirectionIntoFelt252 of Into<Direction, felt252> {
//     fn into(self: Direction) -> felt252 {
//         match self {
//             Direction::Left => 1,
//             Direction::Right => 2,
//             Direction::Up => 3,
//             Direction::Down => 4,
//         }
//     }
// }

// impl OptionDirectionIntoFelt252 of Into<Option<Direction>, felt252> {
//     fn into(self: Option<Direction>) -> felt252 {
//         match self {
//             Option::None => 0,
//             Option::Some(d) => d.into(),
//         }
//     }
// }

// #[generate_trait]
// impl Vec2Impl of Vec2Trait {
//     fn is_zero(self: Vec2) -> bool {
//         if self.x - self.y == 0 {
//             return true;
//         }
//         false
//     }

//     fn is_equal(self: Vec2, b: Vec2) -> bool {
//         self.x == b.x && self.y == b.y
//     }
// }

// #[cfg(test)]
// mod tests {
//     use super::{Vec2, Vec2Trait};

//     #[test]
//     fn test_vec_is_zero() {
//         assert(Vec2Trait::is_zero(Vec2 { x: 0, y: 0 }), 'not zero');
//     }

//     #[test]
//     fn test_vec_is_equal() {
//         let position = Vec2 { x: 420, y: 0 };
//         assert(position.is_equal(Vec2 { x: 420, y: 0 }), 'not equal');
//     }
// }


