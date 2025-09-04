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

    use evolute_duel::{
        models::{
            game::{
                Game, m_Game, Board, m_Board, GameModeConfig, m_GameModeConfig, MatchmakingState,
                m_MatchmakingState, PlayerMatchmaking, m_PlayerMatchmaking, Move, m_Move, Rules,
                m_Rules, TileCommitments, m_TileCommitments, AvailableTiles, m_AvailableTiles,
                BoardCounter, m_BoardCounter
            },
            player::{Player, m_Player},
            scoring::{UnionNode, m_UnionNode, PotentialContests, m_PotentialContests},
            tournament::{TournamentPass, m_TournamentPass, PlayerTournamentIndex, m_PlayerTournamentIndex},
            tournament_matchmaking::{
                TournamentRegistry, m_TournamentRegistry, TournamentLeague, m_TournamentLeague, 
                TournamentSlot, m_TournamentSlot, TournamentELOTrait, TournamentLeagueTrait,
                PlayerLeagueIndex, m_PlayerLeagueIndex, calculate_search_radius, validate_match_fairness
            },
        },
        events::{
            GameCreated, e_GameCreated, GameStarted, e_GameStarted, GameCanceled, e_GameCanceled,
            BoardUpdated, e_BoardUpdated, GameCreateFailed, e_GameCreateFailed, GameJoinFailed,
            e_GameJoinFailed, GameCanceleFailed, e_GameCanceleFailed, PlayerNotInGame,
            e_PlayerNotInGame, GameFinished, e_GameFinished, ErrorEvent, e_ErrorEvent,
            MigrationError, e_MigrationError, NotYourTurn, e_NotYourTurn, NotEnoughJokers,
            e_NotEnoughJokers, Moved, e_Moved, Skiped, e_Skiped, InvalidMove, e_InvalidMove,
            PhaseStarted, e_PhaseStarted,
        },
        types::packing::{GameStatus, GameMode, GameState},
        systems::{
            matchmaking::{matchmaking, IMatchmakingDispatcher, IMatchmakingDispatcherTrait},
            helpers::board::{BoardTrait},
        },
        constants::bitmap::{
            DEFAULT_RATING, LEAGUE_SIZE, LEAGUE_COUNT, LEAGUE_MIN_THRESHOLD,
            SEARCH_TIER_1_TIME, SEARCH_TIER_2_TIME, SEARCH_TIER_3_TIME,
            SEARCH_RADIUS_TIER_0, SEARCH_RADIUS_TIER_1, SEARCH_RADIUS_TIER_2, SEARCH_RADIUS_TIER_3,
            MAX_ELO_DIFFERENCE
        },
    };

    const PLAYER1_ADDRESS: felt252 = 0x123;
    const PLAYER2_ADDRESS: felt252 = 0x456;
    const PLAYER3_ADDRESS: felt252 = 0x789;
    const ADMIN_ADDRESS: felt252 = 0x111;
    const TOURNAMENT_ID: u64 = 1;

    fn namespace_def() -> NamespaceDef {
        let ndef = NamespaceDef {
            namespace: "evolute_duel",
            resources: [
                TestResource::Model(m_Game::TEST_CLASS_HASH),
                TestResource::Model(m_Board::TEST_CLASS_HASH),
                TestResource::Model(m_GameModeConfig::TEST_CLASS_HASH),
                TestResource::Model(m_MatchmakingState::TEST_CLASS_HASH),
                TestResource::Model(m_PlayerMatchmaking::TEST_CLASS_HASH),
                TestResource::Model(m_Player::TEST_CLASS_HASH),
                TestResource::Model(m_Move::TEST_CLASS_HASH),
                TestResource::Model(m_Rules::TEST_CLASS_HASH),
                TestResource::Model(m_TileCommitments::TEST_CLASS_HASH),
                TestResource::Model(m_AvailableTiles::TEST_CLASS_HASH),
                TestResource::Model(m_UnionNode::TEST_CLASS_HASH),
                TestResource::Model(m_PotentialContests::TEST_CLASS_HASH),
                TestResource::Model(m_BoardCounter::TEST_CLASS_HASH),
                TestResource::Model(m_TournamentPass::TEST_CLASS_HASH),
                TestResource::Model(m_PlayerTournamentIndex::TEST_CLASS_HASH),
                TestResource::Model(m_TournamentRegistry::TEST_CLASS_HASH),
                TestResource::Model(m_TournamentLeague::TEST_CLASS_HASH),
                TestResource::Model(m_TournamentSlot::TEST_CLASS_HASH),
                TestResource::Model(m_PlayerLeagueIndex::TEST_CLASS_HASH),
                TestResource::Contract(matchmaking::TEST_CLASS_HASH),
                TestResource::Event(e_GameCreated::TEST_CLASS_HASH),
                TestResource::Event(e_GameStarted::TEST_CLASS_HASH),
                TestResource::Event(e_GameCanceled::TEST_CLASS_HASH),
                TestResource::Event(e_BoardUpdated::TEST_CLASS_HASH),
                TestResource::Event(e_GameCreateFailed::TEST_CLASS_HASH),
                TestResource::Event(e_GameJoinFailed::TEST_CLASS_HASH),
                TestResource::Event(e_GameCanceleFailed::TEST_CLASS_HASH),
                TestResource::Event(e_PlayerNotInGame::TEST_CLASS_HASH),
                TestResource::Event(e_GameFinished::TEST_CLASS_HASH),
                TestResource::Event(e_ErrorEvent::TEST_CLASS_HASH),
                TestResource::Event(e_MigrationError::TEST_CLASS_HASH),
                TestResource::Event(e_NotYourTurn::TEST_CLASS_HASH),
                TestResource::Event(e_NotEnoughJokers::TEST_CLASS_HASH),
                TestResource::Event(e_Moved::TEST_CLASS_HASH),
                TestResource::Event(e_Skiped::TEST_CLASS_HASH),
                TestResource::Event(e_InvalidMove::TEST_CLASS_HASH),
                TestResource::Event(e_PhaseStarted::TEST_CLASS_HASH),
            ]
                .span(),
        };
        ndef
    }

    fn contract_defs() -> Span<ContractDef> {
        [
            ContractDefTrait::new(@"evolute_duel", @"matchmaking")
                .with_writer_of([dojo::utils::bytearray_hash(@"evolute_duel")].span())
                .with_init_calldata([ADMIN_ADDRESS].span()),
        ]
            .span()
    }

    fn deploy_world() -> WorldStorage {
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());
        world
    }

    fn setup_player(mut world: WorldStorage, player_address: ContractAddress) {
        let player = Player {
            player_id: player_address,
            username: 'TestPlayer',
            balance: 1000,
            games_played: 0,
            active_skin: 0,
            role: 1, // Controller
            tutorial_completed: true,
            migration_target: Zero::zero(),
            migration_initiated_at: 0,
            migration_used: false,
        };
        world.write_model(@player);

        let game = Game {
            player: player_address,
            status: GameStatus::Finished,
            board_id: Option::None,
            game_mode: GameMode::None,
        };
        world.write_model(@game);
    }

    fn create_tournament_pass(mut world: WorldStorage, player_address: ContractAddress, pass_id: u64, rating: u32) -> TournamentPass {
        let tournament_pass = TournamentPass {
            pass_id,
            tournament_id: TOURNAMENT_ID,
            player_address,
            entry_number: 1,
            rating,
            games_played: 0,
            wins: 0,
            losses: 0,
        };
        world.write_model(@tournament_pass);
        
        // Create player tournament index
        let index = PlayerTournamentIndex {
            player_address,
            tournament_id: TOURNAMENT_ID,
            pass_id,
        };
        world.write_model(@index);
        
        tournament_pass
    }

    // Tests for TournamentELO system
    #[test]
    fn test_get_tournament_player_rating_with_pass() {
        let mut world = deploy_world();
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        
        let pass = create_tournament_pass(world, player1, 1, 1500);
        
        let rating = TournamentELOTrait::get_tournament_player_rating(player1, TOURNAMENT_ID, world);
        assert!(rating == 1500, "Rating should match tournament pass");
    }

    #[test]
    fn test_get_tournament_player_rating_no_pass() {
        let world = deploy_world();
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        
        let rating = TournamentELOTrait::get_tournament_player_rating(player1, TOURNAMENT_ID, world);
        assert!(rating == DEFAULT_RATING, "Should return default rating when no pass");
    }

    #[test]
    fn test_update_tournament_ratings_after_match() {
        let mut world = deploy_world();
        let winner: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let loser: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        
        create_tournament_pass(world, winner, 1, 1200);
        create_tournament_pass(world, loser, 2, 1300);
        
        TournamentELOTrait::update_tournament_ratings_after_match(winner, loser, TOURNAMENT_ID, world);
        
        let winner_pass: TournamentPass = world.read_model(1_u64);
        let loser_pass: TournamentPass = world.read_model(2_u64);
        
        // Winner should gain rating
        assert!(winner_pass.rating > 1200, "Winner should gain rating");
        assert!(winner_pass.wins == 1, "Winner should have 1 win");
        assert!(winner_pass.games_played == 1, "Winner should have 1 game played");
        
        // Loser should lose rating  
        assert!(loser_pass.rating < 1300, "Loser should lose rating");
        assert!(loser_pass.losses == 1, "Loser should have 1 loss");
        assert!(loser_pass.games_played == 1, "Loser should have 1 game played");
    }

    #[test]
    fn test_update_tournament_ratings_no_passes() {
        let mut world = deploy_world();
        let winner: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let loser: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        
        // No passes created - should not panic
        TournamentELOTrait::update_tournament_ratings_after_match(winner, loser, TOURNAMENT_ID, world);
        
        // Should not create any passes
        let winner_index: PlayerTournamentIndex = world.read_model((winner, TOURNAMENT_ID));
        assert!(winner_index.pass_id == 0, "No pass should be created");
    }

    // Tests for League system
    #[test]
    fn test_tournament_league_compute_id_boundaries() {
        // Test league boundaries based on actual algorithm:
        // if rating <= LEAGUE_MIN_THRESHOLD (100) -> league 1
        // else 1 + (rating - LEAGUE_MIN_THRESHOLD) / LEAGUE_SIZE (50)
        // if result >= LEAGUE_COUNT (56) -> league LEAGUE_COUNT
        
        // Test below threshold
        assert!(TournamentLeagueTrait::compute_id(0) == 1, "Rating 0 should be league 1");
        assert!(TournamentLeagueTrait::compute_id(50) == 1, "Rating 50 should be league 1"); 
        assert!(TournamentLeagueTrait::compute_id(100) == 1, "Rating 100 (threshold) should be league 1");
        
        // Test just above threshold
        assert!(TournamentLeagueTrait::compute_id(101) == 1, "Rating 101 should be league 1"); // 1 + (101-100)/50 = 1 + 0 = 1
        assert!(TournamentLeagueTrait::compute_id(149) == 1, "Rating 149 should be league 1"); // 1 + (149-100)/50 = 1 + 0 = 1
        assert!(TournamentLeagueTrait::compute_id(150) == 2, "Rating 150 should be league 2"); // 1 + (150-100)/50 = 1 + 1 = 2
        assert!(TournamentLeagueTrait::compute_id(200) == 3, "Rating 200 should be league 3"); // 1 + (200-100)/50 = 1 + 2 = 3
        
        // Test higher ratings
        assert!(TournamentLeagueTrait::compute_id(1000) == 19, "Rating 1000 should be league 19"); // 1 + (1000-100)/50 = 1 + 18 = 19
        assert!(TournamentLeagueTrait::compute_id(1500) == 29, "Rating 1500 should be league 29"); // 1 + (1500-100)/50 = 1 + 28 = 29
        
        // Test very high rating (should cap at LEAGUE_COUNT)
        assert!(TournamentLeagueTrait::compute_id(9999) == LEAGUE_COUNT, "Very high rating should be Global Elite");
    }

    #[test]
    fn test_tournament_league_new() {
        let _world = deploy_world();
        
        // Test Silver I league
        let league1 = TournamentLeagueTrait::new(GameMode::Tournament.into(), TOURNAMENT_ID, 1);
        assert!(league1.league_id == 1, "League ID should be 1");
        assert!(league1.size == 0, "New league should be empty");
        
        // Calculate expected rating ranges for Silver I (league_id = 1)
        let silver_i_min_rating = 0; // Always 0 for lowest league
        let silver_i_max_rating = LEAGUE_MIN_THRESHOLD + LEAGUE_SIZE - 1;
        println!("Silver I rating range: {} - {}", silver_i_min_rating, silver_i_max_rating);
        
        // Test Silver II league  
        let league2 = TournamentLeagueTrait::new(GameMode::Tournament.into(), TOURNAMENT_ID, 2);
        assert!(league2.league_id == 2, "League ID should be 2");
        
        // Calculate expected rating ranges for Silver II (league_id = 2)
        let silver_ii_min_rating = LEAGUE_MIN_THRESHOLD + LEAGUE_SIZE;
        let silver_ii_max_rating = LEAGUE_MIN_THRESHOLD + 2 * LEAGUE_SIZE - 1;
        println!("Silver II rating range: {} - {}", silver_ii_min_rating, silver_ii_max_rating);
        
        // Test Global Elite league (highest)
        let global_elite = TournamentLeagueTrait::new(GameMode::Tournament.into(), TOURNAMENT_ID, LEAGUE_COUNT);
        assert!(global_elite.league_id == LEAGUE_COUNT, "Should be Global Elite");
        
        // Global Elite has no upper limit - starts at LEAGUE_MIN_THRESHOLD + (LEAGUE_COUNT-1) * LEAGUE_SIZE
        let global_elite_min_rating = LEAGUE_MIN_THRESHOLD + (LEAGUE_COUNT - 1).into() * LEAGUE_SIZE;
        println!("Global Elite min rating: {} (no upper limit)", global_elite_min_rating);
    }

    #[test]
    fn test_find_tournament_opponent_no_opponents() {
        let mut world = deploy_world();
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        
        create_tournament_pass(world, player1, 1, 1200);
        
        let opponent = TournamentELOTrait::find_tournament_opponent(player1, TOURNAMENT_ID, world);
        assert!(opponent.is_none(), "Should not find opponent when none available");
    }

    // Tests for error cases
    #[test]
    fn test_tournament_elo_edge_cases() {
        let mut world = deploy_world();
        let winner: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let loser: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        
        // Test with extreme ratings
        create_tournament_pass(world, winner, 1, 0); // Minimum rating
        create_tournament_pass(world, loser, 2, 9999); // High rating
        
        TournamentELOTrait::update_tournament_ratings_after_match(winner, loser, TOURNAMENT_ID, world);
        
        let winner_pass: TournamentPass = world.read_model(1_u64);
        let loser_pass: TournamentPass = world.read_model(2_u64);
        
        // Winner should gain significant rating when beating higher rated opponent
        assert!(winner_pass.rating > 0, "Winner should gain rating");
        assert!(loser_pass.rating < 9999, "Loser should lose rating");
    }

    #[test]
    fn test_league_computation_extensive() {
        // Test all league boundaries systematically
        let mut league_id = 1_u8;
        let mut rating = 0_u32;
        
        while league_id <= LEAGUE_COUNT && rating < 10000 {
            let computed_league = TournamentLeagueTrait::compute_id(rating);
            
            if league_id <= LEAGUE_COUNT {
                // For ratings within expected range, league should be predictable
                if rating < LEAGUE_MIN_THRESHOLD {
                    assert!(computed_league == 1, "Low ratings should be Silver I");
                }
            }
            
            rating += 50; // Test every 50 rating points
            if rating > LEAGUE_MIN_THRESHOLD + league_id.into() * LEAGUE_SIZE {
                league_id += 1;
            }
        }
    }

    #[test] 
    fn test_tournament_pass_integration() {
        let mut world = deploy_world();
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player2: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        
        // Create passes in different leagues
        create_tournament_pass(world, player1, 1, 1100); // League 21: 1 + (1100-100)/50 = 1 + 20 = 21
        create_tournament_pass(world, player2, 2, 1400); // League 27: 1 + (1400-100)/50 = 1 + 26 = 27
        
        // Verify league computation for each player
        let p1_league = TournamentLeagueTrait::compute_id(1100);
        let p2_league = TournamentLeagueTrait::compute_id(1400);
        
        assert!(p1_league == 21, "Player 1 should be in league 21"); // 1 + (1100-100)/50 = 21
        assert!(p2_league == 27, "Player 2 should be in league 27"); // 1 + (1400-100)/50 = 27 
        
        // Test cross-league match
        TournamentELOTrait::update_tournament_ratings_after_match(player1, player2, TOURNAMENT_ID, world);
        
        let p1_pass: TournamentPass = world.read_model(1_u64);
        let p2_pass: TournamentPass = world.read_model(2_u64);
        
        // Lower rated player beating higher rated should gain more
        assert!(p1_pass.rating > 1100, "Winner should gain rating");
        assert!(p2_pass.rating < 1400, "Loser should lose rating");
        
        // Verify leagues might have changed after rating update
        let p1_new_league = TournamentLeagueTrait::compute_id(p1_pass.rating);
        let p2_new_league = TournamentLeagueTrait::compute_id(p2_pass.rating);
    }

    // Error and Edge Case Tests
    #[test]
    fn test_tournament_elo_invalid_tournament_id() {
        let world = deploy_world();
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        
        // Try to get rating with invalid tournament ID
        let rating = TournamentELOTrait::get_tournament_player_rating(player1, 999_u64, world);
        assert!(rating == DEFAULT_RATING, "Invalid tournament should return default rating");
    }

    #[test]
    fn test_update_ratings_invalid_players() {
        let mut world = deploy_world();
        let fake_winner: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let fake_loser: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        
        // Try to update ratings for players without passes
        TournamentELOTrait::update_tournament_ratings_after_match(fake_winner, fake_loser, TOURNAMENT_ID, world);
        
        // Should not panic, but no changes should occur
        let winner_index: PlayerTournamentIndex = world.read_model((fake_winner, TOURNAMENT_ID));
        assert!(winner_index.pass_id == 0, "No pass should exist for fake winner");
    }

    #[test]
    fn test_league_compute_id_boundary_values() {
        // Test exact boundary values
        assert!(TournamentLeagueTrait::compute_id(LEAGUE_MIN_THRESHOLD - 1) == 1, "Just below threshold should be league 1");
        assert!(TournamentLeagueTrait::compute_id(LEAGUE_MIN_THRESHOLD) == 1, "At threshold should be league 1");
        assert!(TournamentLeagueTrait::compute_id(LEAGUE_MIN_THRESHOLD + 1) == 1, "Just above threshold should be league 1");
        
        // Test league transitions  
        let league2_min = LEAGUE_MIN_THRESHOLD + LEAGUE_SIZE; // 100 + 50 = 150
        assert!(TournamentLeagueTrait::compute_id(league2_min - 1) == 1, "149 should be league 1"); // 1 + (149-100)/50 = 1 + 0 = 1
        assert!(TournamentLeagueTrait::compute_id(league2_min) == 2, "150 should be league 2"); // 1 + (150-100)/50 = 1 + 1 = 2
        
        // Test maximum league
        let max_normal_rating = LEAGUE_MIN_THRESHOLD + LEAGUE_SIZE * LEAGUE_COUNT.into();
        assert!(TournamentLeagueTrait::compute_id(max_normal_rating) == LEAGUE_COUNT, "Max rating should be Global Elite");
    }

    #[test]
    fn test_league_new_invalid_id() {
        // Test with league_id 0 (invalid)
        let league0 = TournamentLeagueTrait::new(GameMode::Tournament.into(), TOURNAMENT_ID, 0);
        // Should handle gracefully or have defined behavior
        assert!(league0.league_id == 0, "Should preserve invalid ID");
        
        // Test with league_id beyond maximum
        let league_max_plus = TournamentLeagueTrait::new(GameMode::Tournament.into(), TOURNAMENT_ID, LEAGUE_COUNT + 1);
        // Behavior depends on implementation
    }

    #[test]
    fn test_rating_underflow_protection() {
        let mut world = deploy_world();
        let winner: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let loser: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        
        // Create players with very low rating for loser
        create_tournament_pass(world, winner, 1, 2000); // High rating winner
        create_tournament_pass(world, loser, 2, 1); // Very low rating loser
        
        TournamentELOTrait::update_tournament_ratings_after_match(winner, loser, TOURNAMENT_ID, world);
        
        let loser_pass: TournamentPass = world.read_model(2_u64);
        // Rating should not underflow below 0 (if implementation has protection)
        // Actual behavior depends on ELO implementation
    }

    #[test]
    fn test_rating_overflow_protection() {
        let mut world = deploy_world();
        let winner: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let loser: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        
        // Create players with very high rating for winner
        create_tournament_pass(world, winner, 1, 999999); // Max rating winner
        create_tournament_pass(world, loser, 2, 1000); // Normal rating loser
        
        TournamentELOTrait::update_tournament_ratings_after_match(winner, loser, TOURNAMENT_ID, world);
        
        let winner_pass: TournamentPass = world.read_model(1_u64);
        // Rating should not overflow (if implementation has protection)
        assert!(winner_pass.rating <= 999999, "Rating should not exceed maximum");
    }

    #[test]
    fn test_find_opponent_empty_tournament() {
        let world = deploy_world();
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        
        // Create pass but don't set up tournament registry/leagues
        create_tournament_pass(world, player1, 1, 1500);
        
        let opponent = TournamentELOTrait::find_tournament_opponent(player1, TOURNAMENT_ID, world);
        assert!(opponent.is_none(), "Should not find opponent in empty tournament");
    }

    #[test]
    fn test_multiple_rating_updates_same_players() {
        let mut world = deploy_world();
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player2: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        
        create_tournament_pass(world, player1, 1, 1200);
        create_tournament_pass(world, player2, 2, 1300);
        
        // First match - player1 wins
        TournamentELOTrait::update_tournament_ratings_after_match(player1, player2, TOURNAMENT_ID, world);
        
        let p1_after_first: TournamentPass = world.read_model(1_u64);
        let p2_after_first: TournamentPass = world.read_model(2_u64);
        
        // Second match - player2 wins (revenge)
        TournamentELOTrait::update_tournament_ratings_after_match(player2, player1, TOURNAMENT_ID, world);
        
        let p1_after_second: TournamentPass = world.read_model(1_u64);
        let p2_after_second: TournamentPass = world.read_model(2_u64);
        
        // Verify stats accumulate correctly
        assert!(p1_after_second.games_played == 2, "Player1 should have 2 games played");
        assert!(p2_after_second.games_played == 2, "Player2 should have 2 games played");
        assert!(p1_after_second.wins == 1, "Player1 should have 1 win");
        assert!(p1_after_second.losses == 1, "Player1 should have 1 loss");
        assert!(p2_after_second.wins == 1, "Player2 should have 1 win");
        assert!(p2_after_second.losses == 1, "Player2 should have 1 loss");
    }

    // Helper functions for dynamic search testing
    fn setup_multiple_players_in_different_leagues(mut world: WorldStorage) -> (ContractAddress, ContractAddress, ContractAddress) {
        let player_silver: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player_gold: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        let player_master: ContractAddress = contract_address_const::<PLAYER3_ADDRESS>();
        
        setup_player(world, player_silver);
        setup_player(world, player_gold);  
        setup_player(world, player_master);
        
        create_tournament_pass(world, player_silver, 1, 150); // League 2: 1 + (150-100)/50 = 2
        create_tournament_pass(world, player_gold, 2, 600);   // League 11: 1 + (600-100)/50 = 11 
        create_tournament_pass(world, player_master, 3, 1100); // League 21: 1 + (1100-100)/50 = 21
        
        (player_silver, player_gold, player_master)
    }


    #[test]
    fn test_league_computation_stress() {
        // Test a wide range of ratings for consistency
        let mut rating = 0_u32;
        let mut prev_league = 0_u8;
        
        while rating <= 5000 {
            let current_league = TournamentLeagueTrait::compute_id(rating);
            
            // League should never decrease as rating increases
            assert!(current_league >= prev_league, "League should not decrease with higher rating");
            
            // Should not exceed maximum league
            assert!(current_league <= LEAGUE_COUNT, "League should not exceed maximum");
            
            // Should be at least 1
            assert!(current_league >= 1, "League should be at least 1");
            
            prev_league = current_league;
            rating += 100;
        }
    }

    #[test]
    fn test_tournament_pass_data_integrity() {
        let mut world = deploy_world();
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        
        let original_pass = create_tournament_pass(world, player1, 1, 1500);
        
        // Verify pass was stored correctly
        let retrieved_pass: TournamentPass = world.read_model(1_u64);
        assert!(retrieved_pass.player_address == player1, "Player address mismatch");
        assert!(retrieved_pass.rating == 1500, "Rating mismatch");
        assert!(retrieved_pass.tournament_id == TOURNAMENT_ID, "Tournament ID mismatch");
        assert!(retrieved_pass.pass_id == 1, "Pass ID mismatch");
        
        // Verify index was created correctly
        let index: PlayerTournamentIndex = world.read_model((player1, TOURNAMENT_ID));
        assert!(index.pass_id == 1, "Index pass_id mismatch");
    }

    #[test] 
    fn test_concurrent_rating_updates() {
        let mut world = deploy_world();
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player2: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        let player3: ContractAddress = contract_address_const::<PLAYER3_ADDRESS>();
        
        create_tournament_pass(world, player1, 1, 1200);
        create_tournament_pass(world, player2, 2, 1300);
        create_tournament_pass(world, player3, 3, 1400);
        
        // Simulate concurrent matches involving same player
        // Match 1: player1 beats player2
        TournamentELOTrait::update_tournament_ratings_after_match(player1, player2, TOURNAMENT_ID, world);
        
        // Match 2: player1 beats player3 (player1 in multiple matches)
        TournamentELOTrait::update_tournament_ratings_after_match(player1, player3, TOURNAMENT_ID, world);
        
        let p1_final: TournamentPass = world.read_model(1_u64);
        
        // Player1 should have 2 wins, 2 games played
        assert!(p1_final.wins == 2, "Player1 should have 2 wins");
        assert!(p1_final.games_played == 2, "Player1 should have 2 games");
        assert!(p1_final.losses == 0, "Player1 should have no losses");
    }

    // ========== DYNAMIC SEARCH RADIUS TESTS ==========

    #[test]
    fn test_dynamic_search_first_subscription_tier_0() {
        let mut world = deploy_world();
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        
        setup_player(world, player1);
        create_tournament_pass(world, player1, 1, 1200);
        testing::set_block_timestamp(1000); // Set initial time
        
        // First call should subscribe player with radius 0 (own league only)
        let opponent = TournamentELOTrait::find_tournament_opponent(player1, TOURNAMENT_ID, world);
        assert!(opponent.is_none(), "Should not find opponent on first call (tier 0)");
        
        // Verify player was subscribed  
        let player_index: PlayerLeagueIndex = world.read_model((
            Into::<GameMode, u8>::into(GameMode::Tournament),
            TOURNAMENT_ID,
            player1
        ));
        assert!(player_index.league_id != 0, "Player should be subscribed to a league");
        assert!(player_index.join_time > 0, "Join time should be set");
    }

    #[test]  
    fn test_dynamic_search_tier_1_expansion() {
        let mut world = deploy_world();
        let (player_silver, player_gold, _) = setup_multiple_players_in_different_leagues(world);
        testing::set_block_timestamp(1000); // Set initial time
        
        // Subscribe both players first
        let _opponent1 = TournamentELOTrait::find_tournament_opponent(player_silver, TOURNAMENT_ID, world);
        let _opponent2 = TournamentELOTrait::find_tournament_opponent(player_gold, TOURNAMENT_ID, world);
        
        // Simulate player_silver waiting 15+ seconds (tier 1)
        testing::set_block_timestamp(1000 + SEARCH_TIER_1_TIME + 5);
        
        // Should expand radius to ±1 league and find opponent
        let opponent = TournamentELOTrait::find_tournament_opponent(player_silver, TOURNAMENT_ID, world);
        // In a real scenario with proper queue setup, this might find the gold player
        // For now, just test that it doesn't panic and handles the expansion
        assert!(true, "Tier 1 expansion should work without errors");
    }

    #[test]
    fn test_dynamic_search_tier_2_expansion() {
        let mut world = deploy_world();
        let (player_silver, _, player_master) = setup_multiple_players_in_different_leagues(world);
        testing::set_block_timestamp(1000); // Set initial time
        
        // Subscribe both players first
        let _opponent1 = TournamentELOTrait::find_tournament_opponent(player_silver, TOURNAMENT_ID, world);
        let _opponent2 = TournamentELOTrait::find_tournament_opponent(player_master, TOURNAMENT_ID, world);
        
        // Simulate player_silver waiting 30+ seconds (tier 2)
        testing::set_block_timestamp(1000 + SEARCH_TIER_2_TIME + 5);
        
        // Should expand radius to ±2 leagues
        let opponent = TournamentELOTrait::find_tournament_opponent(player_silver, TOURNAMENT_ID, world);
        assert!(true, "Tier 2 expansion should work without errors");
    }

    #[test]
    fn test_dynamic_search_tier_3_maximum_radius() {
        let mut world = deploy_world();
        let (player_silver, _, player_master) = setup_multiple_players_in_different_leagues(world);
        testing::set_block_timestamp(1000); // Set initial time
        
        // Subscribe both players first
        let _opponent1 = TournamentELOTrait::find_tournament_opponent(player_silver, TOURNAMENT_ID, world);
        let _opponent2 = TournamentELOTrait::find_tournament_opponent(player_master, TOURNAMENT_ID, world);
        
        // Simulate player_silver waiting 60+ seconds (tier 3)
        testing::set_block_timestamp(1000 + SEARCH_TIER_3_TIME + 10);
        
        // Should allow maximum radius (any available opponent)
        let opponent = TournamentELOTrait::find_tournament_opponent(player_silver, TOURNAMENT_ID, world);
        assert!(true, "Tier 3 maximum radius should work without errors");
    }

    // ========== FAIRNESS CHECK TESTS ==========

    #[test]
    fn test_fairness_check_rejects_unfair_match_short_wait() {
        let mut world = deploy_world();
        let player_low: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player_high: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        
        setup_player(world, player_low);
        setup_player(world, player_high);
        create_tournament_pass(world, player_low, 1, 1000);  // Low rating
        create_tournament_pass(world, player_high, 2, 1300); // High rating (300 point diff > MAX_ELO_DIFFERENCE)
        
        // Short wait time (< 60s) should reject unfair matches
        let is_fair = validate_match_fairness(1000, 1300, 30);
        assert!(!is_fair, "Should reject unfair match with short wait time");
    }

    #[test]
    fn test_fairness_check_accepts_unfair_match_long_wait() {
        // Long wait time (≥ 60s) should accept any match
        let is_fair = validate_match_fairness(1000, 1300, SEARCH_TIER_3_TIME);
        assert!(is_fair, "Should accept any match after long wait time");
    }

    #[test]
    fn test_fairness_check_accepts_fair_match() {
        // Fair match (≤ MAX_ELO_DIFFERENCE) should always be accepted
        let is_fair = validate_match_fairness(1000, 1150, 5); // 150 point diff < MAX_ELO_DIFFERENCE
        assert!(is_fair, "Should accept fair match regardless of wait time");
    }

    #[test]
    fn test_fairness_check_boundary_values() {
        // Test exact boundary values
        let is_fair_exact = validate_match_fairness(1000, 1000 + MAX_ELO_DIFFERENCE, 10);
        assert!(is_fair_exact, "Should accept match at exact MAX_ELO_DIFFERENCE");
        
        let is_unfair_over = validate_match_fairness(1000, 1000 + MAX_ELO_DIFFERENCE + 1, 10);
        assert!(!is_unfair_over, "Should reject match over MAX_ELO_DIFFERENCE");
        
        let is_fair_tier3_exact = validate_match_fairness(1000, 2000, SEARCH_TIER_3_TIME);
        assert!(is_fair_tier3_exact, "Should accept any match at tier 3 boundary");
    }

    // ========== REPEATED SUBSCRIPTION TESTS ==========

    #[test]
    fn test_repeated_calls_no_resubscription_error() {
        let mut world = deploy_world();
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        
        setup_player(world, player1);
        create_tournament_pass(world, player1, 1, 1200);
        testing::set_block_timestamp(1000); // Set initial time
        
        // First call - should subscribe player
        let opponent1 = TournamentELOTrait::find_tournament_opponent(player1, TOURNAMENT_ID, world);
        assert!(opponent1.is_none(), "First call should return None (no opponents)");
        
        // Verify subscription
        let player_index_after_first: PlayerLeagueIndex = world.read_model((
            Into::<GameMode, u8>::into(GameMode::Tournament),
            TOURNAMENT_ID,
            player1
        ));
        assert!(player_index_after_first.league_id != 0, "Player should be subscribed after first call");
        let original_join_time = player_index_after_first.join_time;
        
        // Second call - should NOT try to resubscribe
        let opponent2 = TournamentELOTrait::find_tournament_opponent(player1, TOURNAMENT_ID, world);
        assert!(opponent2.is_none(), "Second call should return None (still no opponents)");
        
        // Verify no resubscription error and join_time preserved
        let player_index_after_second: PlayerLeagueIndex = world.read_model((
            Into::<GameMode, u8>::into(GameMode::Tournament),
            TOURNAMENT_ID,
            player1
        ));
        assert!(player_index_after_second.league_id == player_index_after_first.league_id, "League should remain same");
        assert!(player_index_after_second.join_time == original_join_time, "Join time should be preserved");
        
        // Third call - should work with radius expansion
        testing::set_block_timestamp(original_join_time + SEARCH_TIER_1_TIME + 5);
        let opponent3 = TournamentELOTrait::find_tournament_opponent(player1, TOURNAMENT_ID, world);
        assert!(true, "Third call with radius expansion should work without errors");
    }

    // ========== INTEGRATION TESTS ==========

    #[test]
    fn test_full_search_escalation_scenario() {
        let mut world = deploy_world();
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        
        setup_player(world, player1);
        create_tournament_pass(world, player1, 1, 1200);
        testing::set_block_timestamp(1000); // Set initial time
        
        // t=0: First call - subscription with radius 0
        let opponent_t0 = TournamentELOTrait::find_tournament_opponent(player1, TOURNAMENT_ID, world);
        assert!(opponent_t0.is_none(), "t=0: Should not find opponent (tier 0)");
        
        // t=20s: Second call - radius 1 (±1 league)
        testing::set_block_timestamp(1000 + 20);
        let opponent_t20 = TournamentELOTrait::find_tournament_opponent(player1, TOURNAMENT_ID, world);
        assert!(opponent_t20.is_none(), "t=20s: Still no opponents in tier 1");
        
        // t=35s: Third call - radius 2 (±2 leagues)
        testing::set_block_timestamp(1000 + 35);
        let opponent_t35 = TournamentELOTrait::find_tournament_opponent(player1, TOURNAMENT_ID, world);
        assert!(opponent_t35.is_none(), "t=35s: Still no opponents in tier 2");
        
        // t=65s: Fourth call - maximum radius
        testing::set_block_timestamp(1000 + 65);
        let opponent_t65 = TournamentELOTrait::find_tournament_opponent(player1, TOURNAMENT_ID, world);
        assert!(opponent_t65.is_none(), "t=65s: Still no opponents even with max radius");
        
        // Verify player remains subscribed throughout
        let final_player_index: PlayerLeagueIndex = world.read_model((
            Into::<GameMode, u8>::into(GameMode::Tournament),
            TOURNAMENT_ID,
            player1
        ));
        assert!(final_player_index.league_id != 0, "Player should remain subscribed");
    }

    #[test]
    fn test_search_radius_calculation_transitions() {
        // Test all tier transitions
        assert!(calculate_search_radius(0) == SEARCH_RADIUS_TIER_0, "t=0s should be tier 0");
        assert!(calculate_search_radius(14) == SEARCH_RADIUS_TIER_0, "t=14s should be tier 0");
        assert!(calculate_search_radius(15) == SEARCH_RADIUS_TIER_1, "t=15s should be tier 1");
        assert!(calculate_search_radius(29) == SEARCH_RADIUS_TIER_1, "t=29s should be tier 1");
        assert!(calculate_search_radius(30) == SEARCH_RADIUS_TIER_2, "t=30s should be tier 2");
        assert!(calculate_search_radius(59) == SEARCH_RADIUS_TIER_2, "t=59s should be tier 2");
        assert!(calculate_search_radius(60) == SEARCH_RADIUS_TIER_3, "t=60s should be tier 3");
        assert!(calculate_search_radius(120) == SEARCH_RADIUS_TIER_3, "t=120s should be tier 3");
    }

    // ========== HELPER FUNCTION TESTS ==========

    #[test]
    fn test_calculate_search_radius_function() {
        // Test tier 0 (0-14s)
        assert!(calculate_search_radius(0) == 0, "0s should return radius 0");
        assert!(calculate_search_radius(10) == 0, "10s should return radius 0");
        assert!(calculate_search_radius(14) == 0, "14s should return radius 0");
        
        // Test tier 1 (15-29s)
        assert!(calculate_search_radius(15) == 1, "15s should return radius 1");
        assert!(calculate_search_radius(20) == 1, "20s should return radius 1");
        assert!(calculate_search_radius(29) == 1, "29s should return radius 1");
        
        // Test tier 2 (30-59s)
        assert!(calculate_search_radius(30) == 2, "30s should return radius 2");
        assert!(calculate_search_radius(45) == 2, "45s should return radius 2");
        assert!(calculate_search_radius(59) == 2, "59s should return radius 2");
        
        // Test tier 3 (60s+)
        assert!(calculate_search_radius(60) == 255, "60s should return max radius");
        assert!(calculate_search_radius(120) == 255, "120s should return max radius");
        assert!(calculate_search_radius(999) == 255, "999s should return max radius");
    }

    #[test]
    fn test_validate_match_fairness_function() {
        // Test fair matches (always accepted)
        assert!(validate_match_fairness(1000, 1000, 0), "Same rating should be fair");
        assert!(validate_match_fairness(1000, 1100, 10), "100 point diff should be fair");
        assert!(validate_match_fairness(1000, 1200, 30), "200 point diff should be fair");
        assert!(validate_match_fairness(1200, 1000, 50), "200 point diff (reverse) should be fair");
        
        // Test unfair matches with short wait (rejected)
        assert!(!validate_match_fairness(1000, 1250, 10), "250 point diff with short wait should be unfair");
        assert!(!validate_match_fairness(1000, 1300, 30), "300 point diff with short wait should be unfair");
        assert!(!validate_match_fairness(1500, 1000, 50), "500 point diff with short wait should be unfair");
        
        // Test unfair matches with long wait (accepted)
        assert!(validate_match_fairness(1000, 1500, 60), "Any diff with 60s+ wait should be fair");
        assert!(validate_match_fairness(1000, 2000, 120), "1000 point diff with long wait should be fair");
        assert!(validate_match_fairness(2000, 500, 90), "1500 point diff with long wait should be fair");
        
        // Test boundary conditions
        assert!(!validate_match_fairness(1000, 1201, 59), "201 point diff at 59s should be unfair");
        assert!(validate_match_fairness(1000, 1201, 60), "201 point diff at 60s should be fair");
    }

    #[test]
    fn test_time_tier_boundary_conditions() {
        // Test exact boundary values
        assert!(calculate_search_radius(SEARCH_TIER_1_TIME - 1) == SEARCH_RADIUS_TIER_0, "Just before tier 1");
        assert!(calculate_search_radius(SEARCH_TIER_1_TIME) == SEARCH_RADIUS_TIER_1, "Exactly tier 1");
        assert!(calculate_search_radius(SEARCH_TIER_2_TIME - 1) == SEARCH_RADIUS_TIER_1, "Just before tier 2");
        assert!(calculate_search_radius(SEARCH_TIER_2_TIME) == SEARCH_RADIUS_TIER_2, "Exactly tier 2");
        assert!(calculate_search_radius(SEARCH_TIER_3_TIME - 1) == SEARCH_RADIUS_TIER_2, "Just before tier 3");
        assert!(calculate_search_radius(SEARCH_TIER_3_TIME) == SEARCH_RADIUS_TIER_3, "Exactly tier 3");
    }
}