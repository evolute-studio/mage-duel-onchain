use dojo::event::EventStorage;
use dojo::model::ModelStorage;
use evolute_duel::{
    models::scoring::{CityNode, PotentialCityContests}, events::{CityContestWon, CityContestDraw},
    systems::helpers::{
        city_union_find::{find, union}, board::{},
        tile_helpers::{
            create_extended_tile, convert_board_position_to_node_position, tile_city_number,
        },
    },
    packing::{TEdge, PlayerSide},
};
use dojo::world::{WorldStorage};

pub fn connect_city_edges_in_tile(
    ref world: WorldStorage, board_id: felt252, tile_position: u8, tile: u8, rotation: u8, side: u8,
) {
    let extended_tile = create_extended_tile(tile.into(), rotation);

    let mut cities: Array<u8> = ArrayTrait::new();

    for i in 0..4_u8 {
        if *extended_tile.edges.at(i.into()) == (TEdge::C).into() {
            let mut open_edges = 1;
            let blue_points = if side == (PlayerSide::Blue).into() {
                2
            } else {
                0
            };
            let red_points = if side == (PlayerSide::Red).into() {
                2
            } else {
                0
            };
            let position = convert_board_position_to_node_position(tile_position, i);
            cities.append(position);
            let city_node = CityNode {
                board_id,
                parent: position,
                position: position,
                rank: 1,
                blue_points,
                red_points,
                open_edges,
                contested: false,
            };
            world.write_model(@city_node);
        }
    };

    if cities.len() > 1 {
        for i in 1..cities.len() {
            union(ref world, board_id, *cities.at(0), *cities.at(i), true);
        }
    }
}

pub fn connect_adjacent_city_edges(
    ref world: WorldStorage,
    board_id: felt252,
    state: Array<(u8, u8, u8)>,
    initial_edge_state: Array<u8>,
    tile_position: u8,
    tile: u8,
    rotation: u8,
    side: u8,
) //None - if no contest or draw, Some(u8, u16) -> (who_wins, points_delta) - if contest
-> Option<
    (PlayerSide, u16),
> {
    let extended_tile = create_extended_tile(tile.into(), rotation);
    let row = tile_position % 8;
    let col = tile_position / 8;
    let mut cities_connected: Array<u8> = ArrayTrait::new();
    let edges = extended_tile.edges;

    //connect bottom edge
    if *edges.at(2) == TEdge::C {
        let edge_pos = convert_board_position_to_node_position(tile_position, 2);
        if row != 0 {
            let down_edge_pos = convert_board_position_to_node_position(tile_position - 1, 0);
            let (tile, rotation, _) = *state.at((tile_position - 1).into());
            let extended_down_tile = create_extended_tile(tile.into(), rotation);
            if *extended_down_tile.edges.at(0) == (TEdge::C).into() {
                union(ref world, board_id, down_edge_pos, edge_pos, false);
                cities_connected.append(edge_pos);
            }
        } // tile is connected to bottom edge
        else if *initial_edge_state.at(col.into()) == TEdge::C.into() {
            let mut edge = find(ref world, board_id, edge_pos);
            edge.open_edges -= 1;
            if side == (PlayerSide::Blue).into() {
                edge.blue_points += 2;
            } else {
                edge.red_points += 2;
            }
            world.write_model(@edge);
            cities_connected.append(edge_pos);
        } else if *initial_edge_state.at(col.into()) == TEdge::M.into() {
            let mut edge = find(ref world, board_id, edge_pos);
            edge.open_edges -= 1;
            world.write_model(@edge);
            cities_connected.append(edge_pos);
        }
    }

    //connect top edge
    if *edges.at(0) == TEdge::C {
        let edge_pos = convert_board_position_to_node_position(tile_position, 0);
        if row != 7 {
            let up_edge_pos = convert_board_position_to_node_position(tile_position + 1, 2);

            let (tile, rotation, _) = *state.at((tile_position + 1).into());
            let extended_up_tile = create_extended_tile(tile.into(), rotation);
            if *extended_up_tile.edges.at(2) == (TEdge::C).into() {
                union(ref world, board_id, up_edge_pos, edge_pos, false);
                cities_connected.append(edge_pos);
            }
        } // tile is connected to top edge
        else if *initial_edge_state.at((23 - col).into()) == TEdge::C.into() {
            let mut edge = find(ref world, board_id, edge_pos);
            edge.open_edges -= 1;
            if side == (PlayerSide::Blue).into() {
                edge.blue_points += 2;
            } else {
                edge.red_points += 2;
            }
            world.write_model(@edge);
            cities_connected.append(edge_pos);
        } else if *initial_edge_state.at((23 - col).into()) == TEdge::M.into() {
            let mut edge = find(ref world, board_id, edge_pos);
            edge.open_edges -= 1;
            world.write_model(@edge);
            cities_connected.append(edge_pos);
        }
    }

    //connect left edge
    if *edges.at(3) == TEdge::C {
        let edge_pos = convert_board_position_to_node_position(tile_position, 3);
        if col != 0 {
            let left_edge_pos = convert_board_position_to_node_position(tile_position - 8, 1);

            let (tile, rotation, _) = *state.at((tile_position - 8).into());
            let extended_left_tile = create_extended_tile(tile.into(), rotation);
            if *extended_left_tile.edges.at(1) == (TEdge::C).into() {
                union(ref world, board_id, left_edge_pos, edge_pos, false);
                cities_connected.append(edge_pos);
            }
        } // tile is connected to left edge
        else if *initial_edge_state.at((31 - row).into()) == TEdge::C.into() {
            let mut edge = find(ref world, board_id, edge_pos);
            edge.open_edges -= 1;
            if side == (PlayerSide::Blue).into() {
                edge.blue_points += 2;
            } else {
                edge.red_points += 2;
            }
            world.write_model(@edge);
            cities_connected.append(edge_pos);
        } else if *initial_edge_state.at((31 - row).into()) == TEdge::M.into() {
            let mut edge = find(ref world, board_id, edge_pos);
            edge.open_edges -= 1;
            world.write_model(@edge);
            cities_connected.append(edge_pos);
        }
    }

    //connect right edge
    if *edges.at(1) == TEdge::C {
        let edge_pos = convert_board_position_to_node_position(tile_position, 1);
        if col != 7 {
            let right_edge_pos = convert_board_position_to_node_position(tile_position + 8, 3);

            let (tile, rotation, _) = *state.at((tile_position + 8).into());
            let extended_right_tile = create_extended_tile(tile.into(), rotation);
            if *extended_right_tile.edges.at(3) == (TEdge::C).into() {
                union(ref world, board_id, right_edge_pos, edge_pos, false);
                cities_connected.append(edge_pos);
            }
        } // tile is connected to right edge
        else if *initial_edge_state.at((8 + row).into()) == TEdge::C.into() {
            let mut edge = find(ref world, board_id, edge_pos);
            edge.open_edges -= 1;
            if side == (PlayerSide::Blue).into() {
                edge.blue_points += 2;
            } else {
                edge.red_points += 2;
            }
            world.write_model(@edge);
            cities_connected.append(edge_pos);
        } else if *initial_edge_state.at((8 + row).into()) == TEdge::M.into() {
            let mut edge = find(ref world, board_id, edge_pos);
            edge.open_edges -= 1;
            world.write_model(@edge);
            cities_connected.append(edge_pos);
        }
    }

    let mut contest_result = Option::None;
    if cities_connected.len() > 0 {
        let mut city_root = find(ref world, board_id, *cities_connected.at(0));
        if city_root.open_edges == 0 {
            contest_result = handle_city_contest(ref world, city_root);
        }
    }

    // Update potential city contests
    let city_number = tile_city_number(tile.into());
    if city_number.into() > cities_connected.len() {
        let mut potential_cities: PotentialCityContests = world.read_model(board_id);
        let mut roots = potential_cities.roots;
        for i in 0..4_u8 {
            if *extended_tile.edges.at(i.into()) == (TEdge::C).into() {
                let node_pos = find(
                    ref world, board_id, convert_board_position_to_node_position(tile_position, i),
                )
                    .position;
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
        potential_cities.roots = roots;
        world.write_model(@potential_cities);
    }

    return contest_result;
}

pub fn handle_city_contest(
    ref world: WorldStorage, mut city_root: CityNode,
) -> Option<(PlayerSide, u16)> {
    city_root.contested = true;
    let mut result: Option<(PlayerSide, u16)> = Option::None;
    if city_root.blue_points > city_root.red_points {
        world
            .emit_event(
                @CityContestWon {
                    board_id: city_root.board_id,
                    root: city_root.position,
                    winner: PlayerSide::Blue,
                    red_points: city_root.red_points,
                    blue_points: city_root.blue_points,
                },
            );
        let winner = PlayerSide::Blue;
        let points_delta = city_root.red_points;
        city_root.blue_points += city_root.red_points;
        city_root.red_points = 0;
        result = Option::Some((winner, points_delta));
    } else if city_root.blue_points < city_root.red_points {
        world
            .emit_event(
                @CityContestWon {
                    board_id: city_root.board_id,
                    root: city_root.position,
                    winner: PlayerSide::Red,
                    red_points: city_root.red_points,
                    blue_points: city_root.blue_points,
                },
            );
        let winner = PlayerSide::Red;
        let points_delta = city_root.blue_points;
        city_root.red_points += city_root.blue_points;
        city_root.blue_points = 0;
        result = Option::Some((winner, points_delta));
    } else {
        world
            .emit_event(
                @CityContestDraw {
                    board_id: city_root.board_id,
                    root: city_root.position,
                    red_points: city_root.red_points,
                    blue_points: city_root.blue_points,
                },
            );
        result = Option::None;
    }
    world.write_model(@city_root);
    return result;
}

pub fn close_all_cities(
    ref world: WorldStorage, board_id: felt252,
) -> Span<Option<(PlayerSide, u16)>> {
    let potential_cities: PotentialCityContests = world.read_model(board_id);
    let roots = potential_cities.roots;
    let mut contest_results: Array<Option<(PlayerSide, u16)>> = ArrayTrait::new();
    for i in 0..roots.len() {
        let root = find(ref world, board_id, *roots.at(i));
        if !root.contested {
            let contest_result = handle_city_contest(ref world, root);
            contest_results.append(contest_result);
        }
    };
    return contest_results.span();
}


#[cfg(test)]
mod tests {
    use super::*;
    use dojo_cairo_test::WorldStorageTestTrait;
    use dojo::model::{ModelStorage};
    use dojo::world::WorldStorageTrait;
    use dojo_cairo_test::{spawn_test_world, NamespaceDef, TestResource, ContractDef};

    use evolute_duel::{
        models::{CityNode, m_CityNode, PotentialCityContests, m_PotentialCityContests},
        events::{CityContestWon, e_CityContestWon, CityContestDraw, e_CityContestDraw},
        packing::{Tile},
        systems::helpers::{board::generate_initial_board_state, city_union_find::{connected}},
    };
    use evolute_duel::systems::game::{};

    fn namespace_def() -> NamespaceDef {
        NamespaceDef {
            namespace: "evolute_duel",
            resources: [
                TestResource::Model(m_CityNode::TEST_CLASS_HASH),
                TestResource::Model(m_PotentialCityContests::TEST_CLASS_HASH),
                TestResource::Event(e_CityContestWon::TEST_CLASS_HASH),
                TestResource::Event(e_CityContestDraw::TEST_CLASS_HASH),
            ]
                .span(),
        }
    }

    fn contract_defs() -> Span<ContractDef> {
        [].span()
    }

    #[test]
    fn test_no_rotation() {
        let tile = Tile::CCCF;
        let extended = create_extended_tile(tile, 0);
        assert_eq!(extended.edges, [TEdge::C, TEdge::C, TEdge::C, TEdge::F].span());
    }

    #[test]
    fn test_rotation_90() {
        let tile = Tile::CCCF;
        let extended = create_extended_tile(tile, 1);
        assert_eq!(extended.edges, [TEdge::F, TEdge::C, TEdge::C, TEdge::C].span());
    }

    #[test]
    fn test_rotation_180() {
        let tile = Tile::CCCF;
        let extended = create_extended_tile(tile, 2);
        assert_eq!(extended.edges, [TEdge::C, TEdge::F, TEdge::C, TEdge::C].span());
    }

    #[test]
    fn test_rotation_270() {
        let tile = Tile::CCCF;
        let extended = create_extended_tile(tile, 3);
        assert_eq!(extended.edges, [TEdge::C, TEdge::C, TEdge::F, TEdge::C].span());
    }

    #[test]
    fn test_connect_city_edges_in_tile() {
        // Initialize test environment
        let caller = starknet::contract_address_const::<0x0>();
        let ndef = namespace_def();

        // Register the resources.
        let mut world = spawn_test_world([ndef].span());

        // Ensures permissions and initializations are synced.
        world.sync_perms_and_inits(contract_defs());

        let board_id = 1;
        let tile_position = 2; // Arbitrary tile position

        // Create a tile with all edges as city (CCCC)
        let tile = Tile::CFCF;
        let rotation = 0;
        let side = PlayerSide::Blue;

        let initial_edge_state = generate_initial_board_state(1, 1, board_id);

        // Call function to connect city edges
        connect_city_edges_in_tile(
            ref world, board_id, tile_position, tile.into(), rotation, side.into(),
        );

        // Verify all city edges are connected
        let base_pos = convert_board_position_to_node_position(tile_position, 0);
        let root = find(ref world, board_id, base_pos).position;
        let city_node: CityNode = world.read_model((board_id, base_pos + 2));

        //println!("Root1: {:?}", find(ref world, board_id, base_pos));
        //println!("Root2: {:?}", city_node);

        for i in 0..4_u8 {
            if i % 2 == 1 {
                continue;
            }
            let edge_pos = convert_board_position_to_node_position(tile_position, i);
            assert_eq!(
                find(ref world, board_id, edge_pos).position,
                root,
                "City edge {} is not connected correctly",
                edge_pos,
            );
        };
    }

    #[test]
    fn test_connect_adjacent_city_edges() {
        let caller = starknet::contract_address_const::<0x0>();
        let ndef = namespace_def();

        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let board_id = 1;

        let tile_position_1 = 10;
        let tile_position_2 = 18;

        let tile_1 = Tile::CFCF;
        let tile_2 = Tile::CFCF;
        let rotation = 1;
        let side = PlayerSide::Blue;

        let initial_edge_state = generate_initial_board_state(1, 1, board_id);

        connect_city_edges_in_tile(
            ref world, board_id, tile_position_1, tile_1.into(), rotation, side.into(),
        );
        connect_city_edges_in_tile(
            ref world, board_id, tile_position_2, tile_2.into(), rotation, side.into(),
        );

        let mut state = ArrayTrait::new();
        for i in 0..64_u8 {
            if i == tile_position_1 {
                state.append((tile_1.into(), rotation, side.into()));
            } else if i == tile_position_2 {
                state.append((tile_2.into(), rotation, side.into()));
            } else {
                state.append((Tile::Empty.into(), 0, 0));
            }
        };

        connect_adjacent_city_edges(
            ref world,
            board_id,
            state.clone(),
            initial_edge_state.clone(),
            tile_position_1,
            tile_1.into(),
            rotation,
            side.into(),
        );

        connect_adjacent_city_edges(
            ref world,
            board_id,
            state,
            initial_edge_state.clone(),
            tile_position_2,
            tile_2.into(),
            rotation,
            side.into(),
        );

        let edge_pos_1 = convert_board_position_to_node_position(tile_position_1, 1);
        let edge_pos_2 = convert_board_position_to_node_position(tile_position_2, 3);

        assert!(
            connected(ref world, board_id, edge_pos_1, edge_pos_2),
            "Adjacent edges {} and {} are not connected correctly",
            edge_pos_1,
            edge_pos_2,
        );
    }

    #[test]
    fn test_connect_adjacent_city_edges_contest() {
        let caller = starknet::contract_address_const::<0x0>();
        let ndef = namespace_def();

        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let board_id = 1;

        let tile_position_1 = 10; // CCFF 
        let tile_position_2 = 11; // FCCF
        let tile_position_3 = 19; // FFCC
        let tile_position_4 = 18; // CFFC

        let tile_1 = Tile::CCFF;
        let tile_2 = Tile::CCFF;
        let tile_3 = Tile::CCFF;
        let tile_4 = Tile::CCFF;
        let rotation1 = 0;
        let rotation2 = 1;
        let rotation3 = 2;
        let rotation4 = 3;
        let side1 = PlayerSide::Blue;
        let side2 = PlayerSide::Red;
        let side3 = PlayerSide::Blue;
        let side4 = PlayerSide::Blue;

        let initial_edge_state = generate_initial_board_state(1, 1, board_id);

        connect_city_edges_in_tile(
            ref world, board_id, tile_position_1, tile_1.into(), rotation1, side1.into(),
        );

        let root1 = find(
            ref world, board_id, convert_board_position_to_node_position(tile_position_1, 0),
        );
        assert_eq!(root1.open_edges, 2, "City contest is not conducted correctly");
        //println!("Root1: {:?}", root1);

        connect_city_edges_in_tile(
            ref world, board_id, tile_position_2, tile_2.into(), rotation2, side2.into(),
        );

        let root2 = find(
            ref world, board_id, convert_board_position_to_node_position(tile_position_2, 1),
        );
        assert_eq!(root2.open_edges, 2, "City contest is not conducted correctly");
        //println!("Root2: {:?}", root2);

        connect_city_edges_in_tile(
            ref world, board_id, tile_position_3, tile_3.into(), rotation3, side3.into(),
        );

        let root3 = find(
            ref world, board_id, convert_board_position_to_node_position(tile_position_3, 2),
        );
        assert_eq!(root3.open_edges, 2, "City contest is not conducted correctly");
        //println!("Root3: {:?}", root3);

        connect_city_edges_in_tile(
            ref world, board_id, tile_position_4, tile_4.into(), rotation4, side4.into(),
        );

        let root4 = find(
            ref world, board_id, convert_board_position_to_node_position(tile_position_4, 3),
        );
        assert_eq!(root4.open_edges, 2, "City contest is not conducted correctly");
        //println!("Root4: {:?}", root4);

        let mut state = ArrayTrait::new();
        for i in 0..64_u8 {
            if i == tile_position_1 {
                state.append((tile_1.into(), rotation1, side1.into()));
            } else {
                state.append((Tile::Empty.into(), 0, 0));
            }
        };

        connect_adjacent_city_edges(
            ref world,
            board_id,
            state,
            initial_edge_state.clone(),
            tile_position_1,
            tile_1.into(),
            rotation1,
            side1.into(),
        );

        let rot1 = find(
            ref world, board_id, convert_board_position_to_node_position(tile_position_1, 0),
        );
        //println!("Rot1: {:?}", rot1);
        assert_eq!(rot1.open_edges, 2, "City contest is not conducted correctly");

        let mut state = ArrayTrait::new();
        for i in 0..64_u8 {
            if i == tile_position_1 {
                state.append((tile_1.into(), rotation1, side1.into()));
            } else if i == tile_position_2 {
                state.append((tile_2.into(), rotation2, side2.into()));
            } else {
                state.append((Tile::Empty.into(), 0, 0));
            }
        };

        connect_adjacent_city_edges(
            ref world,
            board_id,
            state.clone(),
            initial_edge_state.clone(),
            tile_position_2,
            tile_2.into(),
            rotation2,
            side2.into(),
        );

        let rot2 = find(
            ref world, board_id, convert_board_position_to_node_position(tile_position_2, 1),
        );
        //println!("Rot2: {:?}", rot2);
        assert_eq!(rot2.open_edges, 2, "City contest is not conducted correctly");

        let mut state = ArrayTrait::new();
        for i in 0..64_u8 {
            if i == tile_position_1 {
                state.append((tile_1.into(), rotation1, side1.into()));
            } else if i == tile_position_2 {
                state.append((tile_2.into(), rotation2, side2.into()));
            } else if i == tile_position_3 {
                state.append((tile_3.into(), rotation3, side3.into()));
            } else {
                state.append((Tile::Empty.into(), 0, 0));
            }
        };

        connect_adjacent_city_edges(
            ref world,
            board_id,
            state.clone(),
            initial_edge_state.clone(),
            tile_position_3,
            tile_3.into(),
            rotation3,
            side3.into(),
        );

        let rot3 = find(
            ref world, board_id, convert_board_position_to_node_position(tile_position_3, 2),
        );
        //println!("Rot3: {:?}", rot3);
        assert_eq!(rot3.open_edges, 2, "City contest is not conducted correctly");

        let mut state = ArrayTrait::new();
        for i in 0..64_u8 {
            if i == tile_position_1 {
                state.append((tile_1.into(), rotation1, side1.into()));
            } else if i == tile_position_2 {
                state.append((tile_2.into(), rotation2, side2.into()));
            } else if i == tile_position_3 {
                state.append((tile_3.into(), rotation3, side3.into()));
            } else if i == tile_position_4 {
                state.append((tile_4.into(), rotation4, side4.into()));
            } else {
                state.append((Tile::Empty.into(), 0, 0));
            }
        };

        connect_adjacent_city_edges(
            ref world,
            board_id,
            state,
            initial_edge_state.clone(),
            tile_position_4,
            tile_4.into(),
            rotation4,
            side4.into(),
        );

        let rot4 = find(
            ref world, board_id, convert_board_position_to_node_position(tile_position_4, 3),
        );
        //println!("Rot4: {:?}", rot4);
        assert_eq!(rot4.open_edges, 0, "City contest is not conducted correctly");

        // 1 and 2
        let edge_pos_1 = convert_board_position_to_node_position(tile_position_1, 0);
        let edge_pos_2 = convert_board_position_to_node_position(tile_position_2, 2);

        assert!(
            connected(ref world, board_id, edge_pos_1, edge_pos_2),
            "Adjacent edges {} and {} are not connected correctly",
            edge_pos_1,
            edge_pos_2,
        );

        // 2 and 3
        let edge_pos_2 = convert_board_position_to_node_position(tile_position_2, 1);
        let edge_pos_3 = convert_board_position_to_node_position(tile_position_3, 3);

        assert!(
            connected(ref world, board_id, edge_pos_2, edge_pos_3),
            "Adjacent edges {} and {} are not connected correctly",
            edge_pos_2,
            edge_pos_3,
        );

        // 3 and 4
        let edge_pos_3 = convert_board_position_to_node_position(tile_position_3, 2);
        let edge_pos_4 = convert_board_position_to_node_position(tile_position_4, 0);

        assert!(
            connected(ref world, board_id, edge_pos_3, edge_pos_4),
            "Adjacent edges {} and {} are not connected correctly",
            edge_pos_3,
            edge_pos_4,
        );

        // 4 and 1
        let edge_pos_4 = convert_board_position_to_node_position(tile_position_4, 3);
        let edge_pos_1 = convert_board_position_to_node_position(tile_position_1, 1);

        assert!(
            connected(ref world, board_id, edge_pos_4, edge_pos_1),
            "Adjacent edges {} and {} are not connected correctly",
            edge_pos_4,
            edge_pos_1,
        );

        let city_root = find(ref world, board_id, edge_pos_1);
        assert_eq!(city_root.open_edges, 0, "City contest is not conducted correctly");
    }

    #[test]
    fn test_contest_with_edge() {
        let caller = starknet::contract_address_const::<0x0>();
        let ndef = namespace_def();

        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let board_id = 1;

        // City and road just on bottom edge
        let initial_edge_state = array![
            2,
            2,
            0,
            2,
            2,
            2,
            1,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
            2,
        ];

        let tile_1 = Tile::CFRR;
        let col1 = 2;
        let row1 = 0;
        let tile_position_1 = col1 * 8 + row1;
        let rotation1 = 2;
        let side1 = PlayerSide::Blue;

        connect_city_edges_in_tile(
            ref world, board_id, tile_position_1, tile_1.into(), rotation1, side1.into(),
        );

        let root1 = find(
            ref world, board_id, convert_board_position_to_node_position(tile_position_1, 2),
        );

        assert_eq!(root1.open_edges, 1, "City contest is not conducted correctly");

        let mut state: Array<(u8, u8, u8)> = ArrayTrait::new();
        state.append_span([((Tile::Empty).into(), 0, 0); 64].span());

        let scoring_result = connect_adjacent_city_edges(
            ref world,
            board_id,
            state.clone(),
            initial_edge_state.clone(),
            tile_position_1,
            tile_1.into(),
            rotation1,
            side1.into(),
        );

        println!("{:?}", scoring_result);

        let root2 = find(
            ref world, board_id, convert_board_position_to_node_position(tile_position_1, 2),
        );

        println!("{:?}", root2);
        assert_eq!(root2.open_edges, 0, "City contest is not conducted correctly");

        for i in 0..64_u8 {
            if i == tile_position_1 {
                state.append((tile_1.into(), rotation1, side1.into()));
            } else {
                state.append((Tile::Empty.into(), 0, 0));
            }
        };
    }
}
