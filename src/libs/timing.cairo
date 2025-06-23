use starknet::ContractAddress;
use evolute_duel::{
    models::{game::{Board, Move}}, events::{NotYourTurn}, types::packing::{PlayerSide},
};
use dojo::{model::{ModelStorage}, event::EventStorage};
use starknet::get_block_timestamp;

#[generate_trait]
pub impl TimingImpl of TimingTrait {
    fn validate_move_timing(
        board: @Board,
        player: ContractAddress,
        player_side: PlayerSide,
        move_time: u64,
        mut world: dojo::world::WorldStorage,
    ) -> bool {
        let prev_move_id = *board.last_move_id;
        if prev_move_id.is_some() {
            let prev_move_id = prev_move_id.unwrap();
            let prev_move: Move = world.read_model(prev_move_id);
            let prev_player_side = prev_move.player_side;
            let time = get_block_timestamp();
            let last_update_timestamp = *board.last_update_timestamp;
            let time_delta = time - last_update_timestamp;

            if player_side == prev_player_side {
                if time_delta <= move_time || time_delta > 2 * move_time {
                    world.emit_event(@NotYourTurn { player_id: player, board_id: *board.id });
                    return false;
                }
            } else {
                if time_delta > move_time {
                    world.emit_event(@NotYourTurn { player_id: player, board_id: *board.id });
                    return false;
                }
            }
        }
        true
    }

    fn should_skip_opponent_move(
        board: @Board,
        player: ContractAddress,
        player_side: PlayerSide,
        player1_address: ContractAddress,
        player2_address: ContractAddress,
        player1_side: PlayerSide,
        player2_side: PlayerSide,
        move_time: u64,
        mut world: dojo::world::WorldStorage,
    ) -> Option<(ContractAddress, PlayerSide)> {
        let prev_move_id = *board.last_move_id;
        if prev_move_id.is_some() {
            let prev_move_id = prev_move_id.unwrap();
            let prev_move: Move = world.read_model(prev_move_id);
            let prev_player_side = prev_move.player_side;
            let time = get_block_timestamp();
            let last_update_timestamp = *board.last_update_timestamp;
            let time_delta = time - last_update_timestamp;

            if player_side == prev_player_side {
                if time_delta > move_time && time_delta <= 2 * move_time {
                    let another_player = if player == player1_address {
                        player2_address
                    } else {
                        player1_address
                    };
                    let another_player_side = if player == player1_address {
                        player2_side
                    } else {
                        player1_side
                    };
                    return Option::Some((another_player, another_player_side));
                }
            }
        }
        Option::None
    }

    fn validate_skip_move_timing(
        board: @Board,
        player: ContractAddress,
        player_side: PlayerSide,
        player1_address: ContractAddress,
        player2_address: ContractAddress,
        player1_side: PlayerSide,
        player2_side: PlayerSide,
        move_time: u64,
        mut world: dojo::world::WorldStorage,
    ) -> Option<(ContractAddress, PlayerSide)> {
        let prev_move_id = *board.last_move_id;
        if prev_move_id.is_some() {
            let prev_move_id = prev_move_id.unwrap();
            let prev_move: Move = world.read_model(prev_move_id);
            let prev_player_side = prev_move.player_side;

            let time = get_block_timestamp();
            let last_update_timestamp = *board.last_update_timestamp;
            let time_delta = time - last_update_timestamp;

            if player_side == prev_player_side {
                if time_delta > move_time && time_delta <= 2 * move_time {
                    let another_player = if player == player1_address {
                        player2_address
                    } else {
                        player1_address
                    };
                    let another_player_side = if player == player1_address {
                        player2_side
                    } else {
                        player1_side
                    };
                    return Option::Some((another_player, another_player_side));
                }

                if time_delta <= move_time || time_delta > 2 * move_time {
                    world.emit_event(@NotYourTurn { player_id: player, board_id: *board.id });
                    return Option::None;
                }
            } else {
                if time_delta > move_time {
                    world.emit_event(@NotYourTurn { player_id: player, board_id: *board.id });
                    return Option::None;
                }
            }
        }
        Option::Some((player, player_side))
    }

    fn check_if_game_should_finish_after_skip(
        board: @Board, mut world: dojo::world::WorldStorage,
    ) -> bool {
        let prev_move_id = *board.last_move_id;
        if prev_move_id.is_some() {
            let prev_move_id = prev_move_id.unwrap();
            let prev_move: Move = world.read_model(prev_move_id);

            if prev_move.tile.is_none() && !prev_move.is_joker {
                return true;
            }
        }
        false
    }

    fn validate_finish_game_timing(board: @Board, move_time: u64) -> bool {
        let last_update_timestamp = *board.last_update_timestamp;
        let timestamp = get_block_timestamp();
        let time_delta = timestamp - last_update_timestamp;
        time_delta > 2 * move_time
    }
}
