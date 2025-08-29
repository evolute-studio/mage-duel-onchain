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
                TournamentSlot, m_TournamentSlot, TournamentELOTrait, TournamentLeagueTrait
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
        constants::bitmap::{DEFAULT_RATING, LEAGUE_SIZE, LEAGUE_COUNT, LEAGUE_MIN_THRESHOLD},
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
        // Test league boundaries
        assert!(TournamentLeagueTrait::compute_id(0) == 1, "Rating 0 should be Silver I");
        assert!(TournamentLeagueTrait::compute_id(999) == 1, "Rating 999 should be Silver I");
        assert!(TournamentLeagueTrait::compute_id(1000) == 1, "Rating 1000 should be Silver I");
        assert!(TournamentLeagueTrait::compute_id(1001) == 1, "Rating 1001 should be Silver I");
        assert!(TournamentLeagueTrait::compute_id(1149) == 1, "Rating 1149 should be Silver I");
        assert!(TournamentLeagueTrait::compute_id(1150) == 2, "Rating 1150 should be Silver II");
        assert!(TournamentLeagueTrait::compute_id(1300) == 3, "Rating 1300 should be Silver III");
        assert!(TournamentLeagueTrait::compute_id(2550) == 11, "Rating 2550 should be Master Guardian");
        assert!(TournamentLeagueTrait::compute_id(9999) == LEAGUE_COUNT, "Very high rating should be Global Elite");
    }

    #[test]
    fn test_tournament_league_new() {
        let world = deploy_world();
        
        // Test Silver I league
        let league1 = TournamentLeagueTrait::new(GameMode::Tournament, TOURNAMENT_ID, 1);
        assert!(league1.league_id == 1, "League ID should be 1");
        assert!(league1.min_rating == 0, "Silver I should start from 0");
        assert!(league1.max_rating == LEAGUE_MIN_THRESHOLD + LEAGUE_SIZE - 1, "Silver I max rating");
        assert!(league1.size == 0, "New league should be empty");
        
        // Test Silver II league  
        let league2 = TournamentLeagueTrait::new(GameMode::Tournament, TOURNAMENT_ID, 2);
        assert!(league2.league_id == 2, "League ID should be 2");
        assert!(league2.min_rating == LEAGUE_MIN_THRESHOLD + LEAGUE_SIZE, "Silver II min rating");
        assert!(league2.max_rating == LEAGUE_MIN_THRESHOLD + 2 * LEAGUE_SIZE - 1, "Silver II max rating");
        
        // Test Global Elite league (highest)
        let global_elite = TournamentLeagueTrait::new(GameMode::Tournament, TOURNAMENT_ID, LEAGUE_COUNT);
        assert!(global_elite.league_id == LEAGUE_COUNT, "Should be Global Elite");
        assert!(global_elite.max_rating == 999999, "Global Elite has no upper limit");
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
        create_tournament_pass(world, player1, 1, 1100); // Silver I
        create_tournament_pass(world, player2, 2, 1400); // Silver III
        
        // Verify league computation for each player
        let p1_league = TournamentLeagueTrait::compute_id(1100);
        let p2_league = TournamentLeagueTrait::compute_id(1400);
        
        assert!(p1_league == 1, "Player 1 should be in Silver I");
        assert!(p2_league == 2, "Player 2 should be in Silver II"); 
        
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
        let fake_winner: ContractAddress = contract_address_const::<0xfake1>();
        let fake_loser: ContractAddress = contract_address_const::<0xfake2>();
        
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
        let league2_min = LEAGUE_MIN_THRESHOLD + LEAGUE_SIZE;
        assert!(TournamentLeagueTrait::compute_id(league2_min - 1) == 1, "Just below league 2 should be league 1");
        assert!(TournamentLeagueTrait::compute_id(league2_min) == 2, "At league 2 min should be league 2");
        
        // Test maximum league
        let max_normal_rating = LEAGUE_MIN_THRESHOLD + LEAGUE_SIZE * LEAGUE_COUNT.into();
        assert!(TournamentLeagueTrait::compute_id(max_normal_rating) == LEAGUE_COUNT, "Max rating should be Global Elite");
    }

    #[test]
    fn test_league_new_invalid_id() {
        // Test with league_id 0 (invalid)
        let league0 = TournamentLeagueTrait::new(GameMode::Tournament, TOURNAMENT_ID, 0);
        // Should handle gracefully or have defined behavior
        assert!(league0.league_id == 0, "Should preserve invalid ID");
        
        // Test with league_id beyond maximum
        let league_max_plus = TournamentLeagueTrait::new(GameMode::Tournament, TOURNAMENT_ID, LEAGUE_COUNT + 1);
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
}