
use dojo::event::EventStorage;
use dojo::model::{Model};
use dojo::world::{WorldStorage};
use dojo::model::{ModelStorage};

use starknet::{ContractAddress, contract_address_const};
use origami_random::deck::{DeckTrait};
use origami_random::dice::{DiceTrait};
use core::dict::Felt252Dict;

use evolute_duel::{
    models::{
        scoring::{UnionFind, UnionFindTrait},
        game::{Board, Rules, Move},
    },
    events::{BoardCreated, BoardCreatedFromSnapshot, BoardCreateFromSnapshotFalied}, 
    packing::{GameState, TEdge, Tile, PlayerSide, UnionNode},
    systems::helpers::{
        city_scoring::{connect_adjacent_city_edges, connect_city_edges_in_tile},
        road_scoring::{connect_adjacent_road_edges, connect_road_edges_in_tile},
        tile_helpers::{calcucate_tile_points, calculate_adjacent_edge_points},
    },
};

use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

use core::starknet::get_block_timestamp;

use alexandria_data_structures::vec::{NullableVec, VecTrait};


pub fn create_board(
    ref world: WorldStorage,
    player1: ContractAddress,
    player2: ContractAddress,
    mut board_id_generator: core::starknet::storage::StorageBase::<
        core::starknet::storage::Mutable<core::felt252>,
    >,
) -> Board {
    let board_id = board_id_generator.read();
    board_id_generator.write(board_id + 1);

    let rules: Rules = world.read_model(0);
    let mut deck_rules_flat = flatten_deck_rules(rules.deck);

    // Create an empty board.
    let mut tiles: Array<(u8, u8, u8)> = ArrayTrait::new();
    tiles.append_span([((Tile::Empty).into(), 0, 0); 64].span());

    let last_move_id = Option::None;
    let game_state = GameState::InProgress;

    let mut board = Board {
        id: board_id,
        initial_edge_state: array![].span(),
        available_tiles_in_deck: deck_rules_flat,
        top_tile: Option::None,
        state: tiles.clone(),
        player1: (player1, PlayerSide::Blue, rules.joker_number),
        player2: (player2, PlayerSide::Red, rules.joker_number),
        blue_score: (0, 0),
        red_score: (0, 0),
        last_move_id,
        moves_done: 0,
        game_state,
        last_update_timestamp: get_block_timestamp(),
    };

    let top_tile = draw_tile_from_board_deck(ref board);

    world.write_model(@board);

    // Initialize edges
    let (cities_on_edges, roads_on_edges) = rules.edges;
    let initial_edge_state = generate_initial_board_state(
        cities_on_edges, roads_on_edges, board_id,
    );

    world
        .write_member(
            Model::<Board>::ptr_from_keys(board_id),
            selector!("initial_edge_state"),
            initial_edge_state.clone(),
        );

    world
        .emit_event(
            @BoardCreated {
                board_id,
                initial_edge_state,
                top_tile,
                state: tiles,
                player1: board.player1,
                player2: board.player2,
                blue_score: board.blue_score,
                red_score: board.red_score,
                last_move_id,
                game_state,
            },
        );

    return board;
}

pub fn create_board_from_snapshot(
    ref world: WorldStorage,
    old_board_id: felt252,
    player1: ContractAddress,
    move_number: u8,
    board_id_generator: core::starknet::storage::StorageBase::<
        core::starknet::storage::Mutable<core::felt252>,
    >,
) -> felt252 {
    let board_id = board_id_generator.read();
 
    let old_board: Board = world.read_model(old_board_id);

    // ////println!("old_board: {:?}", old_board);
    let mut deleted_tiles_positions: Felt252Dict<bool> = Default::default();
    let (_, player1_side, mut joker_number1) = old_board.player1;
    let (_, player2_side, mut joker_number2) = old_board.player2;

    let old_board_move_number = old_board.moves_done;
    
    // ////println!("old_board_move_number: {:?}", old_board_move_number);
    // ////println!("move_number: {:?}", move_number);
    // //println!("number of reverted moves: {:?}", old_board_move_number - move_number.into());

    let mut last_move_id = old_board.last_move_id;
    let mut top_tile = old_board.top_tile;
    let mut available_tiles_in_deck = old_board.available_tiles_in_deck.clone();
    let mut number_of_reverted_moves = old_board_move_number - move_number.into();
    for _ in  0..number_of_reverted_moves {
        if last_move_id.is_none() {
            world
                .emit_event(
                    @BoardCreateFromSnapshotFalied {
                        player: player1, old_board_id, move_number,
                    },
                );
            break;
        }
        let move_id = last_move_id.unwrap();
        let move: Move = world.read_model(move_id);

        last_move_id = move.prev_move_id;

        // If move is a skip, do not update the board state.
        if !move.is_joker && move.tile.is_none() {
            continue;
        }

        // Rememeber the deleted tile position
        let index: felt252 = (move.col * 8 + move.row).into();
        deleted_tiles_positions.insert(index, true);

        // Update jokers
        if move.is_joker {
            if move.player_side == player1_side {
                joker_number1 += 1;
            } else {
                joker_number2 += 1;
            }
        } // Update top tile and available tiles in deck
        else {
            if top_tile.is_some() {
                available_tiles_in_deck.append(top_tile.unwrap());
            }
            top_tile = move.tile;
        }
        // //println!("move REVERTED: {:?}", move);
    };

    // Update board state
    let mut updated_state: Array<(u8, u8, u8)> = ArrayTrait::new();
    for i in 0..old_board.state.len() {
        //left tile if not deleted
        if !deleted_tiles_positions.get(i.into()) {
            updated_state.append(*old_board.state.at(i.into()));
        } //empty tile if deleted
        else {
            updated_state.append((Tile::Empty.into(), 0, 0));
        }
    };

    let mut board = Board {
        id: board_id,
        initial_edge_state: array![].span(),
        available_tiles_in_deck: available_tiles_in_deck,
        top_tile,
        state: updated_state,
        player1: (player1, player1_side, joker_number1),
        player2: (player1, player2_side, joker_number2),
        blue_score: (0, 0),
        red_score: (0, 0),
        last_move_id,
        moves_done: move_number,
        game_state: GameState::InProgress,
        last_update_timestamp: get_block_timestamp(),
    };

    world.write_model(@board);

    board.initial_edge_state = old_board.initial_edge_state.clone();
    
    // //println!("new_board: {:?}", board);
    //TODO: calculate scores from state

    let mut road_nodes: NullableVec<UnionNode> = VecTrait::new();
    for _ in 0..256_u16 {
        road_nodes.push(Default::default());
    };

    let mut city_nodes: NullableVec<UnionNode> = VecTrait::new();
    for _ in 0..256_u16 {
        city_nodes.push(Default::default());
    };

    let mut potential_city_contests: Array<u8> = array![];
    let mut potential_road_contests: Array<u8> = array![];

    build_score_from_state(
        ref world, 
        ref board, 
        ref road_nodes, 
        ref potential_road_contests,
        ref city_nodes,
        ref potential_city_contests,
    );

    let mut road_nodes_arr: Array<UnionNode> = array![];
    for i in 0..road_nodes.len() {
        road_nodes_arr.append(road_nodes.at(i.into()));
    };
    let mut city_nodes_arr: Array<UnionNode> = array![];
    for i in 0..city_nodes.len() {
        city_nodes_arr.append(city_nodes.at(i.into()));
    };

    let mut union_find = UnionFindTrait::from_union_nodes(
        road_nodes_arr,
        city_nodes_arr,
        potential_road_contests,
        potential_city_contests,
    );

    union_find.write(world);
    // //println!("Final board created from snapshot: {:?}", board);

    world
        .write_member(
            Model::<Board>::ptr_from_keys(board_id),
            selector!("initial_edge_state"),
            board.initial_edge_state.clone(),
        );
    
    world
    .write_member(
        Model::<Board>::ptr_from_keys(board_id),
        selector!("available_tiles_in_deck"),
        board.available_tiles_in_deck.clone(),
    );

    world
        .write_member(
            Model::<Board>::ptr_from_keys(board_id), selector!("top_tile"), top_tile,
        );

    world
        .write_member(
            Model::<Board>::ptr_from_keys(board_id),
            selector!("state"),
            board.state.clone(),
        );

    world
        .write_member(
            Model::<Board>::ptr_from_keys(board_id), selector!("player1"), board.player1,
        );

    world
        .write_member(
            Model::<Board>::ptr_from_keys(board_id), selector!("player2"), board.player2,
        );

    world
        .write_member(
            Model::<Board>::ptr_from_keys(board_id),
            selector!("blue_score"),
            board.blue_score,
        );

    world
        .write_member(
            Model::<Board>::ptr_from_keys(board_id),
            selector!("red_score"),
            board.red_score,
        );

    world
        .write_member(
            Model::<Board>::ptr_from_keys(board_id),
            selector!("last_move_id"),
            board.last_move_id,
        );

    world
        .write_member(
            Model::<Board>::ptr_from_keys(board_id),
            selector!("game_state"),
            board.game_state,
        );    
    board_id_generator.write(board_id + 1);

    world
        .emit_event(
            @BoardCreatedFromSnapshot {
                board_id: board_id,
                old_board_id,
                move_number,
                initial_edge_state: board.initial_edge_state,
                available_tiles_in_deck: board.available_tiles_in_deck.span(),
                top_tile: board.top_tile,
                state: board.state,
                player1: board.player1,
                player2: board.player2,
                blue_score: board.blue_score,
                red_score: board.red_score,
                last_move_id: board.last_move_id,
                game_state: board.game_state,
            },
        );

    board_id
}

fn build_score_from_state(
    ref world: WorldStorage,
    ref board: Board,
    ref road_nodes: NullableVec<UnionNode>,
    ref potential_road_contests: Array<u8>,
    ref city_nodes: NullableVec<UnionNode>,
    ref potential_city_contests: Array<u8>,
) {
    let mut visited: Felt252Dict<bool> = Default::default();

    for i in 0..64_u8 {
        let (tile, rotation, player_side) = *board.state.at(i.into());
        let col = i / 8;
        let row = i % 8;
        
        let (tile_city_points, tile_road_points) = calcucate_tile_points(tile.into());
        let (edges_city_points, edges_road_points) = calculate_adjacent_edge_points(
            ref board.initial_edge_state,
            col,
            row,
            tile.into(),
            rotation,
        );
        let (city_points, road_points) = (
            tile_city_points + edges_city_points,
            tile_road_points + edges_road_points,
        );
        if player_side == PlayerSide::Blue.into() {
            let (old_city_points, old_road_points) = board.blue_score;
            board.blue_score = (old_city_points + city_points, old_road_points + road_points);
        } else {
            let (old_city_points, old_road_points) = board.red_score;
            board.red_score = (old_city_points + city_points, old_road_points + road_points);
        }

        if tile != Tile::Empty.into() {
            connect_road_edges_in_tile(
                ref world,
                ref road_nodes,
                i,
                tile,
                rotation,
                player_side,
            );
            connect_city_edges_in_tile(
                ref world,
                ref city_nodes,
                i,
                tile,
                rotation,
                player_side,
            );
        }
    };

    // //println!("blue_score: {:?}", board.blue_score);
    // //println!("red_score: {:?}", board.red_score);
    
    for i in 0..64_u8 {

        if !visited.get(i.into()) {
            // //println!("start iteration {i}");
            bfs(
                ref world,
                ref visited,
                ref board,
                ref road_nodes,
                ref potential_road_contests,
                ref city_nodes,
                ref potential_city_contests,
                i,
            );
        }
    }
}

fn bfs(
    ref world: WorldStorage,
    ref visited: Felt252Dict<bool>,
    ref board: Board,
    ref road_nodes: NullableVec<UnionNode>,
    ref potential_road_contests: Array<u8>,
    ref city_nodes: NullableVec<UnionNode>,
    ref potential_city_contests: Array<u8>,
    index: u8,
) {
    let mut queue: Array<u8> = ArrayTrait::new();
    queue.append(index);

    while queue.len() > 0 {
        let current_index = queue.pop_front().unwrap();
        if visited.get(current_index.into()) {
            continue;
        }
        visited.insert(current_index.into(), true);

        let (tile_type, rotation, side) = *board.state.at(current_index.into());

        
        // //println!("1");

        let road_contest_scoring_results = connect_adjacent_road_edges(
            ref world,
            board.id,
            board.state.span(),
            ref board.initial_edge_state,
            ref road_nodes,
            current_index,
            tile_type,
            rotation,
            side,
            contract_address_const::<0>(),
            ref visited,
            ref potential_road_contests,
        );

         for i in 0..road_contest_scoring_results.len() {
            let road_scoring_result = *road_contest_scoring_results.at(i.into());
            if road_scoring_result.is_some() {
                let (winner, points_delta) = road_scoring_result.unwrap();
                if winner == PlayerSide::Blue {
                    let (old_blue_city_points, old_blue_road_points) = board.blue_score;
                    board
                        .blue_score =
                            (old_blue_city_points, old_blue_road_points + points_delta);
                    let (old_red_city_points, old_red_road_points) = board.red_score;
                    board.red_score = (old_red_city_points, old_red_road_points - points_delta);
                } else {
                    let (old_blue_city_points, old_blue_road_points) = board.blue_score;
                    board
                        .blue_score =
                            (old_blue_city_points, old_blue_road_points - points_delta);
                    let (old_red_city_points, old_red_road_points) = board.red_score;
                    board.red_score = (old_red_city_points, old_red_road_points + points_delta);
                }
            }
        };


        let city_contest_scoring_result = connect_adjacent_city_edges(
            ref world,
            board.id,
            board.state.span(),
            ref board.initial_edge_state,
            ref city_nodes,
            current_index,
            tile_type,
            rotation,
            side,
            contract_address_const::<0>(),
            ref visited,
            ref potential_city_contests,
        );


        if city_contest_scoring_result.is_some() {
            let (winner, points_delta): (PlayerSide, u16) = city_contest_scoring_result
                .unwrap();
            if winner == PlayerSide::Blue {
                let (old_blue_city_points, old_blue_road_points) = board.blue_score;
                board.blue_score = (old_blue_city_points + points_delta, old_blue_road_points);
                let (old_red_city_points, old_red_road_points) = board.red_score;
                board.red_score = (old_red_city_points - points_delta, old_red_road_points);
            } else {
                let (old_blue_city_points, old_blue_road_points) = board.blue_score;
                board.blue_score = (old_blue_city_points - points_delta, old_blue_road_points);
                let (old_red_city_points, old_red_road_points) = board.red_score;
                board.red_score = (old_red_city_points + points_delta, old_red_road_points);
            }
        }


        let col = current_index / 8;
        let row = current_index % 8;

        //up
        if row != 7 {
            let (tile_type, _, _) = *board.state.at((current_index + 1).into());
            if !visited.get((current_index + 1).into()) && tile_type != Tile::Empty.into() {
                queue.append(current_index + 1);
            }
        }

        //down
        if row != 0 { 
            let (tile_type, _, _) = *board.state.at((current_index - 1).into());
            assert!(current_index >= 1, "1");
            if !visited.get((current_index - 1).into()) && tile_type != Tile::Empty.into() {
                queue.append(current_index - 1);
            }
        }

        //right
        if col != 7 {
            let (tile_type, _, _) = *board.state.at((current_index + 8).into());
            if !visited.get((current_index + 8).into()) && tile_type != Tile::Empty.into() {
                queue.append(current_index + 8);
            }
        }

        //left
        if col != 0 { 
            assert!(current_index >= 8, "2");
            let (tile_type, _, _) = *board.state.at((current_index - 8).into());
            if !visited.get((current_index - 8).into()) && tile_type != Tile::Empty.into() {
                queue.append(current_index - 8);
            }
        }
    }
}


pub fn update_board_state(
    ref board: Board, tile: Tile, rotation: u8, col: u8, row: u8, is_joker: bool, side: PlayerSide,
) {
    let mut updated_state: Array<(u8, u8, u8)> = ArrayTrait::new();
    let index = (col * 8 + row).into();
    for i in 0..board.state.len() {
        if i == index {
            updated_state.append((tile.into(), rotation, side.into()));
        } else {
            updated_state.append(*board.state.at(i.into()));
        }
    };

    board.state = updated_state;
}

pub fn update_board_joker_number(ref board: Board, side: PlayerSide, is_joker: bool) -> (u8, u8) {
    let (player1_address, player1_side, mut joker_number1) = board.player1;
    let (player2_address, player2_side, mut joker_number2) = board.player2;
    if is_joker {
        if side == player1_side {
            joker_number1 -= 1;
        } else {
            joker_number2 -= 1;
        }
    }

    board.player1 = (player1_address, player1_side, joker_number1);
    board.player2 = (player2_address, player2_side, joker_number2);

    (joker_number1, joker_number2)
}

/// Draws random tile from the board deck and updates the deck without the drawn tile.
pub fn draw_tile_from_board_deck(ref board: Board) -> Option<u8> {
    let avaliable_tiles: Array<u8> = board.available_tiles_in_deck.clone();
    if avaliable_tiles.len() == 0 {
        board.top_tile = Option::None;
        return Option::None;
    }
    let mut dice = DiceTrait::new(
        avaliable_tiles.len().try_into().unwrap(), 'SEED' 
        // + get_block_timestamp().into(),
    );

    let mut next_tile = dice.roll() - 1;

    let tile: u8 = *avaliable_tiles.at(next_tile.into());

    // Remove the drawn tile from the deck.
    let mut updated_available_tiles: Array<u8> = ArrayTrait::new();
    for i in 0..avaliable_tiles.len() {
        if i != next_tile.into() {
            updated_available_tiles.append(*avaliable_tiles.at(i.into()));
        }
    };

    board.available_tiles_in_deck = updated_available_tiles.clone();
    board.top_tile = Option::Some(tile.into());

    return Option::Some(tile);
}

pub fn redraw_tile_from_board_deck(ref board: Board) {
    if board.top_tile.is_some() {
        board.available_tiles_in_deck.append(board.top_tile.unwrap());
        board.top_tile = Option::None;
    }

    let _new_top_tile = draw_tile_from_board_deck(ref board);
}


pub fn generate_initial_board_state(
    cities_on_edges: u8, roads_on_edges: u8, board_id: felt252,
) -> Array<u8> {
    let mut initial_state: Array<u8> = ArrayTrait::new();

    for side in 0..4_u8 {
        let mut deck = DeckTrait::new(
            // (
                'SEED',
            // + side.into() + get_block_timestamp().into() + board_id).into(),
             8,
        );
        let mut edge: Felt252Dict<u8> = Default::default();
        for i in 0..8_u8 {
            edge.insert(i.into(), TEdge::M.into());
        };
        for _ in 0..cities_on_edges {
            edge.insert(deck.draw().into() - 1, TEdge::C.into());
        };
        for _ in 0..roads_on_edges {
            edge.insert(deck.draw().into() - 1, TEdge::R.into());
        };

        for i in 0..8_u8 {
            initial_state.append(edge.get(i.into()));
        };
    };
    return initial_state;
}

fn flatten_deck_rules(deck_rules: Span<u8>) -> Array<u8> {
    let mut deck_rules_flat = ArrayTrait::new();
    for tile_index in 0..24_u8 {
        let tile_type: u8 = tile_index;
        let tile_amount: u8 = *deck_rules.at(tile_index.into());
        for _ in 0..tile_amount {
            deck_rules_flat.append(tile_type);
        }
    };

    return deck_rules_flat;
}