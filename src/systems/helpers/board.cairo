use starknet::{ContractAddress};
use origami_random::deck::{DeckTrait};
use origami_random::dice::{DiceTrait};
use core::dict::Felt252Dict;

use evolute_duel::{
    models::game::{Board, Rules, Move},
    packing::{GameState, TEdge, Tile, PlayerSide},
    systems::helpers::{
        city_scoring::{connect_adjacent_city_edges, connect_city_edges_in_tile},
        road_scoring::{connect_adjacent_road_edges, connect_road_edges_in_tile},
        tile_helpers::{calcucate_tile_points},
    },
};

use evolute_duel::libs::store::{Store, StoreTrait};

use core::starknet::get_block_timestamp;


pub fn create_board(
    ref store: Store,
    player1: ContractAddress,
    player2: ContractAddress,
    duel_id: felt252,
) -> Board {
    let rules: Rules = store.get_rules();
    let mut deck_rules_flat = flatten_deck_rules(@rules.deck);

    // Create an empty board.
    let mut tiles: Array<(u8, u8, u8)> = ArrayTrait::new();
    tiles.append_span([((Tile::Empty).into(), 0, 0); 64].span());

    let last_move_id = Option::None;
    let game_state = GameState::InProgress;

    let mut board = Board {
        id: duel_id,
        initial_edge_state: array![],
        available_tiles_in_deck: deck_rules_flat.clone(),
        top_tile: Option::None,
        state: tiles.clone(),
        player1: (player1, PlayerSide::Blue, rules.joker_number),
        player2: (player2, PlayerSide::Red, rules.joker_number),
        blue_score: (0, 0),
        red_score: (0, 0),
        last_move_id,
        game_state,
    };

    let _top_tile = draw_tile_from_board_deck(ref board);

    store.set_board(@board);

    // Initialize edges
    let (cities_on_edges, roads_on_edges) = rules.edges;
    let initial_edge_state = generate_initial_board_state(
        cities_on_edges, roads_on_edges, duel_id,
    );
    store.set_board_initial_state(duel_id, initial_edge_state);

    store.emit_board_created(board.clone());

    return board;
}

pub fn create_board_from_snapshot(
    ref store: Store,
    old_board_id: felt252,
    player1: ContractAddress,
    player2: ContractAddress,
    move_number: u8,
    duel_id: felt252,
) {
    let mut old_board: Board = store.get_board(old_board_id);
    let new_board_id = duel_id;

    let rules: Rules = store.get_rules();
    let mut deck_rules_flat = flatten_deck_rules(@rules.deck);

    let mut tiles: Array<(u8, u8, u8)> = ArrayTrait::new();
    tiles.append_span([((Tile::Empty).into(), 0, 0); 64].span());

    let mut new_board: Board = Board {
        id: new_board_id,
        initial_edge_state: old_board.initial_edge_state.clone(),
        available_tiles_in_deck: deck_rules_flat.clone(),
        top_tile: Option::None,
        state: tiles.clone(),
        player1: (player1, PlayerSide::Blue, rules.joker_number),
        player2: (player2, PlayerSide::Red, rules.joker_number),
        blue_score: (0, 0),
        red_score: (0, 0),
        last_move_id: Option::None,
        game_state: GameState::InProgress,
    };

    let mut drawn_tiles: Felt252Dict<u8> = Default::default();

    let mut move_ids = ArrayTrait::new();
    let mut current_move_id = old_board.last_move_id;
    while current_move_id.is_some() {
        let move_id = current_move_id.unwrap();
        move_ids.append(move_id);
        let move: Move = store.get_move(move_id);
        current_move_id = move.prev_move_id;
    };

    let mut move_ids = move_ids.span();
    let mut current_move_id = move_ids.pop_back();

    for _ in 0..move_number {
        let move_id = *current_move_id.unwrap();
        let move: Move = store.get_move(move_id);

        let tile = move.tile;
        let rotation = move.rotation;
        let col = move.col;
        let row = move.row;
        let is_joker = move.is_joker;
        let player_side = move.player_side;
        let next_move_id = move_ids.pop_back();

        if tile.is_some() {
            let tile = tile.unwrap();
            let tile_draws = drawn_tiles.get(tile.into());
            drawn_tiles.insert(tile.into(), tile_draws + 1);

            let tile_points = calcucate_tile_points(tile.into());
            let (city_points, road_points) = tile_points;
            if player_side == PlayerSide::Blue {
                let (city_score, road_score) = new_board.blue_score;
                new_board.blue_score = (city_score + city_points, road_score + road_points);
            } else {
                let (city_score, road_score) = new_board.red_score;
                new_board.red_score = (city_score + city_points, road_score + road_points);
            }

            let tile_position = (col * 8 + row).into();
            connect_city_edges_in_tile(
                ref store, new_board_id, tile_position, tile.into(), rotation, player_side.into(),
            );
            let city_contest_scoring_result = connect_adjacent_city_edges(
                ref store,
                new_board_id,
                new_board.state.clone(),
                new_board.initial_edge_state.clone(),
                tile_position,
                tile.into(),
                rotation,
                player_side.into(),
            );
            if city_contest_scoring_result.is_some() {
                let (winner, points_delta) = city_contest_scoring_result.unwrap();
                if winner == PlayerSide::Blue {
                    let (city_score, road_score) = new_board.blue_score;
                    new_board.blue_score = (city_score + points_delta, road_score);
                    let (city_score, road_score) = new_board.red_score;
                    new_board.red_score = (city_score - points_delta, road_score);
                } else {
                    let (city_score, road_score) = new_board.red_score;
                    new_board.red_score = (city_score + points_delta, road_score);
                    let (city_score, road_score) = new_board.blue_score;
                    new_board.blue_score = (city_score - points_delta, road_score);
                }
            }

            connect_road_edges_in_tile(
                ref store, new_board_id, tile_position, tile.into(), rotation, player_side.into(),
            );
            let road_contest_scoring_results = connect_adjacent_road_edges(
                ref store,
                new_board_id,
                new_board.state.clone(),
                new_board.initial_edge_state.clone(),
                tile_position,
                tile.into(),
                rotation,
                player_side.into(),
            );

            for i in 0..road_contest_scoring_results.len() {
                let road_scoring_result = *road_contest_scoring_results.at(i.into());
                if road_scoring_result.is_some() {
                    let (winner, points_delta) = road_scoring_result.unwrap();
                    if winner == PlayerSide::Blue {
                        let (city_score, road_score) = new_board.blue_score;
                        new_board.blue_score = (city_score, road_score + points_delta);
                        let (city_score, road_score) = new_board.red_score;
                        new_board.red_score = (city_score, road_score - points_delta);
                    } else {
                        let (city_score, road_score) = new_board.red_score;
                        new_board.red_score = (city_score, road_score + points_delta);
                        let (city_score, road_score) = new_board.blue_score;
                        new_board.blue_score = (city_score, road_score - points_delta);
                    }
                }
            };

            update_board_state(
                ref new_board, tile.into(), rotation, col, row, is_joker, player_side,
            );

            update_board_joker_number(ref new_board, player_side, is_joker);
        }
        new_board.last_move_id = Option::Some(move_id);
        current_move_id = next_move_id;
    };

    let mut updated_avaliable_tiles: Array<u8> = ArrayTrait::new();
    for i in 0..deck_rules_flat.len() {
        let tile = *deck_rules_flat.at(i.into());
        let drawn_tiles_number = drawn_tiles.get(tile.into());
        if drawn_tiles_number == 0 {
            updated_avaliable_tiles.append(tile);
        } else {
            drawn_tiles.insert(tile.into(), drawn_tiles_number - 1);
        }
    };
    new_board.available_tiles_in_deck = updated_avaliable_tiles.clone();
    new_board.top_tile = draw_tile_from_board_deck(ref new_board);

    new_board.initial_edge_state = array![];
    store.set_board(@new_board);
    store.set_board_initial_state(new_board_id, new_board.initial_edge_state.clone());


    store.emit_board_created_from_snapshot(new_board, old_board_id, move_number);
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
        avaliable_tiles.len().try_into().unwrap(), 'SEED' + get_block_timestamp().into(),
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
            ('SEED' + side.into() + get_block_timestamp().into() + board_id).into(), 8,
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

fn flatten_deck_rules(deck_rules: @Array<u8>) -> Array<u8> {
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
