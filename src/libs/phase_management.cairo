use evolute_duel::{models::game::Board, events::PhaseStarted, types::packing::GameState};
use dojo::{model::{ModelStorage, Model}, event::EventStorage};
use starknet::get_block_timestamp;

#[derive(Drop, Copy)]
pub struct PhaseTransitionData {
    pub board_id: felt252,
    pub new_game_state: GameState,
    pub top_tile: Option<u8>,
    pub commited_tile: Option<u8>,
}

#[generate_trait]
pub impl PhaseManagementImpl of PhaseManagementTrait {
    fn get_phase_number(game_state: GameState) -> u8 {
        match game_state {
            GameState::Creating => 0,
            GameState::Reveal => 1,
            GameState::Request => 2,
            GameState::Move => 3,
            _ => 255 // Invalid phase
        }
    }

    fn update_board_phase(
        board_id: felt252, new_game_state: GameState, mut world: dojo::world::WorldStorage,
    ) {
        let timestamp = get_block_timestamp();

        world
            .write_member(
                Model::<Board>::ptr_from_keys(board_id), selector!("game_state"), new_game_state,
            );

        world
            .write_member(
                Model::<Board>::ptr_from_keys(board_id), selector!("phase_started_at"), timestamp,
            );
    }

    fn emit_phase_started_event(
        transition_data: PhaseTransitionData, mut world: dojo::world::WorldStorage,
    ) {
        let phase_number = Self::get_phase_number(transition_data.new_game_state);
        let timestamp = get_block_timestamp();

        world
            .emit_event(
                @PhaseStarted {
                    board_id: transition_data.board_id,
                    phase: phase_number,
                    top_tile: transition_data.top_tile,
                    commited_tile: transition_data.commited_tile,
                    started_at: timestamp,
                },
            );
    }

    fn transition_to_phase(
        transition_data: PhaseTransitionData, mut world: dojo::world::WorldStorage,
    ) {
        Self::update_board_phase(transition_data.board_id, transition_data.new_game_state, world);

        Self::emit_phase_started_event(transition_data, world);
    }

    fn transition_to_reveal_phase(
        board_id: felt252,
        top_tile: Option<u8>,
        commited_tile: Option<u8>,
        mut world: dojo::world::WorldStorage,
    ) {
        let transition_data = PhaseTransitionData {
            board_id, new_game_state: GameState::Reveal, top_tile, commited_tile,
        };

        Self::transition_to_phase(transition_data, world);
    }

    fn transition_to_request_phase(
        board_id: felt252,
        top_tile: Option<u8>,
        commited_tile: Option<u8>,
        mut world: dojo::world::WorldStorage,
    ) {
        let transition_data = PhaseTransitionData {
            board_id, new_game_state: GameState::Request, top_tile, commited_tile,
        };

        Self::transition_to_phase(transition_data, world);
    }

    fn transition_to_move_phase(
        board_id: felt252,
        top_tile: Option<u8>,
        commited_tile: Option<u8>,
        mut world: dojo::world::WorldStorage,
    ) {
        let transition_data = PhaseTransitionData {
            board_id, new_game_state: GameState::Move, top_tile, commited_tile,
        };

        Self::transition_to_phase(transition_data, world);
    }

    fn transition_to_creating_phase(
        board_id: felt252,
        top_tile: Option<u8>,
        commited_tile: Option<u8>,
        mut world: dojo::world::WorldStorage,
    ) {
        let transition_data = PhaseTransitionData {
            board_id, new_game_state: GameState::Creating, top_tile, commited_tile,
        };

        Self::transition_to_phase(transition_data, world);
    }

    fn determine_next_phase_after_move(commited_tile: Option<u8>) -> GameState {
        match commited_tile {
            Option::Some(_) => GameState::Reveal,
            Option::None => GameState::Move,
        }
    }

    fn transition_after_move(
        board_id: felt252,
        top_tile: Option<u8>,
        commited_tile: Option<u8>,
        mut world: dojo::world::WorldStorage,
    ) {
        let next_state = Self::determine_next_phase_after_move(commited_tile);

        let transition_data = PhaseTransitionData {
            board_id, new_game_state: next_state, top_tile, commited_tile,
        };

        Self::transition_to_phase(transition_data, world);
    }
}
