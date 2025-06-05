#[derive(Serde, Drop, IntrospectPacked, PartialEq, Debug, Destruct, Copy)]
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
            3 => TEdge::F,
            _ => panic!("Unsupported TEdge"),
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
    Empty,
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
            24 => Tile::Empty,
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
            Tile::Empty => 24,
        };
        value.try_into().unwrap()
    }
}

#[derive(Copy, Drop, Serde, Debug, Introspect, PartialEq)]
pub enum GameState {
    Creating,
    Reveal,
    Move,
    Finished,
}

#[derive(Drop, Serde, Copy, IntrospectPacked, PartialEq, Debug)]
pub enum GameStatus {
    Finished,
    Created,
    Canceled,
    InProgress,
}

#[derive(Drop, Serde, Copy, IntrospectPacked, PartialEq, Debug)]
pub enum PlayerSide {
    Blue,
    Red,
}

impl PlayerSideToU8 of Into<PlayerSide, u8> {
    fn into(self: PlayerSide) -> u8 {
        match self {
            PlayerSide::Blue => 0,
            PlayerSide::Red => 1,
        }
    }
}

/// Represents a node involved in a potential contest.
///
/// - `parent`: Parent node reference for union-find structure.
/// - `rank`: Rank in the disjoint set for contest resolution.
/// - `blue_points`: Points earned by the blue player.
/// - `red_points`: Points earned by the red player.
/// - `open_edges`: Number of open edges in this city.
/// - `contested`: Boolean flag indicating if the city is contested.
#[derive(Drop, Destruct, Serde, Copy, Introspect, PartialEq, Debug)]
pub struct UnionNode {
    pub parent: u8,
    pub rank: u8,
    pub blue_points: u16,
    pub red_points: u16,
    pub open_edges: u8,
    pub contested: bool,
    pub node_type: u8, // 0: City, 1: Road, 2: None
}

impl UnionNodeDefault of  Default<UnionNode> {
    fn default() -> UnionNode {
        UnionNode {
            parent: 0,
            rank: 0,
            blue_points: 0,
            red_points: 0,
            open_edges: 0,
            contested: false,
            node_type: 2, // Default to None
        }
    }
}