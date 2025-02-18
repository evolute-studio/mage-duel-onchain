use dojo::event::EventStorage;
use dojo::world::{WorldStorage};
use starknet::{ContractAddress};
use evolute_duel::models::{Board, TEdge, GameState, Rules, Tile};

use dojo::model::{ModelStorage};
use origami_random::deck::{DeckTrait};
use core::dict::Felt252Dict;

use evolute_duel::events::{BoardCreated};

pub fn create_board(
    mut world: WorldStorage, player1: ContractAddress, player2: ContractAddress,
) -> Board {
    // let board_id = world.uuid();
    // TODO: Generate unique id for board. Use simple counter increment for board_count.
    let board_id = 0;

    let rules: Rules = world.read_model(0);

    let (cities_on_edges, roads_on_edges) = rules.edges;
    let initial_edge_state = generate_initial_board_state(cities_on_edges, roads_on_edges);

    let mut deck_rules_flat = flatten_deck_rules(@rules.deck);

    // Create an empty board.
    let mut tiles: Array<u8> = ArrayTrait::new();
    tiles.append_span([(Tile::Empty).into(); 64].span());

    let last_move_id = Option::Some(0);
    let game_state = GameState::InProgress;

    let board = Board {
        id: board_id,
        initial_edge_state: initial_edge_state.clone(),
        available_tiles_in_deck: deck_rules_flat.clone(),
        state: tiles.clone(),
        player1,
        player2,
        last_move_id,
        game_state,
    };

    // Write the board to the world.
    world.write_model(@board);

    // // Emit an event to the world to notify about the board creation.
    world
        .emit_event(
            @BoardCreated {
                board_id,
                initial_edge_state,
                available_tiles_in_deck: deck_rules_flat,
                state: tiles,
                player1,
                player2,
                last_move_id: 0,
                game_state,
            },
        );

    return board;
}


fn generate_initial_board_state(cities_on_edges: u8, roads_on_edges: u8) -> Array<u8> {
    let mut initial_state: Array<u8> = ArrayTrait::new();

    for side in 0..4_u8 {
        let mut deck = DeckTrait::new(('SEED' + side.into()).into(), 8);
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

        //TODO: No sense to do transformation 0 -> M, 1 -> C, 2 -> R. Why not doing deck.draw()
        //right in loop and get rid of edge variable?
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

    // let mut random_deck: Array<Tile> = ArrayTrait::new();
    // for _ in 0..64_u8 {
    //     let random_tile: Tile = *avaliable_tiles.at(deck.draw().into() - 1);
    //     random_deck.append(random_tile);
    // };

    return deck_rules_flat;
}
