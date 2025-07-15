use dojo::model::ModelStorage;
use dojo::event::EventStorage;
use evolute_duel::{
    events::{CityContestWon, CityContestDraw, RoadContestWon, RoadContestDraw},
    systems::helpers::{
        union_find::{find, union}, board::{},
        tile_helpers::{
            create_extended_tile, convert_board_position_to_node_position,
        },
    },
    types::packing::{TEdge, PlayerSide, Tile},
    models::scoring::{UnionNode, PotentialContests},
};
use dojo::world::{WorldStorage};

use evolute_duel::libs::{achievements::{AchievementsTrait}};
use starknet::ContractAddress;

pub fn connect_edges_in_tile(
    mut world: WorldStorage,
    board_id: felt252,
    col: u32,
    row: u32,
    tile: u8,
    rotation: u8,
    board_size: u32,
    side: PlayerSide,
) -> (u16, u16) {
    let extended_tile = create_extended_tile(tile.into(), rotation);

    let mut cities: Array<u32> = ArrayTrait::new();
    let mut roads: Array<u32> = ArrayTrait::new();
    for i in 0..4_u8 {
        let node_type = *extended_tile.edges.at(i.into());
        let points = match node_type {
            TEdge::C => 2_u16,
            TEdge::R => 1_u16,
            _ => 0_u16,
        };
        let position = convert_board_position_to_node_position(col, row, i, board_size);
        
        match node_type {
            TEdge::C => cities.append(position),
            TEdge::R => roads.append(position),
            _ => {},
        };

        let mut open_edges = 1;
        let blue_points = if side == (PlayerSide::Blue).into() {
            points
        } else {
            0
        };
        let red_points = if side == (PlayerSide::Red).into() {
            points
        } else {
            0
        };
        let node = UnionNode {
            board_id,
            position: position,
            parent: position,
            rank: 1,
            blue_points,
            red_points,
            open_edges,
            contested: false,
            node_type,
            player_side: side,
        };
        world.write_model(@node);
    };

    if cities.len() > 1 {
        for i in 1..cities.len() {
            union(world, board_id, *cities.at(0), *cities.at(i), true);
        }
    }

    if roads.len() == 2 && tile != Tile::CRCR.into() {
        union(world, board_id, *roads.at(0), *roads.at(1), true);
    }

    (cities.len().try_into().unwrap() * 2, roads.len().try_into().unwrap())
}

pub fn connect_adjacent_edges(
    mut world: WorldStorage,
    board_id: felt252,
    col: u32,
    row: u32,
    tile: u8,
    rotation: u8,
    board_size: u32,
    player_side: PlayerSide,
    player_address: ContractAddress,
) //None - if no contest or draw, Some(u8, u16) -> (who_wins, points_delta) - if contest
-> ((i16, i16), (i16, i16)) {
    let extended_tile = create_extended_tile(tile.into(), rotation);
    let mut city_root: Option<u32> = Option::None;
    let mut road_roots: Array<u32> = ArrayTrait::new();
    let edges = extended_tile.edges;
    
    let direction_offsets = array![
        4 + 2, // Up
        board_size.try_into().unwrap() * 4 + 2, // Right
        -4 - 2, // Down
        -board_size.try_into().unwrap() * 4 - 2, // Left
    ];
    let tile_position: u32 = col.into() * 10 + row.into();
    let mut city_points_for_initial_nodes: u16 = 0;
    let mut road_points_for_initial_nodes: u16 = 0;

    for side in 0..4_u8 {
        let node_type = *edges.at(side.into());

        if node_type == TEdge::None || node_type == TEdge::F {
            continue;
        }

        let offset: i32 = *direction_offsets[side.into()];
        let node_position: u32 = tile_position * 4 + side.into();
        let adjacent_node_position: u32 = (node_position.try_into().unwrap() + offset).try_into().unwrap();
        let mut adjacent_node: UnionNode = world.read_model((board_id, adjacent_node_position));
        if adjacent_node.node_type == TEdge::None {
            // No tile placed in this position
            continue;
        } //If initial tile 
        else if adjacent_node.open_edges == 1 && adjacent_node.player_side == PlayerSide::None {
            adjacent_node.player_side = player_side;
            let points = match adjacent_node.node_type {
                TEdge::C => {
                    let points = 2_u16;
                    city_points_for_initial_nodes += points;
                    points
                },
                TEdge::R => {
                    let points = 1_u16;
                    road_points_for_initial_nodes += points;
                    points
                },
                _ => 0_u16,
            };
            match player_side {
                PlayerSide::Blue => {
                    adjacent_node.blue_points += points;
                },
                PlayerSide::Red => {
                    adjacent_node.red_points += points;
                },
                _ => {}
            }
            world.write_model(@adjacent_node);
        }


        let root = union(
            world,
            board_id,
            node_position,
            adjacent_node_position,
            false,
        );


        if node_type == TEdge::C {
            city_root = Option::Some(root.position);
        } else if node_type == TEdge::R {
            let mut contains = false;
            for i in 0..road_roots.len() {
                if *road_roots.at(i) == root.position {
                    contains = true;
                    break;
                }
            };
            if !contains {road_roots.append(root.position);}
        }
    };

    let mut city_contest_result = Option::None;
    if city_root.is_some() {
        let mut city_root: UnionNode = world.read_model((board_id, city_root.unwrap()));
        if city_root.open_edges == 0 && !city_root.contested {
            city_contest_result = handle_contest(world, ref city_root);
            //[Achivement] CityBuilder
            AchievementsTrait::build_city(
                world, player_address, ((city_root.red_points + city_root.blue_points) / 2).into(),
            );
        }
    }

    let mut road_contest_results = ArrayTrait::new();
    for road_root_position in road_roots {
        let mut road_root: UnionNode = world.read_model((board_id, road_root_position));
        if road_root.open_edges == 0 && !road_root.contested {
            let contest_result = handle_contest(world, ref road_root);
            road_contest_results.append(contest_result);

            // [Achievement] RoadBuilder
            AchievementsTrait::build_road(
                world,
                player_address,
                (road_root.red_points + road_root.blue_points).into(),
            );
        }
    };


    // Update potential contests
    let mut potential_contests_model: PotentialContests = world.read_model(board_id);
    for side in 0..4_u8 {
        let node_position: u32 = tile_position * 4 + side.into();
        let root_pos = find(world, board_id, node_position);
        let mut root: UnionNode = world.read_model((board_id, root_pos));
        if !root.contested {
            let mut found = false;
            for j in 0..potential_contests_model.potential_contests.len() {
                if *potential_contests_model.potential_contests.at(j) == root_pos {
                    found = true;
                    break;
                }
            };
            if !found {
                potential_contests_model.potential_contests.append(root_pos);
            }
        }
    };
    world.write_model(@potential_contests_model);

    let (mut blue_city_points_delta, mut red_city_points_delta) = (0, 0);
    let (mut blue_road_points_delta, mut red_road_points_delta) = (0, 0);

    if player_side == PlayerSide::Blue {
        blue_city_points_delta += city_points_for_initial_nodes.try_into().unwrap();
        blue_road_points_delta += road_points_for_initial_nodes.try_into().unwrap();
    } else if player_side == PlayerSide::Red {
        red_city_points_delta += city_points_for_initial_nodes.try_into().unwrap();
        red_road_points_delta += road_points_for_initial_nodes.try_into().unwrap();
    }

    if city_contest_result.is_some() {
        let (winner, _, points_delta) = city_contest_result.unwrap();
        if winner == PlayerSide::Blue {
            blue_city_points_delta += points_delta.try_into().unwrap();
            red_city_points_delta -= points_delta.try_into().unwrap();
        } else if winner == PlayerSide::Red {
            red_city_points_delta += points_delta.try_into().unwrap();
            blue_city_points_delta -= points_delta.try_into().unwrap();
        }
    }

    for road_result in road_contest_results {
        if road_result.is_some() {
            let (winner, _, points_delta) = road_result.unwrap();
            if winner == PlayerSide::Blue {
                blue_road_points_delta += points_delta.try_into().unwrap();
                red_road_points_delta -= points_delta.try_into().unwrap();
            } else if winner == PlayerSide::Red {
                red_road_points_delta += points_delta.try_into().unwrap();
                blue_road_points_delta -= points_delta.try_into().unwrap();
            }
        }
    };

    ((blue_city_points_delta, blue_road_points_delta), (red_city_points_delta, red_road_points_delta))   
}


pub fn handle_contest(
    mut world: WorldStorage,
    ref root: UnionNode,
) -> Option<(PlayerSide, TEdge, u16)> {
    root.contested = true;
    let mut result = Option::None;
    let mut winner = PlayerSide::None;
    if root.blue_points > root.red_points {
        winner = PlayerSide::Blue;
        let points_delta = root.red_points;
        root.blue_points += root.red_points;
        root.red_points = 0;
        result = Option::Some((winner, root.node_type, points_delta));
    } else if root.blue_points < root.red_points {
        winner = PlayerSide::Red;
        let points_delta = root.blue_points;
        root.red_points += root.blue_points;
        root.blue_points = 0;
        result = Option::Some((winner, root.node_type, points_delta));
    }
    
    match root.node_type {
        TEdge::C => {
            if winner == PlayerSide::None {
                world.emit_event(@CityContestDraw {
                    board_id: root.board_id,
                    root: root.position,
                    red_points: root.red_points,
                    blue_points: root.blue_points,
                });
            } else {
                world.emit_event(@CityContestWon {
                    board_id: root.board_id,
                    root: root.position,
                    red_points: root.red_points,
                    blue_points: root.blue_points,
                    winner: winner,
                });
            }
        },
        TEdge::R => {
            if winner == PlayerSide::None {
                world.emit_event(@RoadContestDraw {
                    board_id: root.board_id,
                    root: root.position,
                    red_points: root.red_points,
                    blue_points: root.blue_points,
                });
            } else {
                world.emit_event(@RoadContestWon {
                    board_id: root.board_id,
                    root: root.position,
                    red_points: root.red_points,
                    blue_points: root.blue_points,
                    winner: winner,
                });
            }
        },
        _ => {}   
    }
    world.write_model(@root);
    return result;
}

pub fn close_all_nodes(
    world: WorldStorage,
    roots: Span<u32>,
    board_id: felt252,
) -> Span<Option<(PlayerSide, TEdge, u16)>> {
    let mut contest_results = ArrayTrait::new();
    for i in 0..roots.len() {
        let root_pos = find(world, board_id, *roots.at(i));
        let mut root: UnionNode = world.read_model((board_id, root_pos));
        if !root.contested {
            let contest_result = handle_contest(world, ref root);
            contest_results.append(contest_result);
        }
    };
    return contest_results.span();
}
// #[cfg(test)]
// mod tests {
//     use super::*;
//     use dojo_cairo_test::WorldStorageTestTrait;
//     use dojo::model::{ModelStorage};
//     use dojo::world::WorldStorageTrait;
//     use dojo_cairo_test::{spawn_test_world, NamespaceDef, TestResource, ContractDef};

//     use evolute_duel::{
//         models::{CityNode, m_CityNode, PotentialCityContests, m_PotentialCityContests},
//         events::{CityContestWon, e_CityContestWon, CityContestDraw, e_CityContestDraw},
//         packing::{Tile},
//         systems::helpers::{board::generate_initial_board_state, city_union_find::{connected}},
//     };
//     use evolute_duel::systems::game::{};

//     fn namespace_def() -> NamespaceDef {
//         NamespaceDef {
//             namespace: "evolute_duel",
//             resources: [
//                 TestResource::Model(m_CityNode::TEST_CLASS_HASH),
//                 TestResource::Model(m_PotentialCityContests::TEST_CLASS_HASH),
//                 TestResource::Event(e_CityContestWon::TEST_CLASS_HASH),
//                 TestResource::Event(e_CityContestDraw::TEST_CLASS_HASH),
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
//     fn test_connect_city_edges_in_tile() {
//         // Initialize test environment
//         let caller = starknet::contract_address_const::<0x0>();
//         let ndef = namespace_def();

//         // Register the resources.
//         let mut world = spawn_test_world([ndef].span());

//         // Ensures permissions and initializations are synced.
//         world.sync_perms_and_inits(contract_defs());

//         let board_id = 1;
//         let tile_position = 2; // Arbitrary tile position

//         // Create a tile with all edges as city (CCCC)
//         let tile = Tile::CFCF;
//         let rotation = 0;
//         let side = PlayerSide::Blue;

//         let initial_edge_state = generate_initial_board_state(1, 1, board_id);

//         // Call function to connect city edges
//         connect_city_edges_in_tile(
//             ref world, board_id, tile_position, tile.into(), rotation, side.into(),
//         );

//         // Verify all city edges are connected
//         let base_pos = convert_board_position_to_node_position(tile_position, 0);
//         let root = find(ref world, board_id, base_pos).position;
//         let city_node: CityNode = world.read_model((board_id, base_pos + 2));

//         //println!("Root1: {:?}", find(ref world, board_id, base_pos));
//         //println!("Root2: {:?}", city_node);

//         for i in 0..4_u8 {
//             if i % 2 == 1 {
//                 continue;
//             }
//             let edge_pos = convert_board_position_to_node_position(tile_position, i);
//             assert_eq!(
//                 find(ref world, board_id, edge_pos).position,
//                 root,
//                 "City edge {} is not connected correctly",
//                 edge_pos,
//             );
//         };
//     }

//     #[test]
//     fn test_connect_adjacent_city_edges() {
//         let caller = starknet::contract_address_const::<0x0>();
//         let ndef = namespace_def();

//         let mut world = spawn_test_world([ndef].span());
//         world.sync_perms_and_inits(contract_defs());

//         let board_id = 1;

//         let tile_position_1 = 10;
//         let tile_position_2 = 18;

//         let tile_1 = Tile::CFCF;
//         let tile_2 = Tile::CFCF;
//         let rotation = 1;
//         let side = PlayerSide::Blue;

//         let initial_edge_state = generate_initial_board_state(1, 1, board_id);

//         connect_city_edges_in_tile(
//             ref world, board_id, tile_position_1, tile_1.into(), rotation, side.into(),
//         );
//         connect_city_edges_in_tile(
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

//         connect_adjacent_city_edges(
//             ref world,
//             board_id,
//             state.clone(),
//             initial_edge_state.clone(),
//             tile_position_1,
//             tile_1.into(),
//             rotation,
//             side.into(),
//         );

//         connect_adjacent_city_edges(
//             ref world,
//             board_id,
//             state,
//             initial_edge_state.clone(),
//             tile_position_2,
//             tile_2.into(),
//             rotation,
//             side.into(),
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
//     fn test_connect_adjacent_city_edges_contest() {
//         let caller = starknet::contract_address_const::<0x0>();
//         let ndef = namespace_def();

//         let mut world = spawn_test_world([ndef].span());
//         world.sync_perms_and_inits(contract_defs());

//         let board_id = 1;

//         let tile_position_1 = 10; // CCFF
//         let tile_position_2 = 11; // FCCF
//         let tile_position_3 = 19; // FFCC
//         let tile_position_4 = 18; // CFFC

//         let tile_1 = Tile::CCFF;
//         let tile_2 = Tile::CCFF;
//         let tile_3 = Tile::CCFF;
//         let tile_4 = Tile::CCFF;
//         let rotation1 = 0;
//         let rotation2 = 1;
//         let rotation3 = 2;
//         let rotation4 = 3;
//         let side1 = PlayerSide::Blue;
//         let side2 = PlayerSide::Red;
//         let side3 = PlayerSide::Blue;
//         let side4 = PlayerSide::Blue;

//         let initial_edge_state = generate_initial_board_state(1, 1, board_id);

//         connect_city_edges_in_tile(
//             ref world, board_id, tile_position_1, tile_1.into(), rotation1, side1.into(),
//         );

//         let root1 = find(
//             ref world, board_id, convert_board_position_to_node_position(tile_position_1, 0),
//         );
//         assert_eq!(root1.open_edges, 2, "City contest is not conducted correctly");
//         //println!("Root1: {:?}", root1);

//         connect_city_edges_in_tile(
//             ref world, board_id, tile_position_2, tile_2.into(), rotation2, side2.into(),
//         );

//         let root2 = find(
//             ref world, board_id, convert_board_position_to_node_position(tile_position_2, 1),
//         );
//         assert_eq!(root2.open_edges, 2, "City contest is not conducted correctly");
//         //println!("Root2: {:?}", root2);

//         connect_city_edges_in_tile(
//             ref world, board_id, tile_position_3, tile_3.into(), rotation3, side3.into(),
//         );

//         let root3 = find(
//             ref world, board_id, convert_board_position_to_node_position(tile_position_3, 2),
//         );
//         assert_eq!(root3.open_edges, 2, "City contest is not conducted correctly");
//         //println!("Root3: {:?}", root3);

//         connect_city_edges_in_tile(
//             ref world, board_id, tile_position_4, tile_4.into(), rotation4, side4.into(),
//         );

//         let root4 = find(
//             ref world, board_id, convert_board_position_to_node_position(tile_position_4, 3),
//         );
//         assert_eq!(root4.open_edges, 2, "City contest is not conducted correctly");
//         //println!("Root4: {:?}", root4);

//         let mut state = ArrayTrait::new();
//         for i in 0..64_u8 {
//             if i == tile_position_1 {
//                 state.append((tile_1.into(), rotation1, side1.into()));
//             } else {
//                 state.append((Tile::Empty.into(), 0, 0));
//             }
//         };

//         connect_adjacent_city_edges(
//             ref world,
//             board_id,
//             state,
//             initial_edge_state.clone(),
//             tile_position_1,
//             tile_1.into(),
//             rotation1,
//             side1.into(),
//         );

//         let rot1 = find(
//             ref world, board_id, convert_board_position_to_node_position(tile_position_1, 0),
//         );
//         //println!("Rot1: {:?}", rot1);
//         assert_eq!(rot1.open_edges, 2, "City contest is not conducted correctly");

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

//         connect_adjacent_city_edges(
//             ref world,
//             board_id,
//             state.clone(),
//             initial_edge_state.clone(),
//             tile_position_2,
//             tile_2.into(),
//             rotation2,
//             side2.into(),
//         );

//         let rot2 = find(
//             ref world, board_id, convert_board_position_to_node_position(tile_position_2, 1),
//         );
//         //println!("Rot2: {:?}", rot2);
//         assert_eq!(rot2.open_edges, 2, "City contest is not conducted correctly");

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

//         connect_adjacent_city_edges(
//             ref world,
//             board_id,
//             state.clone(),
//             initial_edge_state.clone(),
//             tile_position_3,
//             tile_3.into(),
//             rotation3,
//             side3.into(),
//         );

//         let rot3 = find(
//             ref world, board_id, convert_board_position_to_node_position(tile_position_3, 2),
//         );
//         //println!("Rot3: {:?}", rot3);
//         assert_eq!(rot3.open_edges, 2, "City contest is not conducted correctly");

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

//         connect_adjacent_city_edges(
//             ref world,
//             board_id,
//             state,
//             initial_edge_state.clone(),
//             tile_position_4,
//             tile_4.into(),
//             rotation4,
//             side4.into(),
//         );

//         let rot4 = find(
//             ref world, board_id, convert_board_position_to_node_position(tile_position_4, 3),
//         );
//         //println!("Rot4: {:?}", rot4);
//         assert_eq!(rot4.open_edges, 0, "City contest is not conducted correctly");

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

//         let city_root = find(ref world, board_id, edge_pos_1);
//         assert_eq!(city_root.open_edges, 0, "City contest is not conducted correctly");
//     }

//     #[test]
//     fn test_contest_with_edge() {
//         let caller = starknet::contract_address_const::<0x0>();
//         let ndef = namespace_def();

//         let mut world = spawn_test_world([ndef].span());
//         world.sync_perms_and_inits(contract_defs());

//         let board_id = 1;

//         // City and road just on bottom edge
//         let initial_edge_state = array![
//             2,
//             2,
//             0,
//             2,
//             2,
//             2,
//             1,
//             2,
//             2,
//             2,
//             2,
//             2,
//             2,
//             2,
//             2,
//             2,
//             2,
//             2,
//             2,
//             2,
//             2,
//             2,
//             2,
//             2,
//             2,
//             2,
//             2,
//             2,
//             2,
//             2,
//             2,
//             2,
//         ];

//         let tile_1 = Tile::CFRR;
//         let col1 = 2;
//         let row1 = 0;
//         let tile_position_1 = col1 * 8 + row1;
//         let rotation1 = 2;
//         let side1 = PlayerSide::Blue;

//         connect_city_edges_in_tile(
//             ref world, board_id, tile_position_1, tile_1.into(), rotation1, side1.into(),
//         );

//         let root1 = find(
//             ref world, board_id, convert_board_position_to_node_position(tile_position_1, 2),
//         );

//         assert_eq!(root1.open_edges, 1, "City contest is not conducted correctly");

//         let mut state: Array<(u8, u8, u8)> = ArrayTrait::new();
//         state.append_span([((Tile::Empty).into(), 0, 0); 64].span());

//         let mut visited: Felt252Dict<bool> = Default::default();

//         let scoring_result = connect_adjacent_city_edges(
//             ref world,
//             board_id,
//             state.clone(),
//             initial_edge_state.clone(),
//             tile_position_1,
//             tile_1.into(),
//             rotation1,
//             side1.into(),
//         );

//         println!("{:?}", scoring_result);

//         let root2 = find(
//             ref world, board_id, convert_board_position_to_node_position(tile_position_1, 2),
//         );

//         println!("{:?}", root2);
//         assert_eq!(root2.open_edges, 0, "City contest is not conducted correctly");

//         for i in 0..64_u8 {
//             if i == tile_position_1 {
//                 state.append((tile_1.into(), rotation1, side1.into()));
//             } else {
//                 state.append((Tile::Empty.into(), 0, 0));
//             }
//         };
//     }
// }


