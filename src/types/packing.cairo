#[derive(Serde, Drop, Introspect, PartialEq, Debug, Copy, DojoStore, Default)]
pub enum TEdge {
    #[default]
    None,
    C,
    R,
    F,
}

impl TEdgeIntoU8 of Into<TEdge, u8> {
    fn into(self: TEdge) -> u8 {
        match self {
            TEdge::None => 0,
            TEdge::C => 1,
            TEdge::R => 2,
            TEdge::F => 3,
        }
    }
}

impl U8IntoTEdge of Into<u8, TEdge> {
    fn into(self: u8) -> TEdge {
        match self {
            0 => TEdge::None,
            1 => TEdge::C,
            2 => TEdge::R,
            3 => TEdge::F,
            _ => panic!("Unsupported TEdge"),
        }
    }
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
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
    #[default]
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

#[derive(Copy, Drop, Serde, Debug, Introspect, PartialEq, DojoStore, Default)]
pub enum GameState {
    #[default]
    Creating,
    Reveal,
    Request,
    Move,
    Finished,
}

#[derive(Drop, Serde, Copy, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum GameStatus {
    #[default]
    Finished,
    Created,
    Canceled,
    InProgress,
}

#[derive(Drop, Serde, Copy, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum PlayerSide {
    #[default]
    None,
    Blue,
    Red,
}

impl PlayerSideToU8 of Into<PlayerSide, u8> {
    fn into(self: PlayerSide) -> u8 {
        match self {
            PlayerSide::None => 0,
            PlayerSide::Blue => 1,
            PlayerSide::Red => 2,
        }
    }
}

impl U8ToPlayerSide of Into<u8, PlayerSide> {
    fn into(self: u8) -> PlayerSide {
        match self {
            0 => PlayerSide::None,
            1 => PlayerSide::Blue,
            2 => PlayerSide::Red,
            _ => panic!("Unsupported PlayerSide"),
        }
    }
}

#[derive(Drop, Serde, Copy, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum GameMode {
    #[default]
    None,
    Tutorial,
    Ranked,
    Casual,
    Tournament,
}

impl GameModeToU8 of Into<GameMode, u8> {
    fn into(self: GameMode) -> u8 {
        match self {
            GameMode::None => 0,
            GameMode::Tutorial => 1,
            GameMode::Ranked => 2,
            GameMode::Casual => 3,
            GameMode::Tournament => 4,
        }
    }
}

impl U8ToGameMode of Into<u8, GameMode> {
    fn into(self: u8) -> GameMode {
        match self {
            0 => GameMode::None,
            1 => GameMode::Tutorial,
            2 => GameMode::Ranked,
            3 => GameMode::Casual,
            4 => GameMode::Tournament,
            _ => panic!("Unsupported GameMode"),
        }
    }
}

