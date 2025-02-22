use dojo::event::EventStorage;
use dojo::model::ModelStorage;
use evolute_duel::{
    models::{RoadNode, PotentialRoadContests},
    events::{RoadContestWon, RoadContestDraw},
    systems::helpers::{
        road_union_find::{find, union},
        board::{},
        tile_helpers::{create_extended_tile, convert_board_position_to_node_position,
        tile_roads_number},
    },
    packing::{TEdge, PlayerSide},
};
use dojo::world::{WorldStorage};

pub fn connect_road_edges_in_tile(
    ref world: WorldStorage, board_id: felt252, initial_edge_state: Array<u8>, tile_position: u8, tile: u8, rotation: u8, side: u8,
) {
    let extended_tile = create_extended_tile(tile.into(), rotation);
    let row = tile_position % 8;
    let col = tile_position / 8;

    let mut roads: Array<u8> = ArrayTrait::new();
    let mut cities_count = 0;

    for i in 0..4_u8 {
        if *extended_tile.edges.at(i.into()) == (TEdge::R).into() {
            let mut open_edges = 1;
            let blue_points = if side == (PlayerSide::Blue).into() {
                let mut score = 1;
                //check if it is on the edge of the board
                if (row == 0 && *initial_edge_state.at(col.into()) == TEdge::R.into()) || 
                    (row == 7 && *initial_edge_state.at((23 - col).into()) == TEdge::R.into()) || 
                    (col == 0 && *initial_edge_state.at((31 - row).into()) == TEdge::R.into()) || 
                    (col == 7 && *initial_edge_state.at((8 + row).into()) == TEdge::R.into()) {
                    score += 1;
                    open_edges = 0;
                }
                score
            } else {
                0
            };
            let red_points = if side == (PlayerSide::Red).into() {
                let mut score = 1;
                //check if it is on the edge of the board
                if (row == 0 && *initial_edge_state.at(col.into()) == TEdge::R.into()) || 
                    (row == 7 && *initial_edge_state.at((23 - col).into()) == TEdge::R.into()) || 
                    (col == 0 && *initial_edge_state.at((31 - row).into()) == TEdge::R.into()) || 
                    (col == 7 && *initial_edge_state.at((8 + row).into()) == TEdge::R.into()) {
                    score += 1;
                    open_edges = 0;
                }
                score
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
                //Need to mark the color of the player who placed the tile in board
                blue_points,
                red_points,
                open_edges,
                contested: false,
            };
            world.write_model(@road_node);
        } else if *extended_tile.edges.at(i.into()) == (TEdge::C).into() {
            cities_count += 1;
        }
    };

    //TODO: if we close th road with edge we need to check if we need to connect the road

    // Connect the roads if needed
    if roads.len() == 2 {
        if !(cities_count == 2 && extended_tile.edges.at(0) == extended_tile.edges.at(2) && extended_tile.edges.at(1) == extended_tile.edges.at(3)) {
            union(ref world, board_id, *roads.at(0), *roads.at(1), true);
        }
    }
    
}

pub fn connect_adjacent_road_edges(
    ref world: WorldStorage, board_id: felt252, state: Array<(u8, u8, u8)>, tile_position: u8, tile: u8, rotation: u8, side: u8,
)
//None - if no contest or draw, Some(u8, u32) -> (who_wins, points_delta) - if contest 
//TODO - return list of multiple contests
-> Option<(PlayerSide, u32)>{
    let extended_tile = create_extended_tile(tile.into(), rotation);
    let row = tile_position % 8;
    let col = tile_position / 8;
    let mut roads_connected: Array<u8> = ArrayTrait::new();
    let edges = extended_tile.edges;
    //find all adjacent edges
    //connect bottom edge
    if row != 0 && *edges.at(2) == TEdge::R {
        let edge_pos = convert_board_position_to_node_position(tile_position, 2);
        let down_edge_pos = convert_board_position_to_node_position(tile_position - 1, 0);
        ////println!("edge_pos: {:?}, down_edge_pos: {:?}", edge_pos, down_edge_pos);
        // check if the down edge is road
        let (tile, rotation, _) = *state.at((tile_position - 1).into());
        let extended_down_tile = create_extended_tile(tile.into(), rotation);
        if *extended_down_tile.edges.at(0) == (TEdge::R).into() {
            union(ref world, board_id, down_edge_pos, edge_pos, false);
            roads_connected.append(edge_pos);
        }
    } 
    //connect top edge
    if row != 7 && *edges.at(0) == TEdge::R {
        let edge_pos = convert_board_position_to_node_position(tile_position, 0);
        let up_edge_pos = convert_board_position_to_node_position(tile_position + 1, 2);
       //println!("edge_pos: {:?}, up_edge_pos: {:?}", edge_pos, up_edge_pos);
        // check if the up edge is road
        let (tile, rotation, _) = *state.at((tile_position + 1).into());
        let extended_up_tile = create_extended_tile(tile.into(), rotation);
        if *extended_up_tile.edges.at(2) == (TEdge::R).into() {
            union(ref world, board_id, up_edge_pos, edge_pos, false);
            roads_connected.append(edge_pos);
        }
    }

    //connect left edge
    if col != 0 && *edges.at(3) == TEdge::R {
        let edge_pos = convert_board_position_to_node_position(tile_position, 3);
        let left_edge_pos = convert_board_position_to_node_position(tile_position - 8, 1);
       //println!("edge_pos: {:?}, left_edge_pos: {:?}", edge_pos, left_edge_pos);
        // check if the left edge is road
        let (tile, rotation, _) = *state.at((tile_position - 8).into());
        let extended_left_tile = create_extended_tile(tile.into(), rotation);
        if *extended_left_tile.edges.at(1) == (TEdge::R).into() {
            union(ref world, board_id, left_edge_pos, edge_pos, false);
            roads_connected.append(edge_pos);
        }
    }

    //connect right edge
    if col != 7 && *edges.at(1) == TEdge::R {
        let edge_pos = convert_board_position_to_node_position(tile_position, 1);
        let right_edge_pos = convert_board_position_to_node_position(tile_position + 8, 3);
       //println!("edge_pos: {:?}, right_edge_pos: {:?}", edge_pos, right_edge_pos);
        // check if the right edge is road
        let (tile, rotation, _) = *state.at((tile_position + 8).into());
        let extended_right_tile = create_extended_tile(tile.into(), rotation);
        if *extended_right_tile.edges.at(3) == (TEdge::R).into() {
            union(ref world, board_id, right_edge_pos, edge_pos, false);
            roads_connected.append(edge_pos);
        }
    }

    //check for contest(open_edges == 0) in union
    if roads_connected.len() > 0 {
        //TODO: if we have more than 2 roads or CRCR we can have multiple contests
        let mut road_root = find(ref world, board_id, *roads_connected.at(0));
        if road_root.open_edges == 0 {
            //TODO contest
           //println!("Contest");
           road_root.contested = true;
            if road_root.blue_points > road_root.red_points {
                //TODO blue player wins contest
               //println!("Blue player wins contest");
                world.emit_event(@RoadContestWon {
                    board_id,
                    root: road_root.position,
                    winner: PlayerSide::Blue,
                    red_points: road_root.red_points,
                    blue_points: road_root.blue_points,
                });
                let winner = PlayerSide::Blue;
                let points_delta = road_root.red_points;
                road_root.blue_points += road_root.red_points;
                road_root.red_points = 0;
                world.write_model(@road_root);
                return Option::Some((winner, points_delta));
            } else if road_root.blue_points < road_root.red_points {
                //TODO red player wins contest
               //println!("Red player wins contest");
                world.emit_event(@RoadContestWon {
                    board_id,
                    root: road_root.position,
                    winner: PlayerSide::Red,
                    red_points: road_root.red_points,
                    blue_points: road_root.blue_points,
                });
                let winner = PlayerSide::Red;
                let points_delta = road_root.blue_points;
                road_root.red_points += road_root.blue_points;
                road_root.blue_points = 0;
                world.write_model(@road_root);
                return Option::Some((winner, points_delta));
            } else {
                //TODO draw in contest
               //println!("Draw in contest");
                world.emit_event(@RoadContestDraw {
                    board_id,
                    root: road_root.position,
                    red_points: road_root.red_points,
                    blue_points: road_root.blue_points,
                });
                world.write_model(@road_root);
                return Option::None;
            }
        }
    }


    // Update potential road contests
    let road_number = tile_roads_number(tile.into());
    if road_number.into() > roads_connected.len() {
        let mut potential_roads: PotentialRoadContests = world.read_model(board_id);
        let mut roots = potential_roads.roots;
        for i in 0..4_u8 {
            if *extended_tile.edges.at(i.into()) == (TEdge::R).into() {
                let node_pos = find(ref world, board_id, convert_board_position_to_node_position(tile_position, i)).position;
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
        world.write_model(@potential_roads);
    }


    Option::None
}  




#[cfg(test)]
mod tests {
    use super::*;
    use dojo_cairo_test::WorldStorageTestTrait;
    use dojo::model::{ModelStorage};
    use dojo::world::WorldStorageTrait;
    use dojo_cairo_test::{
        spawn_test_world, NamespaceDef, TestResource, ContractDef,
    };

    use evolute_duel::{
        models::{RoadNode, m_RoadNode, PotentialRoadContests, m_PotentialRoadContests},
        events::{
            RoadContestWon, e_RoadContestWon, RoadContestDraw, e_RoadContestDraw,
        },
        packing::{Tile, TEdge, PlayerSide},
        systems::helpers::{
            board::generate_initial_board_state,
            road_union_find::{connected},
        }
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
        let mut world = spawn_test_world([ndef].span());

        // Ensures permissions and initializations are synced.
        world.sync_perms_and_inits(contract_defs());

        let board_id = 1;
        let tile_position = 2; // Arbitrary tile position

        // Create a tile with all edges as road (CCCC)
        let tile = Tile::FRFR;
        let rotation = 0;
        let side = PlayerSide::Blue;

        let initial_edge_state = generate_initial_board_state(1, 1, board_id);

        // Call function to connect road edges
        connect_road_edges_in_tile(
            ref world, board_id, initial_edge_state, tile_position, tile.into(), rotation, side.into(),
        );

        // Verify all road edges are connected
        let base_pos = convert_board_position_to_node_position(tile_position, 0);
        let root = find(ref world, board_id, base_pos).position;
        let road_node: RoadNode = world.read_model((board_id, base_pos + 2));

       //println!("Root1: {:?}", find(ref world, board_id, base_pos));
       //println!("Root2: {:?}", road_node);

        for i in 0..4_u8 {
            if i % 2 == 1 {
                continue;
            }
            let edge_pos = convert_board_position_to_node_position(tile_position, i);
            assert_eq!(
                find(ref world, board_id, edge_pos).position,
                root,
                "Road edge {} is not connected correctly",
                edge_pos,
            );
        };
    }

    #[test]
    fn test_connect_adjacent_road_edges() {
        // Инициализация тестового окружения
        let caller = starknet::contract_address_const::<0x0>();
        let ndef = namespace_def();

        // Создание тестового мира
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let board_id = 1;
        
        // Размещаем два тайла рядом друг с другом
        let tile_position_1 = 10; // Произвольная позиция
        let tile_position_2 = 18; // Позиция справа от первого тайла (смежное правое)

        let tile_1 = Tile::FRFR;
        let tile_2 = Tile::FRFR;
        let rotation = 0;
        let side = PlayerSide::Blue;

        // Создаем начальное состояние границ
        let initial_edge_state = generate_initial_board_state(1, 1, board_id);
        // Подключаем границы внутри каждого тайла
        connect_road_edges_in_tile(
            ref world, board_id, initial_edge_state.clone(),  tile_position_1, tile_1.into(), rotation, side.into(),
        );
        connect_road_edges_in_tile(
            ref world, board_id, initial_edge_state, tile_position_2, tile_2.into(), rotation, side.into(),
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
        

        // Соединяем смежные границы между тайлами
        connect_adjacent_road_edges(
            ref world, board_id, state.clone(), tile_position_1, tile_1.into(), rotation, side.into(),
        );

        connect_adjacent_road_edges(
            ref world, board_id, state, tile_position_2, tile_2.into(), rotation, side.into(),
        );

        // Проверяем, что соединены соответствующие края
        let edge_pos_1 = convert_board_position_to_node_position(tile_position_1, 1);
        let edge_pos_2 = convert_board_position_to_node_position(tile_position_2, 3);

        assert!(connected(ref world, board_id, edge_pos_1, edge_pos_2),
            "Adjacent edges {} and {} are not connected correctly", edge_pos_1, edge_pos_2);
    }

    #[test]
    fn test_connect_adjacent_road_edges_contest() {
        // Инициализация тестового окружения
        let caller = starknet::contract_address_const::<0x0>();
        let ndef = namespace_def();

        // Создание тестового мира
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let board_id = 1;
        
        // Размещаем два тайла рядом друг с другом
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


        // Создаем начальное состояние границ
        let initial_edge_state = generate_initial_board_state(1, 1, board_id);
        // Подключаем границы внутри каждого тайла
        connect_road_edges_in_tile(
            ref world, board_id, initial_edge_state.clone(),  tile_position_1, tile_1.into(), rotation1, side1.into(),
        );

        let root1 = find(ref world, board_id, convert_board_position_to_node_position(tile_position_1, 0));
        assert_eq!(root1.open_edges, 2, "Road contest is not conducted correctly");
       //println!("Root1: {:?}", root1);

        connect_road_edges_in_tile(
            ref world, board_id, initial_edge_state.clone(),  tile_position_2, tile_2.into(), rotation2, side2.into(),
        );

        let root2 = find(ref world, board_id, convert_board_position_to_node_position(tile_position_2, 1));
        assert_eq!(root2.open_edges, 2, "Road contest is not conducted correctly");
       //println!("Root2: {:?}", root2);

        connect_road_edges_in_tile(
            ref world, board_id, initial_edge_state.clone(),  tile_position_3, tile_3.into(), rotation3, side3.into(),
        );

        let root3 = find(ref world, board_id, convert_board_position_to_node_position(tile_position_3, 2));
        assert_eq!(root3.open_edges, 2, "Road contest is not conducted correctly");
       //println!("Root3: {:?}", root3);
        

        connect_road_edges_in_tile(
            ref world, board_id, initial_edge_state.clone(),  tile_position_4, tile_4.into(), rotation4, side4.into(),
        );

        let root4 = find(ref world, board_id, convert_board_position_to_node_position(tile_position_4, 3));
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
        
        // Соединяем смежные границы между тайлами
        connect_adjacent_road_edges(
            ref world, board_id, state, tile_position_1, tile_1.into(), rotation1, side1.into(),
        );

        let rot1 = find(ref world, board_id, convert_board_position_to_node_position(tile_position_1, 0));
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
            ref world, board_id, state.clone(), tile_position_2, tile_2.into(), rotation2, side2.into(),
        );

        let rot2 = find(ref world, board_id, convert_board_position_to_node_position(tile_position_2, 1));
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
            ref world, board_id, state.clone(), tile_position_3, tile_3.into(), rotation3, side3.into(),
        );

        let rot3 = find(ref world, board_id, convert_board_position_to_node_position(tile_position_3, 2));
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
            ref world, board_id, state, tile_position_4, tile_4.into(), rotation4, side4.into(),
        );

        let rot4 = find(ref world, board_id, convert_board_position_to_node_position(tile_position_4, 3));
       //println!("Rot4: {:?}", rot4);
        assert_eq!(rot4.open_edges, 0, "Road contest is not conducted correctly");


        // Проверяем, что соединены соответствующие края
        // 1 and 2
        let edge_pos_1 = convert_board_position_to_node_position(tile_position_1, 0);
        let edge_pos_2 = convert_board_position_to_node_position(tile_position_2, 2);

        assert!(connected(ref world, board_id, edge_pos_1, edge_pos_2),
            "Adjacent edges {} and {} are not connected correctly", edge_pos_1, edge_pos_2);


        // 2 and 3
        let edge_pos_2 = convert_board_position_to_node_position(tile_position_2, 1);
        let edge_pos_3 = convert_board_position_to_node_position(tile_position_3, 3);

        assert!(connected(ref world, board_id, edge_pos_2, edge_pos_3),
            "Adjacent edges {} and {} are not connected correctly", edge_pos_2, edge_pos_3);

        // 3 and 4
        let edge_pos_3 = convert_board_position_to_node_position(tile_position_3, 2);
        let edge_pos_4 = convert_board_position_to_node_position(tile_position_4, 0);

        assert!(connected(ref world, board_id, edge_pos_3, edge_pos_4),
            "Adjacent edges {} and {} are not connected correctly", edge_pos_3, edge_pos_4);

        // 4 and 1
        let edge_pos_4 = convert_board_position_to_node_position(tile_position_4, 3);
        let edge_pos_1 = convert_board_position_to_node_position(tile_position_1, 1);

        assert!(connected(ref world, board_id, edge_pos_4, edge_pos_1),
            "Adjacent edges {} and {} are not connected correctly", edge_pos_4, edge_pos_1);

        // Проверяем, что проведен конкурс
        let road_root = find(ref world, board_id, edge_pos_1);
        assert_eq!(road_root.open_edges, 0, "Road contest is not conducted correctly");
    }
}
