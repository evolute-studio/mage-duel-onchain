use evolute_duel::{
    packing::{Tile, TEdge},
    systems::helpers::{
        tile_helpers::{create_extended_tile},
    },
};

pub fn is_valid_move(tile: Tile, rotation: u8, col: u8, row: u8, state: Span<(u8, u8, u8)>, initial_edge_state: Span<u8>) -> bool {
    let extended_tile = create_extended_tile(tile, rotation);
    let tile_position = col * 8 + row;

    //check if the tile is empty
    if extended_tile.edges[0] == @TEdge::M && extended_tile.edges[1] == @TEdge::M && extended_tile.edges[2] == @TEdge::M && extended_tile.edges[3] == @TEdge::M {
        return false;
    }

    //check if the tile is already placed
    if *state[tile_position.into()] != (TEdge::M.into(), 0, 0) {
        return false;
    }

    let edges = extended_tile.edges;
    let mut actual_connections = 0;

    //check adjacent tiles
   
    if row != 0 {
        let (tile, rotation, _) = *state.at((tile_position - 1).into());
        let extended_down_tile = create_extended_tile(tile.into(), rotation);
        if *extended_down_tile.edges.at(0) != *edges.at(2) {
            return false;
        } else {
            actual_connections += 1;
        }
    } // tile is connected to bottom edge
    else if *initial_edge_state.at(col.into()) != (*edges.at(2)).into() 
        && *initial_edge_state.at(col.into()) != TEdge::M.into() {
        return false;
    } else if *initial_edge_state.at(col.into()) == (*edges.at(2)).into() {
        actual_connections += 1;
    }
    

    //connect top edge
    if row != 7 {
        let (tile, rotation, _) = *state.at((tile_position + 1).into());
        let extended_up_tile = create_extended_tile(tile.into(), rotation);
        if *extended_up_tile.edges.at(2) != *edges.at(0) {
            return false;
        } else {
            actual_connections += 1;
        }
    } // tile is connected to top edge
    else if *initial_edge_state.at((23 - col).into()) != (*edges.at(0)).into() 
        && *initial_edge_state.at((23 - col).into()) != TEdge::M.into() {
        return false;
    } else if *initial_edge_state.at((23 - col).into()) == (*edges.at(0)).into() {
        actual_connections += 1;
    }



    if col != 0 {
        let (tile, rotation, _) = *state.at((tile_position - 8).into());
        let extended_left_tile = create_extended_tile(tile.into(), rotation);
        if *extended_left_tile.edges.at(1) != *edges.at(3) {
            return false;
        } else {
            actual_connections += 1;
        }
    } // tile is connected to left edge
    else if *initial_edge_state.at((31 - row).into()) != (*edges.at(3)).into() 
        && *initial_edge_state.at((31 - row).into()) != TEdge::M.into() {
        return false;
    } else if *initial_edge_state.at((31 - row).into()) == (*edges.at(3)).into() {
        actual_connections += 1;
    }



    if col != 7 {
        let (tile, rotation, _) = *state.at((tile_position + 8).into());
        let extended_right_tile = create_extended_tile(tile.into(), rotation);
        if *extended_right_tile.edges.at(3) != *edges.at(1) {
            return false;
        } else {
            actual_connections += 1;
        }
    } // tile is connected to right edge
    else if *initial_edge_state.at((8 + row).into()) != (*edges.at(1)).into() 
        && *initial_edge_state.at((8 + row).into()) != TEdge::M.into() {
        return false;
    } else if *initial_edge_state.at((8 + row).into()) == (*edges.at(1)).into() {
        actual_connections += 1;
    }
    

    if actual_connections == 0 {
        return false;
    }

    true
}