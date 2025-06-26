use starknet::ContractAddress;
use evolute_duel::{
    models::{game::{Board}, scoring::{UnionFind, UnionFindTrait}},
    systems::helpers::{
        city_scoring::{connect_city_edges_in_tile, connect_adjacent_city_edges, close_all_cities},
        road_scoring::{connect_road_edges_in_tile, connect_adjacent_road_edges, close_all_roads},
        tile_helpers::{calcucate_tile_points, calculate_adjacent_edge_points},
    },
    types::packing::{PlayerSide, UnionNode},
};
use alexandria_data_structures::vec::{NullableVec, VecTrait};
use core::dict::Felt252Dict;

#[derive(Drop, Copy, Debug)]
pub struct ScoringResult {
    pub city_points: u16,
    pub road_points: u16,
    pub city_contest_result: Option<(PlayerSide, u16)>,
    pub road_contest_results: Span<Option<(PlayerSide, u16)>>,
}

#[generate_trait]
pub impl ScoringImpl of ScoringTrait {
    fn calculate_move_scoring(
        tile: u8,
        rotation: u8,
        col: u8,
        row: u8,
        player_side: PlayerSide,
        player: ContractAddress,
        board_id: felt252,
        ref board: Board,
        ref union_find: UnionFind,
        mut world: dojo::world::WorldStorage,
    ) -> ScoringResult {
        let (mut city_nodes, mut road_nodes) = union_find.to_nullable_vecs();

        let (tile_city_points, tile_road_points) = calcucate_tile_points(tile.into());
        let (edges_city_points, edges_road_points) = calculate_adjacent_edge_points(
            ref board.initial_edge_state, col, row, tile.into(), rotation,
        );
        let city_points = tile_city_points + edges_city_points;
        let road_points = tile_road_points + edges_road_points;


        println!("NODES BEFORE SCORING:");
        // Printing debug information
        for i in 0..city_nodes.len() {
            let node = city_nodes.at(i.into());
            if node.node_type != 0 {
                continue; // Skip non-city nodes
            }
            println!(
                "City Node {}: parent={}, rank={}, blue_points={}, red_points={}, open_edges={}",
                i, node.parent, node.rank, node.blue_points, node.red_points, node.open_edges
            );
        };

        for i in 0..road_nodes.len() {
            let node = road_nodes.at(i.into());
            if node.node_type != 1 {
                continue; // Skip non-road nodes
            }
            println!(
                "Road Node {}: parent={}, rank={}, blue_points={}, red_points={}, open_edges={}",
                i, node.parent, node.rank, node.blue_points, node.red_points, node.open_edges
            );
        };


        let mut visited: Felt252Dict<bool> = Default::default();
        let tile_position = (col * 8 + row).into();


        connect_city_edges_in_tile(
            ref world, ref city_nodes, tile_position, tile, rotation, player_side.into(),
        );


        let city_contest_result = connect_adjacent_city_edges(
            ref world,
            board_id,
            board.state.span(),
            ref board.initial_edge_state,
            ref city_nodes,
            tile_position,
            tile,
            rotation,
            player_side.into(),
            player,
            ref visited,
            ref union_find.potential_city_contests,
        );


        connect_road_edges_in_tile(
            ref world, ref road_nodes, tile_position, tile, rotation, player_side.into(),
        );


        let road_contest_results = connect_adjacent_road_edges(
            ref world,
            board_id,
            board.state.span(),
            ref board.initial_edge_state,
            ref road_nodes,
            tile_position,
            tile,
            rotation,
            player_side.into(),
            player,
            ref visited,
            ref union_find.potential_road_contests,
        );


        union_find.update_with_union_nodes(ref city_nodes, ref road_nodes);


        println!("NODES AFTER SCORING:");
        // Printing debug information
        for i in 0..city_nodes.len() {
            let node = city_nodes.at(i.into());
            if node.node_type != 0 {
                continue; // Skip non-city nodes
            }
            println!(
                "City Node {}: parent={}, rank={}, blue_points={}, red_points={}, open_edges={}",
                i, node.parent, node.rank, node.blue_points, node.red_points, node.open_edges
            );
        };

        for i in 0..road_nodes.len() {
            let node = road_nodes.at(i.into());
            if node.node_type != 1 {
                continue; // Skip non-road nodes
            }
            println!(
                "Road Node {}: parent={}, rank={}, blue_points={}, red_points={}, open_edges={}",
                i, node.parent, node.rank, node.blue_points, node.red_points, node.open_edges
            );
        };



        union_find.write(world);

        ScoringResult { city_points, road_points, city_contest_result, road_contest_results }
    }

    fn apply_scoring_results(
        scoring_result: ScoringResult, player_side: PlayerSide, ref board: Board,
    ) {
        if player_side == PlayerSide::Blue {
            let (old_city_points, old_road_points) = board.blue_score;
            board
                .blue_score =
                    (
                        old_city_points + scoring_result.city_points,
                        old_road_points + scoring_result.road_points,
                    );
        } else {
            let (old_city_points, old_road_points) = board.red_score;
            board
                .red_score =
                    (
                        old_city_points + scoring_result.city_points,
                        old_road_points + scoring_result.road_points,
                    );
        }

        if scoring_result.city_contest_result.is_some() {
            let (winner, points_delta) = scoring_result.city_contest_result.unwrap();
            Self::apply_contest_points(winner, points_delta, ref board, true);
        }

        let road_results = scoring_result.road_contest_results;
        for i in 0..road_results.len() {
            let road_result = *road_results.at(i.into());
            if road_result.is_some() {
                let (winner, points_delta) = road_result.unwrap();
                Self::apply_contest_points(winner, points_delta, ref board, false);
            }
        }
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
        potential_city_contests: Span<u8>,
        potential_road_contests: Span<u8>,
        ref city_nodes: NullableVec<UnionNode>,
        ref road_nodes: NullableVec<UnionNode>,
        board_id: felt252,
        ref board: Board,
        mut world: dojo::world::WorldStorage,
    ) {
        println!("Calculating final scoring...");
        let city_scoring_results = close_all_cities(
            ref world, potential_city_contests, ref city_nodes, board_id,
        );
        for i in 0..city_scoring_results.len() {
            let city_scoring_result = *city_scoring_results.at(i.into());
            if city_scoring_result.is_some() {
                let (winner, points_delta) = city_scoring_result.unwrap();
                Self::apply_contest_points(winner, points_delta, ref board, true);
            }
        };

        let road_scoring_results = close_all_roads(
            ref world, potential_road_contests, ref road_nodes, board_id,
        );
        for i in 0..road_scoring_results.len() {
            let road_scoring_result = *road_scoring_results.at(i.into());
            if road_scoring_result.is_some() {
                let (winner, points_delta) = road_scoring_result.unwrap();
                Self::apply_contest_points(winner, points_delta, ref board, false);
            }
        };
    }
}
