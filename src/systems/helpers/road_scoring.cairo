use dojo::event::EventStorage;
use evolute_duel::{
    events::{RoadContestWon, RoadContestDraw},
    systems::helpers::{
        union_find::{find, union}, board::{},
        tile_helpers::{
            create_extended_tile, convert_board_position_to_node_position, tile_roads_number,
        },
    },
    packing::{TEdge, PlayerSide, Tile, UnionNode},
};
use dojo::world::{WorldStorage};
use core::dict::Felt252Dict;
use alexandria_data_structures::vec::{NullableVec, VecTrait};

pub fn connect_road_edges_in_tile(
    ref world: WorldStorage, ref road_nodes: NullableVec<UnionNode>, tile_position: u8, tile: u8, rotation: u8, side: u8,
) {
    let extended_tile = create_extended_tile(tile.into(), rotation);

    let mut roads: Array<u8> = ArrayTrait::new();

    for i in 0..4_u8 {
        if *extended_tile.edges.at(i.into()) == (TEdge::R).into() {
            let mut open_edges = 1;
            let blue_points = if side == (PlayerSide::Blue).into() {
                1
            } else {
                0
            };
            let red_points = if side == (PlayerSide::Red).into() {
                1
            } else {
                0
            };
            let position = convert_board_position_to_node_position(tile_position, i);
            roads.append(position);
            let road_node = UnionNode {
                parent: position,
                rank: 1,
                blue_points,
                red_points,
                open_edges,
                contested: false,
            };
            println!("4");
            println!("Position: {:?}", position);
            println!("Road node: {:?}", road_node);
            println!("Road nodes: {:?}", road_nodes.len());
            road_nodes.set(position.into(), road_node);
            println!("5");
        }
    };
    println!("6");
    if roads.len() == 2 && tile != Tile::CRCR.into() {
        union(ref world, ref road_nodes, *roads.at(0), *roads.at(1), true);
        // println!("After union in tile");
        // println!("{:?}", find(ref world, board_id, *roads.at(0)));
        // println!("{:?}", find(ref world, board_id, *roads.at(1)));
    }

}

pub fn connect_adjacent_road_edges(
    ref world: WorldStorage,
    board_id: felt252,
    state: Span<(u8, u8, u8)>,
    ref initial_edge_state: Span<u8>,
    ref road_nodes: NullableVec<UnionNode>,
    tile_position: u8,
    tile: u8,
    rotation: u8,
    side: u8,
    ref visited: Felt252Dict<bool>,
    ref potential_road_contests: Array<u8>,
) //None - if no contest or draw, Some(u8, u16) -> (who_wins, points_delta) - if contest
-> Span<
    Option<(PlayerSide, u16)>,
> {
    let extended_tile = create_extended_tile(tile.into(), rotation);
    let row = tile_position % 8;
    let col = tile_position / 8;
    let mut roads_connected: Array<u8> = ArrayTrait::new();
    let edges = extended_tile.edges;

    // println!("Extended tile: {:?}", extended_tile);
    // println!("Initial edge state: {:?}", initial_edge_state);
    // println!("State: {:?}", state);
    // println!("Tile position: {:?}", tile_position);
    // println!("Row: {:?}", row);
    // println!("Col: {:?}", col);
    // println!("Side: {:?}", side);
    //connect bottom edge
    if *edges.at(2) == TEdge::R {
        let edge_pos = find(ref world, ref road_nodes, convert_board_position_to_node_position(tile_position, 2));
        // println!("Edge pos: {:?}", edge_pos);
        // let edge = find(ref world, board_id, edge_pos);
        // println!("Edge before: {:?}", edge);
        if row != 0 {
            if !visited.get((tile_position - 1).into()) {
 
                let down_edge_pos = convert_board_position_to_node_position(tile_position - 1, 0);
                
                let (tile, rotation, _) = *state.at((tile_position - 1).into());
                let extended_down_tile = create_extended_tile(tile.into(), rotation);
                if *extended_down_tile.edges.at(0) == (TEdge::R).into() {
                    union(ref world, ref road_nodes, down_edge_pos, edge_pos, false);
                    roads_connected.append(edge_pos);
                }
            }
        } // tile is connected to bottom edge
        else {
            let mut edge = road_nodes.at(edge_pos.into());
            edge.open_edges -= 1;
            if *initial_edge_state.at(col.into()) == TEdge::R.into() {
                if side == (PlayerSide::Blue).into() {
                    edge.blue_points += 1;
                } else {
                    edge.red_points += 1;
                }
            }
            road_nodes.set(edge_pos.into(), edge);
            roads_connected.append(edge_pos)
        }
        // println!("Edge after: {:?}", find(ref world, board_id, edge_pos));
    }


    //connect top edge
    if *edges.at(0) == TEdge::R {
        let edge_pos = find(ref world, ref road_nodes, convert_board_position_to_node_position(tile_position, 0));
        // println!("Edge pos: {:?}", edge_pos);
        // let edge = find(ref world, board_id, edge_pos);
        // println!("Edge before: {:?}", edge);
        if row != 7 {
            if !visited.get((tile_position + 1).into()) {
                let up_edge_pos = convert_board_position_to_node_position(tile_position + 1, 2);

                let (tile, rotation, _) = *state.at((tile_position + 1).into());
                let extended_up_tile = create_extended_tile(tile.into(), rotation);
                if *extended_up_tile.edges.at(2) == (TEdge::R).into() {
                    union(ref world, ref road_nodes, up_edge_pos, edge_pos, false);
                    roads_connected.append(edge_pos);
                }
            }
        } // tile is connected to top edge
        else  {
            let mut edge = road_nodes.at(edge_pos.into());
            edge.open_edges -= 1;
            if *initial_edge_state.at((23 - col).into()) == TEdge::R.into() {   
                if side == (PlayerSide::Blue).into() {
                    edge.blue_points += 1;
                } else {
                    edge.red_points += 1;
                }
            }
            road_nodes.set(edge_pos.into(), edge);
            roads_connected.append(edge_pos);
        }
        // println!("Edge after: {:?}", find(ref world, board_id, edge_pos));
    }

    //connect left edge
    if *edges.at(3) == TEdge::R {
        let edge_pos = find(ref world, ref road_nodes, convert_board_position_to_node_position(tile_position, 3));
        // println!("Edge pos: {:?}", edge_pos);
        // let edge = find(ref world, board_id, edge_pos);
        // println!("Edge before: {:?}", edge);
        // println!("1");
        if col != 0 {
            if !visited.get((tile_position - 8).into()) {
            // println!("2");
                let left_edge_pos = convert_board_position_to_node_position(tile_position - 8, 1);

                let (tile, rotation, _) = *state.at((tile_position - 8).into());
                let extended_left_tile = create_extended_tile(tile.into(), rotation);
                if *extended_left_tile.edges.at(1) == (TEdge::R).into() {
                    // println!("3");
                    union(ref world, ref road_nodes, left_edge_pos, edge_pos, false);
                    // println!("4");
                    roads_connected.append(edge_pos);
                }
            }
        } // tile is connected to left edge
        else {
            // println!("5");
            let mut edge = road_nodes.at(edge_pos.into());
            // println!("6");
            //print all the information
            edge.open_edges -= 1;
            // println!("7");
            if *initial_edge_state.at((31 - row).into()) == TEdge::R.into() {
                if side == (PlayerSide::Blue).into() {
                    edge.blue_points += 1;
                } else {
                    edge.red_points += 1;
                }
            }
            road_nodes.set(edge_pos.into(), edge);
            roads_connected.append(edge_pos);
        }
        // println!("Edge after: {:?}", find(ref world, board_id, edge_pos));
    }


    //connect right edge
    if *edges.at(1) == TEdge::R {
        let edge_pos = find(ref world, ref road_nodes, convert_board_position_to_node_position(tile_position, 1));
        // println!("Edge pos: {:?}", edge_pos);
        // let edge = find(ref world, board_id, edge_pos);
        // println!("Edge before: {:?}", edge);
        if col != 7 {
            if !visited.get((tile_position + 8).into()) {
                let right_edge_pos = convert_board_position_to_node_position(tile_position + 8, 3);

                let (tile, rotation, _) = *state.at((tile_position + 8).into());
                let extended_right_tile = create_extended_tile(tile.into(), rotation);
                if *extended_right_tile.edges.at(3) == (TEdge::R).into() {
                    union(ref world, ref road_nodes, right_edge_pos, edge_pos, false);
                    roads_connected.append(edge_pos);
                }
            }
        } // tile is connected to right edge
        else {
            let mut edge = road_nodes.at(edge_pos.into());
            edge.open_edges -= 1;
            if *initial_edge_state.at((8 + row).into()) == TEdge::R.into() {
                if side == (PlayerSide::Blue).into() {
                    edge.blue_points += 1;
                } else {
                    edge.red_points += 1;
                }
            } 
            road_nodes.set(edge_pos.into(), edge);
            roads_connected.append(edge_pos);
        }
        // println!("Edge after: {:?}", find(ref world, board_id, edge_pos));
    }


    let tile_roads_number = tile_roads_number(tile.into());

    let mut contest_results: Array<Option<(PlayerSide, u16)>> = ArrayTrait::new();
    if tile_roads_number != 2 || tile == Tile::CRCR.into() {
        for i in 0..roads_connected.len() {
            let mut road_root_pos = find(ref world, ref road_nodes, *roads_connected.at(i));
            let mut road_root = road_nodes.at(road_root_pos.into());
            if road_root.open_edges == 0 {
                let contest_result = handle_contest(ref world, ref road_nodes, road_root_pos, board_id);
                if contest_result.is_some() {
                    contest_results.append(contest_result);
                }
            }
        }
    } else if roads_connected.len() > 0 {
        let mut road_root_pos = find(ref world, ref road_nodes, *roads_connected.at(0));
        let mut road_root = road_nodes.at(road_root_pos.into());
        if road_root.open_edges == 0 {
            let contest_result: Option<(PlayerSide, u16)> = handle_contest(ref world, ref road_nodes, road_root_pos, board_id);
            if contest_result.is_some() {
                contest_results.append(contest_result);
            }
        }
    }


    // Update potential road contests
    if tile_roads_number.into() > roads_connected.len() {
        let mut roots = potential_road_contests;
        for i in 0..4_u8 {
            if *extended_tile.edges.at(i.into()) == (TEdge::R).into() {
                let node_pos = find(
                    ref world, ref road_nodes, convert_board_position_to_node_position(tile_position, i),
                );
                let mut found = false;
                for j in 0..roots.len() {
                    if *roots.at(j) == node_pos {
                        found = true;
                        break;
                    }
                };
                if !found {
                    roots.append(node_pos);
                }
            }
        };
        potential_road_contests = roots;
    }

    return contest_results.span();
}

pub fn handle_contest(
    ref world: WorldStorage, ref nodes: NullableVec<UnionNode>, mut road_root_pos: u8, board_id: felt252,
) -> Option<(PlayerSide, u16)> {
    let mut road_root = nodes.at(road_root_pos.into());
    road_root.contested = true;
    let mut result = Option::None;
    if road_root.blue_points > road_root.red_points {
        world
            .emit_event(
                @RoadContestWon {
                    board_id: board_id,
                    root: road_root_pos,
                    winner: PlayerSide::Blue,
                    red_points: road_root.red_points,
                    blue_points: road_root.blue_points,
                },
            );
        let winner = PlayerSide::Blue;
        let points_delta = road_root.red_points;
        road_root.blue_points += road_root.red_points;
        road_root.red_points = 0;
        result = Option::Some((winner, points_delta));
    } else if road_root.blue_points < road_root.red_points {
        world
            .emit_event(
                @RoadContestWon {
                    board_id: board_id,
                    root: road_root_pos,
                    winner: PlayerSide::Red,
                    red_points: road_root.red_points,
                    blue_points: road_root.blue_points,
                },
            );
        let winner = PlayerSide::Red;
        let points_delta = road_root.blue_points;
        road_root.red_points += road_root.blue_points;
        road_root.blue_points = 0;
        result = Option::Some((winner, points_delta));
    } else {
        world
            .emit_event(
                @RoadContestDraw {
                    board_id: board_id,
                    root: road_root_pos,
                    red_points: road_root.red_points,
                    blue_points: road_root.blue_points,
                },
            );
        result = Option::None;
    }

    nodes.set(road_root_pos.into(), road_root);

    return result;
}

pub fn close_all_roads(
    ref world: WorldStorage, potential_road_contests: Span<u8>, ref nodes: NullableVec<UnionNode>, board_id: felt252,
) -> Span<Option<(PlayerSide, u16)>> {
    let roots = potential_road_contests;
    let mut contest_results = ArrayTrait::new();
    for i in 0..roots.len() {
        let root_pos: u8 = find(ref world, ref nodes, *roots.at(i));
        let mut root = nodes.at(root_pos.into());
        if !root.contested {
            let contest_result = handle_contest(ref world, ref nodes, root_pos, board_id);
            contest_results.append(contest_result);
        }
    };
    return contest_results.span();
}


// #[cfg(test)]
// #[allow(unused_imports)]
// mod tests {
//     use super::*;
//     use dojo_cairo_test::WorldStorageTestTrait;
//     use dojo::model::{ModelStorage};
//     use dojo::world::WorldStorageTrait;
//     use dojo_cairo_test::{spawn_test_world, NamespaceDef, TestResource, ContractDef};

//     use evolute_duel::{
//         models::{RoadNode, m_RoadNode, PotentialRoadContests, m_PotentialRoadContests},
//         events::{RoadContestWon, e_RoadContestWon, RoadContestDraw, e_RoadContestDraw},
//         packing::{Tile, TEdge, PlayerSide},
//         systems::helpers::{board::generate_initial_board_state, road_union_find::{connected}},
//     };
//     use evolute_duel::systems::game::{};

//     fn namespace_def() -> NamespaceDef {
//         NamespaceDef {
//             namespace: "evolute_duel",
//             resources: [
//                 TestResource::Model(m_RoadNode::TEST_CLASS_HASH),
//                 TestResource::Model(m_PotentialRoadContests::TEST_CLASS_HASH),
//                 TestResource::Event(e_RoadContestWon::TEST_CLASS_HASH),
//                 TestResource::Event(e_RoadContestDraw::TEST_CLASS_HASH),
//             ]
//                 .span(),
//         }
//     }

//     fn contract_defs() -> Span<ContractDef> {
//         [].span()
//     }

//     #[test]
//     fn test_no_rotation() {
//         let tile = Tile::CCCF;
//         let extended = create_extended_tile(tile, 0);
//         assert_eq!(extended.edges, [TEdge::C, TEdge::C, TEdge::C, TEdge::F].span());
//     }

//     #[test]
//     fn test_rotation_90() {
//         let tile = Tile::CCCF;
//         let extended = create_extended_tile(tile, 1);
//         assert_eq!(extended.edges, [TEdge::F, TEdge::C, TEdge::C, TEdge::C].span());
//     }

//     #[test]
//     fn test_rotation_180() {
//         let tile = Tile::CCCF;
//         let extended = create_extended_tile(tile, 2);
//         assert_eq!(extended.edges, [TEdge::C, TEdge::F, TEdge::C, TEdge::C].span());
//     }

//     #[test]
//     fn test_rotation_270() {
//         let tile = Tile::CCCF;
//         let extended = create_extended_tile(tile, 3);
//         assert_eq!(extended.edges, [TEdge::C, TEdge::C, TEdge::F, TEdge::C].span());
//     }

//     #[test]
//     fn test_connect_road_edges_in_tile() {
//         // Initialize test environment
//         let ndef = namespace_def();

//         // Register the resources.
//         let mut world = spawn_test_world([ndef].span());

//         // Ensures permissions and initializations are synced.
//         world.sync_perms_and_inits(contract_defs());

//         let board_id = 1;
//         let tile_position = 2; // Arbitrary tile position

//         // Create a tile with all edges as road (CCCC)
//         let tile = Tile::FRFR;
//         let rotation = 0;
//         let side = PlayerSide::Blue;

//         // Call function to connect road edges
//         connect_road_edges_in_tile(
//             ref world, board_id, tile_position, tile.into(), rotation, side.into(),
//         );

//         // Verify all road edges are connected
//         let base_pos = convert_board_position_to_node_position(tile_position, 0);
//         let root = find(ref world, board_id, base_pos).position;
//         let _road_node: RoadNode = world.read_model((board_id, base_pos + 2));

//         //println!("Root1: {:?}", find(ref world, board_id, base_pos));
//         //println!("Root2: {:?}", road_node);

//         for i in 0..4_u8 {
//             if i % 2 == 1 {
//                 continue;
//             }
//             let edge_pos = convert_board_position_to_node_position(tile_position, i);
//             assert_eq!(
//                 find(ref world, board_id, edge_pos).position,
//                 root,
//                 "Road edge {} is not connected correctly",
//                 edge_pos,
//             );
//         };
//     }

//     #[test]
//     fn test_connect_adjacent_road_edges() {
//         let ndef = namespace_def();

//         let mut world = spawn_test_world([ndef].span());
//         world.sync_perms_and_inits(contract_defs());

//         let board_id = 1;

//         let tile_position_1 = 10;
//         let tile_position_2 = 18;

//         let tile_1 = Tile::FRFR;
//         let tile_2 = Tile::FRFR;
//         let rotation = 0;
//         let side = PlayerSide::Blue;

//         let mut initial_edge_state = generate_initial_board_state(1, 1, board_id);

//         connect_road_edges_in_tile(
//             ref world, board_id, tile_position_1, tile_1.into(), rotation, side.into(),
//         );
//         connect_road_edges_in_tile(
//             ref world, board_id, tile_position_2, tile_2.into(), rotation, side.into(),
//         );

//         let mut state = ArrayTrait::new();
//         for i in 0..64_u8 {
//             if i == tile_position_1 {
//                 state.append((tile_1.into(), rotation, side.into()));
//             } else if i == tile_position_2 {
//                 state.append((tile_2.into(), rotation, side.into()));
//             } else {
//                 state.append((Tile::Empty.into(), 0, 0));
//             }
//         };

//         let mut visited: Felt252Dict<bool> = Default::default();

//         connect_adjacent_road_edges(
//             ref world,
//             board_id,
//             ref state,
//             ref initial_edge_state,
//             tile_position_1,
//             tile_1.into(),
//             rotation,
//             side.into(),
//             ref visited,
//         );

//         connect_adjacent_road_edges(
//             ref world,
//             board_id,
//             ref state,
//             ref initial_edge_state,
//             tile_position_2,
//             tile_2.into(),
//             rotation,
//             side.into(),
//             ref visited,
//         );

//         let edge_pos_1 = convert_board_position_to_node_position(tile_position_1, 1);
//         let edge_pos_2 = convert_board_position_to_node_position(tile_position_2, 3);

//         assert!(
//             connected(ref world, board_id, edge_pos_1, edge_pos_2),
//             "Adjacent edges {} and {} are not connected correctly",
//             edge_pos_1,
//             edge_pos_2,
//         );
//     }

//     #[test]
//     fn test_connect_adjacent_road_edges_contest() {
//         let ndef = namespace_def();

//         let mut world = spawn_test_world([ndef].span());
//         world.sync_perms_and_inits(contract_defs());

//         let board_id = 1;

//         let tile_position_1 = 10; // CCFF 
//         let tile_position_2 = 11; // FCCF
//         let tile_position_3 = 19; // FFCC
//         let tile_position_4 = 18; // CFFC

//         let tile_1 = Tile::FFRR;
//         let tile_2 = Tile::FFRR;
//         let tile_3 = Tile::FFRR;
//         let tile_4 = Tile::FFRR;
//         let rotation1 = 2;
//         let rotation2 = 3;
//         let rotation3 = 0;
//         let rotation4 = 1;
//         let side1 = PlayerSide::Blue;
//         let side2 = PlayerSide::Red;
//         let side3 = PlayerSide::Blue;
//         let side4 = PlayerSide::Blue;

//         let mut initial_edge_state = generate_initial_board_state(1, 1, board_id);

//         connect_road_edges_in_tile(
//             ref world, board_id, tile_position_1, tile_1.into(), rotation1, side1.into(),
//         );

//         let root1 = find(
//             ref world, board_id, convert_board_position_to_node_position(tile_position_1, 0),
//         );
//         assert_eq!(root1.open_edges, 2, "Road contest is not conducted correctly");
//         //println!("Root1: {:?}", root1);

//         connect_road_edges_in_tile(
//             ref world, board_id, tile_position_2, tile_2.into(), rotation2, side2.into(),
//         );

//         let root2 = find(
//             ref world, board_id, convert_board_position_to_node_position(tile_position_2, 1),
//         );
//         assert_eq!(root2.open_edges, 2, "Road contest is not conducted correctly");
//         //println!("Root2: {:?}", root2);

//         connect_road_edges_in_tile(
//             ref world, board_id, tile_position_3, tile_3.into(), rotation3, side3.into(),
//         );

//         let root3 = find(
//             ref world, board_id, convert_board_position_to_node_position(tile_position_3, 2),
//         );
//         assert_eq!(root3.open_edges, 2, "Road contest is not conducted correctly");
//         //println!("Root3: {:?}", root3);

//         connect_road_edges_in_tile(
//             ref world, board_id, tile_position_4, tile_4.into(), rotation4, side4.into(),
//         );

//         let root4 = find(
//             ref world, board_id, convert_board_position_to_node_position(tile_position_4, 3),
//         );
//         assert_eq!(root4.open_edges, 2, "Road contest is not conducted correctly");
//         //println!("Root4: {:?}", root4);

//         let mut state = ArrayTrait::new();
//         for i in 0..64_u8 {
//             if i == tile_position_1 {
//                 state.append((tile_1.into(), rotation1, side1.into()));
//             } else {
//                 state.append((Tile::Empty.into(), 0, 0));
//             }
//         };

//         let mut visited: Felt252Dict<bool> = Default::default();

//         connect_adjacent_road_edges(
//             ref world,
//             board_id,
//             ref state,
//             ref initial_edge_state,
//             tile_position_1,
//             tile_1.into(),
//             rotation1,
//             side1.into(),
//             ref visited,
//         );

//         let rot1 = find(
//             ref world, board_id, convert_board_position_to_node_position(tile_position_1, 0),
//         );
//         //println!("Rot1: {:?}", rot1);
//         assert_eq!(rot1.open_edges, 2, "Road contest is not conducted correctly");

//         let mut state = ArrayTrait::new();
//         for i in 0..64_u8 {
//             if i == tile_position_1 {
//                 state.append((tile_1.into(), rotation1, side1.into()));
//             } else if i == tile_position_2 {
//                 state.append((tile_2.into(), rotation2, side2.into()));
//             } else {
//                 state.append((Tile::Empty.into(), 0, 0));
//             }
//         };

//         connect_adjacent_road_edges(
//             ref world,
//             board_id,
//             ref state,
//             ref initial_edge_state,
//             tile_position_2,
//             tile_2.into(),
//             rotation2,
//             side2.into(),
//             ref visited,
//         );

//         let rot2 = find(
//             ref world, board_id, convert_board_position_to_node_position(tile_position_2, 1),
//         );
//         //println!("Rot2: {:?}", rot2);
//         assert_eq!(rot2.open_edges, 2, "Road contest is not conducted correctly");

//         let mut state = ArrayTrait::new();
//         for i in 0..64_u8 {
//             if i == tile_position_1 {
//                 state.append((tile_1.into(), rotation1, side1.into()));
//             } else if i == tile_position_2 {
//                 state.append((tile_2.into(), rotation2, side2.into()));
//             } else if i == tile_position_3 {
//                 state.append((tile_3.into(), rotation3, side3.into()));
//             } else {
//                 state.append((Tile::Empty.into(), 0, 0));
//             }
//         };

//         connect_adjacent_road_edges(
//             ref world,
//             board_id,
//             ref state,
//             ref initial_edge_state,
//             tile_position_3,
//             tile_3.into(),
//             rotation3,
//             side3.into(),
//             ref visited,
//         );

//         let rot3 = find(
//             ref world, board_id, convert_board_position_to_node_position(tile_position_3, 2),
//         );
//         //println!("Rot3: {:?}", rot3);
//         assert_eq!(rot3.open_edges, 2, "Road contest is not conducted correctly");

//         let mut state = ArrayTrait::new();
//         for i in 0..64_u8 {
//             if i == tile_position_1 {
//                 state.append((tile_1.into(), rotation1, side1.into()));
//             } else if i == tile_position_2 {
//                 state.append((tile_2.into(), rotation2, side2.into()));
//             } else if i == tile_position_3 {
//                 state.append((tile_3.into(), rotation3, side3.into()));
//             } else if i == tile_position_4 {
//                 state.append((tile_4.into(), rotation4, side4.into()));
//             } else {
//                 state.append((Tile::Empty.into(), 0, 0));
//             }
//         };

//         connect_adjacent_road_edges(
//             ref world,
//             board_id,
//             ref state,
//             ref initial_edge_state,
//             tile_position_4,
//             tile_4.into(),
//             rotation4,
//             side4.into(),
//             ref visited,
//         );

//         let rot4 = find(
//             ref world, board_id, convert_board_position_to_node_position(tile_position_4, 3),
//         );
//         //println!("Rot4: {:?}", rot4);
//         assert_eq!(rot4.open_edges, 0, "Road contest is not conducted correctly");

//         // 1 and 2
//         let edge_pos_1 = convert_board_position_to_node_position(tile_position_1, 0);
//         let edge_pos_2 = convert_board_position_to_node_position(tile_position_2, 2);

//         assert!(
//             connected(ref world, board_id, edge_pos_1, edge_pos_2),
//             "Adjacent edges {} and {} are not connected correctly",
//             edge_pos_1,
//             edge_pos_2,
//         );

//         // 2 and 3
//         let edge_pos_2 = convert_board_position_to_node_position(tile_position_2, 1);
//         let edge_pos_3 = convert_board_position_to_node_position(tile_position_3, 3);

//         assert!(
//             connected(ref world, board_id, edge_pos_2, edge_pos_3),
//             "Adjacent edges {} and {} are not connected correctly",
//             edge_pos_2,
//             edge_pos_3,
//         );

//         // 3 and 4
//         let edge_pos_3 = convert_board_position_to_node_position(tile_position_3, 2);
//         let edge_pos_4 = convert_board_position_to_node_position(tile_position_4, 0);

//         assert!(
//             connected(ref world, board_id, edge_pos_3, edge_pos_4),
//             "Adjacent edges {} and {} are not connected correctly",
//             edge_pos_3,
//             edge_pos_4,
//         );

//         // 4 and 1
//         let edge_pos_4 = convert_board_position_to_node_position(tile_position_4, 3);
//         let edge_pos_1 = convert_board_position_to_node_position(tile_position_1, 1);

//         assert!(
//             connected(ref world, board_id, edge_pos_4, edge_pos_1),
//             "Adjacent edges {} and {} are not connected correctly",
//             edge_pos_4,
//             edge_pos_1,
//         );

//         let road_root = find(ref world, board_id, edge_pos_1);
//         assert_eq!(road_root.open_edges, 0, "Road contest is not conducted correctly");
//     }
// }
