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

#[cfg(test)]
mod tests {
    use dojo::model::ModelStorageTest;
    use super::*;
    use evolute_duel::{
        types::packing::{Tile, TEdge, PlayerSide},
        models::scoring::{UnionNode, m_UnionNode},
    };
    use dojo_cairo_test::{spawn_test_world, NamespaceDef, TestResource, WorldStorageTestTrait};
    use dojo::{world::WorldStorage, model::ModelStorage};

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
        
        
        let result = is_valid_move(board_id, Tile::Empty, 0, 4, 4, world);
        
        assert!(result == false, "Empty tile should not be valid");
    }

    #[test]
    fn test_is_valid_move_out_of_bounds() {
        let world = setup_world();
        let board_id = 123;
        
        let result = is_valid_move(board_id, Tile::CCCC, 0, 0, 4, world);
        
        assert!(result == false, "Out of bounds should not be valid");
    }

    #[test]
    fn test_is_valid_move_out_of_bounds_high() {
        let world = setup_world();
        let board_id = 123;
        
        
        let result = is_valid_move(board_id, Tile::CCCC, 0, 9, 4, world);
        
        assert!(result == false, "Out of bounds high should not be valid");
    }

    #[test]
    fn test_is_valid_move_position_occupied() {
        let world = setup_world();
        let board_id = 123;
        
        // Place a tile at position 4,4
        let edges = array![TEdge::C, TEdge::C, TEdge::C, TEdge::C].span();
        place_tile_on_board(world, board_id, 4, 4, edges);
        
        let result = is_valid_move(board_id, Tile::CCCC, 0, 4, 4, world);
        
        assert!(result == false, "Occupied position should not be valid");
    }

    #[test]
    fn test_is_valid_move_no_connections() {
        let world = setup_world();
        let board_id = 123;
        
        
        let result = is_valid_move(board_id, Tile::CCCC, 0, 4, 4, world);
        
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
        let result = is_valid_move(board_id, Tile::CCCC, 0, 4, 4, world);
        
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
        let result = is_valid_move(board_id, Tile::CCCC, 0, 5, 3, world);
        
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
        let result = is_valid_move(board_id, Tile::CCRR, 3, 4, 4, world);
        
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
        let result = is_valid_move(board_id, Tile::CCCC, 0, 4, 4, world);
        
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
        let result = is_valid_move(board_id, Tile::CCCC, 0, 1, 1, world);
        
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
        let result = is_valid_move(board_id, Tile::CCCC, 0, 1, 1, world);
        
        assert!(result == true, "Edge position should work with connection");
    }
}
