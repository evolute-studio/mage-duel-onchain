#[cfg(test)]
mod tests {
    use super::*;
    use dojo_cairo_test::WorldStorageTestTrait;
    use dojo::model::{ModelStorage};
    use dojo::world::WorldStorageTrait;
    use dojo_cairo_test::{spawn_test_world, NamespaceDef, TestResource, ContractDef};

    use evolute_duel::{
        models::{RoadNode, m_RoadNode, PotentialRoadContests, m_PotentialRoadContests, CityNode, m_CityNode},
        events::{RoadContestWon, e_RoadContestWon, RoadContestDraw, e_RoadContestDraw, CityContestWon, e_CityContestWon, CityContestDraw, e_CityContestDraw},
        packing::{Tile, TEdge, PlayerSide},
        systems::helpers::{
            board::generate_initial_board_state,
            road_union_find,
            road_scoring::{connect_adjacent_road_edges, connect_road_edges_in_tile},
            city_union_find,
            city_scoring::{connect_adjacent_city_edges, connect_city_edges_in_tile},
            tile_helpers::{convert_board_position_to_node_position},
        },
    };
    use evolute_duel::systems::game::{};

    fn namespace_def() -> NamespaceDef {
        NamespaceDef {
            namespace: "evolute_duel",
            resources: [
                TestResource::Model(m_RoadNode::TEST_CLASS_HASH),
                TestResource::Model(m_PotentialRoadContests::TEST_CLASS_HASH),
                TestResource::Model(m_CityNode::TEST_CLASS_HASH),
                TestResource::Event(e_CityContestWon::TEST_CLASS_HASH),
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
    fn test_contest1() {
        // Инициализация тестового окружения
        let caller = starknet::contract_address_const::<0x0>();
        let ndef = namespace_def();

        // Создание тестового мира
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let board_id = 1;
        
        // City and road just on bottom edge
        let initial_edge_state = array![
            2,
            2,
            2,
            2,
            1,
            0,
            2,
            2,
            2,
            2,
            2,
            2,
            0,
            2,
            1,
            2,
            2,
            2,
            2,
            1,
            2,
            2,
            0,
            2,
            2,
            0,
            2,
            2,
            2,
            2,
            2,
            1
        ];
        
        let mut state: Array<(u8, u8, u8)> = array![
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (4, 2, 1),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (14, 2, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (22, 2, 1),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (13, 1, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
            (24, 0, 0),
        ];

        // Размещаем два тайла рядом друг с другом
        let tile_1 = Tile::CCCF;
        let col1 = 1;
        let row1 = 6;
        let tile_position_1 = col1 * 8 + row1; 
        let rotation1 = 2;
        let side1 = PlayerSide::Blue;



        connect_city_edges_in_tile(
            ref world, board_id, tile_position_1, tile_1.into(), rotation1, side1.into(),
        );

        connect_road_edges_in_tile(
            ref world, board_id, tile_position_1, tile_1.into(), rotation1, side1.into(),
        );

        let road_root1 = road_union_find::find(
            ref world, board_id, convert_board_position_to_node_position(tile_position_1, 1),
        );

        let city_root1 = city_union_find::find(
            ref world, board_id, convert_board_position_to_node_position(tile_position_1, 0),
        );

        println!("road_root1: {:?}", road_root1);
        println!("city_root1: {:?}", city_root1);
        
        let city_scoring_result1 = connect_adjacent_city_edges(
            ref world, board_id, state.clone(), initial_edge_state.clone(), tile_position_1, tile_1.into(), rotation1, side1.into(),
        );

        println!("there");

        let road_scoring_result1 = connect_adjacent_road_edges(
            ref world, board_id, state.clone(), initial_edge_state.clone(), tile_position_1, tile_1.into(), rotation1, side1.into(),
        );
        
        println!("{:?}", city_scoring_result1);
        println!("{:?}", road_scoring_result1);

        for i in 0..64_u8 {
            if i == tile_position_1 {
                state.append((tile_1.into(), rotation1, side1.into()));
            } else {
                state.append((Tile::Empty.into(), 0, 0));
            }
        };
    }
}