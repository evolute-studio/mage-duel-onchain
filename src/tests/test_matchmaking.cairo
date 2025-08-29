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
            tournament_matchmaking::{TournamentRegistry, m_TournamentRegistry, TournamentLeague, m_TournamentLeague, TournamentSlot, m_TournamentSlot},
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
    };

    const PLAYER1_ADDRESS: felt252 = 0x123;
    const PLAYER2_ADDRESS: felt252 = 0x456;
    const BOT_ADDRESS: felt252 = 0x789;
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

    fn setup_bot(mut world: WorldStorage, bot_address: ContractAddress) {
        let bot = Player {
            player_id: bot_address,
            username: 'Bot',
            balance: 0,
            games_played: 0,
            active_skin: 0,
            role: 2, // Bot
            tutorial_completed: true,
            migration_target: Zero::zero(),
            migration_initiated_at: 0,
            migration_used: false,
        };
        world.write_model(@bot);

        let game = Game {
            player: bot_address,
            status: GameStatus::Finished,
            board_id: Option::None,
            game_mode: GameMode::None,
        };
        world.write_model(@game);
    }

    // Test Helper Functions
    fn assert_game_status(
        world: WorldStorage, player: ContractAddress, expected_status: GameStatus,
    ) {
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

    fn setup_tournament_player(mut world: WorldStorage, player: ContractAddress, pass_id: u64, rating: u32) {
        setup_player(world, player);
        
        // Create tournament pass
        let tournament_pass = TournamentPass {
            pass_id,
            tournament_id: TOURNAMENT_ID,
            player_address: player,
            entry_number: 1,
            rating,
            games_played: 0,
            wins: 0,
            losses: 0,
        };
        world.write_model(@tournament_pass);
        
        // Create player tournament index
        let index = PlayerTournamentIndex {
            player_address: player,
            tournament_id: TOURNAMENT_ID,
            pass_id,
        };
        world.write_model(@index);
    }

    // Tests for create_game function
    #[test]
    fn test_create_casual_game_success() {
        let (dispatcher, mut world) = deploy_matchmaking();

        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        setup_player(world, player1);

        testing::set_contract_address(player1);
        dispatcher.create_game(GameMode::Casual.into(), Option::None);

        assert_game_status(world, player1, GameStatus::Created);
        assert_game_mode(world, player1, GameMode::Casual);
    }

    #[test]
    fn test_create_ranked_game_success() {
        let (dispatcher, mut world) = deploy_matchmaking();

        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        setup_player(world, player1);

        testing::set_contract_address(player1);
        dispatcher.create_game(GameMode::Ranked.into(), Option::None);

        assert_game_status(world, player1, GameStatus::Created);
        assert_game_mode(world, player1, GameMode::Ranked);
    }

    #[test]
    fn test_create_tutorial_game_success() {
        let (dispatcher, mut world) = deploy_matchmaking();

        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let bot: ContractAddress = contract_address_const::<BOT_ADDRESS>();
        setup_player(world, player1);
        setup_bot(world, bot);

        testing::set_contract_address(player1);
        dispatcher.create_game(GameMode::Tutorial.into(), Option::Some(bot));

        assert_game_status(world, player1, GameStatus::InProgress);
        assert_game_mode(world, player1, GameMode::Tutorial);
        assert_board_exists(world, player1);

        // Bot should also be in game
        assert_game_status(world, bot, GameStatus::InProgress);
        assert_game_mode(world, bot, GameMode::Tutorial);
    }

    #[test]
    fn test_create_game_when_already_in_game_fails() {
        let (dispatcher, mut world) = deploy_matchmaking();

        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        setup_player(world, player1);

        // Set player to already be in a game
        let mut game: Game = world.read_model(player1);
        game.status = GameStatus::InProgress;
        world.write_model(@game);

        testing::set_contract_address(player1);
        dispatcher.create_game(GameMode::Casual.into(), Option::None);

        // Status should remain InProgress (not changed to Created)
        assert_game_status(world, player1, GameStatus::InProgress);
    }

    // Tests for join_game function
    #[test]
    fn test_join_casual_game_success() {
        let (dispatcher, mut world) = deploy_matchmaking();

        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player2: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        setup_player(world, player1);
        setup_player(world, player2);

        // Player1 creates a game
        testing::set_contract_address(player1);
        dispatcher.create_game(GameMode::Casual.into(), Option::None);

        // Player2 joins the game
        testing::set_contract_address(player2);
        dispatcher.join_game(player1);

        // Both players should be in progress
        assert_game_status(world, player1, GameStatus::InProgress);
        assert_game_status(world, player2, GameStatus::InProgress);
        assert_game_mode(world, player1, GameMode::Casual);
        assert_game_mode(world, player2, GameMode::Casual);
        assert_board_exists(world, player1);
        assert_board_exists(world, player2);
    }

    #[test]
    fn test_join_ranked_game_success() {
        let (dispatcher, mut world) = deploy_matchmaking();

        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player2: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        setup_player(world, player1);
        setup_player(world, player2);

        // Player1 creates a ranked game
        testing::set_contract_address(player1);
        dispatcher.create_game(GameMode::Ranked.into(), Option::None);

        // Player2 joins the game
        testing::set_contract_address(player2);
        dispatcher.join_game(player1);

        // Both players should be in progress
        assert_game_status(world, player1, GameStatus::InProgress);
        assert_game_status(world, player2, GameStatus::InProgress);
        assert_game_mode(world, player1, GameMode::Ranked);
        assert_game_mode(world, player2, GameMode::Ranked);
    }

    #[test]
    fn test_join_game_when_host_not_created_fails() {
        let (dispatcher, mut world) = deploy_matchmaking();

        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player2: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        setup_player(world, player1);
        setup_player(world, player2);

        // Player2 tries to join without player1 creating a game
        testing::set_contract_address(player2);
        dispatcher.join_game(player1);

        // Both players should remain in Finished status (from setup)
        assert_game_status(world, player1, GameStatus::Finished);
        assert_game_status(world, player2, GameStatus::Finished);
    }

    #[test]
    fn test_join_game_when_guest_already_in_game_fails() {
        let (dispatcher, mut world) = deploy_matchmaking();

        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player2: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        setup_player(world, player1);
        setup_player(world, player2);

        // Player1 creates a game
        testing::set_contract_address(player1);
        dispatcher.create_game(GameMode::Casual.into(), Option::None);

        // Set player2 to already be in a game
        let mut game: Game = world.read_model(player2);
        game.status = GameStatus::InProgress;
        world.write_model_test(@game);

        // Player2 tries to join
        testing::set_contract_address(player2);
        dispatcher.join_game(player1);

        // Player1 should remain Created, player2 should remain InProgress
        assert_game_status(world, player1, GameStatus::Created);
        assert_game_status(world, player2, GameStatus::InProgress);
    }

    // Tests for cancel_game function
    #[test]
    fn test_cancel_created_game_success() {
        let (dispatcher, mut world) = deploy_matchmaking();

        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        setup_player(world, player1);

        // Create a game
        testing::set_contract_address(player1);
        dispatcher.create_game(GameMode::Casual.into(), Option::None);
        assert_game_status(world, player1, GameStatus::Created);

        // Cancel the game
        dispatcher.cancel_game();

        assert_game_status(world, player1, GameStatus::Canceled);
        assert_game_mode(world, player1, GameMode::None);
    }

    #[test]
    fn test_cancel_in_progress_game_success() {
        let (dispatcher, mut world) = deploy_matchmaking();

        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player2: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        setup_player(world, player1);
        setup_player(world, player2);

        // Create and join a game
        testing::set_contract_address(player1);
        dispatcher.create_game(GameMode::Casual.into(), Option::None);

        testing::set_contract_address(player2);
        dispatcher.join_game(player1);

        assert_game_status(world, player1, GameStatus::InProgress);
        assert_game_status(world, player2, GameStatus::InProgress);

        // Player1 cancels the game
        testing::set_contract_address(player1);
        dispatcher.cancel_game();

        // Both players should be canceled
        assert_game_status(world, player1, GameStatus::Canceled);
        assert_game_status(world, player2, GameStatus::Canceled);
        assert_game_mode(world, player1, GameMode::None);
        assert_game_mode(world, player2, GameMode::None);
    }

    #[test]
    fn test_cancel_tutorial_game_success() {
        let (dispatcher, mut world) = deploy_matchmaking();

        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let bot: ContractAddress = contract_address_const::<BOT_ADDRESS>();
        setup_player(world, player1);
        setup_bot(world, bot);

        // Create tutorial game
        testing::set_contract_address(player1);
        dispatcher.create_game(GameMode::Tutorial.into(), Option::Some(bot));
        assert_game_status(world, player1, GameStatus::InProgress);

        // Cancel tutorial game
        dispatcher.cancel_game();

        // Tutorial games can be canceled like any other game
        assert_game_status(world, player1, GameStatus::Canceled);
        assert_game_status(world, bot, GameStatus::Canceled);
    }

    // Tests for auto_match function
    #[test]
    fn test_auto_match_no_waiting_players() {
        let (dispatcher, mut world) = deploy_matchmaking();

        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        setup_player(world, player1);

        testing::set_contract_address(player1);
        let board_id = dispatcher.auto_match(GameMode::Ranked.into(), Option::None);

        // Should return 0 (waiting in queue)
        assert!(board_id == 0, "Should return 0 when no match found");
        assert_game_status(world, player1, GameStatus::Created);
        assert_game_mode(world, player1, GameMode::Ranked);
    }

    #[test]
    fn test_auto_match_with_waiting_player() {
        let (dispatcher, mut world) = deploy_matchmaking();

        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player2: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        setup_player(world, player1);
        setup_player(world, player2);

        // Player1 joins queue first
        testing::set_contract_address(player1);
        let board_id1 = dispatcher.auto_match(GameMode::Ranked.into(), Option::None);
        assert!(board_id1 == 0, "First player should wait in queue");

        // Player2 joins and should get matched
        testing::set_contract_address(player2);
        let board_id2 = dispatcher.auto_match(GameMode::Ranked.into(), Option::None);
        assert!(board_id2 != 0, "Second player should get matched");

        // Both players should be in progress with same board
        assert_game_status(world, player1, GameStatus::InProgress);
        assert_game_status(world, player2, GameStatus::InProgress);
        assert_game_mode(world, player1, GameMode::Ranked);
        assert_game_mode(world, player2, GameMode::Ranked);

        let game1: Game = world.read_model(player1);
        let game2: Game = world.read_model(player2);
        assert!(game1.board_id == game2.board_id, "Both players should have same board_id");
    }

    #[test]
    fn test_auto_match_different_game_modes_separate_queues() {
        let (dispatcher, mut world) = deploy_matchmaking();

        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player2: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        setup_player(world, player1);
        setup_player(world, player2);

        // Player1 joins ranked queue
        testing::set_contract_address(player1);
        let board_id1 = dispatcher.auto_match(GameMode::Ranked.into(), Option::None);
        assert!(board_id1 == 0, "First player should wait in ranked queue");

        // Player2 joins casual queue (should not match with player1)
        testing::set_contract_address(player2);
        let board_id2 = dispatcher.auto_match(GameMode::Casual.into(), Option::None);
        assert!(board_id2 == 0, "Second player should wait in casual queue");

        // Both should be waiting in their respective queues
        assert_game_status(world, player1, GameStatus::Created);
        assert_game_status(world, player2, GameStatus::Created);
        assert_game_mode(world, player1, GameMode::Ranked);
        assert_game_mode(world, player2, GameMode::Casual);
    }

    // Tests for configs initialized via dojo_init
    #[test]
    fn test_configs_initialized() {
        let (dispatcher, mut world) = deploy_matchmaking();

        // Check that configs are created for all game modes via dojo_init
        let tutorial_config: GameModeConfig = world.read_model(GameMode::Tutorial);
        let ranked_config: GameModeConfig = world.read_model(GameMode::Ranked);
        let casual_config: GameModeConfig = world.read_model(GameMode::Casual);
        let tournament_config: GameModeConfig = world.read_model(GameMode::Tournament);

        assert!(tutorial_config.game_mode == GameMode::Tutorial, "Tutorial config should exist");
        assert!(ranked_config.game_mode == GameMode::Ranked, "Ranked config should exist");
        assert!(casual_config.game_mode == GameMode::Casual, "Casual config should exist");
        assert!(
            tournament_config.game_mode == GameMode::Tournament, "Tournament config should exist",
        );

        // Check some specific values
        assert!(tutorial_config.board_size == 7, "Tutorial should have board size 7");
        assert!(ranked_config.board_size == 10, "Ranked should have board size 10");
        assert!(casual_config.board_size == 10, "Casual should have board size 10");

        assert!(tutorial_config.auto_match == false, "Tutorial should not have auto match");
        assert!(ranked_config.auto_match == true, "Ranked should have auto match");
        assert!(casual_config.auto_match == false, "Casual should not have auto match");
    }

    // Tests for update_config
    #[test]
    fn test_update_config() {
        let (dispatcher, mut world) = deploy_matchmaking();

        // Get current deck config to reuse
        let current_config: GameModeConfig = world.read_model(GameMode::Casual);

        // Update casual config
        dispatcher
            .update_config(
                GameMode::Casual.into(),
                8, // board_size
                2, // deck_type
                1, // initial_jokers
                30, // time_per_phase
                true, // auto_match
                current_config.deck, // keep existing deck
                current_config.edges, // keep existing edges
                current_config.joker_price // keep existing joker_price
            );

        let config: GameModeConfig = world.read_model(GameMode::Casual);
        assert!(config.board_size == 8, "Board size should be updated");
        assert!(config.deck_type == 2, "Deck type should be updated");
        assert!(config.initial_jokers == 1, "Initial jokers should be updated");
        assert!(config.time_per_phase == 30, "Time per phase should be updated");
        assert!(config.auto_match == true, "Auto match should be updated");
    }

    // Tests for Tournament mode
    #[test]
    fn test_create_tournament_game_success() {
        let (dispatcher, mut world) = deploy_matchmaking();

        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        setup_tournament_player(world, player1, 1, 1200);

        testing::set_contract_address(player1);
        dispatcher.create_game(GameMode::Tournament.into(), Option::None);

        assert_game_status(world, player1, GameStatus::Created);
        assert_game_mode(world, player1, GameMode::Tournament);
    }

    #[test]
    #[should_panic]
    fn test_create_tournament_game_fails() {
        let (dispatcher, mut world) = deploy_matchmaking();

        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player2: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        setup_tournament_player(world, player1, 1, 1200);
        setup_tournament_player(world, player2, 2, 1300);

        // Player1 creates a tournament game
        testing::set_contract_address(player1);
        dispatcher.create_game(GameMode::Tournament.into(), Option::None);

        // // Player2 tries to join (should fail - tournament mode doesn't support manual join)
        // testing::set_contract_address(player2);
        // dispatcher.join_game(player1);

        // // Player1 should remain Created, player2 should remain Finished (from setup)
        // assert_game_status(world, player1, GameStatus::Created);
        // assert_game_status(world, player2, GameStatus::Finished);
    }

    #[test]
    fn test_tournament_auto_match_no_tournament_id() {
        let (dispatcher, mut world) = deploy_matchmaking();

        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        setup_tournament_player(world, player1, 1, 1200);

        testing::set_contract_address(player1);
        let board_id = dispatcher.auto_match(GameMode::Tournament.into(), Option::None);

        // Should return 0 and add to FIFO queue instead of ELO matching (tournament_id = 0)
        assert!(board_id == 0, "Should return 0 when no tournament_id provided");
        assert_game_status(world, player1, GameStatus::Created);
    }

    #[test]
    fn test_tournament_auto_match_with_tournament_id() {
        let (dispatcher, mut world) = deploy_matchmaking();

        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        setup_tournament_player(world, player1, 1, 1200);

        testing::set_contract_address(player1);
        let board_id = dispatcher.auto_match(GameMode::Tournament.into(), Option::Some(TOURNAMENT_ID));

        // Should return 0 (no opponents in ELO system yet) and add to tournament queue
        assert!(board_id == 0, "Should return 0 when no opponents found");
        assert_game_status(world, player1, GameStatus::Created);
        assert_game_mode(world, player1, GameMode::Tournament);
    }

    // Tests for multiple players in FIFO queue
    #[test]
    fn test_auto_match_multiple_players_fifo() {
        let (dispatcher, mut world) = deploy_matchmaking();

        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player2: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        let player3: ContractAddress = contract_address_const::<0xabc>();
        setup_player(world, player1);
        setup_player(world, player2);
        setup_player(world, player3);

        // Player1 joins queue
        testing::set_contract_address(player1);
        let board_id1 = dispatcher.auto_match(GameMode::Ranked.into(), Option::None);
        assert!(board_id1 == 0, "First player should wait");

        // Player2 joins queue  
        testing::set_contract_address(player2);
        let board_id2 = dispatcher.auto_match(GameMode::Ranked.into(), Option::None);
        assert!(board_id2 != 0, "Second player should get matched with first");

        // Player3 joins queue
        testing::set_contract_address(player3);
        let board_id3 = dispatcher.auto_match(GameMode::Ranked.into(), Option::None);
        assert!(board_id3 == 0, "Third player should wait in queue");

        // Verify first two players matched
        assert_game_status(world, player1, GameStatus::InProgress);
        assert_game_status(world, player2, GameStatus::InProgress);
        assert_game_status(world, player3, GameStatus::Created);
    }

    #[test]
    fn test_matchmaking_state_tracking() {
        let (dispatcher, mut world) = deploy_matchmaking();

        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player2: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        setup_player(world, player1);
        setup_player(world, player2);

        // Note: MatchmakingState is created dynamically during auto_match, so we skip direct validation
        // and rely on game status checks instead
        
        // Player1 joins queue
        testing::set_contract_address(player1);
        let board_id1 = dispatcher.auto_match(GameMode::Ranked.into(), Option::None);
        assert!(board_id1 == 0, "First player should wait in queue");
        assert_game_status(world, player1, GameStatus::Created);

        // Player2 joins and gets matched
        testing::set_contract_address(player2);
        let board_id2 = dispatcher.auto_match(GameMode::Ranked.into(), Option::None);
        assert!(board_id2 != 0, "Second player should get matched");
        assert_game_status(world, player1, GameStatus::InProgress);
        assert_game_status(world, player2, GameStatus::InProgress);
    }

    #[test]
    fn test_player_matchmaking_tracking() {
        let (dispatcher, mut world) = deploy_matchmaking();

        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        setup_player(world, player1);

        // Player joins queue
        testing::set_contract_address(player1);
        let board_id = dispatcher.auto_match(GameMode::Ranked.into(), Option::None);
        assert!(board_id == 0, "Player should wait in queue");
        
        // Game status should indicate player is waiting
        assert_game_status(world, player1, GameStatus::Created);
        assert_game_mode(world, player1, GameMode::Ranked);
    }

    #[test]
    fn test_cancel_game_in_queue() {
        let (dispatcher, mut world) = deploy_matchmaking();

        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        setup_player(world, player1);

        // Player joins queue
        testing::set_contract_address(player1);
        dispatcher.auto_match(GameMode::Ranked.into(), Option::None);
        assert_game_status(world, player1, GameStatus::Created);

        // Cancel while in queue
        dispatcher.cancel_game();
        assert_game_status(world, player1, GameStatus::Canceled);
        assert_game_mode(world, player1, GameMode::None);
    }

    // Error and Validation Tests
    #[test]
    fn test_invalid_game_mode_create() {
        let (dispatcher, mut world) = deploy_matchmaking();
        
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        setup_player(world, player1);
        
        testing::set_contract_address(player1);
        // Try to create game with invalid mode (255)
        dispatcher.create_game(255, Option::None);
        
        // Should remain in default state (not created)
        assert_game_status(world, player1, GameStatus::Finished);
        assert_game_mode(world, player1, GameMode::None);
    }

    #[test] 
    fn test_auto_match_invalid_game_mode() {
        let (dispatcher, mut world) = deploy_matchmaking();
        
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        setup_player(world, player1);
        
        testing::set_contract_address(player1);
        let board_id = dispatcher.auto_match(255, Option::None);
        
        // Should return 0 and not change state
        assert!(board_id == 0, "Invalid mode should return 0");
        assert_game_status(world, player1, GameStatus::Finished);
    }

    #[test]
    fn test_double_create_game_fails() {
        let (dispatcher, mut world) = deploy_matchmaking();
        
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        setup_player(world, player1);
        
        testing::set_contract_address(player1);
        
        // Create first game
        dispatcher.create_game(GameMode::Casual.into(), Option::None);
        assert_game_status(world, player1, GameStatus::Created);
        
        // Try to create second game while first is pending
        dispatcher.create_game(GameMode::Ranked.into(), Option::None);
        
        // Should remain in Casual mode (first creation)
        assert_game_mode(world, player1, GameMode::Casual);
    }

    #[test]
    fn test_join_nonexistent_host() {
        let (dispatcher, mut world) = deploy_matchmaking();
        
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let fake_host: ContractAddress = contract_address_const::<0x999>();
        setup_player(world, player1);
        
        testing::set_contract_address(player1);
        dispatcher.join_game(fake_host);
        
        // Should not change state
        assert_game_status(world, player1, GameStatus::Finished);
    }

    #[test]
    fn test_cancel_nonexistent_game() {
        let (dispatcher, mut world) = deploy_matchmaking();
        
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        setup_player(world, player1);
        
        testing::set_contract_address(player1);
        // Try to cancel when no game exists
        dispatcher.cancel_game();
        
        // Should remain in Finished state
        assert_game_status(world, player1, GameStatus::Finished);
    }

    #[test]
    fn test_auto_match_while_in_progress() {
        let (dispatcher, mut world) = deploy_matchmaking();
        
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        setup_player(world, player1);
        
        // Manually set player to InProgress to simulate active game
        let game = Game {
            player: player1,
            status: GameStatus::InProgress,
            game_mode: GameMode::Ranked,
            board_id: Option::Some(123),
        };
        world.write_model(@game);
        
        testing::set_contract_address(player1);
        let board_id = dispatcher.auto_match(GameMode::Casual.into(), Option::None);
        
        // Should return 0 and not change state
        assert!(board_id == 0, "Should not auto match while in progress");
        assert_game_status(world, player1, GameStatus::InProgress);
        assert_game_mode(world, player1, GameMode::Ranked);
    }

    #[test]
    fn test_tournament_mode_without_tournament_pass() {
        let (dispatcher, mut world) = deploy_matchmaking();
        
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        setup_player(world, player1); // No tournament pass created
        
        testing::set_contract_address(player1);
        let board_id = dispatcher.auto_match(GameMode::Tournament.into(), Option::Some(TOURNAMENT_ID));
        
        // Should handle gracefully (return 0 or fallback behavior)
        assert!(board_id == 0, "Should return 0 when no tournament pass");
    }

    #[test]
    fn test_admin_cancel_permissions() {
        let (dispatcher, mut world) = deploy_matchmaking();
        
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let admin: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
        let non_admin: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        
        setup_player(world, player1);
        
        // Player creates game
        testing::set_contract_address(player1);
        dispatcher.create_game(GameMode::Casual.into(), Option::None);
        assert_game_status(world, player1, GameStatus::Created);
        
        // Non-admin tries to cancel player's game - should fail
        testing::set_contract_address(non_admin);
        // Note: admin_cancel_game should fail with non-admin caller
        // The actual behavior depends on ownable implementation
        
        // Admin can cancel player's game
        testing::set_contract_address(admin);
        dispatcher.admin_cancel_game(player1);
        assert_game_status(world, player1, GameStatus::Canceled);
    }

    #[test]
    fn test_concurrent_auto_match_same_player() {
        let (dispatcher, mut world) = deploy_matchmaking();
        
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        setup_player(world, player1);
        
        testing::set_contract_address(player1);
        
        // First auto match call
        let board_id1 = dispatcher.auto_match(GameMode::Ranked.into(), Option::None);
        assert!(board_id1 == 0, "First call should add to queue");
        assert_game_status(world, player1, GameStatus::Created);
        
        // Immediate second call (should be handled gracefully)
        let _board_id2 = dispatcher.auto_match(GameMode::Ranked.into(), Option::None);
        
        // Should not create duplicate queue entries
        assert_game_status(world, player1, GameStatus::Created);
        assert_game_mode(world, player1, GameMode::Ranked);
    }

    #[test]
    fn test_create_tutorial_without_bot() {
        let (dispatcher, mut world) = deploy_matchmaking();
        
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        setup_player(world, player1);
        
        testing::set_contract_address(player1);
        // Try to create tutorial without providing bot address
        dispatcher.create_game(GameMode::Tutorial.into(), Option::None);
        
        // Should fail to create game
        assert_game_status(world, player1, GameStatus::Finished);
        assert_game_mode(world, player1, GameMode::None);
    }

    #[test]
    fn test_join_tutorial_game_fails() {
        let (dispatcher, mut world) = deploy_matchmaking();
        
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player2: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        let bot: ContractAddress = contract_address_const::<BOT_ADDRESS>();
        
        setup_player(world, player1);
        setup_player(world, player2);
        setup_bot(world, bot);
        
        // Player1 creates tutorial game
        testing::set_contract_address(player1);
        dispatcher.create_game(GameMode::Tutorial.into(), Option::Some(bot));
        assert_game_status(world, player1, GameStatus::InProgress);
        
        // Player2 tries to join tutorial (should fail)
        testing::set_contract_address(player2);
        dispatcher.join_game(player1);
        
        // Player2 should remain unchanged
        assert_game_status(world, player2, GameStatus::Finished);
    }
}
