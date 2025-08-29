#[cfg(test)]
mod tests {
    use core::starknet::testing;
    use dojo::model::{ModelStorage, Model};
    use dojo::world::{WorldStorage, IWorldDispatcher};
    use starknet::{ContractAddress, get_block_timestamp};

    use evolute_duel::{
        models::{
            game::{Board},
        },
        types::packing::{GameState},
        libs::{
            phase_management::{PhaseManagementTrait, PhaseTransitionData},
        },
        tests::test_helpers::trait_test_helpers::{TraitTestHelpersTrait},
        events::{PhaseStarted},
    };

    use dojo::utils::test::{spawn_test_world, deploy_contract};

    fn setup_world() -> WorldStorage {
        let world = spawn_test_world(
            array![
                evolute_duel::models::game::board::TEST_CLASS_HASH,
            ]
        );
        
        let mut world_storage = WorldStorage { dispatcher: world };
        TraitTestHelpersTrait::setup_world_with_models(world_storage);
        world_storage
    }

    #[test]
    fn test_get_phase_number() {
        assert!(PhaseManagementTrait::get_phase_number(GameState::Creating) == 0, "Creating should be phase 0");
        assert!(PhaseManagementTrait::get_phase_number(GameState::Reveal) == 1, "Reveal should be phase 1");
        assert!(PhaseManagementTrait::get_phase_number(GameState::Request) == 2, "Request should be phase 2");
        assert!(PhaseManagementTrait::get_phase_number(GameState::Move) == 3, "Move should be phase 3");
        assert!(PhaseManagementTrait::get_phase_number(GameState::Finished) == 255, "Finished should be invalid phase");
    }

    #[test]
    fn test_update_board_phase() {
        let mut world = setup_world();
        let board_id = 12345;
        let new_state = GameState::Move;
        let initial_timestamp = get_block_timestamp();
        
        PhaseManagementTrait::update_board_phase(board_id, new_state, world);
        
        let updated_board: Board = world.read_model(board_id);
        assert!(updated_board.game_state == new_state, "Game state should be updated");
        assert!(updated_board.phase_started_at >= initial_timestamp, "Phase start time should be updated");
        assert!(updated_board.last_update_timestamp >= initial_timestamp, "Last update time should be updated");
    }

    #[test]
    fn test_transition_to_phase() {
        let mut world = setup_world();
        let board_id = 12345;
        let top_tile = Option::Some(5);
        let commited_tile = Option::Some(42);
        
        let transition_data = PhaseTransitionData {
            board_id,
            new_game_state: GameState::Reveal,
            top_tile,
            commited_tile,
        };
        
        PhaseManagementTrait::transition_to_phase(transition_data, world);
        
        let updated_board: Board = world.read_model(board_id);
        assert!(updated_board.game_state == GameState::Reveal, "Should transition to Reveal state");
    }

    #[test]
    fn test_transition_to_reveal_phase() {
        let mut world = setup_world();
        let board_id = 12345;
        let top_tile = Option::Some(3);
        let commited_tile = Option::Some(42);
        
        PhaseManagementTrait::transition_to_reveal_phase(board_id, top_tile, commited_tile, world);
        
        TraitTestHelpersTrait::assert_board_game_state(world, GameState::Reveal);
    }

    #[test]
    fn test_transition_to_request_phase() {
        let mut world = setup_world();
        let board_id = 12345;
        let top_tile = Option::Some(7);
        let commited_tile = Option::None;
        
        PhaseManagementTrait::transition_to_request_phase(board_id, top_tile, commited_tile, world);
        
        TraitTestHelpersTrait::assert_board_game_state(world, GameState::Request);
    }

    #[test]
    fn test_transition_to_move_phase() {
        let mut world = setup_world();
        let board_id = 12345;
        let top_tile = Option::Some(8);
        let commited_tile = Option::Some(99);
        
        PhaseManagementTrait::transition_to_move_phase(board_id, top_tile, commited_tile, world);
        
        TraitTestHelpersTrait::assert_board_game_state(world, GameState::Move);
    }

    #[test]
    fn test_transition_to_creating_phase() {
        let mut world = setup_world();
        let board_id = 12345;
        let top_tile = Option::None;
        let commited_tile = Option::None;
        
        PhaseManagementTrait::transition_to_creating_phase(board_id, top_tile, commited_tile, world);
        
        TraitTestHelpersTrait::assert_board_game_state(world, GameState::Creating);
    }

    #[test]
    fn test_determine_next_phase_after_move_with_committed_tile() {
        let commited_tile = Option::Some(42);
        
        let next_phase = PhaseManagementTrait::determine_next_phase_after_move(commited_tile);
        
        assert!(next_phase == GameState::Reveal, "Should transition to Reveal when tile is committed");
    }

    #[test]
    fn test_determine_next_phase_after_move_without_committed_tile() {
        let commited_tile = Option::None;
        
        let next_phase = PhaseManagementTrait::determine_next_phase_after_move(commited_tile);
        
        assert!(next_phase == GameState::Move, "Should stay in Move when no tile is committed");
    }

    #[test]
    fn test_transition_after_move_to_reveal() {
        let mut world = setup_world();
        let board_id = 12345;
        let top_tile = Option::Some(5);
        let commited_tile = Option::Some(42); // Has committed tile, should go to Reveal
        
        PhaseManagementTrait::transition_after_move(board_id, top_tile, commited_tile, world);
        
        TraitTestHelpersTrait::assert_board_game_state(world, GameState::Reveal);
    }

    #[test]
    fn test_transition_after_move_to_move() {
        let mut world = setup_world();
        let board_id = 12345;
        let top_tile = Option::Some(5);
        let commited_tile = Option::None; // No committed tile, should stay in Move
        
        PhaseManagementTrait::transition_after_move(board_id, top_tile, commited_tile, world);
        
        TraitTestHelpersTrait::assert_board_game_state(world, GameState::Move);
    }

    #[test]
    fn test_phase_transition_updates_timestamps() {
        let mut world = setup_world();
        let board_id = 12345;
        
        // Get initial timestamp
        let initial_board: Board = world.read_model(board_id);
        let initial_timestamp = initial_board.phase_started_at;
        
        // Wait a moment (in test this might not actually wait, but in real scenario it would)
        starknet::testing::set_block_timestamp(initial_timestamp + 1);
        
        // Transition to a new phase
        PhaseManagementTrait::transition_to_move_phase(
            board_id, 
            Option::Some(1), 
            Option::None, 
            world
        );
        
        // Check that timestamp was updated
        TraitTestHelpersTrait::assert_phase_started_at_updated(world, initial_timestamp);
    }

    #[test]
    fn test_multiple_phase_transitions() {
        let mut world = setup_world();
        let board_id = 12345;
        
        // Start in Creating
        PhaseManagementTrait::transition_to_creating_phase(board_id, Option::None, Option::None, world);
        TraitTestHelpersTrait::assert_board_game_state(world, GameState::Creating);
        
        // Move to Reveal
        PhaseManagementTrait::transition_to_reveal_phase(board_id, Option::None, Option::Some(42), world);
        TraitTestHelpersTrait::assert_board_game_state(world, GameState::Reveal);
        
        // Move to Request
        PhaseManagementTrait::transition_to_request_phase(board_id, Option::Some(5), Option::None, world);
        TraitTestHelpersTrait::assert_board_game_state(world, GameState::Request);
        
        // Move to Move
        PhaseManagementTrait::transition_to_move_phase(board_id, Option::Some(5), Option::Some(99), world);
        TraitTestHelpersTrait::assert_board_game_state(world, GameState::Move);
    }

    #[test]
    fn test_emit_phase_started_event() {
        let mut world = setup_world();
        let board_id = 12345;
        let top_tile = Option::Some(7);
        let commited_tile = Option::Some(42);
        
        let transition_data = PhaseTransitionData {
            board_id,
            new_game_state: GameState::Move,
            top_tile,
            commited_tile,
        };
        
        // This test verifies that the function doesn't panic when emitting events
        // In a full test environment, you would capture and verify the emitted events
        PhaseManagementTrait::emit_phase_started_event(transition_data, world);
    }

    #[test]
    fn test_phase_consistency_after_multiple_operations() {
        let mut world = setup_world();
        let board_id = 12345;
        
        // Perform several phase transitions
        PhaseManagementTrait::transition_to_creating_phase(board_id, Option::None, Option::None, world);
        PhaseManagementTrait::transition_to_reveal_phase(board_id, Option::None, Option::Some(1), world);
        PhaseManagementTrait::transition_after_move(board_id, Option::Some(2), Option::Some(3), world);
        
        // Verify final state
        let final_board: Board = world.read_model(board_id);
        assert!(final_board.game_state == GameState::Reveal, "Final state should be Reveal due to committed tile");
        
        // Verify that all board fields are consistent
        assert!(final_board.id == board_id, "Board ID should remain consistent");
        assert!(final_board.phase_started_at > 0, "Phase start time should be set");
        assert!(final_board.last_update_timestamp > 0, "Last update time should be set");
    }
}