use starknet::ContractAddress;
use evolute_duel::{
    models::{game::{Board, Move}}, events::{Moved, BoardUpdated, InvalidMove, NotEnoughJokers},
    systems::helpers::{validation::{is_valid_move}, board::{BoardTrait}},
    types::packing::{PlayerSide, Tile},
};
use dojo::world::{WorldStorage, WorldStorageTrait};
use dojo::model::{ModelStorage, Model};
use dojo::event::EventStorage;
use starknet::get_block_timestamp;

#[derive(Drop, Copy)]
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

    fn get_tile_for_move(joker_tile: Option<u8>, board: @Board) -> u8 {
        match joker_tile {
            Option::Some(tile_type) => tile_type,
            Option::None => {
                match *board.top_tile {
                    Option::Some(tile_index) => *(*board.available_tiles_in_deck).at(tile_index.into()),
                    Option::None => {
                        if board.commited_tile.is_none() {
                            return panic!("No tiles in the deck"); 
                        } else {
                            return panic!("Tile is not revealed yet");
                        }
                    },
                }
            },
        }
    }

    fn validate_move(board_id: felt252, tile: Tile, rotation: u8, col: u8, row: u8, world: WorldStorage) -> bool {
        is_valid_move(
            board_id, tile, rotation, col, row, world
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
        move_data: MoveData, ref board: Board, is_joker: bool,
    ) -> Option<u8> {
        let top_tile = match board.top_tile {
            Option::Some(tile_index) => {
                if tile_index == (board.available_tiles_in_deck.len().try_into().unwrap() - 1) {
                    Option::None
                } else {
                    Option::Some(tile_index + 1)
                }
            },
            Option::None => Option::None, 
        };

        let (_, _) = BoardTrait::update_board_joker_number(
            ref board, move_data.player_side, is_joker,
        );

        board.moves_done = board.moves_done + 1;

        top_tile
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
