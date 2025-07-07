use evolute_duel::{
    types::packing::{Tile, TEdge}, systems::helpers::{tile_helpers::{create_extended_tile}},
    models::scoring::{UnionNode},
};
use dojo::{
    world::{WorldStorage},
    model::{ModelStorage},
};


pub fn is_valid_move(
    board_id: felt252,
    tile: Tile,
    rotation: u8,
    col: u32,
    row: u32,
    board_size: u32,
    min_col: u32,
    min_row: u32,
    max_col: u32,
    max_row: u32,
    can_place_not_adjacents: bool,
    world: WorldStorage,
) -> bool {
    if tile == Tile::Empty {
        return false;
    }
    
    //check if valid col and row
    if !(col >= min_col && col <= max_col && row >= min_row && row <= max_row) {
        return false;
    }
    
    //check if the tile is empty
    
    let tile_position: u32 = col.into() * board_size + row.into();
    let mut is_placed = false;
    let position: u32 = tile_position.into() * 4;
    for i in 0..4_u8 {
        let mut node: UnionNode = world.read_model((board_id, position + i.into()));
        if node.node_type != TEdge::None {is_placed = true;}
    };
    if is_placed {
        return false;
    }
    
    
    let extended_tile = create_extended_tile(tile, rotation);
    let edges = extended_tile.edges;
    let mut actual_connections = 0;

    //check adjacent tiles

    let direction_offsets = array![
        4 + 2, // Up
        board_size.try_into().unwrap() * 4 + 2, // Right
        -4 - 2, // Down
        -board_size.try_into().unwrap() * 4 - 2, // Left
    ];

    let mut result = true;

    for side in 0..4_u8 {
        let offset: i32 = *direction_offsets[side.into()];
        let edge_position: u32 = tile_position * 4 + side.into();
        let adjacent_node_position: u32 = (edge_position.try_into().unwrap() + offset).try_into().unwrap();
        
        if adjacent_node_position < 0 || adjacent_node_position / 4 > board_size * board_size {
            // Out of bounds
            continue;
        }

        let mut adjacent_node: UnionNode = world.read_model((board_id, adjacent_node_position));
        if adjacent_node.node_type == TEdge::None {
            // No tile placed in this position
            continue;
        }
        if adjacent_node.node_type != *edges.at(side.into()) && adjacent_node.node_type != TEdge::None {
            // Edge does not match
            result = false;
            break;
        } else if adjacent_node.node_type == *edges.at(side.into()) {
            actual_connections += 1;
        }
    };

    if actual_connections == 0 && !can_place_not_adjacents {
        result = false; 
    }

    result
}

// #[cfg(test)]
// mod tests {
//     use super::*;

//     #[test]
//     fn test_is_valid_move() {
//         let tile = Tile::CCFF;
//         let rotation = 2;
//         let col = 6;
//         let row = 0;

//         let mut state: Array<(u8, u8, u8)> = ArrayTrait::new();
//         state.append_span([(Tile::Empty.into(), 0, 0); 64].span());

//         let initial_edge_state = array![
//             2,
//             2,
//             2,
//             2,
//             2,
//             2,
//             0,
//             1,
//             2,
//             2,
//             2,
//             2,
//             2,
//             2,
//             0,
//             1,
//             2,
//             2,
//             2,
//             2,
//             2,
//             2,
//             0,
//             1,
//             2,
//             2,
//             2,
//             2,
//             2,
//             2,
//             0,
//             1,
//         ];

//         // println!(
//         //     "is valid: {:?}",
//         //     is_valid_move(tile, rotation, col, row, state.span(), initial_edge_state.span()),
//         // );

//         assert_eq!(
//             is_valid_move(tile, rotation, col, row, state.span(), initial_edge_state.span()), true,
//         );
//     }
// }
