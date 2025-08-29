use starknet::ContractAddress;
use evolute_duel::{
    models::{game::{Board, Move, Rules}}, events::{Moved, BoardUpdated, InvalidMove, NotEnoughJokers},
    systems::helpers::{validation::{is_valid_move}, board::{BoardTrait}},
    types::packing::{PlayerSide, Tile},
    events::{ErrorEvent}
};
use dojo::world::{WorldStorage};
use dojo::model::{ModelStorage, Model};
use dojo::event::EventStorage;
use starknet::get_block_timestamp;

#[derive(Drop, Copy, Debug)]
pub struct MoveData {
    pub tile: u8,
    pub rotation: u8,
    pub col: u8,
    pub row: u8,
    pub is_joker: bool,
    pub player_side: PlayerSide,
    pub top_tile: Option<u8>,
}

#[generate_trait]
pub impl MoveExecutionImpl of MoveExecutionTrait {
    fn validate_joker_usage(
        joker_tile: Option<u8>,
        joker_number: u8,
        player: ContractAddress,
        board_id: felt252,
        mut world: dojo::world::WorldStorage,
    ) -> bool {
        let is_joker = joker_tile.is_some();
        if is_joker && joker_number == 0 {
            world.emit_event(@NotEnoughJokers { player_id: player, board_id });
            return false;
        }
        true
    }

    fn get_tile_for_move(joker_tile: Option<u8>, board: @Board, mut world: WorldStorage, player_address: ContractAddress) -> Option<u8> {
        match joker_tile {
            Option::Some(tile_type) => Option::Some(tile_type),
            Option::None => {
                match *board.top_tile {
                    Option::Some(tile_index) => Option::Some(*(*board.available_tiles_in_deck).at(tile_index.into())),
                    Option::None => {
                        if board.commited_tile.is_none() {
                            world.emit_event(@ErrorEvent {
                                player_address,
                                name: 'No tiles in the deck',
                                message: "There are no tiles available in the deck to play",
                            });
                            return Option::None; 
                        } else {
                            world.emit_event(@ErrorEvent {
                                player_address,
                                name: 'Tile not revealed',
                                message: "The top tile is not revealed yet",
                            });
                            return Option::None;
                        }
                    },
                }
            },
        }
    }

    fn validate_move(board_id: felt252, tile: Tile, rotation: u8, col: u8, row: u8, board_size: u32, world: WorldStorage) -> bool {
        is_valid_move(
            board_id, tile, rotation, col.into(), row.into(), board_size, 1, 1, board_size - 2, board_size - 2, false, world
        )
    }

    fn create_move_record(
        move_id: felt252, move_data: MoveData, prev_move_id: Option<felt252>, board_id: felt252,
    ) -> Move {
        Move {
            id: move_id,
            prev_move_id,
            player_side: move_data.player_side,
            tile: Option::Some(move_data.tile.into()),
            rotation: move_data.rotation,
            col: move_data.col,
            row: move_data.row,
            is_joker: move_data.is_joker,
            first_board_id: board_id,
            timestamp: get_block_timestamp(),
            top_tile: move_data.top_tile,
        }
    }

    fn update_board_after_move(
        move_data: MoveData, ref board: Board, is_joker: bool, is_tutorial: bool, world: WorldStorage,
    ) -> Option<u8> {
        let top_tile = if is_tutorial {
            Self::update_top_tile_in_tutorial(@board)
        } else {
            Option::None
        };

        let (_, _) = BoardTrait::update_board_joker_number(
            ref board, move_data.player_side, is_joker,
        );

        println!(
            "Updating board after move: move_data: {:?}, is_joker: {}, is_tutorial: {}",
            move_data, is_joker, is_tutorial
        );
        println!(
            "Board before move: {:?}",
            board
        );

        if is_tutorial && board.moves_done == 0 {
            println!("First move in tutorial, updating available tiles in deck");
            if move_data.rotation == 2 {
                // If the first move if road facing right, we need to change deck
                println!("Updating deck to right facing tiles");
                BoardTrait::replace_tile_in_deck(
                    ref board, 2, Tile::CCRF, world
                );
                Self::update_avaliable_tiles_in_board(
                    board.id, board.available_tiles_in_deck, world
                );
            }
        }
        // Only increment moves_done for actual tile placements (not skips)
        board.moves_done = board.moves_done + 1;
        board.top_tile = top_tile;

        top_tile
    }

    fn update_top_tile_in_tutorial(board: @Board) -> Option<u8> {
        match board.top_tile {
            Option::Some(tile_index) => {
                if *tile_index == ((*board.available_tiles_in_deck).len().try_into().unwrap() - 1) {
                    Option::None
                } else {
                    Option::Some(*tile_index + 1)
                }
            },
            Option::None => Option::None, 
        }
    }

    fn emit_move_events(
        move_record: Move,
        board: @Board,
        player: ContractAddress,
        mut world: dojo::world::WorldStorage,
    ) {
        world
            .emit_event(
                @Moved {
                    move_id: move_record.id,
                    player,
                    prev_move_id: move_record.prev_move_id,
                    tile: move_record.tile,
                    rotation: move_record.rotation,
                    col: move_record.col,
                    row: move_record.row,
                    is_joker: move_record.is_joker,
                    board_id: *board.id,
                    timestamp: move_record.timestamp,
                },
            );

        world
            .emit_event(
                @BoardUpdated {
                    board_id: *board.id,
                    top_tile: *board.top_tile,
                    player1: *board.player1,
                    player2: *board.player2,
                    blue_score: *board.blue_score,
                    red_score: *board.red_score,
                    last_move_id: *board.last_move_id,
                    moves_done: *board.moves_done,
                    game_state: *board.game_state,
                },
            );
    }

    fn emit_board_updated_event(
        board: @Board,
        mut world: dojo::world::WorldStorage,
    ) {
        world
            .emit_event(
                @BoardUpdated {
                    board_id: *board.id,
                    top_tile: *board.top_tile,
                    player1: *board.player1,
                    player2: *board.player2,
                    blue_score: *board.blue_score,
                    red_score: *board.red_score,
                    last_move_id: *board.last_move_id,
                    moves_done: *board.moves_done,
                    game_state: *board.game_state,
                },
            );
    }

    fn emit_invalid_move_event(
        move_record: Move,
        board_id: felt252,
        player: ContractAddress,
        mut world: dojo::world::WorldStorage,
    ) {
        world
            .emit_event(
                @InvalidMove {
                    player,
                    prev_move_id: move_record.prev_move_id,
                    tile: move_record.tile,
                    rotation: move_record.rotation,
                    col: move_record.col,
                    row: move_record.row,
                    is_joker: move_record.is_joker,
                    board_id,
                },
            );
    }

    fn update_avaliable_tiles_in_board(board_id: felt252, available_tiles_in_deck: Span<u8>, mut world: WorldStorage) {
        world.write_member(
            Model::<Board>::ptr_from_keys(board_id), selector!("available_tiles_in_deck"), available_tiles_in_deck,
        );
    }

    fn persist_board_updates(
        board: @Board,
        move_record: Move,
        top_tile: Option<u8>,
        mut world: dojo::world::WorldStorage,
    ) {
        let board_id = *board.id;

        world.write_model(@move_record);

        world
            .write_member(Model::<Board>::ptr_from_keys(board_id), selector!("top_tile"), top_tile);

        world
            .write_member(
                Model::<Board>::ptr_from_keys(board_id), selector!("player1"), *board.player1,
            );

        world
            .write_member(
                Model::<Board>::ptr_from_keys(board_id), selector!("player2"), *board.player2,
            );

        world
            .write_member(
                Model::<Board>::ptr_from_keys(board_id), selector!("blue_score"), *board.blue_score,
            );

        world
            .write_member(
                Model::<Board>::ptr_from_keys(board_id), selector!("red_score"), *board.red_score,
            );

        world
            .write_member(
                Model::<Board>::ptr_from_keys(board_id),
                selector!("last_move_id"),
                *board.last_move_id,
            );

        world
            .write_member(
                Model::<Board>::ptr_from_keys(board_id), selector!("moves_done"), *board.moves_done,
            );

        world
            .write_member(
                Model::<Board>::ptr_from_keys(board_id), selector!("game_state"), *board.game_state,
            );
    }

    fn should_finish_game(
        joker_number1: u8, 
        joker_number2: u8, 
        available_tiles_len_player1: u32, 
        available_tiles_len_player2: u32
    ) -> bool {
        (available_tiles_len_player1 == 0 && available_tiles_len_player2 == 0 && joker_number1 == 0 && joker_number2 == 0)
    }

    fn is_board_full(moves_done: u8, board_size: u8) -> bool {
        let playable_positions = (board_size - 2) * (board_size - 2);
        moves_done >= playable_positions
    }

    fn create_skip_move_record(
        move_id: felt252, player_side: PlayerSide, prev_move_id: Option<felt252>, board_id: felt252, top_tile: Option<u8>,
    ) -> Move {
        Move {
            id: move_id,
            prev_move_id,
            player_side,
            tile: Option::None,
            rotation: 0,
            col: 0,
            row: 0,
            is_joker: false,
            first_board_id: board_id,
            timestamp: get_block_timestamp(),
            top_tile,
        }
    }
}
