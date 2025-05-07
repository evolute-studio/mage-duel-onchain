use evolute_duel::{
    models::{
        scoring::{RoadNode, PotentialRoadContests}
    }, 
    events::{RoadContestWon, RoadContestDraw},
    systems::helpers::{
        road_union_find::{find, union}, board::{},
        tile_helpers::{
            create_extended_tile, convert_board_position_to_node_position, tile_roads_number,
        },
    },
    packing::{TEdge, PlayerSide, Tile},
};
use evolute_duel::libs::store::{Store, StoreTrait};

pub fn connect_road_edges_in_tile(
    ref store: Store, board_id: felt252, tile_position: u8, tile: u8, rotation: u8, side: u8,
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
            let road_node = RoadNode {
                board_id,
                parent: position,
                position: position,
                rank: 1,
                blue_points,
                red_points,
                open_edges,
                contested: false,
            };
            store.set_road_node(@road_node);
        }
    };

    if roads.len() == 2 && tile != Tile::CRCR.into() {
        union(ref store, board_id, *roads.at(0), *roads.at(1), true);
    }
}

pub fn connect_adjacent_road_edges(
    ref store: Store,
    board_id: felt252,
    state: Array<(u8, u8, u8)>,
    initial_edge_state: Array<u8>,
    tile_position: u8,
    tile: u8,
    rotation: u8,
    side: u8,
) //None - if no contest or draw, Some(u8, u16) -> (who_wins, points_delta) - if contest
-> Span<
    Option<(PlayerSide, u16)>,
> {
    let extended_tile = create_extended_tile(tile.into(), rotation);
    let row = tile_position % 8;
    let col = tile_position / 8;
    let mut roads_connected: Array<u8> = ArrayTrait::new();
    let edges = extended_tile.edges;

    //connect bottom edge
    if *edges.at(2) == TEdge::R {
        let edge_pos = convert_board_position_to_node_position(tile_position, 2);
        if row != 0 {
            let down_edge_pos = convert_board_position_to_node_position(tile_position - 1, 0);

            let (tile, rotation, _) = *state.at((tile_position - 1).into());
            let extended_down_tile = create_extended_tile(tile.into(), rotation);
            if *extended_down_tile.edges.at(0) == (TEdge::R).into() {
                union(ref store, board_id, down_edge_pos, edge_pos, false);
                roads_connected.append(edge_pos);
            }
        } // tile is connected to bottom edge
        else if *initial_edge_state.at(col.into()) == TEdge::R.into() {
            let mut edge = find(ref store, board_id, edge_pos);
            edge.open_edges -= 1;
            if side == (PlayerSide::Blue).into() {
                edge.blue_points += 1;
            } else {
                edge.red_points += 1;
            }
            store.set_road_node(@edge);
            roads_connected.append(edge_pos);
        } else if *initial_edge_state.at(col.into()) == TEdge::M.into() {
            let mut edge = find(ref store, board_id, edge_pos);
            edge.open_edges -= 1;
            store.set_road_node(@edge);
            roads_connected.append(edge_pos);
        }
    }

    //connect top edge
    if *edges.at(0) == TEdge::R {
        let edge_pos = convert_board_position_to_node_position(tile_position, 0);
        if row != 7 {
            let up_edge_pos = convert_board_position_to_node_position(tile_position + 1, 2);

            let (tile, rotation, _) = *state.at((tile_position + 1).into());
            let extended_up_tile = create_extended_tile(tile.into(), rotation);
            if *extended_up_tile.edges.at(2) == (TEdge::R).into() {
                union(ref store, board_id, up_edge_pos, edge_pos, false);
                roads_connected.append(edge_pos);
            }
        } // tile is connected to top edge
        else if *initial_edge_state.at((23 - col).into()) == TEdge::R.into() {
            let mut edge = find(ref store, board_id, edge_pos);
            edge.open_edges -= 1;
            if side == (PlayerSide::Blue).into() {
                edge.blue_points += 1;
            } else {
                edge.red_points += 1;
            }
            store.set_road_node(@edge);
            roads_connected.append(edge_pos);
        } else if *initial_edge_state.at((23 - col).into()) == TEdge::M.into() {
            let mut edge = find(ref store, board_id, edge_pos);
            edge.open_edges -= 1;
            store.set_road_node(@edge);
            roads_connected.append(edge_pos);
        }
    }

    //connect left edge
    if *edges.at(3) == TEdge::R {
        let edge_pos = convert_board_position_to_node_position(tile_position, 3);
        if col != 0 {
            let left_edge_pos = convert_board_position_to_node_position(tile_position - 8, 1);

            let (tile, rotation, _) = *state.at((tile_position - 8).into());
            let extended_left_tile = create_extended_tile(tile.into(), rotation);
            if *extended_left_tile.edges.at(1) == (TEdge::R).into() {
                union(ref store, board_id, left_edge_pos, edge_pos, false);
                roads_connected.append(edge_pos);
            }
        } // tile is connected to left edge
        else if *initial_edge_state.at((31 - row).into()) == TEdge::R.into() {
            let mut edge = find(ref store, board_id, edge_pos);
            edge.open_edges -= 1;
            if side == (PlayerSide::Blue).into() {
                edge.blue_points += 1;
            } else {
                edge.red_points += 1;
            }
            store.set_road_node(@edge);
            roads_connected.append(edge_pos);
        } else if *initial_edge_state.at((31 - row).into()) == TEdge::M.into() {
            let mut edge = find(ref store, board_id, edge_pos);
            edge.open_edges -= 1;
            store.set_road_node(@edge);
            roads_connected.append(edge_pos);
        }
    }

    //connect right edge
    if *edges.at(1) == TEdge::R {
        let edge_pos = convert_board_position_to_node_position(tile_position, 1);
        if col != 7 {
            let right_edge_pos = convert_board_position_to_node_position(tile_position + 8, 3);

            let (tile, rotation, _) = *state.at((tile_position + 8).into());
            let extended_right_tile = create_extended_tile(tile.into(), rotation);
            if *extended_right_tile.edges.at(3) == (TEdge::R).into() {
                union(ref store, board_id, right_edge_pos, edge_pos, false);
                roads_connected.append(edge_pos);
            }
        } // tile is connected to right edge
        else if *initial_edge_state.at((8 + row).into()) == TEdge::R.into() {
            let mut edge = find(ref store, board_id, edge_pos);
            edge.open_edges -= 1;
            if side == (PlayerSide::Blue).into() {
                edge.blue_points += 1;
            } else {
                edge.red_points += 1;
            }
            store.set_road_node(@edge);
            roads_connected.append(edge_pos);
        } else if *initial_edge_state.at((8 + row).into()) == TEdge::M.into() {
            let mut edge = find(ref store, board_id, edge_pos);
            edge.open_edges -= 1;
            store.set_road_node(@edge);
            roads_connected.append(edge_pos);
        }
    }

    let tile_roads_number = tile_roads_number(tile.into());

    let mut contest_results: Array<Option<(PlayerSide, u16)>> = ArrayTrait::new();
    if tile_roads_number != 2 || tile == Tile::CRCR.into() {
        for i in 0..roads_connected.len() {
            let mut road_root = find(ref store, board_id, *roads_connected.at(i));
            if road_root.open_edges == 0 {
                let contest_result = handle_contest(ref store, road_root);
                if contest_result.is_some() {
                    contest_results.append(contest_result);
                }
            }
        }
    } else if roads_connected.len() > 0 {
        let mut road_root = find(ref store, board_id, *roads_connected.at(0));
        if road_root.open_edges == 0 {
            let contest_result: Option<(PlayerSide, u16)> = handle_contest(ref store, road_root);
            if contest_result.is_some() {
                contest_results.append(contest_result);
            }
        }
    }

    // Update potential road contests
    if tile_roads_number.into() > roads_connected.len() {
        let mut potential_roads: PotentialRoadContests = store.get_potential_road_contests(board_id);
        let mut roots = potential_roads.roots;
        for i in 0..4_u8 {
            if *extended_tile.edges.at(i.into()) == (TEdge::R).into() {
                let node_pos = find(
                    ref store, board_id, convert_board_position_to_node_position(tile_position, i),
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
        potential_roads.roots = roots;
        store.set_potential_road_contests(@potential_roads);
    }

    return contest_results.span();
}

pub fn handle_contest(
    ref store: Store, mut road_root: RoadNode,
) -> Option<(PlayerSide, u16)> {
    road_root.contested = true;
    let mut result = Option::None;
    if road_root.blue_points > road_root.red_points {
        store
            .emit_road_contest_won(
                @RoadContestWon {
                    board_id: road_root.board_id,
                    root: road_root.position,
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
        store
            .emit_road_contest_won(
                @RoadContestWon {
                    board_id: road_root.board_id,
                    root: road_root.position,
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
        store
            .emit_road_contest_draw(
                @RoadContestDraw {
                    board_id: road_root.board_id,
                    root: road_root.position,
                    red_points: road_root.red_points,
                    blue_points: road_root.blue_points,
                },
            );
        result = Option::None;
    }

    store.set_road_node(@road_root);
    return result;
}

pub fn close_all_roads(
    ref store: Store, board_id: felt252,
) -> Span<Option<(PlayerSide, u16)>> {
    let potential_roads: PotentialRoadContests = store.get_potential_road_contests(board_id);
    let roots = potential_roads.roots;
    let mut contest_results = ArrayTrait::new();
    for i in 0..roots.len() {
        let root = find(ref store, board_id, *roots.at(i));
        if !root.contested {
            let contest_result = handle_contest(ref store, root);
            contest_results.append(contest_result);
        }
    };
    return contest_results.span();
}


#[cfg(test)]
mod tests {
    use super::*;
    use dojo_cairo_test::StoreTestTrait;
    use dojo::model::{ModelStorage};
    use dojo::store::StoreTrait;
    use dojo_cairo_test::{spawn_test_store, NamespaceDef, TestResource, ContractDef};

    use evolute_duel::{
        models::{RoadNode, m_RoadNode, PotentialRoadContests, m_PotentialRoadContests},
        events::{RoadContestWon, e_RoadContestWon, RoadContestDraw, e_RoadContestDraw},
        packing::{Tile, TEdge, PlayerSide},
        systems::helpers::{board::generate_initial_board_state, road_union_find::{connected}},
    };
    use evolute_duel::systems::game::{};

    fn namespace_def() -> NamespaceDef {
        NamespaceDef {
            namespace: "evolute_duel",
            resources: [
                TestResource::Model(m_RoadNode::TEST_CLASS_HASH),
                TestResource::Model(m_PotentialRoadContests::TEST_CLASS_HASH),
                TestResource::Event(e_RoadContestWon::TEST_CLASS_HASH),
                TestResource::Event(e_RoadContestDraw::TEST_CLASS_HASH),
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
    fn test_connect_road_edges_in_tile() {
        // Initialize test environment
        let caller = starknet::contract_address_const::<0x0>();
        let ndef = namespace_def();

        // Register the resources.
        let mut store = spawn_test_store([ndef].span());

        // Ensures permissions and initializations are synced.
        store.sync_perms_and_inits(contract_defs());

        let board_id = 1;
        let tile_position = 2; // Arbitrary tile position

        // Create a tile with all edges as road (CCCC)
        let tile = Tile::FRFR;
        let rotation = 0;
        let side = PlayerSide::Blue;

        let initial_edge_state = generate_initial_board_state(1, 1, board_id);

        // Call function to connect road edges
        connect_road_edges_in_tile(
            ref store, board_id, tile_position, tile.into(), rotation, side.into(),
        );

        // Verify all road edges are connected
        let base_pos = convert_board_position_to_node_position(tile_position, 0);
        let root = find(ref store, board_id, base_pos).position;
        let road_node: RoadNode = store.read_model((board_id, base_pos + 2));

        //println!("Root1: {:?}", find(ref store, board_id, base_pos));
        //println!("Root2: {:?}", road_node);

        for i in 0..4_u8 {
            if i % 2 == 1 {
                continue;
            }
            let edge_pos = convert_board_position_to_node_position(tile_position, i);
            assert_eq!(
                find(ref store, board_id, edge_pos).position,
                root,
                "Road edge {} is not connected correctly",
                edge_pos,
            );
        };
    }

    #[test]
    fn test_connect_adjacent_road_edges() {
        let caller = starknet::contract_address_const::<0x0>();
        let ndef = namespace_def();

        let mut store = spawn_test_store([ndef].span());
        store.sync_perms_and_inits(contract_defs());

        let board_id = 1;

        let tile_position_1 = 10;
        let tile_position_2 = 18;

        let tile_1 = Tile::FRFR;
        let tile_2 = Tile::FRFR;
        let rotation = 0;
        let side = PlayerSide::Blue;

        let initial_edge_state = generate_initial_board_state(1, 1, board_id);

        connect_road_edges_in_tile(
            ref store, board_id, tile_position_1, tile_1.into(), rotation, side.into(),
        );
        connect_road_edges_in_tile(
            ref store, board_id, tile_position_2, tile_2.into(), rotation, side.into(),
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

        connect_adjacent_road_edges(
            ref store,
            board_id,
            state.clone(),
            initial_edge_state.clone(),
            tile_position_1,
            tile_1.into(),
            rotation,
            side.into(),
        );

        connect_adjacent_road_edges(
            ref store,
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
            connected(ref store, board_id, edge_pos_1, edge_pos_2),
            "Adjacent edges {} and {} are not connected correctly",
            edge_pos_1,
            edge_pos_2,
        );
    }

    #[test]
    fn test_connect_adjacent_road_edges_contest() {
        let caller = starknet::contract_address_const::<0x0>();
        let ndef = namespace_def();

        let mut store = spawn_test_store([ndef].span());
        store.sync_perms_and_inits(contract_defs());

        let board_id = 1;

        let tile_position_1 = 10; // CCFF 
        let tile_position_2 = 11; // FCCF
        let tile_position_3 = 19; // FFCC
        let tile_position_4 = 18; // CFFC

        let tile_1 = Tile::FFRR;
        let tile_2 = Tile::FFRR;
        let tile_3 = Tile::FFRR;
        let tile_4 = Tile::FFRR;
        let rotation1 = 2;
        let rotation2 = 3;
        let rotation3 = 0;
        let rotation4 = 1;
        let side1 = PlayerSide::Blue;
        let side2 = PlayerSide::Red;
        let side3 = PlayerSide::Blue;
        let side4 = PlayerSide::Blue;

        let initial_edge_state = generate_initial_board_state(1, 1, board_id);

        connect_road_edges_in_tile(
            ref store, board_id, tile_position_1, tile_1.into(), rotation1, side1.into(),
        );

        let root1 = find(
            ref store, board_id, convert_board_position_to_node_position(tile_position_1, 0),
        );
        assert_eq!(root1.open_edges, 2, "Road contest is not conducted correctly");
        //println!("Root1: {:?}", root1);

        connect_road_edges_in_tile(
            ref store, board_id, tile_position_2, tile_2.into(), rotation2, side2.into(),
        );

        let root2 = find(
            ref store, board_id, convert_board_position_to_node_position(tile_position_2, 1),
        );
        assert_eq!(root2.open_edges, 2, "Road contest is not conducted correctly");
        //println!("Root2: {:?}", root2);

        connect_road_edges_in_tile(
            ref store, board_id, tile_position_3, tile_3.into(), rotation3, side3.into(),
        );

        let root3 = find(
            ref store, board_id, convert_board_position_to_node_position(tile_position_3, 2),
        );
        assert_eq!(root3.open_edges, 2, "Road contest is not conducted correctly");
        //println!("Root3: {:?}", root3);

        connect_road_edges_in_tile(
            ref store, board_id, tile_position_4, tile_4.into(), rotation4, side4.into(),
        );

        let root4 = find(
            ref store, board_id, convert_board_position_to_node_position(tile_position_4, 3),
        );
        assert_eq!(root4.open_edges, 2, "Road contest is not conducted correctly");
        //println!("Root4: {:?}", root4);

        let mut state = ArrayTrait::new();
        for i in 0..64_u8 {
            if i == tile_position_1 {
                state.append((tile_1.into(), rotation1, side1.into()));
            } else {
                state.append((Tile::Empty.into(), 0, 0));
            }
        };

        connect_adjacent_road_edges(
            ref store,
            board_id,
            state,
            initial_edge_state.clone(),
            tile_position_1,
            tile_1.into(),
            rotation1,
            side1.into(),
        );

        let rot1 = find(
            ref store, board_id, convert_board_position_to_node_position(tile_position_1, 0),
        );
        //println!("Rot1: {:?}", rot1);
        assert_eq!(rot1.open_edges, 2, "Road contest is not conducted correctly");

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

        connect_adjacent_road_edges(
            ref store,
            board_id,
            state.clone(),
            initial_edge_state.clone(),
            tile_position_2,
            tile_2.into(),
            rotation2,
            side2.into(),
        );

        let rot2 = find(
            ref store, board_id, convert_board_position_to_node_position(tile_position_2, 1),
        );
        //println!("Rot2: {:?}", rot2);
        assert_eq!(rot2.open_edges, 2, "Road contest is not conducted correctly");

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

        connect_adjacent_road_edges(
            ref store,
            board_id,
            state.clone(),
            initial_edge_state.clone(),
            tile_position_3,
            tile_3.into(),
            rotation3,
            side3.into(),
        );

        let rot3 = find(
            ref store, board_id, convert_board_position_to_node_position(tile_position_3, 2),
        );
        //println!("Rot3: {:?}", rot3);
        assert_eq!(rot3.open_edges, 2, "Road contest is not conducted correctly");

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

        connect_adjacent_road_edges(
            ref store,
            board_id,
            state,
            initial_edge_state.clone(),
            tile_position_4,
            tile_4.into(),
            rotation4,
            side4.into(),
        );

        let rot4 = find(
            ref store, board_id, convert_board_position_to_node_position(tile_position_4, 3),
        );
        //println!("Rot4: {:?}", rot4);
        assert_eq!(rot4.open_edges, 0, "Road contest is not conducted correctly");

        // 1 and 2
        let edge_pos_1 = convert_board_position_to_node_position(tile_position_1, 0);
        let edge_pos_2 = convert_board_position_to_node_position(tile_position_2, 2);

        assert!(
            connected(ref store, board_id, edge_pos_1, edge_pos_2),
            "Adjacent edges {} and {} are not connected correctly",
            edge_pos_1,
            edge_pos_2,
        );

        // 2 and 3
        let edge_pos_2 = convert_board_position_to_node_position(tile_position_2, 1);
        let edge_pos_3 = convert_board_position_to_node_position(tile_position_3, 3);

        assert!(
            connected(ref store, board_id, edge_pos_2, edge_pos_3),
            "Adjacent edges {} and {} are not connected correctly",
            edge_pos_2,
            edge_pos_3,
        );

        // 3 and 4
        let edge_pos_3 = convert_board_position_to_node_position(tile_position_3, 2);
        let edge_pos_4 = convert_board_position_to_node_position(tile_position_4, 0);

        assert!(
            connected(ref store, board_id, edge_pos_3, edge_pos_4),
            "Adjacent edges {} and {} are not connected correctly",
            edge_pos_3,
            edge_pos_4,
        );

        // 4 and 1
        let edge_pos_4 = convert_board_position_to_node_position(tile_position_4, 3);
        let edge_pos_1 = convert_board_position_to_node_position(tile_position_1, 1);

        assert!(
            connected(ref store, board_id, edge_pos_4, edge_pos_1),
            "Adjacent edges {} and {} are not connected correctly",
            edge_pos_4,
            edge_pos_1,
        );

        let road_root = find(ref store, board_id, edge_pos_1);
        assert_eq!(road_root.open_edges, 0, "Road contest is not conducted correctly");
    }
}
