use dojo::model::ModelStorage;
use dojo::event::EventStorage;
use evolute_duel::{
    events::{CityContestWon, CityContestDraw, RoadContestWon, RoadContestDraw},
    systems::helpers::{
        union_find::{find, union}, board::{},
        tile_helpers::{create_extended_tile, convert_board_position_to_node_position},
    },
    types::packing::{TEdge, PlayerSide, Tile}, models::scoring::{UnionNode, PotentialContests},
};
use dojo::world::{WorldStorage};

// use evolute_duel::libs::{achievements::{AchievementsTrait}};
use starknet::ContractAddress;

pub fn is_edge_node(col: u32, row: u32, side: u8, board_size: u32) -> bool {
    if col > board_size || row > board_size {
        return false;
    }

    match side {
        0 => { row == 0 && (col > 0 && col < board_size - 1) }, // Bottom Edge(Node looks Up)
        1 => { col == 0 && (row > 0 && row < board_size - 1) }, // Left Edge(Node looks Right)
        2 => {
            row == board_size - 1 && (col > 0 && col < board_size - 1)
        }, // Top Edge(Node looks Down)
        3 => {
            col == board_size - 1 && (row > 0 && row < board_size - 1)
        }, // Right Edge(Node looks Left)
        _ => false,
    }
}

pub fn connect_edges_in_tile(
    mut world: WorldStorage,
    board_id: felt252,
    col: u32,
    row: u32,
    tile: u8,
    rotation: u8,
    side: PlayerSide,
    board_size: u32,
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
        -board_size.try_into().unwrap() * 4 - 2 // Left
    ];
    let tile_position: u32 = col.into() * board_size + row.into();
    let mut city_points_for_initial_nodes: u16 = 0;
    let mut road_points_for_initial_nodes: u16 = 0;
    let col_row_offsets: Array<(i32, i32)> = array![
        (0, 1), // Up
        (1, 0), // Right
        (0, -1), // Down
        (-1, 0) // Left
    ];

    for side in 0..4_u8 {
        let node_type = *edges.at(side.into());

        if node_type == TEdge::None || node_type == TEdge::F {
            continue;
        }

        let offset: i32 = *direction_offsets[side.into()];
        let node_position: u32 = tile_position * 4 + side.into();
        let adjacent_node_position: u32 = (node_position.try_into().unwrap() + offset)
            .try_into()
            .unwrap();
        let (col_offset, row_offset) = *col_row_offsets.at(side.into());
        let adjacent_col: u32 = (col.try_into().unwrap() + col_offset).try_into().unwrap();
        let adjacent_row: u32 = (row.try_into().unwrap() + row_offset).try_into().unwrap();
        let adjacent_side: u8 = match side {
            0 => 2, // Up -> Down
            1 => 3, // Right -> Left
            2 => 0, // Down -> Up
            3 => 1, // Left -> Right
            _ => 0,
        };
        let mut adjacent_node: UnionNode = world.read_model((board_id, adjacent_node_position));
        if adjacent_node.node_type == TEdge::None {
            if is_edge_node(adjacent_col, adjacent_row, adjacent_side, board_size) {
                let root_pos = find(world, board_id, node_position);
                let mut root: UnionNode = world.read_model((board_id, root_pos));
                root.open_edges -= 1;
                world.write_model(@root);

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
                    if !contains {
                        road_roots.append(root.position);
                    }
                }
            }
            continue;
        } //If initial tile 

        if adjacent_node.open_edges == 1 && adjacent_node.player_side == PlayerSide::None {
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
                PlayerSide::Blue => { adjacent_node.blue_points += points; },
                PlayerSide::Red => { adjacent_node.red_points += points; },
                _ => {},
            }
            world.write_model(@adjacent_node);
        }

        let root = union(world, board_id, node_position, adjacent_node_position, false);

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
            if !contains {
                road_roots.append(root.position);
            }
        }
    };

    let mut city_contest_result = Option::None;
    if city_root.is_some() {
        let mut city_root: UnionNode = world.read_model((board_id, city_root.unwrap()));
        if city_root.open_edges == 0 && !city_root.contested {
            city_contest_result = handle_contest(world, ref city_root);
            //[Achivement] CityBuilder
            // AchievementsTrait::build_city(
            //     world, player_address, ((city_root.red_points + city_root.blue_points) / 2).into(),
            // );
        }
    }

    let mut road_contest_results = ArrayTrait::new();
    for road_root_position in road_roots {
        let mut road_root: UnionNode = world.read_model((board_id, road_root_position));
        if road_root.open_edges == 0 && !road_root.contested {
            let contest_result = handle_contest(world, ref road_root);
            road_contest_results.append(contest_result);

            // [Achievement] RoadBuilder
            // AchievementsTrait::build_road(
            //     world, player_address, (road_root.red_points + road_root.blue_points).into(),
            // );
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

    (
        (blue_city_points_delta, blue_road_points_delta),
        (red_city_points_delta, red_road_points_delta),
    )
}


pub fn handle_contest(
    mut world: WorldStorage, ref root: UnionNode,
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
                world
                    .emit_event(
                        @CityContestDraw {
                            board_id: root.board_id,
                            root: root.position,
                            red_points: root.red_points,
                            blue_points: root.blue_points,
                        },
                    );
            } else {
                world
                    .emit_event(
                        @CityContestWon {
                            board_id: root.board_id,
                            root: root.position,
                            red_points: root.red_points,
                            blue_points: root.blue_points,
                            winner: winner,
                        },
                    );
            }
        },
        TEdge::R => {
            if winner == PlayerSide::None {
                world
                    .emit_event(
                        @RoadContestDraw {
                            board_id: root.board_id,
                            root: root.position,
                            red_points: root.red_points,
                            blue_points: root.blue_points,
                        },
                    );
            } else {
                world
                    .emit_event(
                        @RoadContestWon {
                            board_id: root.board_id,
                            root: root.position,
                            red_points: root.red_points,
                            blue_points: root.blue_points,
                            winner: winner,
                        },
                    );
            }
        },
        _ => {},
    }
    world.write_model(@root);
    return result;
}

pub fn close_all_nodes(
    world: WorldStorage, roots: Span<u32>, board_id: felt252,
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

#[cfg(test)]
mod tests {
    use super::*;
    use dojo::model::ModelStorageTest;
    use dojo_cairo_test::{spawn_test_world, NamespaceDef, TestResource};
    use evolute_duel::models::scoring::{m_UnionNode, m_PotentialContests};
    use evolute_duel::events::{
        e_CityContestWon, e_CityContestDraw, e_RoadContestWon, e_RoadContestDraw,
    };
    use starknet::contract_address_const;

    fn setup_world() -> WorldStorage {
        let namespace_def = NamespaceDef {
            namespace: "evolute_duel",
            resources: [
                TestResource::Model(m_UnionNode::TEST_CLASS_HASH),
                TestResource::Model(m_PotentialContests::TEST_CLASS_HASH),
                TestResource::Event(e_CityContestWon::TEST_CLASS_HASH),
                TestResource::Event(e_CityContestDraw::TEST_CLASS_HASH),
                TestResource::Event(e_RoadContestWon::TEST_CLASS_HASH),
                TestResource::Event(e_RoadContestDraw::TEST_CLASS_HASH),
            ]
                .span(),
        };
        spawn_test_world([namespace_def].span())
    }

    #[test]
    fn test_is_edge_node_bottom_edge() {
        // Test bottom edge (row == 0)
        assert!(is_edge_node(1, 0, 0, 10) == true, "Should be bottom edge");
        assert!(is_edge_node(5, 0, 0, 10) == true, "Should be bottom edge");
        assert!(is_edge_node(8, 0, 0, 10) == true, "Should be bottom edge");

        // Test corners (not edges)
        assert!(is_edge_node(0, 0, 0, 10) == false, "Corner should not be edge");
        assert!(is_edge_node(9, 0, 0, 10) == false, "Corner should not be edge");

        // Test non-bottom positions
        assert!(is_edge_node(1, 1, 0, 10) == false, "Should not be bottom edge");
    }

    #[test]
    fn test_is_edge_node_left_edge() {
        // Test left edge (col == 0)
        assert!(is_edge_node(0, 1, 1, 10) == true, "Should be left edge");
        assert!(is_edge_node(0, 5, 1, 10) == true, "Should be left edge");
        assert!(is_edge_node(0, 8, 1, 10) == true, "Should be left edge");

        // Test corners (not edges)
        assert!(is_edge_node(0, 0, 1, 10) == false, "Corner should not be edge");
        assert!(is_edge_node(0, 9, 1, 10) == false, "Corner should not be edge");

        // Test non-left positions
        assert!(is_edge_node(1, 1, 1, 10) == false, "Should not be left edge");
    }

    #[test]
    fn test_is_edge_node_top_edge() {
        // Test top edge (row == board_size - 1)
        assert!(is_edge_node(1, 9, 2, 10) == true, "Should be top edge");
        assert!(is_edge_node(5, 9, 2, 10) == true, "Should be top edge");
        assert!(is_edge_node(8, 9, 2, 10) == true, "Should be top edge");

        // Test corners (not edges)
        assert!(is_edge_node(0, 9, 2, 10) == false, "Corner should not be edge");
        assert!(is_edge_node(9, 9, 2, 10) == false, "Corner should not be edge");

        // Test non-top positions
        assert!(is_edge_node(1, 8, 2, 10) == false, "Should not be top edge");
    }

    #[test]
    fn test_is_edge_node_right_edge() {
        // Test right edge (col == board_size - 1)
        assert!(is_edge_node(9, 1, 3, 10) == true, "Should be right edge");
        assert!(is_edge_node(9, 5, 3, 10) == true, "Should be right edge");
        assert!(is_edge_node(9, 8, 3, 10) == true, "Should be right edge");

        // Test corners (not edges)
        assert!(is_edge_node(9, 0, 3, 10) == false, "Corner should not be edge");
        assert!(is_edge_node(9, 9, 3, 10) == false, "Corner should not be edge");

        // Test non-right positions
        assert!(is_edge_node(8, 1, 3, 10) == false, "Should not be right edge");
    }

    #[test]
    fn test_is_edge_node_out_of_bounds() {
        // Test out of bounds coordinates
        assert!(is_edge_node(10, 5, 0, 10) == false, "Out of bounds should return false");
        assert!(is_edge_node(5, 10, 0, 10) == false, "Out of bounds should return false");
        assert!(is_edge_node(11, 11, 0, 10) == false, "Out of bounds should return false");
    }

    #[test]
    fn test_connect_edges_in_tile_cccc() {
        let world = setup_world();
        let board_id = 123;
        let col = 5;
        let row = 5;
        let tile = Tile::CCCC.into();
        let rotation = 0;
        let player_side = PlayerSide::Blue;
        let board_size = 10;

        let (city_points, road_points) = connect_edges_in_tile(
            world, board_id, col, row, tile, rotation, player_side, board_size,
        );
        assert!(city_points == 8, "CCCC should give 8 city points (4 edges * 2 points)");
        assert!(road_points == 0, "CCCC should give 0 road points");

        // get node on this position
        let root_position = find(
            world, board_id, convert_board_position_to_node_position(col, row, 0, board_size),
        );
        let root: UnionNode = world.read_model((board_id, root_position));

        assert!(root.blue_points == 8, "Blue should get all city points");
        assert!(root.red_points == 0, "Red should have no points");
        assert!(root.node_type == TEdge::C, "Node type should be city");
        assert!(root.open_edges == 4, "Open edges should be 4");
        assert!(root.player_side == player_side, "Player side should be Blue");
        assert!(root.contested == false, "Node should not be contested");
        assert!(root.rank == 2, "Node rank should be 2");
        assert!(root.parent == root.position, "Parent should be the same as position");
    }

    #[test]
    fn test_connect_edges_in_tile_rrrr() {
        let world = setup_world();
        let board_id = 123;
        let col = 5;
        let row = 5;
        let tile = Tile::RRRR.into();
        let rotation = 0;
        let player_side = PlayerSide::Red;
        let board_size = 10;

        let (city_points, road_points) = connect_edges_in_tile(
            world, board_id, col, row, tile, rotation, player_side, board_size,
        );

        assert!(city_points == 0, "RRRR should give 0 city points");
        assert!(road_points == 4, "RRRR should give 4 road points");

        // Check the root node
        let root_position_up = convert_board_position_to_node_position(col, row, 0, board_size);
        let root_up: UnionNode = world.read_model((board_id, root_position_up));
        assert!(root_up.blue_points == 0, "Blue should have no points");
        assert!(root_up.red_points == 1, "Red should get all road points");
        assert!(root_up.node_type == TEdge::R, "Node type should be road");
        assert!(root_up.open_edges == 1, "Road should have 1 open edge");
        assert!(root_up.player_side == player_side, "Player side should be Red");
        assert!(root_up.contested == false, "Node should not be contested");
        assert!(root_up.rank == 1, "Node rank should be 1");

        let root_position_right = convert_board_position_to_node_position(col, row, 1, board_size);
        let root_right: UnionNode = world.read_model((board_id, root_position_right));
        assert!(root_right.blue_points == 0, "Blue should have no points");
        assert!(root_right.red_points == 1, "Red should get all road points");
        assert!(root_right.node_type == TEdge::R, "Node type should be road");
        assert!(root_right.open_edges == 1, "Road should have 1 open edge");
        assert!(root_right.player_side == player_side, "Player side should be Red");
        assert!(root_right.contested == false, "Node should not be contested");
        assert!(root_right.rank == 1, "Node rank should be 1");

        let root_position_down = convert_board_position_to_node_position(col, row, 2, board_size);
        let root_down: UnionNode = world.read_model((board_id, root_position_down));
        assert!(root_down.blue_points == 0, "Blue should have no points");
        assert!(root_down.red_points == 1, "Red should get all road points");
        assert!(root_down.node_type == TEdge::R, "Node type should be road");
        assert!(root_down.open_edges == 1, "Road should have 1 open edge");
        assert!(root_down.player_side == player_side, "Player side should be Red");
        assert!(root_down.contested == false, "Node should not be contested");
        assert!(root_down.rank == 1, "Node rank should be 1");

        let root_position_left = convert_board_position_to_node_position(col, row, 3, board_size);
        let root_left: UnionNode = world.read_model((board_id, root_position_left));
        assert!(root_left.blue_points == 0, "Blue should have no points");
        assert!(root_left.red_points == 1, "Red should get all road points");
        assert!(root_left.node_type == TEdge::R, "Node type should be road");
        assert!(root_left.open_edges == 1, "Road should have 1 open edge");
        assert!(root_left.player_side == player_side, "Player side should be Red");
        assert!(root_left.contested == false, "Node should not be contested");
        assert!(root_left.rank == 1, "Node rank should be 1");
    }

    #[test]
    fn test_connect_edges_in_tile_ccrr() {
        let world = setup_world();
        let board_id = 123;
        let col = 5;
        let row = 5;
        let tile = Tile::CCRR.into();
        let rotation = 0;
        let player_side = PlayerSide::Blue;
        let board_size = 10;

        let (city_points, road_points) = connect_edges_in_tile(
            world, board_id, col, row, tile, rotation, player_side, board_size,
        );

        assert!(city_points == 4, "CCRR should give 4 city points (2 edges * 2 points)");
        assert!(road_points == 2, "CCRR should give 2 road points");

        // Check city root
        let city_root_position = find(
            world, board_id, convert_board_position_to_node_position(col, row, 0, board_size),
        );
        let city_root: UnionNode = world.read_model((board_id, city_root_position));

        assert!(city_root.blue_points == 4, "Blue should get city points");
        assert!(city_root.red_points == 0, "Red should have no city points");
        assert!(city_root.node_type == TEdge::C, "Node type should be city");
        assert!(city_root.open_edges == 2, "City should have 2 open edges");
        assert!(city_root.player_side == player_side, "Player side should be Blue");

        // Check road root
        let road_root_position = find(
            world, board_id, convert_board_position_to_node_position(col, row, 2, board_size),
        );
        let road_root: UnionNode = world.read_model((board_id, road_root_position));

        assert!(road_root.blue_points == 2, "Blue should get road points");
        assert!(road_root.red_points == 0, "Red should have no road points");
        assert!(road_root.node_type == TEdge::R, "Node type should be road");
        assert!(road_root.open_edges == 2, "Road should have 2 open edges");
        assert!(road_root.player_side == player_side, "Player side should be Blue");
    }

    #[test]
    fn test_connect_edges_in_tile_crcr() {
        let world = setup_world();
        let board_id = 123;
        let col = 5;
        let row = 5;
        let tile = Tile::CRCR.into();
        let rotation = 0;
        let player_side = PlayerSide::Blue;
        let board_size = 10;

        let (city_points, road_points) = connect_edges_in_tile(
            world, board_id, col, row, tile, rotation, player_side, board_size,
        );

        assert!(city_points == 4, "CRCR should give 4 city points (2 edges * 2 points)");
        assert!(road_points == 2, "CRCR should give 2 road points");

        // For CRCR, roads should NOT be connected (special case)
        // Check individual city nodes
        let city_root1_position = find(
            world, board_id, convert_board_position_to_node_position(col, row, 0, board_size),
        );
        let city_root1: UnionNode = world.read_model((board_id, city_root1_position));

        assert!(city_root1.blue_points == 4, "Blue should get points for city");
        assert!(city_root1.red_points == 0, "Red should have no points for city");
        assert!(city_root1.node_type == TEdge::C, "Node type should be city");
        assert!(city_root1.open_edges == 2, "City should have 2 open edge");
        assert!(city_root1.player_side == player_side, "Player side should be Blue");

        // Check individual road nodes (should NOT be connected)
        let road_root1_position = find(
            world, board_id, convert_board_position_to_node_position(col, row, 1, board_size),
        );
        let road_root1: UnionNode = world.read_model((board_id, road_root1_position));

        assert!(road_root1.blue_points == 1, "Blue should get points for first road");
        assert!(road_root1.red_points == 0, "Red should have no points for first road");
        assert!(road_root1.node_type == TEdge::R, "Node type should be road");
        assert!(road_root1.open_edges == 1, "Road should have 1 open edge");
        assert!(road_root1.player_side == player_side, "Player side should be Blue");

        let road_root2_position = find(
            world, board_id, convert_board_position_to_node_position(col, row, 3, board_size),
        );
        let road_root2: UnionNode = world.read_model((board_id, road_root2_position));

        assert!(road_root2.blue_points == 1, "Blue should get points for second road");
        assert!(road_root2.red_points == 0, "Red should have no points for second road");
        assert!(road_root2.node_type == TEdge::R, "Node type should be road");
        assert!(road_root2.open_edges == 1, "Road should have 1 open edge");
        assert!(road_root2.player_side == player_side, "Player side should be Blue");

        // Verify roads are NOT connected (different parents)
        assert!(road_root1.parent != road_root2.parent, "Roads should not be connected in CRCR");
    }

    #[test]
    fn test_connect_edges_in_tile_ffff() {
        let world = setup_world();
        let board_id = 123;
        let col = 5;
        let row = 5;
        let tile = Tile::FFFF.into();
        let rotation = 0;
        let player_side = PlayerSide::Blue;
        let board_size = 10;

        let (city_points, road_points) = connect_edges_in_tile(
            world, board_id, col, row, tile, rotation, player_side, board_size,
        );

        assert!(city_points == 0, "FFFF should give 0 city points");
        assert!(road_points == 0, "FFFF should give 0 road points");

        // Check that no nodes are created for field edges
        let position1 = convert_board_position_to_node_position(col, row, 0, board_size);
        let node1: UnionNode = world.read_model((board_id, position1));
        assert!(node1.node_type == TEdge::F, "Node type should be field");
        assert!(node1.blue_points == 0, "Field should have no points");
        assert!(node1.red_points == 0, "Field should have no points");
    }

    #[test]
    fn test_connect_edges_in_tile_cccf() {
        let world = setup_world();
        let board_id = 123;
        let col = 5;
        let row = 5;
        let tile = Tile::CCCF.into();
        let rotation = 0;
        let player_side = PlayerSide::Red;
        let board_size = 10;

        let (city_points, road_points) = connect_edges_in_tile(
            world, board_id, col, row, tile, rotation, player_side, board_size,
        );

        assert!(city_points == 6, "CCCF should give 6 city points (3 edges * 2 points)");
        assert!(road_points == 0, "CCCF should give 0 road points");

        // Check city root
        let city_root_position = find(
            world, board_id, convert_board_position_to_node_position(col, row, 0, board_size),
        );
        let city_root: UnionNode = world.read_model((board_id, city_root_position));

        assert!(city_root.blue_points == 0, "Blue should have no points");
        assert!(city_root.red_points == 6, "Red should get all city points");
        assert!(city_root.node_type == TEdge::C, "Node type should be city");
        assert!(city_root.open_edges == 3, "City should have 3 open edges");
        assert!(city_root.player_side == player_side, "Player side should be Red");
    }

    #[test]
    fn test_connect_edges_in_tile_cccr() {
        let world = setup_world();
        let board_id = 123;
        let col = 5;
        let row = 5;
        let tile = Tile::CCCR.into();
        let rotation = 0;
        let player_side = PlayerSide::Blue;
        let board_size = 10;

        let (city_points, road_points) = connect_edges_in_tile(
            world, board_id, col, row, tile, rotation, player_side, board_size,
        );

        assert!(city_points == 6, "CCCR should give 6 city points (3 edges * 2 points)");
        assert!(road_points == 1, "CCCR should give 1 road point");

        // Check city root
        let city_root_position = find(
            world, board_id, convert_board_position_to_node_position(col, row, 0, board_size),
        );
        let city_root: UnionNode = world.read_model((board_id, city_root_position));

        assert!(city_root.blue_points == 6, "Blue should get city points");
        assert!(city_root.red_points == 0, "Red should have no city points");
        assert!(city_root.node_type == TEdge::C, "Node type should be city");
        assert!(city_root.open_edges == 3, "City should have 3 open edges");
        assert!(city_root.player_side == player_side, "Player side should be Blue");

        // Check road node
        let road_root_position = find(
            world, board_id, convert_board_position_to_node_position(col, row, 3, board_size),
        );
        let road_root: UnionNode = world.read_model((board_id, road_root_position));

        assert!(road_root.blue_points == 1, "Blue should get road points");
        assert!(road_root.red_points == 0, "Red should have no road points");
        assert!(road_root.node_type == TEdge::R, "Node type should be road");
        assert!(road_root.open_edges == 1, "Road should have 1 open edge");
        assert!(road_root.player_side == player_side, "Player side should be Blue");
    }

    #[test]
    fn test_connect_edges_in_tile_ffrr() {
        let world = setup_world();
        let board_id = 123;
        let col = 5;
        let row = 5;
        let tile = Tile::FFRR.into();
        let rotation = 0;
        let player_side = PlayerSide::Red;
        let board_size = 10;

        let (city_points, road_points) = connect_edges_in_tile(
            world, board_id, col, row, tile, rotation, player_side, board_size,
        );

        assert!(city_points == 0, "FFRR should give 0 city points");
        assert!(road_points == 2, "FFRR should give 2 road points");

        // Check road root
        let road_root_position = find(
            world, board_id, convert_board_position_to_node_position(col, row, 2, board_size),
        );
        let road_root: UnionNode = world.read_model((board_id, road_root_position));

        assert!(road_root.blue_points == 0, "Blue should have no points");
        assert!(road_root.red_points == 2, "Red should get road points");
        assert!(road_root.node_type == TEdge::R, "Node type should be road");
        assert!(road_root.open_edges == 2, "Road should have 2 open edges");
        assert!(road_root.player_side == player_side, "Player side should be Red");
    }

    #[test]
    fn test_handle_contest_blue_wins() {
        let world = setup_world();
        let board_id = 123;
        let position = 1000;

        let mut root = UnionNode {
            board_id,
            position,
            parent: position,
            rank: 1,
            blue_points: 6,
            red_points: 4,
            open_edges: 0,
            contested: false,
            node_type: TEdge::C,
            player_side: PlayerSide::None,
        };

        let result = handle_contest(world, ref root);

        assert!(result.is_some(), "Should return contest result");
        let (winner, edge_type, points_delta) = result.unwrap();
        assert!(winner == PlayerSide::Blue, "Blue should win");
        assert!(edge_type == TEdge::C, "Should be city edge");
        assert!(points_delta == 4, "Points delta should be red's points");
        assert!(root.contested == true, "Root should be marked as contested");
        assert!(root.blue_points == 10, "Blue should get all points");
        assert!(root.red_points == 0, "Red should have no points");
    }

    #[test]
    fn test_handle_contest_red_wins() {
        let world = setup_world();
        let board_id = 123;
        let position = 1000;

        let mut root = UnionNode {
            board_id,
            position,
            parent: position,
            rank: 1,
            blue_points: 3,
            red_points: 7,
            open_edges: 0,
            contested: false,
            node_type: TEdge::R,
            player_side: PlayerSide::None,
        };

        let result = handle_contest(world, ref root);

        assert!(result.is_some(), "Should return contest result");
        let (winner, edge_type, points_delta) = result.unwrap();
        assert!(winner == PlayerSide::Red, "Red should win");
        assert!(edge_type == TEdge::R, "Should be road edge");
        assert!(points_delta == 3, "Points delta should be blue's points");
        assert!(root.contested == true, "Root should be marked as contested");
        assert!(root.red_points == 10, "Red should get all points");
        assert!(root.blue_points == 0, "Blue should have no points");
    }

    #[test]
    fn test_handle_contest_draw() {
        let world = setup_world();
        let board_id = 123;
        let position = 1000;

        let mut root = UnionNode {
            board_id,
            position,
            parent: position,
            rank: 1,
            blue_points: 5,
            red_points: 5,
            open_edges: 0,
            contested: false,
            node_type: TEdge::C,
            player_side: PlayerSide::None,
        };

        let result = handle_contest(world, ref root);

        assert!(result.is_none(), "Should return None for draw");
        assert!(root.contested == true, "Root should be marked as contested");
        assert!(root.blue_points == 5, "Blue points should remain unchanged");
        assert!(root.red_points == 5, "Red points should remain unchanged");
    }

    #[test]
    fn test_connect_adjacent_edges_basic() {
        let world = setup_world();
        let board_id = 123;
        let col = 5;
        let row = 5;
        let tile = Tile::CCCC.into();
        let rotation = 0;
        let board_size = 10;
        let player_side = PlayerSide::Blue;
        let player_address = contract_address_const::<0x123>();

        // First place the tile
        connect_edges_in_tile(world, board_id, col, row, tile, rotation, player_side, board_size);

        // Then connect adjacent edges
        let ((blue_city_delta, blue_road_delta), (red_city_delta, red_road_delta)) =
            connect_adjacent_edges(
            world, board_id, col, row, tile, rotation, board_size, player_side, player_address,
        );

        // Should have no deltas since no adjacent tiles
        assert!(blue_city_delta == 0, "Should have no blue city delta");
        assert!(blue_road_delta == 0, "Should have no blue road delta");
        assert!(red_city_delta == 0, "Should have no red city delta");
        assert!(red_road_delta == 0, "Should have no red road delta");
    }
}

