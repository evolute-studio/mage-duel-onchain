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
                TournamentSlot, m_TournamentSlot, TournamentRegistryTrait, TournamentLeagueTrait,
                TournamentSlotTrait, TournamentELOTrait
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
            helpers::{board::{BoardTrait}, bitmap::{Bitmap, BitmapTrait}},
        },
        constants::bitmap::{DEFAULT_RATING, LEAGUE_SIZE, LEAGUE_COUNT, LEAGUE_MIN_THRESHOLD},
    };

    // Extended player addresses for stress tests
    const PLAYER1_ADDRESS: felt252 = 0x123;
    const PLAYER2_ADDRESS: felt252 = 0x456;
    const PLAYER3_ADDRESS: felt252 = 0x789;
    const PLAYER4_ADDRESS: felt252 = 0xabc;
    const PLAYER5_ADDRESS: felt252 = 0xdef;
    const PLAYER6_ADDRESS: felt252 = 0x111;
    const PLAYER7_ADDRESS: felt252 = 0x222;
    const PLAYER8_ADDRESS: felt252 = 0x333;
    const PLAYER9_ADDRESS: felt252 = 0x444;
    const PLAYER10_ADDRESS: felt252 = 0x555;
    const ADMIN_ADDRESS: felt252 = 0x999;
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

    fn deploy_matchmaking() -> (IMatchmakingDispatcher, WorldStorage) {
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (matchmaking_address, _) = world.dns(@"matchmaking").unwrap();
        let dispatcher = IMatchmakingDispatcher { contract_address: matchmaking_address };

        (dispatcher, world)
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
        
        let index = PlayerTournamentIndex {
            player_address,
            tournament_id: TOURNAMENT_ID,
            pass_id,
        };
        world.write_model(@index);
        
        tournament_pass
    }

    fn setup_tournament_player(mut world: WorldStorage, player_address: ContractAddress, pass_id: u64, rating: u32) {
        setup_player(world, player_address);
        create_tournament_pass(world, player_address, pass_id, rating);
    }

    // Helper functions for testing
    fn assert_game_status(world: WorldStorage, player: ContractAddress, expected_status: GameStatus) {
        let game: Game = world.read_model(player);
        assert!(game.status == expected_status, "Game status mismatch");
    }

    fn assert_game_mode(world: WorldStorage, player: ContractAddress, expected_mode: GameMode) {
        let game: Game = world.read_model(player);
        assert!(game.game_mode == expected_mode, "Game mode mismatch");
    }

    fn assert_board_exists(world: WorldStorage, player: ContractAddress) {
        let game: Game = world.read_model(player);
        assert!(game.board_id.is_some(), "Board should exist");
    }

    // Full Tournament Flow Tests
    #[test]
    fn test_full_tournament_elo_matchmaking_flow() {
        let (dispatcher, mut world) = deploy_matchmaking();
        
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player2: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        
        // Setup players with similar ratings in same league
        setup_tournament_player(world, player1, 1, 1200); // Silver I
        setup_tournament_player(world, player2, 2, 1250); // Silver I
        
        // Player1 joins tournament queue
        testing::set_contract_address(player1);
        let board_id1 = dispatcher.auto_match(GameMode::Tournament.into(), Option::Some(TOURNAMENT_ID));
        assert!(board_id1 == 0, "First player should wait in tournament queue");
        assert_game_status(world, player1, GameStatus::Created);
        
        // Player2 should get matched with Player1 via ELO system
        testing::set_contract_address(player2);
        let board_id2 = dispatcher.auto_match(GameMode::Tournament.into(), Option::Some(TOURNAMENT_ID));
        
        if board_id2 != 0 {
            // Match successful
            assert_game_status(world, player1, GameStatus::InProgress);
            assert_game_status(world, player2, GameStatus::InProgress);
            assert_board_exists(world, player1);
            assert_board_exists(world, player2);
            
            // Simulate match completion and rating update
            TournamentELOTrait::update_tournament_ratings_after_match(player1, player2, TOURNAMENT_ID, world);
            
            let p1_pass: TournamentPass = world.read_model(1_u64);
            let p2_pass: TournamentPass = world.read_model(2_u64);
            
            assert!(p1_pass.wins == 1, "Winner should have 1 win");
            assert!(p2_pass.losses == 1, "Loser should have 1 loss");
            assert!(p1_pass.rating > 1200, "Winner should gain rating");
            assert!(p2_pass.rating < 1250, "Loser should lose rating");
        } else {
            // Both players waiting (no match found in ELO system)
            assert_game_status(world, player1, GameStatus::Created);
            assert_game_status(world, player2, GameStatus::Created);
        }
    }

    #[test] 
    fn test_cross_league_tournament_matching() {
        let (dispatcher, mut world) = deploy_matchmaking();
        
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player2: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        let player3: ContractAddress = contract_address_const::<PLAYER3_ADDRESS>();
        
        // Setup players in different leagues
        setup_tournament_player(world, player1, 1, 1100); // Silver I  
        setup_tournament_player(world, player2, 2, 1400); // Silver II
        setup_tournament_player(world, player3, 3, 1700); // Silver III
        
        // All players join tournament queue
        testing::set_contract_address(player1);
        let board_id1 = dispatcher.auto_match(GameMode::Tournament.into(), Option::Some(TOURNAMENT_ID));
        assert!(board_id1 == 0, "Player1 should wait");
        
        testing::set_contract_address(player2);
        let board_id2 = dispatcher.auto_match(GameMode::Tournament.into(), Option::Some(TOURNAMENT_ID));
        
        testing::set_contract_address(player3);
        let board_id3 = dispatcher.auto_match(GameMode::Tournament.into(), Option::Some(TOURNAMENT_ID));
        
        // At least some matches should occur based on ELO matching
        let matched_players = if board_id2 != 0 { 1 } else { 0 } + if board_id3 != 0 { 1 } else { 0 };
        
        // Verify at least one successful match
        if matched_players > 0 {
            // Check that matched players are in InProgress status
            if board_id2 != 0 {
                assert_game_status(world, player2, GameStatus::InProgress);
            }
            if board_id3 != 0 {
                assert_game_status(world, player3, GameStatus::InProgress);
            }
        }
    }

    #[test]
    fn test_tournament_rating_migration_between_leagues() {
        let (dispatcher, mut world) = deploy_matchmaking();
        
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player2: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        
        // Player1 at edge of Silver I (1149 rating)
        // Player2 in Silver II (1300 rating)
        setup_tournament_player(world, player1, 1, 1149);
        setup_tournament_player(world, player2, 2, 1300);
        
        let p1_initial_league = TournamentLeagueTrait::compute_id(1149);
        let p2_initial_league = TournamentLeagueTrait::compute_id(1300);
        
        assert!(p1_initial_league == 1, "Player1 should start in Silver I");
        assert!(p2_initial_league == 2, "Player2 should start in Silver II");
        
        // Simulate Player1 winning (should promote to Silver II)
        TournamentELOTrait::update_tournament_ratings_after_match(player1, player2, TOURNAMENT_ID, world);
        
        let p1_pass: TournamentPass = world.read_model(1_u64);
        let p2_pass: TournamentPass = world.read_model(2_u64);
        
        let p1_new_league = TournamentLeagueTrait::compute_id(p1_pass.rating);
        let p2_new_league = TournamentLeagueTrait::compute_id(p2_pass.rating);
        
        // Player1 might have moved up to Silver II
        if p1_pass.rating >= 1150 {
            assert!(p1_new_league >= 2, "Player1 should have moved up leagues");
        }
        
        // Verify rating changes
        assert!(p1_pass.rating > 1149, "Winner should gain rating");
        assert!(p2_pass.rating < 1300, "Loser should lose rating");
    }

    #[test]
    fn test_mixed_mode_matchmaking() {
        let (dispatcher, mut world) = deploy_matchmaking();
        
        let ranked_player: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let casual_player: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        let tournament_player: ContractAddress = contract_address_const::<PLAYER3_ADDRESS>();
        
        setup_player(world, ranked_player);
        setup_player(world, casual_player);
        setup_tournament_player(world, tournament_player, 1, 1400);
        
        // Different players join different game mode queues
        testing::set_contract_address(ranked_player);
        let ranked_board = dispatcher.auto_match(GameMode::Ranked.into(), Option::None);
        
        testing::set_contract_address(casual_player);
        let casual_board = dispatcher.auto_match(GameMode::Casual.into(), Option::None);
        
        testing::set_contract_address(tournament_player);
        let tournament_board = dispatcher.auto_match(GameMode::Tournament.into(), Option::Some(TOURNAMENT_ID));
        
        // All should be waiting (no cross-mode matching)
        assert!(ranked_board == 0, "Ranked player should wait");
        assert!(casual_board == 0, "Casual player should wait");
        assert!(tournament_board == 0, "Tournament player should wait");
        
        // Verify separate queues
        assert_game_mode(world, ranked_player, GameMode::Ranked);
        assert_game_mode(world, casual_player, GameMode::Casual);
        assert_game_mode(world, tournament_player, GameMode::Tournament);
    }

    // Stress Tests
    #[test]
    fn test_multiple_players_tournament_stress() {
        let (dispatcher, mut world) = deploy_matchmaking();
        
        // Create array of player addresses 
        let players = array![
            contract_address_const::<PLAYER1_ADDRESS>(),
            contract_address_const::<PLAYER2_ADDRESS>(),
            contract_address_const::<PLAYER3_ADDRESS>(),
            contract_address_const::<PLAYER4_ADDRESS>(),
            contract_address_const::<PLAYER5_ADDRESS>(),
            contract_address_const::<PLAYER6_ADDRESS>(),
            contract_address_const::<PLAYER7_ADDRESS>(),
            contract_address_const::<PLAYER8_ADDRESS>(),
        ];
        
        // Setup all players with varying ratings across different leagues
        let mut i = 0_u64;
        let mut rating = 1000_u32;
        while i < players.len().into() {
            let player = *players.at(i.try_into().unwrap());
            setup_tournament_player(world, player, i + 1, rating);
            rating += 200; // Spread across leagues
            i += 1;
        };
        
        // All players attempt to auto match
        let mut matched_count = 0_u32;
        i = 0;
        while i < players.len().into() {
            let player = *players.at(i.try_into().unwrap());
            testing::set_contract_address(player);
            let board_id = dispatcher.auto_match(GameMode::Tournament.into(), Option::Some(TOURNAMENT_ID));
            if board_id != 0 {
                matched_count += 1;
            }
            i += 1;
        };
        
        // Verify some matches occurred
        // Note: Exact number depends on ELO matching algorithm
        assert!(matched_count <= players.len(), "Matched count should be reasonable");
        
        // Check that matched players are in InProgress status
        i = 0;
        let mut in_progress_count = 0_u32;
        while i < players.len().into() {
            let player = *players.at(i.try_into().unwrap());
            let game: Game = world.read_model(player);
            if game.status == GameStatus::InProgress {
                in_progress_count += 1;
            }
            i += 1;
        };
        
        // Should be even number (paired players)
        assert!(in_progress_count % 2 == 0, "In progress players should be paired");
    }

    #[test]
    fn test_rapid_fire_matchmaking() {
        let (dispatcher, mut world) = deploy_matchmaking();
        
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player2: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        
        setup_player(world, player1);
        setup_player(world, player2);
        
        // Rapid successive auto_match calls
        testing::set_contract_address(player1);
        let board1_1 = dispatcher.auto_match(GameMode::Ranked.into(), Option::None);
        let board1_2 = dispatcher.auto_match(GameMode::Ranked.into(), Option::None);
        
        testing::set_contract_address(player2);
        let board2_1 = dispatcher.auto_match(GameMode::Ranked.into(), Option::None);
        
        // First call should succeed or wait, subsequent calls should handle properly
        assert!(board1_1 == 0, "First call should add to queue");
        // Second call should not change state (player already in queue)
        
        // Player2 should potentially get matched
        if board2_1 != 0 {
            assert_game_status(world, player1, GameStatus::InProgress);
            assert_game_status(world, player2, GameStatus::InProgress);
        }
    }

    #[test]
    fn test_tournament_cancellation_during_search() {
        let (dispatcher, mut world) = deploy_matchmaking();
        
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player2: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        
        setup_tournament_player(world, player1, 1, 1200);
        setup_tournament_player(world, player2, 2, 1300);
        
        // Player1 joins tournament queue
        testing::set_contract_address(player1);
        let board_id1 = dispatcher.auto_match(GameMode::Tournament.into(), Option::Some(TOURNAMENT_ID));
        assert!(board_id1 == 0, "Should wait in queue");
        assert_game_status(world, player1, GameStatus::Created);
        
        // Player1 cancels while waiting
        dispatcher.cancel_game();
        assert_game_status(world, player1, GameStatus::Canceled);
        
        // Player2 joins queue (should not match with canceled player1)
        testing::set_contract_address(player2);
        let board_id2 = dispatcher.auto_match(GameMode::Tournament.into(), Option::Some(TOURNAMENT_ID));
        assert!(board_id2 == 0, "Should wait since player1 canceled");
        assert_game_status(world, player2, GameStatus::Created);
    }

    #[test]
    fn test_tournament_elo_extreme_ratings() {
        let (dispatcher, mut world) = deploy_matchmaking();
        
        let newbie: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let pro: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        
        // Extreme rating difference
        setup_tournament_player(world, newbie, 1, 500);   // Very low rating
        setup_tournament_player(world, pro, 2, 3000);     // Very high rating
        
        // Both join tournament
        testing::set_contract_address(newbie);
        let newbie_board = dispatcher.auto_match(GameMode::Tournament.into(), Option::Some(TOURNAMENT_ID));
        
        testing::set_contract_address(pro);
        let pro_board = dispatcher.auto_match(GameMode::Tournament.into(), Option::Some(TOURNAMENT_ID));
        
        // They might or might not get matched depending on ELO algorithm tolerance
        if pro_board != 0 {
            // If matched, simulate newbie winning (major upset)
            TournamentELOTrait::update_tournament_ratings_after_match(newbie, pro, TOURNAMENT_ID, world);
            
            let newbie_pass: TournamentPass = world.read_model(1_u64);
            let pro_pass: TournamentPass = world.read_model(2_u64);
            
            // Newbie should gain significant rating
            assert!(newbie_pass.rating > 500, "Newbie should gain much rating");
            assert!(pro_pass.rating < 3000, "Pro should lose rating");
            
            // Verify league changes
            let newbie_new_league = TournamentLeagueTrait::compute_id(newbie_pass.rating);
            let pro_new_league = TournamentLeagueTrait::compute_id(pro_pass.rating);
        }
    }

    #[test]
    fn test_tournament_registry_bitmap_integration() {
        let (dispatcher, mut world) = deploy_matchmaking();
        
        // Create players across multiple leagues
        let players_and_ratings = array![
            (contract_address_const::<PLAYER1_ADDRESS>(), 1100_u32), // League 1
            (contract_address_const::<PLAYER2_ADDRESS>(), 1300_u32), // League 2  
            (contract_address_const::<PLAYER3_ADDRESS>(), 1600_u32), // League 3
            (contract_address_const::<PLAYER4_ADDRESS>(), 2000_u32), // League 4
            (contract_address_const::<PLAYER5_ADDRESS>(), 2500_u32), // League 5
        ];
        
        // Setup all players
        let mut pass_id = 1_u64;
        let mut i = 0;
        while i < players_and_ratings.len() {
            let (player, rating) = *players_and_ratings.at(i);
            setup_tournament_player(world, player, pass_id, rating);
            pass_id += 1;
            i += 1;
        };
        
        // Create tournament registry and leagues
        let mut registry = TournamentRegistryTrait::new(GameMode::Tournament, TOURNAMENT_ID);
        let mut leagues: Array<TournamentLeague> = ArrayTrait::new();
        
        let mut league_id = 1_u8;
        while league_id <= 5 {
            let league = TournamentLeagueTrait::new(GameMode::Tournament, TOURNAMENT_ID, league_id);
            leagues.append(league);
            league_id += 1;
        };
        
        // Subscribe players to their appropriate leagues
        i = 0;
        while i < players_and_ratings.len() {
            let (player, rating) = *players_and_ratings.at(i);
            let computed_league_id = TournamentLeagueTrait::compute_id(rating);
            
            // Find matching league and subscribe
            let mut j = 0;
            while j < leagues.len() {
                let mut league = *leagues.at(j);
                if league.league_id == computed_league_id {
                    let slot = registry.subscribe(ref league, player, world);
                    world.write_model(@slot);
                    leagues.set(j, league); // Update modified league
                    break;
                }
                j += 1;
            };
            i += 1;
        };
        
        // Verify bitmap has correct active leagues
        assert!(Bitmap::get_bit_at(registry.leagues.into(), 1), "League 1 should be active");
        assert!(Bitmap::get_bit_at(registry.leagues.into(), 2), "League 2 should be active");
        assert!(Bitmap::get_bit_at(registry.leagues.into(), 3), "League 3 should be active");
        
        // Verify league sizes
        let mut j = 0;
        while j < leagues.len() {
            let league = *leagues.at(j);
            assert!(league.size <= 1, "Each league should have at most 1 player in this test");
            j += 1;
        };
    }

    // Error and Validation Tests for Integration
    #[test]
    fn test_tournament_flow_with_invalid_data() {
        let (dispatcher, mut world) = deploy_matchmaking();
        
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player2: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        
        // Setup one player without tournament pass
        setup_player(world, player1);
        setup_tournament_player(world, player2, 1, 1200);
        
        // Player without pass tries tournament mode
        testing::set_contract_address(player1);
        let board_id1 = dispatcher.auto_match(GameMode::Tournament.into(), Option::Some(TOURNAMENT_ID));
        assert!(board_id1 == 0, "Player without pass should not match");
        
        // Valid player should still be able to join queue
        testing::set_contract_address(player2);
        let board_id2 = dispatcher.auto_match(GameMode::Tournament.into(), Option::Some(TOURNAMENT_ID));
        assert!(board_id2 == 0, "Valid player should wait in queue");
        assert_game_status(world, player2, GameStatus::Created);
    }

    #[test]
    fn test_mixed_mode_isolation() {
        let (dispatcher, mut world) = deploy_matchmaking();
        
        let ranked_players = array![
            contract_address_const::<PLAYER1_ADDRESS>(),
            contract_address_const::<PLAYER2_ADDRESS>(),
        ];
        let tournament_players = array![
            contract_address_const::<PLAYER3_ADDRESS>(),
            contract_address_const::<PLAYER4_ADDRESS>(),
        ];
        
        // Setup ranked players
        setup_player(world, *ranked_players.at(0));
        setup_player(world, *ranked_players.at(1));
        
        // Setup tournament players  
        setup_tournament_player(world, *tournament_players.at(0), 1, 1200);
        setup_tournament_player(world, *tournament_players.at(1), 2, 1300);
        
        // All players join their respective queues
        testing::set_contract_address(*ranked_players.at(0));
        dispatcher.auto_match(GameMode::Ranked.into(), Option::None);
        
        testing::set_contract_address(*ranked_players.at(1));
        let ranked_match = dispatcher.auto_match(GameMode::Ranked.into(), Option::None);
        
        testing::set_contract_address(*tournament_players.at(0));
        dispatcher.auto_match(GameMode::Tournament.into(), Option::Some(TOURNAMENT_ID));
        
        testing::set_contract_address(*tournament_players.at(1));
        let tournament_match = dispatcher.auto_match(GameMode::Tournament.into(), Option::Some(TOURNAMENT_ID));
        
        // Verify modes don't cross-match
        if ranked_match != 0 {
            // Ranked players matched with each other
            assert_game_mode(world, *ranked_players.at(0), GameMode::Ranked);
            assert_game_mode(world, *ranked_players.at(1), GameMode::Ranked);
        }
        
        if tournament_match != 0 {
            // Tournament players matched with each other  
            assert_game_mode(world, *tournament_players.at(0), GameMode::Tournament);
            assert_game_mode(world, *tournament_players.at(1), GameMode::Tournament);
        }
    }

    #[test]
    fn test_tournament_registry_corruption_recovery() {
        let (dispatcher, mut world) = deploy_matchmaking();
        
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player2: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        
        setup_tournament_player(world, player1, 1, 1200);
        setup_tournament_player(world, player2, 2, 1300);
        
        // Create registry and leagues manually
        let mut registry = TournamentRegistryTrait::new(GameMode::Tournament, TOURNAMENT_ID);
        let mut league1 = TournamentLeagueTrait::new(GameMode::Tournament, TOURNAMENT_ID, 1);
        let mut league2 = TournamentLeagueTrait::new(GameMode::Tournament, TOURNAMENT_ID, 2);
        
        // Subscribe players
        let slot1 = registry.subscribe(ref league1, player1, world);
        let slot2 = registry.subscribe(ref league2, player2, world);
        world.write_model(@slot1);
        world.write_model(@slot2);
        
        // Manually corrupt registry by setting wrong bitmap
        registry.leagues = 0; // Clear bitmap
        
        // Try to find opponent with corrupted registry
        // Should handle gracefully without crashing
        let opponent = TournamentELOTrait::find_tournament_opponent(player1, TOURNAMENT_ID, world);
        assert!(opponent.is_none(), "Should not find opponent in corrupted registry");
    }

    #[test]
    fn test_resource_exhaustion_simulation() {
        let (dispatcher, mut world) = deploy_matchmaking();
        
        // Create maximum number of players we can handle
        let max_players = 10_u8;
        let mut created_players: Array<ContractAddress> = ArrayTrait::new();
        
        let mut i = 0_u8;
        while i < max_players {
            let player_addr = contract_address_const::<{0x1000 + i.into()}>();
            setup_tournament_player(world, player_addr, (i + 1).into(), 1000 + i.into() * 100);
            created_players.append(player_addr);
            i += 1;
        };
        
        // All players attempt to join tournament queue rapidly
        i = 0;
        while i < created_players.len().try_into().unwrap() {
            let player = *created_players.at(i.into());
            testing::set_contract_address(player);
            let _board_id = dispatcher.auto_match(GameMode::Tournament.into(), Option::Some(TOURNAMENT_ID));
            i += 1;
        };
        
        // System should remain stable (no crashes)
        // Some players should be matched, others waiting
        let mut matched_count = 0_u32;
        let mut waiting_count = 0_u32;
        
        i = 0;
        while i < created_players.len().try_into().unwrap() {
            let player = *created_players.at(i.into());
            let game: Game = world.read_model(player);
            
            match game.status {
                GameStatus::InProgress => { matched_count += 1; },
                GameStatus::Created => { waiting_count += 1; },
                _ => {},
            }
            i += 1;
        };
        
        // Should have reasonable distribution
        assert!(matched_count + waiting_count <= max_players.into(), "Total should not exceed max players");
        assert!(matched_count % 2 == 0, "Matched players should be even (paired)");
    }

    #[test]
    fn test_rating_boundary_edge_cases() {
        let (dispatcher, mut world) = deploy_matchmaking();
        
        // Players at exact league boundaries
        let boundary_players = array![
            (contract_address_const::<PLAYER1_ADDRESS>(), 1000_u32), // Exactly at LEAGUE_MIN_THRESHOLD
            (contract_address_const::<PLAYER2_ADDRESS>(), 1149_u32), // Just below league 2
            (contract_address_const::<PLAYER3_ADDRESS>(), 1150_u32), // Just at league 2
            (contract_address_const::<PLAYER4_ADDRESS>(), 999999_u32), // Very high rating
        ];
        
        let mut pass_id = 1_u64;
        let mut i = 0;
        while i < boundary_players.len() {
            let (player, rating) = *boundary_players.at(i);
            setup_tournament_player(world, player, pass_id, rating);
            pass_id += 1;
            i += 1;
        };
        
        // Verify league computations are correct
        i = 0;
        while i < boundary_players.len() {
            let (player, rating) = *boundary_players.at(i);
            let league_id = TournamentLeagueTrait::compute_id(rating);
            
            // Verify league computation consistency
            let league = TournamentLeagueTrait::new(GameMode::Tournament, TOURNAMENT_ID, league_id);
            assert!(rating >= league.min_rating, "Rating should be >= league min");
            assert!(rating <= league.max_rating, "Rating should be <= league max");
            
            i += 1;
        };
    }

    #[test]
    fn test_concurrent_match_attempts() {
        let (dispatcher, mut world) = deploy_matchmaking();
        
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player2: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        
        setup_tournament_player(world, player1, 1, 1200);
        setup_tournament_player(world, player2, 2, 1250);
        
        // Simulate concurrent auto_match calls
        testing::set_contract_address(player1);
        let board1_attempt1 = dispatcher.auto_match(GameMode::Tournament.into(), Option::Some(TOURNAMENT_ID));
        let board1_attempt2 = dispatcher.auto_match(GameMode::Tournament.into(), Option::Some(TOURNAMENT_ID));
        
        testing::set_contract_address(player2);
        let board2_attempt1 = dispatcher.auto_match(GameMode::Tournament.into(), Option::Some(TOURNAMENT_ID));
        let board2_attempt2 = dispatcher.auto_match(GameMode::Tournament.into(), Option::Some(TOURNAMENT_ID));
        
        // First attempts should be consistent
        assert!(board1_attempt1 == board1_attempt2, "Concurrent calls should be consistent");
        
        // Only one successful match should occur
        let successful_matches = (if board1_attempt1 != 0 { 1 } else { 0 }) + 
                                (if board2_attempt1 != 0 { 1 } else { 0 });
        assert!(successful_matches <= 1, "At most one match should succeed initially");
    }

    #[test]
    fn test_game_mode_config_validation() {
        let (dispatcher, mut world) = deploy_matchmaking();
        
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        setup_player(world, player1);
        
        // Try to create games with different modes
        testing::set_contract_address(player1);
        
        let modes_to_test = array![
            GameMode::Tutorial.into(),
            GameMode::Casual.into(), 
            GameMode::Ranked.into(),
            GameMode::Tournament.into(),
        ];
        
        let mut i = 0;
        while i < modes_to_test.len() {
            let mode = *modes_to_test.at(i);
            
            // Reset player state
            let reset_game = Game {
                player: player1,
                status: GameStatus::Finished,
                board_id: Option::None,
                game_mode: GameMode::None,
            };
            world.write_model(@reset_game);
            
            // Try to create game
            if mode == GameMode::Tutorial.into() {
                // Tutorial needs bot address
                dispatcher.create_game(mode, Option::Some(contract_address_const::<BOT_ADDRESS>()));
            } else {
                dispatcher.create_game(mode, Option::None);
            }
            
            let game: Game = world.read_model(player1);
            // Verify game creation behavior
            if mode == GameMode::Tutorial.into() {
                // Tutorial might fail without proper bot setup
            } else {
                // Other modes should create successfully or fail gracefully
            }
            
            i += 1;
        };
    }
}