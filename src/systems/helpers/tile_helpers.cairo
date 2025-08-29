use evolute_duel::{types::packing::{TEdge, Tile}};

#[derive(Drop, Serde, Debug)]
struct ExtendedTile {
    pub edges: Span<TEdge>,
}

pub fn create_extended_tile(tile: Tile, rotation: u8) -> ExtendedTile {
    let mut edges = match tile {
        Tile::CCCC => [TEdge::C, TEdge::C, TEdge::C, TEdge::C],
        Tile::FFFF => [TEdge::F, TEdge::F, TEdge::F, TEdge::F],
        Tile::RRRR => [TEdge::R, TEdge::R, TEdge::R, TEdge::R],
        Tile::CCCF => [TEdge::C, TEdge::C, TEdge::C, TEdge::F],
        Tile::CCCR => [TEdge::C, TEdge::C, TEdge::C, TEdge::R],
        Tile::CCRR => [TEdge::C, TEdge::C, TEdge::R, TEdge::R],
        Tile::CFFF => [TEdge::C, TEdge::F, TEdge::F, TEdge::F],
        Tile::FFFR => [TEdge::F, TEdge::F, TEdge::F, TEdge::R],
        Tile::CRRR => [TEdge::C, TEdge::R, TEdge::R, TEdge::R],
        Tile::FRRR => [TEdge::F, TEdge::R, TEdge::R, TEdge::R],
        Tile::CCFF => [TEdge::C, TEdge::C, TEdge::F, TEdge::F],
        Tile::CFCF => [TEdge::C, TEdge::F, TEdge::C, TEdge::F],
        Tile::CRCR => [TEdge::C, TEdge::R, TEdge::C, TEdge::R],
        Tile::FFRR => [TEdge::F, TEdge::F, TEdge::R, TEdge::R],
        Tile::FRFR => [TEdge::F, TEdge::R, TEdge::F, TEdge::R],
        Tile::CCFR => [TEdge::C, TEdge::C, TEdge::F, TEdge::R],
        Tile::CCRF => [TEdge::C, TEdge::C, TEdge::R, TEdge::F],
        Tile::CFCR => [TEdge::C, TEdge::F, TEdge::C, TEdge::R],
        Tile::CFFR => [TEdge::C, TEdge::F, TEdge::F, TEdge::R],
        Tile::CFRF => [TEdge::C, TEdge::F, TEdge::R, TEdge::F],
        Tile::CRFF => [TEdge::C, TEdge::R, TEdge::F, TEdge::F],
        Tile::CRRF => [TEdge::C, TEdge::R, TEdge::R, TEdge::F],
        Tile::CRFR => [TEdge::C, TEdge::R, TEdge::F, TEdge::R],
        Tile::CFRR => [TEdge::C, TEdge::F, TEdge::R, TEdge::R],
        Tile::Empty => [TEdge::None, TEdge::None, TEdge::None, TEdge::None],
    }.span();

    let rotation = (rotation % 4);

    for _ in 0..rotation {
        edges = [*edges[3], *edges[0], *edges[1], *edges[2]].span();
    };

    ExtendedTile { edges }
}

pub fn convert_board_position_to_node_position(
    col: u32, row: u32, direction: u8, board_size: u32,
) -> u32 {
    let position = (col * board_size + row).into() * 4 + direction.into();
    position
}

pub fn convert_node_position_to_board_position(city_node_position: u8) -> (u8, u8) {
    let rotation = city_node_position % 4;
    let tile_position = city_node_position / 4;
    (tile_position, rotation)
}

pub fn calcucate_tile_points(tile: Tile) -> (u16, u16) {
    match tile {
        // C = 2, R = 1, F = 0, M = 0
        Tile::CCCC => (8, 0),
        Tile::FFFF => (0, 0),
        Tile::RRRR => (0, 4),
        Tile::CCCF => (6, 0),
        Tile::CCCR => (6, 1),
        Tile::CCRR => (4, 2),
        Tile::CFFF => (2, 0),
        Tile::FFFR => (0, 1),
        Tile::CRRR => (2, 3),
        Tile::FRRR => (0, 3),
        Tile::CCFF => (4, 0),
        Tile::CFCF => (4, 0),
        Tile::CRCR => (4, 2),
        Tile::FFRR => (0, 2),
        Tile::FRFR => (0, 2),
        Tile::CCFR => (4, 1),
        Tile::CCRF => (4, 1),
        Tile::CFCR => (4, 1),
        Tile::CFFR => (2, 1),
        Tile::CFRF => (2, 1),
        Tile::CRFF => (2, 1),
        Tile::CRRF => (2, 2),
        Tile::CRFR => (2, 2),
        Tile::CFRR => (2, 2),
        Tile::Empty => (0, 0),
    }
}

pub fn tile_roads_number(tile: Tile) -> u8 {
    match tile {
        Tile::CCCC => 0,
        Tile::FFFF => 0,
        Tile::RRRR => 4,
        Tile::CCCF => 0,
        Tile::CCCR => 1,
        Tile::CCRR => 2,
        Tile::CFFF => 0,
        Tile::FFFR => 1,
        Tile::CRRR => 3,
        Tile::FRRR => 3,
        Tile::CCFF => 0,
        Tile::CFCF => 0,
        Tile::CRCR => 2,
        Tile::FFRR => 2,
        Tile::FRFR => 2,
        Tile::CCFR => 1,
        Tile::CCRF => 1,
        Tile::CFCR => 1,
        Tile::CFFR => 1,
        Tile::CFRF => 1,
        Tile::CRFF => 1,
        Tile::CRRF => 2,
        Tile::CRFR => 2,
        Tile::CFRR => 2,
        Tile::Empty => 0,
    }
}

pub fn tile_city_number(tile: Tile) -> u8 {
    match tile {
        Tile::CCCC => 4,
        Tile::FFFF => 0,
        Tile::RRRR => 0,
        Tile::CCCF => 3,
        Tile::CCCR => 3,
        Tile::CCRR => 2,
        Tile::CFFF => 1,
        Tile::FFFR => 0,
        Tile::CRRR => 1,
        Tile::FRRR => 0,
        Tile::CCFF => 2,
        Tile::CFCF => 2,
        Tile::CRCR => 2,
        Tile::FFRR => 0,
        Tile::FRFR => 0,
        Tile::CCFR => 2,
        Tile::CCRF => 2,
        Tile::CFCR => 2,
        Tile::CFFR => 1,
        Tile::CFRF => 1,
        Tile::CRFF => 1,
        Tile::CRRF => 1,
        Tile::CRFR => 1,
        Tile::CFRR => 1,
        Tile::Empty => 0,
    }
}

pub fn calculate_adjacent_edge_points(
    ref initial_edge_state: Span<u8>, col: u8, row: u8, tile: Tile, rotation: u8,
) -> (u16, u16) {
    let mut city_points = 0;
    let mut road_points = 0;

    let extended_tile = create_extended_tile(tile, rotation);
    let edges = extended_tile.edges;

    if col == 0 && *initial_edge_state.at((31 - row).into()) == (*edges.at(3)).into() {
        if *edges.at(3) == TEdge::C {
            city_points += 2;
        } else if *edges.at(3) == TEdge::R {
            road_points += 1;
        }
    }

    if col == 7 && *initial_edge_state.at((8 + row).into()) == (*edges.at(1)).into() {
        if *edges.at(1) == TEdge::C {
            city_points += 2;
        } else if *edges.at(1) == TEdge::R {
            road_points += 1;
        }
    }

    if row == 0 && *initial_edge_state.at(col.into()) == (*edges.at(2)).into() {
        if *edges.at(2) == TEdge::C {
            city_points += 2;
        } else if *edges.at(2) == TEdge::R {
            road_points += 1;
        }
    }

    if row == 7 && *initial_edge_state.at((23 - col).into()) == (*edges.at(0)).into() {
        if *edges.at(0) == TEdge::C {
            city_points += 2;
        } else if *edges.at(0) == TEdge::R {
            road_points += 1;
        }
    }

    (city_points, road_points)
}
