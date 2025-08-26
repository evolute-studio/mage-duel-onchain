use starknet::ContractAddress;
use evolute_duel::{
    models::{game::{Board, Move}}, events::{NotYourTurn}, types::packing::{PlayerSide},
};
use dojo::{model::{ModelStorage}, event::EventStorage};
use starknet::get_block_timestamp;

#[generate_trait]
pub impl TimingImpl of TimingTrait {
    fn validate_move_turn(
        board: @Board,
        player: ContractAddress,
        player_side: PlayerSide,
        mut world: dojo::world::WorldStorage,
    ) -> bool {
        Self::validate_current_player_turn(board, player, player_side, world)
    }

    fn validate_phase_timing(board: @Board, timeout_duration: u64) -> bool {
        get_block_timestamp() <= *board.phase_started_at + timeout_duration
    }

    fn validate_current_player_turn(
        board: @Board,
        player: ContractAddress,
        player_side: PlayerSide,
        mut world: dojo::world::WorldStorage,
    ) -> bool {
        let prev_move_id = *board.last_move_id;
        if prev_move_id.is_some() {
            let prev_move_id = prev_move_id.unwrap();
            let prev_move: Move = world.read_model(prev_move_id);
            let prev_player_side = prev_move.player_side;

            if player_side == prev_player_side {
                world.emit_event(@NotYourTurn { player_id: player, board_id: *board.id });
                return false;
            }
        }
        true
    }

    fn validate_phase_timeout(
        board: @Board, creating_time: u64, reveal_time: u64, move_time: u64,
    ) -> bool {
        let current_timestamp = get_block_timestamp();
        let phase_started_at = *board.phase_started_at;

        match *board.game_state {
            evolute_duel::types::packing::GameState::Creating => {
                current_timestamp > phase_started_at + creating_time
            },
            evolute_duel::types::packing::GameState::Reveal => {
                current_timestamp > phase_started_at + reveal_time
            },
            evolute_duel::types::packing::GameState::Request => {
                current_timestamp > phase_started_at + reveal_time
            },
            evolute_duel::types::packing::GameState::Move => {
                current_timestamp > phase_started_at + move_time
            },
            _ => false,
        }
    }

    fn check_two_consecutive_skips(board: @Board, mut world: dojo::world::WorldStorage) -> bool {
        let prev_move_id = *board.last_move_id;
        if prev_move_id.is_some() {
            let prev_move_id = prev_move_id.unwrap();
            let prev_move: Move = world.read_model(prev_move_id);

            // Check if previous move was a skip (no tile placed and not a joker)
            if prev_move.tile.is_none() && !prev_move.is_joker {
                return true; // Previous was skip, current is also skip = two consecutive skips
            }
        }
        false
    }
}
