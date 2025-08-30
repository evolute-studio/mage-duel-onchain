#[cfg(test)]
#[allow(unused_imports)]
mod tests {
    use dojo_cairo_test::WorldStorageTestTrait;
    use dojo::model::{ModelStorage, ModelStorageTest};
    use dojo::world::WorldStorageTrait;
    use dojo_cairo_test::{
        spawn_test_world, NamespaceDef, TestResource, ContractDefTrait, ContractDef,
    };
    use dojo::world::WorldStorage;
    use starknet::{testing, ContractAddress, contract_address_const};
    use core::num::traits::Zero;

    // Tournament matchmaking models
    use evolute_duel::models::{
        tournament_matchmaking::{
            TournamentRegistry, TournamentLeague, TournamentSlot, PlayerLeagueIndex,
            TournamentELOTrait, TournamentLeagueTrait, TournamentRegistryTrait
        },
        tournament::{
            TournamentPass, TournamentStateModel, PlayerTournamentIndex, TournamentState,
        },
        player::{Player},
    };

    use evolute_duel::types::packing::{GameMode};

    // Test constants
    const ADMIN_ADDRESS: felt252 = 0x111;
    const PLAYER1_ADDRESS: felt252 = 0x123;
    const PLAYER2_ADDRESS: felt252 = 0x456;
    const PLAYER3_ADDRESS: felt252 = 0x789;

    const TEST_TOURNAMENT_ID: u64 = 1;
    const DEFAULT_RATING: u32 = 1200;

    fn namespace_def() -> NamespaceDef {
        let ndef = NamespaceDef {
            namespace: "evolute_duel",
            resources: [
                // Tournament matchmaking models
                TestResource::Model(evolute_duel::models::tournament_matchmaking::m_TournamentRegistry::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(evolute_duel::models::tournament_matchmaking::m_TournamentLeague::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(evolute_duel::models::tournament_matchmaking::m_TournamentSlot::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(evolute_duel::models::tournament_matchmaking::m_PlayerLeagueIndex::TEST_CLASS_HASH.try_into().unwrap()),
                // Tournament models
                TestResource::Model(evolute_duel::models::tournament::m_TournamentPass::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(evolute_duel::models::tournament::m_TournamentStateModel::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(evolute_duel::models::tournament::m_PlayerTournamentIndex::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(evolute_duel::models::player::m_Player::TEST_CLASS_HASH.try_into().unwrap()),
            ]
                .span(),
        };
        ndef
    }

    fn setup_tournament_matchmaking_world() -> WorldStorage {
        let mut world = spawn_test_world([namespace_def()].span());
        world
    }

    // Helper function to create a tournament pass for a player
    fn create_tournament_pass(
        mut world: WorldStorage,
        pass_id: u64,
        player_address: ContractAddress,
        tournament_id: u64,
        rating: u32
    ) {
        let tournament_pass = TournamentPass {
            pass_id,
            tournament_id,
            player_address,
            rating,
            wins: 0,
            losses: 0,
            games_played: 0,
            state: TournamentState::Enlisted,
        };
        world.write_model_test(@tournament_pass);

        let player_index = PlayerTournamentIndex {
            player_address,
            tournament_id,
            pass_id,
        };
        world.write_model_test(@player_index);
    }

    #[test]
    fn test_get_tournament_player_rating_default() {
        println!("[test_get_tournament_player_rating_default] Testing default rating for new player");
        let world = setup_tournament_matchmaking_world();

        let player_address: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let rating = TournamentELOTrait::get_tournament_player_rating(
            player_address, 
            TEST_TOURNAMENT_ID, 
            world
        );

        assert!(rating == DEFAULT_RATING, "New player should have default rating 1200");
        println!("[test_get_tournament_player_rating_default] ✓ Default rating test passed: {}", rating);
    }

    #[test]
    fn test_get_tournament_player_rating_existing() {
        println!("[test_get_tournament_player_rating_existing] Testing rating for existing player");
        let mut world = setup_tournament_matchmaking_world();

        let player_address: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let expected_rating = 1500;
        
        // Create tournament pass with custom rating
        create_tournament_pass(world, 1, player_address, TEST_TOURNAMENT_ID, expected_rating);

        let rating = TournamentELOTrait::get_tournament_player_rating(
            player_address, 
            TEST_TOURNAMENT_ID, 
            world
        );

        assert!(rating == expected_rating, "Existing player should have their tournament rating");
        println!("[test_get_tournament_player_rating_existing] ✓ Existing player rating test passed: {}", rating);
    }

    #[test]
    fn test_update_tournament_ratings_after_match() {
        println!("[test_update_tournament_ratings_after_match] Testing rating updates after match");
        let mut world = setup_tournament_matchmaking_world();

        let winner_address: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let loser_address: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        let initial_rating = 1200;

        // Create tournament passes for both players
        create_tournament_pass(world, 1, winner_address, TEST_TOURNAMENT_ID, initial_rating);
        create_tournament_pass(world, 2, loser_address, TEST_TOURNAMENT_ID, initial_rating);

        // Get initial ratings
        let winner_rating_before = TournamentELOTrait::get_tournament_player_rating(
            winner_address, TEST_TOURNAMENT_ID, world
        );
        let loser_rating_before = TournamentELOTrait::get_tournament_player_rating(
            loser_address, TEST_TOURNAMENT_ID, world
        );

        println!("[test_update_tournament_ratings_after_match] Initial ratings - Winner: {}, Loser: {}", 
            winner_rating_before, loser_rating_before);

        // Update ratings after match
        TournamentELOTrait::update_tournament_ratings_after_match(
            winner_address,
            loser_address, 
            TEST_TOURNAMENT_ID,
            world
        );

        // Check updated ratings
        let winner_rating_after = TournamentELOTrait::get_tournament_player_rating(
            winner_address, TEST_TOURNAMENT_ID, world
        );
        let loser_rating_after = TournamentELOTrait::get_tournament_player_rating(
            loser_address, TEST_TOURNAMENT_ID, world
        );

        println!("[test_update_tournament_ratings_after_match] Updated ratings - Winner: {}, Loser: {}", 
            winner_rating_after, loser_rating_after);

        // Verify rating changes
        assert!(winner_rating_after > winner_rating_before, "Winner should gain rating");
        assert!(loser_rating_after < loser_rating_before, "Loser should lose rating");

        // Verify game statistics
        let winner_pass: TournamentPass = world.read_model(1_u64);
        let loser_pass: TournamentPass = world.read_model(2_u64);

        assert!(winner_pass.wins == 1, "Winner should have 1 win");
        assert!(winner_pass.losses == 0, "Winner should have 0 losses");
        assert!(winner_pass.games_played == 1, "Winner should have 1 game played");

        assert!(loser_pass.wins == 0, "Loser should have 0 wins");
        assert!(loser_pass.losses == 1, "Loser should have 1 loss");
        assert!(loser_pass.games_played == 1, "Loser should have 1 game played");

        println!("[test_update_tournament_ratings_after_match] ✓ Rating update test passed");
    }

    #[test]
    fn test_find_tournament_opponent_no_opponents() {
        println!("[test_find_tournament_opponent_no_opponents] Testing queue when no opponents available");
        let mut world = setup_tournament_matchmaking_world();

        let player_address: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        
        // Create tournament pass for player
        create_tournament_pass(world, 1, player_address, TEST_TOURNAMENT_ID, DEFAULT_RATING);

        // Try to find opponent (should return None and subscribe player)
        let opponent = TournamentELOTrait::find_tournament_opponent(
            player_address, 
            TEST_TOURNAMENT_ID, 
            world
        );

        assert!(opponent.is_none(), "Should not find opponent when alone in queue");
        println!("[test_find_tournament_opponent_no_opponents] ✓ Correctly returned None");

        // Verify player is subscribed in their league
        let player_rating = TournamentELOTrait::get_tournament_player_rating(player_address, TEST_TOURNAMENT_ID, world);
        let expected_league_id = TournamentLeagueTrait::compute_id(player_rating);
        
        let player_index: PlayerLeagueIndex = world.read_model((
            GameMode::Tournament,
            TEST_TOURNAMENT_ID,
            player_address
        ));
        
        assert!(player_index.league_id == expected_league_id, "Player should be subscribed to correct league");
        assert!(player_index.slot_index == 0, "Player should be first in queue");
        assert!(player_index.join_time > 0, "Join time should be set");
        
        println!("[test_find_tournament_opponent_no_opponents] ✓ Player subscribed - League: {}, Slot: {}", 
            player_index.league_id, player_index.slot_index);

        // Verify league has the player
        let league: TournamentLeague = world.read_model((
            GameMode::Tournament,
            TEST_TOURNAMENT_ID,
            expected_league_id
        ));
        assert!(league.size == 1, "League should have 1 player");

        // Verify slot exists
        let slot: TournamentSlot = world.read_model((
            GameMode::Tournament,
            TEST_TOURNAMENT_ID,
            expected_league_id,
            0_u32
        ));
        assert!(slot.player_address == player_address, "Slot should contain player address");

        println!("[test_find_tournament_opponent_no_opponents] ✓ Test completed successfully");
    }

    #[test]
    fn test_find_tournament_opponent_match_found() {
        println!("[test_find_tournament_opponent_match_found] Testing successful opponent matching");
        let mut world = setup_tournament_matchmaking_world();

        let player1_address: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player2_address: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        
        // Create tournament passes for both players with similar ratings (same league)
        create_tournament_pass(world, 1, player1_address, TEST_TOURNAMENT_ID, DEFAULT_RATING);
        create_tournament_pass(world, 2, player2_address, TEST_TOURNAMENT_ID, DEFAULT_RATING + 10);

        // First player enters queue (should return None and subscribe)
        let opponent1 = TournamentELOTrait::find_tournament_opponent(
            player1_address, 
            TEST_TOURNAMENT_ID, 
            world
        );
        assert!(opponent1.is_none(), "First player should not find opponent");
        println!("[test_find_tournament_opponent_match_found] ✓ Player1 added to queue");

        // Verify first player is subscribed
        let player1_index: PlayerLeagueIndex = world.read_model((
            GameMode::Tournament,
            TEST_TOURNAMENT_ID,
            player1_address
        ));
        assert!(player1_index.league_id != 0, "Player1 should be subscribed");
        println!("[test_find_tournament_opponent_match_found] Player1 in league: {}", player1_index.league_id);

        // Second player enters queue (should find first player)
        let opponent2 = TournamentELOTrait::find_tournament_opponent(
            player2_address, 
            TEST_TOURNAMENT_ID, 
            world
        );
        assert!(opponent2.is_some(), "Second player should find opponent");
        let matched_opponent = opponent2.unwrap();
        assert!(matched_opponent == player1_address, "Should match with player1");
        println!("[test_find_tournament_opponent_match_found] ✓ Player2 matched with Player1: {:?}", matched_opponent);

        // Verify both players are unsubscribed after match
        let player1_index_after: PlayerLeagueIndex = world.read_model((
            GameMode::Tournament,
            TEST_TOURNAMENT_ID,
            player1_address
        ));
        let player2_index_after: PlayerLeagueIndex = world.read_model((
            GameMode::Tournament,
            TEST_TOURNAMENT_ID,
            player2_address
        ));
        
        assert!(player1_index_after.league_id == 0, "Player1 should be unsubscribed after match");
        assert!(player2_index_after.league_id == 0, "Player2 should be unsubscribed after match");
        println!("[test_find_tournament_opponent_match_found] ✓ Both players unsubscribed after match");

        // Verify league size decreased
        let league_id = TournamentLeagueTrait::compute_id(DEFAULT_RATING);
        let league: TournamentLeague = world.read_model((
            GameMode::Tournament,
            TEST_TOURNAMENT_ID,
            league_id
        ));
        assert!(league.size == 0, "League should be empty after match");

        // Verify slots are cleared
        let slot1: TournamentSlot = world.read_model((
            GameMode::Tournament,
            TEST_TOURNAMENT_ID,
            league_id,
            0_u32
        ));
        let slot2: TournamentSlot = world.read_model((
            GameMode::Tournament,
            TEST_TOURNAMENT_ID,
            league_id,
            1_u32
        ));
        assert!(slot1.player_address.is_zero(), "First slot should be cleared");
        assert!(slot2.player_address.is_zero(), "Second slot should be cleared");

        println!("[test_find_tournament_opponent_match_found] ✓ Test completed successfully");
    }

    #[test]
    fn test_tournament_league_compute_id() {
        println!("[test_tournament_league_compute_id] Testing league ID computation");

        // Test minimum rating (should be league 1)
        let min_rating = 800;
        let league_id_min = TournamentLeagueTrait::compute_id(min_rating);
        assert!(league_id_min == 1, "Minimum rating should be league 1");
        println!("[test_tournament_league_compute_id] Min rating {} -> League {}", min_rating, league_id_min);

        // Test default rating
        let default_rating = 1200;
        let league_id_default = TournamentLeagueTrait::compute_id(default_rating);
        println!("[test_tournament_league_compute_id] Default rating {} -> League {}", default_rating, league_id_default);

        // Test higher ratings
        let high_rating = 2000;
        let league_id_high = TournamentLeagueTrait::compute_id(high_rating);
        println!("[test_tournament_league_compute_id] High rating {} -> League {}", high_rating, league_id_high);

        // Test very high rating (should be capped at max league)
        let very_high_rating = 5000;
        let league_id_very_high = TournamentLeagueTrait::compute_id(very_high_rating);
        println!("[test_tournament_league_compute_id] Very high rating {} -> League {}", very_high_rating, league_id_very_high);

        // Verify league IDs are reasonable (1-17 range)
        assert!(league_id_min >= 1 && league_id_min <= 17, "League ID should be in valid range");
        assert!(league_id_default >= 1 && league_id_default <= 17, "League ID should be in valid range");
        assert!(league_id_high >= 1 && league_id_high <= 17, "League ID should be in valid range");
        assert!(league_id_very_high >= 1 && league_id_very_high <= 17, "League ID should be in valid range");

        println!("[test_tournament_league_compute_id] ✓ League computation test passed");
    }

    #[test]
    fn test_multiple_players_same_league() {
        println!("[test_multiple_players_same_league] Testing multiple players in same league");
        let mut world = setup_tournament_matchmaking_world();

        let player1_address: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player2_address: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        let player3_address: ContractAddress = contract_address_const::<PLAYER3_ADDRESS>();
        
        // All players have similar ratings (same league)
        create_tournament_pass(world, 1, player1_address, TEST_TOURNAMENT_ID, DEFAULT_RATING);
        create_tournament_pass(world, 2, player2_address, TEST_TOURNAMENT_ID, DEFAULT_RATING + 5);
        create_tournament_pass(world, 3, player3_address, TEST_TOURNAMENT_ID, DEFAULT_RATING + 10);

        // First player enters (should subscribe)
        let opponent1 = TournamentELOTrait::find_tournament_opponent(
            player1_address, TEST_TOURNAMENT_ID, world
        );
        assert!(opponent1.is_none(), "Player1 should not find opponent");

        // Second player enters (should subscribe)  
        let opponent2 = TournamentELOTrait::find_tournament_opponent(
            player2_address, TEST_TOURNAMENT_ID, world
        );
        assert!(opponent2.is_none(), "Player2 should not find opponent");

        // Third player enters (should match with one of the previous players)
        let opponent3 = TournamentELOTrait::find_tournament_opponent(
            player3_address, TEST_TOURNAMENT_ID, world
        );
        assert!(opponent3.is_some(), "Player3 should find an opponent");
        
        let matched_opponent = opponent3.unwrap();
        assert!(
            matched_opponent == player1_address || matched_opponent == player2_address,
            "Should match with either player1 or player2"
        );
        println!("[test_multiple_players_same_league] ✓ Player3 matched with: {:?}", matched_opponent);

        // Verify league still has one remaining player
        let league_id = TournamentLeagueTrait::compute_id(DEFAULT_RATING);
        let league: TournamentLeague = world.read_model((
            GameMode::Tournament,
            TEST_TOURNAMENT_ID,
            league_id
        ));
        assert!(league.size == 1, "League should have 1 remaining player");

        println!("[test_multiple_players_same_league] ✓ Test completed successfully");
    }
}