// #[cfg(test)]
mod tests {
    use core::starknet::testing;
    use dojo::model::{ModelStorage, Model};
    use dojo::world::{WorldStorage, IWorldDispatcher};
    use starknet::{ContractAddress, get_block_timestamp};

    use evolute_duel::{
        models::{
            game::{Board, TileCommitments, AvailableTiles},
        },
        types::packing::{GameState},
        libs::{
            tile_reveal::{TileRevealTrait, TileRevealData},
        },
        tests::test_helpers::trait_test_helpers::{TraitTestHelpersTrait},
        utils::hash::{hash_values},
    };

    use dojo::utils::test::{spawn_test_world, deploy_contract};

    fn setup_world() -> WorldStorage {
        let world = spawn_test_world(
            array![
                evolute_duel::models::game::board::TEST_CLASS_HASH,
                evolute_duel::models::game::tile_commitments::TEST_CLASS_HASH,
                evolute_duel::models::game::available_tiles::TEST_CLASS_HASH,
            ]
        );
        
        let mut world_storage = WorldStorage { dispatcher: world };
        TraitTestHelpersTrait::setup_world_with_models(world_storage);
        world_storage
    }

    #[test]
    fn test_validate_tile_reveal_state_success() {
        let board = TraitTestHelpersTrait::create_test_board_with_state(GameState::Reveal);
        
        let result = TileRevealTrait::validate_tile_reveal_state(@board, GameState::Reveal);
        assert!(result, "Should validate correct reveal state");
    }

    #[test]
    fn test_validate_tile_reveal_state_wrong_state() {
        let board = TraitTestHelpersTrait::create_test_board_with_state(GameState::Move);
        
        let result = TileRevealTrait::validate_tile_reveal_state(@board, GameState::Reveal);
        assert!(!result, "Should fail with wrong game state");
    }

    #[test]
    fn test_validate_tile_reveal_state_no_top_tile() {
        let mut board = TraitTestHelpersTrait::create_test_board_with_state(GameState::Reveal);
        board.top_tile = Option::Some(1); // Should be None for reveal validation
        
        let result = TileRevealTrait::validate_tile_reveal_state(@board, GameState::Reveal);
        assert!(!result, "Should fail when top tile is already set");
    }

    #[test]
    fn test_validate_tile_reveal_state_no_committed_tile() {
        let mut board = TraitTestHelpersTrait::create_test_board_with_state(GameState::Reveal);
        board.top_tile = Option::None;
        board.commited_tile = Option::None; // Should be Some for reveal validation
        
        let result = TileRevealTrait::validate_tile_reveal_state(@board, GameState::Reveal);
        assert!(!result, "Should fail when no tile is committed");
    }

    #[test]
    fn test_validate_tile_reveal_timing_success() {
        let board = TraitTestHelpersTrait::create_test_board();
        let timeout = 120; // 2 minutes
        
        let result = TileRevealTrait::validate_tile_reveal_timing(@board, timeout);
        assert!(result, "Should validate timing within limit");
    }

    #[test]
    fn test_validate_committed_tile_match_success() {
        let board = TraitTestHelpersTrait::create_test_board();
        let tile_type = 42; // Same as in test board
        
        let result = TileRevealTrait::validate_committed_tile_match(@board, tile_type);
        assert!(result, "Should validate matching committed tile");
    }

    #[test]
    fn test_validate_committed_tile_match_failure() {
        let board = TraitTestHelpersTrait::create_test_board();
        let wrong_tile_type = 99; // Different from committed tile
        
        let result = TileRevealTrait::validate_committed_tile_match(@board, wrong_tile_type);
        assert!(!result, "Should fail with wrong committed tile");
    }

    #[test]
    fn test_validate_tile_commitment_success() {
        let tile_index = 5;
        let nonce = 123456;
        let tile_type = 42;
        let commitment = hash_values([tile_index.into(), nonce, tile_type.into()].span());
        let commitments = array![commitment].span();
        
        let result = TileRevealTrait::validate_tile_commitment(
            commitments, 0, nonce, tile_type
        );
        assert!(result, "Should validate correct tile commitment");
    }

    #[test]
    fn test_validate_tile_commitment_failure() {
        let tile_index = 5;
        let nonce = 123456;
        let tile_type = 42;
        let wrong_commitment = hash_values([tile_index.into(), nonce, 99_u8.into()].span());
        let commitments = array![wrong_commitment].span();
        
        let result = TileRevealTrait::validate_tile_commitment(
            commitments, 0, nonce, tile_type
        );
        assert!(!result, "Should fail with wrong tile commitment");
    }

    #[test]
    fn test_update_available_tiles() {
        let mut world = setup_world();
        let (player1, _) = TraitTestHelpersTrait::create_test_player_addresses();
        let board_id = 12345;
        let tile_to_remove = 42;
        
        // Update available tiles
        let new_tiles = TileRevealTrait::update_available_tiles(
            board_id, player1, tile_to_remove, world
        );
        
        // Verify tile was removed
        let mut found = false;
        let mut i = 0;
        while i < new_tiles.len() {
            if *new_tiles.at(i) == tile_to_remove {
                found = true;
                break;
            }
            i += 1;
        };
        assert!(!found, "Tile should be removed from available tiles");
        
        // Verify model was updated in world
        let available_tiles: AvailableTiles = world.read_model((board_id, player1));
        let mut found_in_model = false;
        let mut j = 0;
        while j < available_tiles.available_tiles.len() {
            if *available_tiles.available_tiles.at(j) == tile_to_remove {
                found_in_model = true;
                break;
            }
            j += 1;
        };
        assert!(!found_in_model, "Tile should be removed from model");
    }

    #[test]
    fn test_reveal_tile_and_update_board() {
        let mut world = setup_world();
        let board_id = 12345;
        let tile_index = 5;
        
        // Before revealing
        let board_before: Board = world.read_model(board_id);
        assert!(board_before.top_tile.is_none() || board_before.top_tile != Option::Some(tile_index), "Top tile should be different initially");
        
        // Reveal tile
        TileRevealTrait::reveal_tile_and_update_board(board_id, tile_index, world);
        
        // After revealing
        let board_after: Board = world.read_model(board_id);
        assert!(board_after.top_tile == Option::Some(tile_index), "Top tile should be set");
        assert!(board_after.commited_tile.is_none(), "Committed tile should be cleared");
    }

    #[test]
    fn test_perform_tile_reveal_validation_success() {
        let mut world = setup_world();
        let (player1, _) = TraitTestHelpersTrait::create_test_player_addresses();
        
        // Setup board in correct state
        let mut board = TraitTestHelpersTrait::create_test_board_with_state(GameState::Reveal);
        board.top_tile = Option::None; // Required for validation
        board.commited_tile = Option::Some(42);
        world.write_model(@board);
        
        let reveal_data = TileRevealData {
            board_id: 12345,
            player: player1,
            tile_index: 5,
            nonce: 123456,
            c: 42,
        };
        
        let result = TileRevealTrait::perform_tile_reveal_validation(
            reveal_data, @board, 120, world
        );
        assert!(result, "Should validate successful tile reveal");
    }

    #[test]
    fn test_perform_tile_reveal_validation_wrong_state() {
        let mut world = setup_world();
        let (player1, _) = TraitTestHelpersTrait::create_test_player_addresses();
        
        // Setup board in wrong state
        let board = TraitTestHelpersTrait::create_test_board_with_state(GameState::Move);
        world.write_model(@board);
        
        let reveal_data = TileRevealData {
            board_id: 12345,
            player: player1,
            tile_index: 5,
            nonce: 123456,
            c: 42,
        };
        
        let result = TileRevealTrait::perform_tile_reveal_validation(
            reveal_data, @board, 120, world
        );
        assert!(!result, "Should fail with wrong game state");
    }

    #[test]
    fn test_perform_tile_reveal_validation_invalid_player() {
        let mut world = setup_world();
        let invalid_player = starknet::contract_address_const::<0x999>();
        
        let board = TraitTestHelpersTrait::create_test_board_with_state(GameState::Reveal);
        world.write_model(@board);
        
        let reveal_data = TileRevealData {
            board_id: 12345,
            player: invalid_player,
            tile_index: 5,
            nonce: 123456,
            c: 42,
        };
        
        let result = TileRevealTrait::perform_tile_reveal_validation(
            reveal_data, @board, 120, world
        );
        assert!(!result, "Should fail with invalid player");
    }
}