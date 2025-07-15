use starknet::ContractAddress;
use evolute_duel::{
    models::{game::{Board}, scoring::{UnionNode}},
    systems::helpers::{
        // city_scoring::{connect_city_edges_in_tile, connect_adjacent_city_edges, close_all_cities},
        // road_scoring::{connect_road_edges_in_tile, connect_adjacent_road_edges, close_all_roads},
        scoring::{connect_edges_in_tile, connect_adjacent_edges, close_all_nodes},
        tile_helpers::{calcucate_tile_points, calculate_adjacent_edge_points},
    },
    types::packing::{PlayerSide, TEdge},
};
use alexandria_data_structures::vec::{NullableVec, VecTrait};
use core::dict::Felt252Dict;

#[derive(Drop, Copy, Debug)]
pub struct ScoringResult {
    pub blue_city_points_delta: i16,
    pub blue_road_points_delta: i16,
    pub red_city_points_delta: i16,
    pub red_road_points_delta: i16,
}

#[generate_trait]
pub impl ScoringImpl of ScoringTrait {
    fn calculate_move_scoring(
        tile: u8,
        rotation: u8,
        col: u32,
        row: u32,
        player_side: PlayerSide,
        player_address: ContractAddress,
        board_id: felt252,
        board_size: u32,
        mut world: dojo::world::WorldStorage,
    ) -> ScoringResult {
        let (city_points, road_points) = connect_edges_in_tile(
            world, board_id, col, row, tile, rotation, board_size, player_side
        );

        let (
            (mut blue_city_points_delta, mut blue_road_points_delta), 
            (mut red_city_points_delta, mut red_road_points_delta)
        ) = connect_adjacent_edges(
            world, board_id, col, row, tile, rotation, board_size, player_side, player_address
        );

        if player_side == PlayerSide::Blue {
            blue_city_points_delta += city_points.try_into().unwrap();
            blue_road_points_delta += road_points.try_into().unwrap();
        } else if player_side == PlayerSide::Red {
            red_city_points_delta += city_points.try_into().unwrap();
            red_road_points_delta += road_points.try_into().unwrap();
        }

        ScoringResult { 
            blue_city_points_delta,
            blue_road_points_delta,
            red_city_points_delta,
            red_road_points_delta,
        }
    }

    fn apply_scoring_results(
        scoring_result: ScoringResult, player_side: PlayerSide, ref board: Board,
    ) {
        
        let (old_city_points, old_road_points) = board.blue_score;
        board
            .blue_score =
                (
                    (old_city_points.try_into().unwrap() + scoring_result.blue_city_points_delta).try_into().unwrap(),
                    (old_road_points.try_into().unwrap() + scoring_result.blue_road_points_delta).try_into().unwrap(),
                );
    
        let (old_city_points, old_road_points) = board.red_score;
        board
            .red_score =
                (
                    (old_city_points.try_into().unwrap() + scoring_result.red_city_points_delta).try_into().unwrap(),
                    (old_road_points.try_into().unwrap() + scoring_result.red_road_points_delta).try_into().unwrap(),
                );
    }

    fn apply_contest_points(
        winner: PlayerSide, points_delta: u16, ref board: Board, is_city: bool,
    ) {
        if winner == PlayerSide::Blue {
            if is_city {
                let (old_blue_city_points, old_blue_road_points) = board.blue_score;
                board.blue_score = (old_blue_city_points + points_delta, old_blue_road_points);
                let (old_red_city_points, old_red_road_points) = board.red_score;
                board.red_score = (old_red_city_points - points_delta, old_red_road_points);
            } else {
                let (old_blue_city_points, old_blue_road_points) = board.blue_score;
                board.blue_score = (old_blue_city_points, old_blue_road_points + points_delta);
                let (old_red_city_points, old_red_road_points) = board.red_score;
                board.red_score = (old_red_city_points, old_red_road_points - points_delta);
            }
        } else {
            if is_city {
                let (old_blue_city_points, old_blue_road_points) = board.blue_score;
                board.blue_score = (old_blue_city_points - points_delta, old_blue_road_points);
                let (old_red_city_points, old_red_road_points) = board.red_score;
                board.red_score = (old_red_city_points + points_delta, old_red_road_points);
            } else {
                let (old_blue_city_points, old_blue_road_points) = board.blue_score;
                board.blue_score = (old_blue_city_points, old_blue_road_points - points_delta);
                let (old_red_city_points, old_red_road_points) = board.red_score;
                board.red_score = (old_red_city_points, old_red_road_points + points_delta);
            }
        }
    }

    fn calculate_final_scoring(
        potential_contests: Span<u32>,
        ref board: Board,
        mut world: dojo::world::WorldStorage,
    ) {
        println!("Calculating final scoring...");

        let contest_results = close_all_nodes(
            world, potential_contests, board.id
        );

        for i in 0..contest_results.len() {
            let contest_result = *contest_results.at(i.into());
            if contest_result.is_some() {
                let (winner, node_type, points_delta) = contest_result.unwrap();
                Self::apply_contest_points(winner, points_delta, ref board, node_type == TEdge::C);
            }
        }
    }
}
