use starknet::{ContractAddress};

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug)]
pub enum TEdge {
    C,
    R,
    M,
}

impl TEdgeIntoFelt252 of Into<TEdge, felt252> {
    fn into(self: TEdge) -> felt252 {
        match self {
            TEdge::C => 0,
            TEdge::R => 1,
            TEdge::M => 2,
        }
    }
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug)]
pub enum Tile {
    CCRF,
    CCFR,
    CFRF,
    CRRF,
    CRFF,
    FFCR,
    FFRF,
    FRRF,
    FFCC,
    RRFF,
}

impl TileIntoFelt252 of Into<Tile, felt252> {
    fn into(self: Tile) -> felt252 {
        match self {
            //TODO let's convert to u8? it's only 24 values. Shouldn't enum be converted
            //automatically to 0,1,2...?
            Tile::CCRF => 0,
            Tile::CCFR => 1,
            Tile::CFRF => 2,
            Tile::CRRF => 3,
            Tile::CRFF => 4,
            Tile::FFCR => 5,
            Tile::FFRF => 6,
            Tile::FRRF => 7,
            Tile::FFCC => 8,
            Tile::RRFF => 9,
        }
    }
}

#[derive(Copy, Drop, Serde, Debug, Introspect)]
pub enum GameState {
    InProgress,
    Finished,
}


#[derive(Drop, Serde, Debug)]
#[dojo::model]
pub struct Board {
    #[key]
    pub id: felt252,
    pub initial_state: Array<TEdge>,
    pub random_deck: Array<Tile>,
    pub tiles: Array<Option<Tile>>,
    pub player1: ContractAddress,
    pub player2: ContractAddress,
    pub last_move_id: felt252,
    pub state: GameState,
}

#[derive(Copy, Drop, Serde, Debug)]
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


