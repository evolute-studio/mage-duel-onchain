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
    println!("[IS_VALID_MOVE] === Starting is_valid_move validation ===");
    println!("[IS_VALID_MOVE] Input parameters:");
    println!("[IS_VALID_MOVE]   board_id: {}", board_id);
    println!("[IS_VALID_MOVE]   tile: {:?}", tile);
    println!("[IS_VALID_MOVE]   rotation: {}", rotation);
    println!("[IS_VALID_MOVE]   col: {}, row: {}", col, row);
    println!("[IS_VALID_MOVE]   board_size: {}", board_size);
    println!("[IS_VALID_MOVE]   bounds: min_col={}, max_col={}, min_row={}, max_row={}", min_col, max_col, min_row, max_row);
    println!("[IS_VALID_MOVE]   can_place_not_adjacents: {}", can_place_not_adjacents);

    if tile == Tile::Empty {
        println!("[IS_VALID_MOVE] FAILED: Tile is Empty");
        return false;
    }
    println!("[IS_VALID_MOVE] PASSED: Tile is not empty");
    
    //check if valid col and row
    println!("[IS_VALID_MOVE] Checking bounds validation...");
    println!("[IS_VALID_MOVE]   col ({}) >= min_col ({})? {}", col, min_col, col >= min_col);
    println!("[IS_VALID_MOVE]   col ({}) <= max_col ({})? {}", col, max_col, col <= max_col);
    println!("[IS_VALID_MOVE]   row ({}) >= min_row ({})? {}", row, min_row, row >= min_row);
    println!("[IS_VALID_MOVE]   row ({}) <= max_row ({})? {}", row, max_row, row <= max_row);
    
    if !(col >= min_col && col <= max_col && row >= min_row && row <= max_row) {
        println!("[IS_VALID_MOVE] FAILED: Invalid column or row: col={}, row={}, min_col={}, max_col={}, min_row={}, max_row={}", col, row, min_col, max_col, min_row, max_row);
        return false;
    }
    println!("[IS_VALID_MOVE] PASSED: Position within bounds");
    
    //check if the tile is empty
    println!("[IS_VALID_MOVE] Checking if position is already occupied...");
    let tile_position: u32 = col.into() * board_size + row.into();
    println!("[IS_VALID_MOVE] Calculated tile_position: {}", tile_position);
    let mut is_placed = false;
    let position: u32 = tile_position.into() * 4;
    println!("[IS_VALID_MOVE] Base position for node check: {}", position);
    
    for i in 0..4_u8 {
        let node_position = position + i.into();
        println!("[IS_VALID_MOVE] Checking node at position {} (edge {})", node_position, i);
        let mut node: UnionNode = world.read_model((board_id, node_position));
        println!("[IS_VALID_MOVE]   Node type: {:?}", node.node_type);
        if node.node_type != TEdge::None {
            is_placed = true;
            println!("[IS_VALID_MOVE]   Found existing tile at edge {}", i);
        }
    };
    
    if is_placed {
        println!("[IS_VALID_MOVE] FAILED: Tile already placed at position: col={}, row={}", col, row);
        return false;
    }
    println!("[IS_VALID_MOVE] PASSED: Position is empty");
    
    println!("[IS_VALID_MOVE] Creating extended tile for validation...");
    let extended_tile = create_extended_tile(tile, rotation);
    let edges = extended_tile.edges;
    println!("[IS_VALID_MOVE] Tile edges after rotation:");
    println!("[IS_VALID_MOVE]   Up (0): {:?}", edges.at(0));
    println!("[IS_VALID_MOVE]   Right (1): {:?}", edges.at(1));
    println!("[IS_VALID_MOVE]   Down (2): {:?}", edges.at(2));
    println!("[IS_VALID_MOVE]   Left (3): {:?}", edges.at(3));
    
    let mut actual_connections = 0;

    //check adjacent tiles
    println!("[IS_VALID_MOVE] Calculating direction offsets...");
    let direction_offsets = array![
        4 + 2, // Up
        board_size.try_into().unwrap() * 4 + 2, // Right
        -4 - 2, // Down
        -board_size.try_into().unwrap() * 4 - 2, // Left
    ];
    
    println!("[IS_VALID_MOVE] Direction offsets:");
    println!("[IS_VALID_MOVE]   Up: {}", *direction_offsets[0]);
    println!("[IS_VALID_MOVE]   Right: {}", *direction_offsets[1]);
    println!("[IS_VALID_MOVE]   Down: {}", *direction_offsets[2]);
    println!("[IS_VALID_MOVE]   Left: {}", *direction_offsets[3]);

    let mut result = true;

    println!("[IS_VALID_MOVE] Checking adjacent tiles for each side...");
    for side in 0..4_u8 {
        let side_name: ByteArray = match side {
            0 => "Up",
            1 => "Right", 
            2 => "Down",
            3 => "Left",
            _ => "Unknown"
        };
        
        println!("[IS_VALID_MOVE] --- Checking {} side (side {}) ---", side_name, side);
        let offset: i64 = *direction_offsets[side.into()];
        let edge_position: u32 = tile_position * 4 + side.into();
        println!("[IS_VALID_MOVE]   Edge position: {}", edge_position);
        println!("[IS_VALID_MOVE]   Offset: {}", offset);
        
        let adjacent_node_position: u32 = (edge_position.try_into().unwrap() + offset).try_into().unwrap();
        println!("[IS_VALID_MOVE]   Adjacent node position: {}", adjacent_node_position);
        
        if adjacent_node_position < 0 || adjacent_node_position / 4 > board_size * board_size {
            println!("[IS_VALID_MOVE]   {} side: Out of bounds, skipping", side_name);
            continue;
        }

        let mut adjacent_node: UnionNode = world.read_model((board_id, adjacent_node_position));
        println!("[IS_VALID_MOVE]   {} side: Adjacent node type: {:?}", side_name, adjacent_node.node_type);
        
        if adjacent_node.node_type == TEdge::None {
            println!("[IS_VALID_MOVE]   {} side: No tile placed, skipping", side_name);
            continue;
        }
        
        let current_edge = *edges.at(side.into());
        println!("[IS_VALID_MOVE]   {} side: Current tile edge: {:?}", side_name, current_edge);
        println!("[IS_VALID_MOVE]   {} side: Adjacent tile edge: {:?}", side_name, adjacent_node.node_type);
        
        if adjacent_node.node_type != current_edge && adjacent_node.node_type != TEdge::None {
            println!("[IS_VALID_MOVE]   {} side: EDGE MISMATCH! Expected {:?}, found {:?}", side_name, current_edge, adjacent_node.node_type);
            println!("[IS_VALID_MOVE] Edge does not match: expected {:?}, found {:?}", edges.at(side.into()), adjacent_node.node_type);
            println!(
                "[IS_VALID_MOVE] Context: board_id={}, edge_position={}, adjacent_node_position={}, tile_position={}, col={}, row={}", 
                board_id, edge_position, adjacent_node_position, tile_position, col, row
            );
            result = false;
            break;
        } else if adjacent_node.node_type == current_edge {
            actual_connections += 1;
            println!("[IS_VALID_MOVE]   {} side: MATCH! Connection found (total connections: {})", side_name, actual_connections);
        }
    };

    if !result {
        println!("[IS_VALID_MOVE] FAILED: Edge mismatch detected, returning false");
        return false;
    } 

    println!("[IS_VALID_MOVE] Connection validation summary:");
    println!("[IS_VALID_MOVE]   Total connections found: {}", actual_connections);
    println!("[IS_VALID_MOVE]   Can place without adjacents: {}", can_place_not_adjacents);
    
    if actual_connections == 0 && !can_place_not_adjacents {
        println!("[IS_VALID_MOVE] FAILED: No adjacent connections found for tile at position: col={}, row={}", col, row);
        result = false; 
    } else if actual_connections == 0 && can_place_not_adjacents {
        println!("[IS_VALID_MOVE] PASSED: No connections but can_place_not_adjacents is true");
    } else {
        println!("[IS_VALID_MOVE] PASSED: Found {} valid connections", actual_connections);
    }

    println!("[IS_VALID_MOVE] Final result: {}", result);
    println!("[IS_VALID_MOVE] === Finished is_valid_move validation ===");
    result
}

#[cfg(test)]
mod tests {
    use dojo::model::ModelStorageTest;
    use super::*;
    use evolute_duel::{
        types::packing::{Tile, TEdge, PlayerSide},
        models::scoring::{UnionNode, m_UnionNode},
    };
    use dojo_cairo_test::{spawn_test_world, NamespaceDef, TestResource};

    fn setup_world() -> WorldStorage {
        let namespace_def = NamespaceDef {
            namespace: "evolute_duel", 
            resources: [
                TestResource::Model(m_UnionNode::TEST_CLASS_HASH),
            ].span()
        };
        spawn_test_world([namespace_def].span())
    }

    fn place_tile_on_board(mut world: WorldStorage, board_id: felt252, col: u8, row: u8, edges: Span<TEdge>) {
        let tile_position: u32 = col.into() * 10 + row.into();
        let mut i = 0;
        loop {
            if i >= 4 {
                break;
            }
            let position = tile_position * 4 + i;
            let node = UnionNode {
                board_id,
                position,
                parent: position,
                rank: 0,
                blue_points: 0,
                red_points: 0,
                open_edges: 0,
                contested: false,
                node_type: *edges.at(i),
                player_side: PlayerSide::None,
            };
            world.write_model_test(@node);
            i += 1;
        }
    }

    #[test]
    fn test_is_valid_move_empty_tile() {
        let world = setup_world();
        let board_id = 123;
        
        
        let result = is_valid_move(board_id, Tile::Empty, 0, 4, 4, 10, 1, 1, 8, 8, false, world);
        
        assert!(result == false, "Empty tile should not be valid");
    }

    #[test]
    fn test_is_valid_move_out_of_bounds() {
        let world = setup_world();
        let board_id = 123;
        
        let result = is_valid_move(board_id, Tile::CCCC, 0, 0, 4, 10, 1, 1, 8, 8, false, world);
        
        assert!(result == false, "Out of bounds should not be valid");
    }

    #[test]
    fn test_is_valid_move_out_of_bounds_high() {
        let world = setup_world();
        let board_id = 123;
        
        
        let result = is_valid_move(board_id, Tile::CCCC, 0, 9, 4, 10, 1, 1, 8, 8, false, world);
        
        assert!(result == false, "Out of bounds high should not be valid");
    }

    #[test]
    fn test_is_valid_move_position_occupied() {
        let world = setup_world();
        let board_id = 123;
        
        // Place a tile at position 4,4
        let edges = array![TEdge::C, TEdge::C, TEdge::C, TEdge::C].span();
        place_tile_on_board(world, board_id, 4, 4, edges);
        
        let result = is_valid_move(board_id, Tile::CCCC, 0, 4, 4, 10, 1, 1, 8, 8, false, world);
        
        assert!(result == false, "Occupied position should not be valid");
    }

    #[test]
    fn test_is_valid_move_no_connections() {
        let world = setup_world();
        let board_id = 123;
        
        
        let result = is_valid_move(board_id, Tile::CCCC, 0, 4, 4, 10, 1, 1, 8, 8, false, world);
        
        assert!(result == false, "No connections should not be valid");
    }

    #[test]
    fn test_is_valid_move_valid_connection() {
        let world = setup_world();
        let board_id = 123;
        
        
        // Place a tile at position 4,3 (below target position)
        let edges = array![TEdge::C, TEdge::R, TEdge::C, TEdge::F].span();
        place_tile_on_board(world, board_id, 4, 3, edges);
        
        // Try to place CCCC at 4,4 (should connect with C edge)
        let result = is_valid_move(board_id, Tile::CCCC, 0, 4, 4, 10, 1, 1, 8, 8, false, world);
        
        assert!(result == true, "Valid connection should be valid");
    }

    #[test]
    fn test_is_valid_move_mismatched_edges() {
        let world = setup_world();
        let board_id = 123;
        
        
        // Place a tile at position 4,3 (below target position) with Road edge facing up
        let edges = array![TEdge::C, TEdge::R, TEdge::R, TEdge::F].span();
        place_tile_on_board(world, board_id, 4, 3, edges);
        
        // Try to place CCCC at 4,4 (City edge facing down, should not match Road)
        let result = is_valid_move(board_id, Tile::CCCC, 0, 5, 3, 10, 1, 1, 8, 8, false, world);
        
        assert!(result == false, "Mismatched edges should not be valid");
    }

    #[test]
    fn test_is_valid_move_with_rotation() {
        let world = setup_world();
        let board_id = 123;
        
        
        // Place a tile at position 3,4 (left of target position) with City edge facing right
        let edges = array![TEdge::F, TEdge::C, TEdge::F, TEdge::R].span();
        place_tile_on_board(world, board_id, 3, 4, edges);
        
        // Try to place CCRR at 4,4 with rotation 3 (should have City edge facing left)
        let result = is_valid_move(board_id, Tile::CCRR, 3, 4, 4, 10, 1, 1, 8, 8, false, world);
        
        assert!(result == true, "Valid rotation should work");
    }

    #[test]
    fn test_is_valid_move_multiple_connections() {
        let world = setup_world();
        let board_id = 123;
        
        
        // Place tiles around target position
        let edges1 = array![TEdge::C, TEdge::R, TEdge::C, TEdge::F].span();
        place_tile_on_board(world, board_id, 4, 3, edges1); // Below
        
        let edges2 = array![TEdge::F, TEdge::C, TEdge::F, TEdge::C].span();
        place_tile_on_board(world, board_id, 3, 4, edges2); // Left
        
        // Try to place CCCC at 4,4 (should connect with both)
        let result = is_valid_move(board_id, Tile::CCFF, 2, 4, 4, 10, 1, 1, 8, 8, false, world);
        
        assert!(result == true, "Multiple connections should be valid");
    }

    #[test]
    fn test_is_valid_move_corner_position() {
        let world = setup_world();
        let board_id = 123;
        
        
        // Place a tile at position 2,1 (right of corner)
        let edges = array![TEdge::F, TEdge::R, TEdge::F, TEdge::C].span();
        place_tile_on_board(world, board_id, 2, 1, edges);
        
        // Try to place CCCC at 1,1 (corner position)
        let result = is_valid_move(board_id, Tile::CCCC, 0, 1, 1, 10, 1, 1, 8, 8, false, world);
        
        assert!(result == true, "Corner position should work with connection");
    }

    #[test]
    fn test_is_valid_move_edge_position() {
        let world = setup_world();
        let board_id = 123;
        
        
        // Place a tile at position 1,2 (below edge)
        let edges = array![TEdge::C, TEdge::R, TEdge::C, TEdge::F].span();
        place_tile_on_board(world, board_id, 1, 2, edges);
        
        // Try to place CCCC at 1,1 (top edge position)
        let result = is_valid_move(board_id, Tile::CCCC, 0, 1, 1, 10, 1, 1, 8, 8, false, world);
        
        assert!(result == true, "Edge position should work with connection");
    }

    #[test]
    fn test_is_valid_move_single_road_connection() {
        let world = setup_world();
        let board_id = 123;
        
        // Place a tile at position 4,3 (below target position) with Road edge facing up
        let edges = array![TEdge::R, TEdge::C, TEdge::R, TEdge::F].span();
        place_tile_on_board(world, board_id, 4, 3, edges);
        
        // Try to place FFRR at 4,4 (Road edge facing down, should connect)
        let result = is_valid_move(board_id, Tile::FFRR, 0, 4, 4, 10, 1, 1, 8, 8, false, world);
        
        assert!(result == true, "Single road connection should be valid");
    }

    #[test]
    fn test_is_valid_move_multiple_road_connections() {
        let world = setup_world();
        let board_id = 123;
        
        // Place tiles around target position with road edges
        let edges1 = array![TEdge::R, TEdge::C, TEdge::F, TEdge::F].span();
        place_tile_on_board(world, board_id, 4, 3, edges1); // Below - road facing up
        
        let edges2 = array![TEdge::F, TEdge::R, TEdge::F, TEdge::C].span();
        place_tile_on_board(world, board_id, 3, 4, edges2); // Left - road facing right
        
        // Try to place FFRR at 4,4 (should connect with both road edges)
        let result = is_valid_move(board_id, Tile::FFRR, 0, 4, 4, 10, 1, 1, 8, 8, false, world);
        
        assert!(result == true, "Multiple road connections should be valid");
    }

    #[test]
    fn test_is_valid_move_road_field_mismatch() {
        let world = setup_world();
        let board_id = 123;
        
        // Place a tile at position 4,3 (below target position) with Field edge facing up
        let edges = array![TEdge::C, TEdge::R, TEdge::F, TEdge::C].span();
        place_tile_on_board(world, board_id, 4, 3, edges);
        
        // Try to place FFRR at 4,4 (Road edge facing down, should not match Field)
        let result = is_valid_move(board_id, Tile::FFRR, 0, 4, 4, 10, 1, 1, 8, 8, false, world);
        
        assert!(result == false, "Road-Field mismatch should not be valid");
    }
}
