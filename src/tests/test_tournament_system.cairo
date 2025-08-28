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

    // Tournament models
    use evolute_duel::models::{
        tournament::{
            TournamentPass, m_TournamentPass, TournamentStateModel, m_TournamentStateModel, PlayerTournamentIndex,
            m_PlayerTournamentIndex, TournamentState,
        },
        tournament_balance::{TournamentBalance, m_TournamentBalance}, player::{Player, m_Player, PlayerAssignment, m_PlayerAssignment},
        game::{
            GameModeConfig, m_GameModeConfig, Game, m_Game, Board, m_Board, MatchmakingState, 
            m_MatchmakingState, PlayerMatchmaking, m_PlayerMatchmaking, Rules, m_Rules, Move, m_Move,
            TileCommitments, m_TileCommitments, AvailableTiles, m_AvailableTiles, BoardCounter, m_BoardCounter
        },
        scoring::{UnionNode, m_UnionNode, PotentialContests, m_PotentialContests},
    };

    // Tournament systems
    use evolute_duel::systems::{
        tournament_budokan_test::{
            tournament_mock, ITournamentMock, ITournamentMockDispatcher, ITournamentMockDispatcherTrait,
            ITournamentMockInit, ITournamentMockInitDispatcher, ITournamentMockInitDispatcherTrait,
        },
        tokens::tournament_token::{
            tournament_token, ITournamentTokenDispatcher, ITournamentTokenDispatcherTrait,
        },
        tokens::evlt_token::{
            evlt_token, IEvltTokenDispatcher, IEvltTokenDispatcherTrait,
            IEvltTokenProtectedDispatcher, IEvltTokenProtectedDispatcherTrait,
        },
        evlt_topup::{
            evlt_topup, ITopUpDispatcher, ITopUpDispatcherTrait, ITopUpAdminDispatcher,
                ITopUpAdminDispatcherTrait,
        },
        matchmaking::{matchmaking, IMatchmaking, IMatchmakingDispatcher, IMatchmakingDispatcherTrait}
    };

    use evolute_duel::types::packing::{GameMode};
    
    // Events
    use evolute_duel::events::{
        GameCreated, e_GameCreated, GameStarted, e_GameStarted, GameCanceled, e_GameCanceled,
        BoardUpdated, e_BoardUpdated, GameCreateFailed, e_GameCreateFailed, GameJoinFailed,
        e_GameJoinFailed, GameCanceleFailed, e_GameCanceleFailed, PlayerNotInGame,
        e_PlayerNotInGame, GameFinished, e_GameFinished, ErrorEvent, e_ErrorEvent,
        MigrationError, e_MigrationError, NotYourTurn, e_NotYourTurn, NotEnoughJokers,
        e_NotEnoughJokers, Moved, e_Moved, Skiped, e_Skiped, InvalidMove, e_InvalidMove,
        PhaseStarted, e_PhaseStarted,
    };

    // Budokan models
    use tournaments::components::models::{
        tournament::{
            Tournament, m_Tournament, Registration, m_Registration, TokenType, Metadata, GameConfig,
            EntryFee, EntryRequirement, Leaderboard, m_Leaderboard, PlatformMetrics, m_PlatformMetrics, 
            TournamentTokenMetrics, m_TournamentTokenMetrics, PrizeMetrics, m_PrizeMetrics, 
            EntryCount, m_EntryCount, Prize, m_Prize, Token, m_Token, TournamentConfig, m_TournamentConfig, 
            PrizeClaim, m_PrizeClaim, QualificationEntries, m_QualificationEntries,
        },
        game::{
            TokenMetadata, m_TokenMetadata, GameMetadata, m_GameMetadata, GameCounter,
            m_GameCounter, Score, m_Score, Settings, m_Settings, SettingsDetails, m_SettingsDetails, 
            SettingsCounter, m_SettingsCounter,
        },
        schedule::{Schedule, Period},
    };

    // Test constants
    const ADMIN_ADDRESS: felt252 = 0x111;
    const PLAYER1_ADDRESS: felt252 = 0x123;
    const PLAYER2_ADDRESS: felt252 = 0x456;

    // EVLT token constants (18 decimals)
    const ONE_EVLT: u256 = 1000000000000000000; // 1 * 10^18
    const HUNDRED_EVLT: u256 = 100000000000000000000; // 100 * 10^18  
    const THOUSAND_EVLT: u256 = 1000000000000000000000; // 1000 * 10^18
    const NINE_HUNDRED_EVLT: u256 = 900000000000000000000; // 900 * 10^18 (1000 - 100)
    const EIGHT_NINETY_NINE_EVLT: u256 = 899000000000000000000; // 899 * 10^18 (900 - 1)
    
    // For EntryFee (u128 type)
    const HUNDRED_EVLT_U128: u128 = 100000000000000000000; // 100 * 10^18 as u128

    fn namespace_def() -> NamespaceDef {
        let ndef = NamespaceDef {
            namespace: "evolute_duel",
            resources: [
                // Tournament models
                TestResource::Model(m_TournamentPass::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_TournamentStateModel::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_PlayerTournamentIndex::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_TournamentBalance::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_Player::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_PlayerAssignment::TEST_CLASS_HASH.try_into().unwrap()),
                //Budokan models
                TestResource::Model(m_Tournament::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_Registration::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_TokenMetadata::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_GameMetadata::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_GameCounter::TEST_CLASS_HASH.try_into().unwrap()),
                // Additional tournament models
                TestResource::Model(m_Score::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_Settings::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_SettingsDetails::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_SettingsCounter::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_Leaderboard::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_PlatformMetrics::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_TournamentTokenMetrics::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_PrizeMetrics::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_EntryCount::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_Prize::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_Token::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_TournamentConfig::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_PrizeClaim::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_QualificationEntries::TEST_CLASS_HASH.try_into().unwrap()),
                //Game models
                TestResource::Model(m_GameModeConfig::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_Game::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_Board::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_MatchmakingState::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_PlayerMatchmaking::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_Rules::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_Move::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_TileCommitments::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_AvailableTiles::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_BoardCounter::TEST_CLASS_HASH.try_into().unwrap()),
                // Scoring models
                TestResource::Model(m_UnionNode::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_PotentialContests::TEST_CLASS_HASH.try_into().unwrap()),
                // Contracts
                TestResource::Contract(tournament_mock::TEST_CLASS_HASH),
                TestResource::Contract(tournament_token::TEST_CLASS_HASH),
                TestResource::Contract(evlt_topup::TEST_CLASS_HASH),
                TestResource::Contract(evlt_token::TEST_CLASS_HASH),
                TestResource::Contract(matchmaking::TEST_CLASS_HASH),
                //Events
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
            ContractDefTrait::new(@"evolute_duel", @"tournament_mock")
                .with_writer_of([dojo::utils::bytearray_hash(@"evolute_duel")].span()),
            ContractDefTrait::new(@"evolute_duel", @"tournament_token")
                .with_writer_of([dojo::utils::bytearray_hash(@"evolute_duel")].span())
                .with_init_calldata([0].span()), // base_uri as felt252
            ContractDefTrait::new(@"evolute_duel", @"evlt_topup")
                .with_writer_of([dojo::utils::bytearray_hash(@"evolute_duel")].span())
                .with_init_calldata([ADMIN_ADDRESS].span()),
            ContractDefTrait::new(@"evolute_duel", @"evlt_token")
                .with_writer_of([dojo::utils::bytearray_hash(@"evolute_duel")].span())
                .with_init_calldata([ADMIN_ADDRESS].span()),
            ContractDefTrait::new(@"evolute_duel", @"matchmaking")
                .with_writer_of([dojo::utils::bytearray_hash(@"evolute_duel")].span())
                .with_init_calldata([ADMIN_ADDRESS].span()),
        ]
            .span()
    }

    fn deploy_tournament_system() -> (
        ITournamentMockDispatcher, 
        ITournamentTokenDispatcher,
        IEvltTokenDispatcher,
        IEvltTokenProtectedDispatcher,
        IMatchmakingDispatcher,
        WorldStorage
    ) {
        println!("[deploy_tournament_system] Starting deployment");
        let mut world = spawn_test_world([namespace_def()].span());
        println!("[deploy_tournament_system] Test world spawned");
        world.sync_perms_and_inits(contract_defs());
        println!("[deploy_tournament_system] Permissions and initializations synced");

        let (tournament_address, _) = world.dns(@"tournament_mock").unwrap();
        let (tournament_token_address, _) = world.dns(@"tournament_token").unwrap();
        let (evlt_token_address, _) = world.dns(@"evlt_token").unwrap();
        let (matchmaking_address, _) = world.dns(@"matchmaking").unwrap();
        println!("[deploy_tournament_system] Contract addresses resolved - Tournament: {:?}, TournamentToken: {:?}, EvltToken: {:?}, Matchmaking: {:?}", tournament_address, tournament_token_address, evlt_token_address, matchmaking_address);

        let tournament_dispatcher = ITournamentMockDispatcher { contract_address: tournament_address };
        let tournament_initializer_dispatcher = ITournamentMockInitDispatcher { contract_address: tournament_address };
        println!("[deploy_tournament_system] Initializing tournament system");
        tournament_initializer_dispatcher.initializer(false, true, evlt_token_address, tournament_token_address);
        println!("[deploy_tournament_system] Tournament system initialized");

        let tournament_token_dispatcher = ITournamentTokenDispatcher { contract_address:
        tournament_token_address };
        let evlt_token_dispatcher = IEvltTokenDispatcher { contract_address: evlt_token_address
        };
        let evlt_token_protected = IEvltTokenProtectedDispatcher { contract_address:
        evlt_token_address };
        let matchmaking_dispatcher = IMatchmakingDispatcher { contract_address: matchmaking_address };
        println!("[deploy_tournament_system] All dispatchers created successfully");

        // Standard deck configuration
        let deck: Span<u8> = array![
            2, // CCCC
            0, // FFFF
            0, // RRRR - not in the deck
            4, // CCCF
            3, // CCCR
            6, // CCRR
            4, // CFFF
            0, // FFFR - not in the deck
            0, // CRRR - not in the deck
            4, // FRRR
            7, // CCFF 
            6, // CFCF
            0, // CRCR - not in the deck
            9, // FFRR
            8, // FRFR
            0, // CCFR - not in the deck
            0, // CCRF - not in the deck
            0, // CFCR - not in the deck
            0, // CFFR - not in the deck
            0, // CFRF - not in the deck
            0, // CRFF - not in the deck
            3, // CRRF
            4, // CRFR
            4 // CFRR
        ]
            .span();

        let edges = (1_u8, 1_u8);
        let joker_price = 5_u16;
        
        // Tournament configuration
        let tournament_config = GameModeConfig {
            game_mode: GameMode::Tournament,
            board_size: 10,
            deck_type: 1, // Full randomized deck
            initial_jokers: 2,
            time_per_phase: 60, // 1 minute per phase
            auto_match: true, // Enable automatic matchmaking for tournaments
            deck,
            edges,
            joker_price,
        };
        world.write_model_test(@tournament_config);

        (tournament_dispatcher, tournament_token_dispatcher, evlt_token_dispatcher, evlt_token_protected, matchmaking_dispatcher, world)
    }

    #[test]
    fn test_deploy_tournament_system() {
        println!("[test_deploy_tournament_system] Starting test");
        let (tournament_dispatcher, _, _, _, _, mut world) = deploy_tournament_system();
        println!("[test_deploy_tournament_system] Deployed tournament system successfully");
        println!("[test_deploy_tournament_system] Tournament address: {:?}", tournament_dispatcher.contract_address);
        println!("[test_deploy_tournament_system] Test completed");
    }
    #[test]
    fn test_create_tournament_with_evlt_entry_fee() {
        println!("[test_create_tournament_with_evlt_entry_fee] Starting test");
        let (tournament_dispatcher, tournament_token_dispatcher, evlt_token_dispatcher,
        evlt_protected, matchmaking_dispatcher, mut world) = deploy_tournament_system();
        println!("[test_create_tournament_with_evlt_entry_fee] System deployed successfully");
        
        let admin_address: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
        let player1_address: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let tournament_token_address = tournament_token_dispatcher.contract_address;
        let evlt_token_address = evlt_token_dispatcher.contract_address;
        let tournament_address = tournament_dispatcher.contract_address;
        println!("[test_create_tournament_with_evlt_entry_fee] Addresses set - Admin: {:?}, Player1: {:?}", admin_address, player1_address);

            // Setup admin as contract caller
        println!("[test_create_tournament_with_evlt_entry_fee] Setting up admin permissions");
        testing::set_contract_address(admin_address);
        evlt_protected.set_minter(admin_address); // Allow admin to mint EVLT
        println!("[test_create_tournament_with_evlt_entry_fee] Admin set as minter");

            // Mint EVLT tokens to player1
        println!("[test_create_tournament_with_evlt_entry_fee] Minting 1000 EVLT tokens to player1");
        evlt_protected.mint(player1_address, THOUSAND_EVLT); // Give player 1000 EVLT with decimals
        println!("[test_create_tournament_with_evlt_entry_fee] EVLT tokens minted successfully");

            // Allow budokan tournament to transfer EVLT tokens
        println!("[test_create_tournament_with_evlt_entry_fee] Allowing tournament to transfer EVLT tokens");
        evlt_protected.set_transfer_allowed(tournament_address);
        println!("[test_create_tournament_with_evlt_entry_fee] Transfer permissions set");

            // Create tournament metadata
        println!("[test_create_tournament_with_evlt_entry_fee] Creating tournament metadata");
        let metadata = Metadata {
            name: 'EVLT Tournament',
            description: "Tournament with EVLT token entry fee",
        };
        println!("[test_create_tournament_with_evlt_entry_fee] Metadata created - Name: {:?}", metadata.name);

            // Create tournament schedule
        println!("[test_create_tournament_with_evlt_entry_fee] Creating tournament schedule");
        let current_time = starknet::get_block_timestamp();
        let schedule = Schedule {
            registration: Option::Some(Period {
                start: current_time,
                end: current_time + 3600, // 1 hour registration
            }),
            game: Period {
                start: current_time + 3600,
                end: current_time + 7200, // 1 hours game period
            },
            submission_duration: 1000, // 5 minutes for score submission
        };
        println!("[test_create_tournament_with_evlt_entry_fee] Schedule created - Current time: {}, Registration end: {}", current_time, current_time + 3600);

            // Create game configuration
        println!("[test_create_tournament_with_evlt_entry_fee] Creating game configuration");
        let game_config = GameConfig {
            address: tournament_token_address,
            settings_id: 1,
            prize_spots: 3,
        };
        println!("[test_create_tournament_with_evlt_entry_fee] Game config created - Prize spots: {}, Settings ID: {}", game_config.prize_spots, game_config.settings_id);

            // Entry fee configuration with EVLT tokens
        println!("[test_create_tournament_with_evlt_entry_fee] Creating entry fee configuration");
        let entry_fee = EntryFee {
            token_address: evlt_token_address,
            amount: HUNDRED_EVLT_U128, // 100 EVLT entry fee with decimals
            distribution: [50, 20, 10].span(), // 1st: 50%, 2nd: 30%, 3rd: 20%
            tournament_creator_share: Option::Some(10),
            game_creator_share: Option::Some(10),
        };
        println!("[test_create_tournament_with_evlt_entry_fee] Entry fee configured - Amount: {}, Token: {:?}", entry_fee.amount, entry_fee.token_address);

            // Create tournament with EVLT entry fee
        println!("[test_create_tournament_with_evlt_entry_fee] Creating tournament with EVLT entry fee");
        let tournament = tournament_dispatcher.create_tournament(
            admin_address,
            metadata,
            schedule,
            game_config,
            Option::Some(entry_fee),
            Option::None  // No entry requirement
        );
        println!("[test_create_tournament_with_evlt_entry_fee] Tournament created successfully - ID: {}", tournament.id);

            // Verify tournament was created successfully
        println!("[test_create_tournament_with_evlt_entry_fee] Verifying tournament creation");
        assert!(tournament.id > 0, "Tournament should have valid ID");
        assert!(tournament.created_by == admin_address, "Creator should match admin address");
        println!("[test_create_tournament_with_evlt_entry_fee] Basic tournament assertions passed");

            // Check that tournament exists in the system
        println!("[test_create_tournament_with_evlt_entry_fee] Fetching tournament from system");
        let fetched_tournament = tournament_dispatcher.tournament(tournament.id);
        assert!(fetched_tournament.id == tournament.id, "Tournament ID should match");
        assert!(fetched_tournament.metadata.name == 'EVLT Tournament', "Tournament name should
        match");
        println!("[test_create_tournament_with_evlt_entry_fee] Tournament fetched and verified successfully");

            // Verify initial state
        println!("[test_create_tournament_with_evlt_entry_fee] Checking initial tournament state");
        let total_entries = tournament_dispatcher.tournament_entries(tournament.id);
        assert!(total_entries == 0, "Tournament should start with 0 entries");
        println!("[test_create_tournament_with_evlt_entry_fee] Initial entries verified - Count: {}", total_entries);

            // Test player entry with EVLT payment
        println!("[test_create_tournament_with_evlt_entry_fee] Testing player entry with EVLT payment");
        testing::set_contract_address(player1_address);
        println!("[test_create_tournament_with_evlt_entry_fee] Contract address set to player1");

            // Check player's balance before entry
        println!("[test_create_tournament_with_evlt_entry_fee] Checking player balance before entry");
        let balance_before = evlt_token_dispatcher.balance_of(player1_address);
        assert!(balance_before == THOUSAND_EVLT, "Player should have 1000 EVLT before entry");
        println!("[test_create_tournament_with_evlt_entry_fee] Player balance before entry: {}", balance_before);
        evlt_token_dispatcher.approve(tournament_address, HUNDRED_EVLT); // Approve tournament to spend 100 EVLT
        // Player enters tournament (should pay entry fee)
        println!("[test_create_tournament_with_evlt_entry_fee] Player entering tournament");
        let (token_id, entry_number) = tournament_dispatcher.enter_tournament(
            tournament.id,
            'player1',
            player1_address,
            Option::None
        );
        println!("[test_create_tournament_with_evlt_entry_fee] Player entered successfully - Token ID: {}, Entry number: {}", token_id, entry_number);

            // Verify entry was successful
        println!("[test_create_tournament_with_evlt_entry_fee] Verifying entry success");
        assert!(token_id > 0, "Token ID should be valid");
        assert!(entry_number == 1, "First entry should have number 1");
        println!("[test_create_tournament_with_evlt_entry_fee] Entry verification passed");

            // Check that entry fee was deducted
        println!("[test_create_tournament_with_evlt_entry_fee] Checking balance after entry");
        let balance_after = evlt_token_dispatcher.balance_of(player1_address);
        assert!(balance_after == NINE_HUNDRED_EVLT, "Player should have 900 EVLT after paying entry fee");
        println!("[test_create_tournament_with_evlt_entry_fee] Player balance after entry: {} (expected 900 EVLT with decimals)", balance_after);

            // Check tournament entries increased
        println!("[test_create_tournament_with_evlt_entry_fee] Checking final tournament entries");
        let total_entries_after = tournament_dispatcher.tournament_entries(tournament.id);
        assert!(total_entries_after == 1, "Tournament should have 1 entry after registration");
        println!("[test_create_tournament_with_evlt_entry_fee] Final entries count: {}", total_entries_after);
        
        println!("[test_create_tournament_with_evlt_entry_fee] Test completed successfully");
    }

    #[test]
    fn test_two_players_tournament_with_enlist_and_join_duel() {
        println!("[test_two_players_tournament_with_enlist_and_join_duel] Starting comprehensive test");
        let (tournament_dispatcher, tournament_token_dispatcher, evlt_token_dispatcher,
        evlt_protected, _matchmaking_dispatcher, mut world) = deploy_tournament_system();
        println!("[test_two_players_tournament_with_enlist_and_join_duel] System deployed successfully");

        let admin_address: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
        let player1_address: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player2_address: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        let tournament_token_address = tournament_token_dispatcher.contract_address;
        let evlt_token_address = evlt_token_dispatcher.contract_address;
        let tournament_address = tournament_dispatcher.contract_address;
        println!("[test_two_players_tournament_with_enlist_and_join_duel] Addresses set - Admin: {:?}, Player1: {:?}, Player2: {:?}", admin_address, player1_address, player2_address);

        // === SETUP PHASE ===
        println!("[test_two_players_tournament_with_enlist_and_join_duel] === SETUP PHASE ===");
        testing::set_contract_address(admin_address);
        evlt_protected.set_minter(admin_address);
        println!("[test_two_players_tournament_with_enlist_and_join_duel] Admin set as minter");

        // Mint EVLT tokens to both players
        println!("[test_two_players_tournament_with_enlist_and_join_duel] Minting 1000 EVLT tokens to each player");
        evlt_protected.mint(player1_address, THOUSAND_EVLT);
        evlt_protected.mint(player2_address, THOUSAND_EVLT);
        println!("[test_two_players_tournament_with_enlist_and_join_duel] EVLT tokens minted successfully");

        // Allow tournament to transfer EVLT tokens
        println!("[test_two_players_tournament_with_enlist_and_join_duel] Setting transfer permissions");
        evlt_protected.set_transfer_allowed(tournament_address);
        println!("[test_two_players_tournament_with_enlist_and_join_duel] Transfer permissions set");

        // === TOURNAMENT CREATION ===
        println!("[test_two_players_tournament_with_enlist_and_join_duel] === TOURNAMENT CREATION ===");
        let metadata = Metadata {
            name: 'Two Player Duel Tournament',
            description: "Tournament for testing enlist and join_duel flow",
        };
        
        let current_time = starknet::get_block_timestamp();
        let schedule = Schedule {
            registration: Option::Some(Period {
                start: current_time,
                end: current_time + 3600, // 1 hour registration
            }),
            game: Period {
                start: current_time + 3600,
                end: current_time + 7200, // 1 hour game period
            },
            submission_duration: 1000, // submission time
        };

        let game_config = GameConfig {
            address: tournament_token_address,
            settings_id: 1,
            prize_spots: 2, // Top 2 players get prizes
        };

        let entry_fee = EntryFee {
            token_address: evlt_token_address,
            amount: HUNDRED_EVLT_U128,
            distribution: [50, 30].span(), // 1st: 50%, 2nd: 30%
            tournament_creator_share: Option::Some(10),
            game_creator_share: Option::Some(10),
        };

        println!("[test_two_players_tournament_with_enlist_and_join_duel] Creating tournament");
        let tournament = tournament_dispatcher.create_tournament(
            admin_address,
            metadata,
            schedule,
            game_config,
            Option::Some(entry_fee),
            Option::None
        );
        println!("[test_two_players_tournament_with_enlist_and_join_duel] Tournament created successfully - ID: {}", tournament.id);

        // === PLAYER 1 ENTRY ===
        println!("[test_two_players_tournament_with_enlist_and_join_duel] === PLAYER 1 ENTRY ===");
        testing::set_contract_address(player1_address);
        
        let balance_before_p1 = evlt_token_dispatcher.balance_of(player1_address);
        println!("[test_two_players_tournament_with_enlist_and_join_duel] Player1 balance before entry: {}", balance_before_p1);
        
        evlt_token_dispatcher.approve(tournament_address, HUNDRED_EVLT);
        let (token_id_p1, entry_number_p1) = tournament_dispatcher.enter_tournament(
            tournament.id,
            'player1',
            player1_address,
            Option::None
        );
        println!("[test_two_players_tournament_with_enlist_and_join_duel] Player1 entered - Token ID: {}, Entry: {}", token_id_p1, entry_number_p1);

        // === PLAYER 2 ENTRY ===
        println!("[test_two_players_tournament_with_enlist_and_join_duel] === PLAYER 2 ENTRY ===");
        testing::set_contract_address(player2_address);
        
        let balance_before_p2 = evlt_token_dispatcher.balance_of(player2_address);
        println!("[test_two_players_tournament_with_enlist_and_join_duel] Player2 balance before entry: {}", balance_before_p2);
        
        evlt_token_dispatcher.approve(tournament_address, HUNDRED_EVLT);
        let (token_id_p2, entry_number_p2) = tournament_dispatcher.enter_tournament(
            tournament.id,
            'player2',
            player2_address,
            Option::None
        );
        println!("[test_two_players_tournament_with_enlist_and_join_duel] Player2 entered - Token ID: {}, Entry: {}", token_id_p2, entry_number_p2);

        // Verify tournament entries
        let total_entries = tournament_dispatcher.tournament_entries(tournament.id);
        assert!(total_entries == 2, "Tournament should have 2 entries");
        println!("[test_two_players_tournament_with_enlist_and_join_duel] Tournament entries verified: {}", total_entries);

        // === ENLIST PHASE ===
        println!("[test_two_players_tournament_with_enlist_and_join_duel] === ENLIST PHASE ===");
        
        // Player 1 enlists in tournament token system
        println!("[test_two_players_tournament_with_enlist_and_join_duel] Player1 enlisting in tournament token system");
        testing::set_contract_address(player1_address);
        
        let can_enlist_p1 = tournament_token_dispatcher.can_enlist_duelist(token_id_p1);
        println!("[test_two_players_tournament_with_enlist_and_join_duel] Player1 can enlist: {}", can_enlist_p1);
        assert!(can_enlist_p1, "Player1 should be able to enlist");
        
        tournament_token_dispatcher.enlist_duelist(token_id_p1);
        println!("[test_two_players_tournament_with_enlist_and_join_duel] Player1 enlisted successfully with pass ID: {}", token_id_p1);

        // Player 2 enlists in tournament token system  
        println!("[test_two_players_tournament_with_enlist_and_join_duel] Player2 enlisting in tournament token system");
        testing::set_contract_address(player2_address);
        
        let can_enlist_p2 = tournament_token_dispatcher.can_enlist_duelist(token_id_p2);
        println!("[test_two_players_tournament_with_enlist_and_join_duel] Player2 can enlist: {}", can_enlist_p2);
        assert!(can_enlist_p2, "Player2 should be able to enlist");
        
        tournament_token_dispatcher.enlist_duelist(token_id_p2);
        println!("[test_two_players_tournament_with_enlist_and_join_duel] Player2 enlisted successfully with pass ID: {}", token_id_p2);

        // === TIME ADVANCE TO GAME PHASE ===
        println!("[test_two_players_tournament_with_enlist_and_join_duel] === TIME ADVANCE TO GAME PHASE ===");
        let game_start_time = current_time + 3600; // Registration end time / Game start time
        println!("[test_two_players_tournament_with_enlist_and_join_duel] Advancing time to game phase - current: {}, target: {}", current_time, game_start_time);
        
        // Set block time to after registration phase (when game phase starts)
        testing::set_block_timestamp(game_start_time + 100); // Add 100 seconds buffer into game phase
        let new_time = starknet::get_block_timestamp();
        println!("[test_two_players_tournament_with_enlist_and_join_duel] Time advanced successfully - new time: {}", new_time);
        
        // Verify we're now in the game phase
        assert!(new_time > game_start_time, "Time should be in game phase");
        println!("[test_two_players_tournament_with_enlist_and_join_duel] Confirmed: We are now in the game phase");
        
        // === TOURNAMENT START PHASE ===
        println!("[test_two_players_tournament_with_enlist_and_join_duel] === TOURNAMENT START PHASE ===");
        
        // Check if tournament can be started
        testing::set_contract_address(player1_address);
        let can_start_p1 = tournament_token_dispatcher.can_start_tournament(token_id_p1);
        println!("[test_two_players_tournament_with_enlist_and_join_duel] Player1 can start tournament: {}", can_start_p1);
        
        if can_start_p1 {
            println!("[test_two_players_tournament_with_enlist_and_join_duel] Player1 starting tournament");
            let started_tournament_id = tournament_token_dispatcher.start_tournament(token_id_p1);
            println!("[test_two_players_tournament_with_enlist_and_join_duel] Tournament started successfully - ID: {}", started_tournament_id);
        } else {
            println!("[test_two_players_tournament_with_enlist_and_join_duel] Player1 cannot start tournament - checking Player2");
            testing::set_contract_address(player2_address);
            let can_start_p2 = tournament_token_dispatcher.can_start_tournament(token_id_p2);
            println!("[test_two_players_tournament_with_enlist_and_join_duel] Player2 can start tournament: {}", can_start_p2);
            
            if can_start_p2 {
                println!("[test_two_players_tournament_with_enlist_and_join_duel] Player2 starting tournament");
                let started_tournament_id = tournament_token_dispatcher.start_tournament(token_id_p2);
                println!("[test_two_players_tournament_with_enlist_and_join_duel] Tournament started successfully by Player2 - ID: {}", started_tournament_id);
            } else {
                println!("[test_two_players_tournament_with_enlist_and_join_duel] Neither player can start tournament - proceeding anyway");
            }
        }

        // === JOIN DUEL PHASE ===
        println!("[test_two_players_tournament_with_enlist_and_join_duel] === JOIN DUEL PHASE ===");
        
        // Check if players can join duel
        println!("[test_two_players_tournament_with_enlist_and_join_duel] Checking if players can join duels");
        testing::set_contract_address(player1_address);
        let can_join_duel_p1 = tournament_token_dispatcher.can_join_duel(token_id_p1);
        println!("[test_two_players_tournament_with_enlist_and_join_duel] Player1 can join duel: {}", can_join_duel_p1);
        
        if !can_join_duel_p1 {
            println!("[test_two_players_tournament_with_enlist_and_join_duel] WARNING: Player1 cannot join duel! Debugging...");
            // Add additional debugging here if needed
        }
        
        testing::set_contract_address(player2_address);
        let can_join_duel_p2 = tournament_token_dispatcher.can_join_duel(token_id_p2);
        println!("[test_two_players_tournament_with_enlist_and_join_duel] Player2 can join duel: {}", can_join_duel_p2);
        
        if !can_join_duel_p2 {
            println!("[test_two_players_tournament_with_enlist_and_join_duel] WARNING: Player2 cannot join duel! Debugging...");
            // Add additional debugging here if needed
        }

        // Player 1 joins duel (enters matchmaking queue)
        println!("[test_two_players_tournament_with_enlist_and_join_duel] Player1 joining duel - attempting join_duel");
        testing::set_contract_address(player1_address);
        
        if can_join_duel_p1 {
            // Player1 needs to approve 1 EVLT to tournament_token before join_duel
            println!("[test_two_players_tournament_with_enlist_and_join_duel] Player1 approving 1 EVLT to tournament_token");
            evlt_token_dispatcher.approve(tournament_token_address, ONE_EVLT);
            
            let board_id_p1 = tournament_token_dispatcher.join_duel(token_id_p1);
            println!("[test_two_players_tournament_with_enlist_and_join_duel] Player1 join_duel SUCCESS - Board ID: {} (0 means waiting in queue)", board_id_p1);
        } else {
            println!("[test_two_players_tournament_with_enlist_and_join_duel] Player1 CANNOT join duel - skipping join_duel call");
        }

        // Player 2 joins duel (should match with Player 1)
        println!("[test_two_players_tournament_with_enlist_and_join_duel] Player2 joining duel - attempting join_duel");
        testing::set_contract_address(player2_address);
        
        let board_id_p2 = if can_join_duel_p2 {
            // Player2 needs to approve 1 EVLT to tournament_token before join_duel
            println!("[test_two_players_tournament_with_enlist_and_join_duel] Player2 approving 1 EVLT to tournament_token");
            evlt_token_dispatcher.approve(tournament_token_address, ONE_EVLT);
            
            let board_id = tournament_token_dispatcher.join_duel(token_id_p2);
            println!("[test_two_players_tournament_with_enlist_and_join_duel] Player2 join_duel SUCCESS - Board ID: {} (should be > 0 if matched)", board_id);
            board_id
        } else {
            println!("[test_two_players_tournament_with_enlist_and_join_duel] Player2 CANNOT join duel - skipping join_duel call");
            0
        };

        // === VERIFICATION PHASE ===
        println!("[test_two_players_tournament_with_enlist_and_join_duel] === VERIFICATION PHASE ===");
        
        // Verify match was created
        if board_id_p2 != 0 {
            println!("[test_two_players_tournament_with_enlist_and_join_duel] MATCH FOUND! Players matched with board ID: {}", board_id_p2);
            
            // Verify both players have same board ID in their game state
            let game_p1: Game = world.read_model(player1_address);
            let game_p2: Game = world.read_model(player2_address);
            
            println!("[test_two_players_tournament_with_enlist_and_join_duel] Player1 game state - Status: {:?}, Board ID: {:?}", game_p1.status, game_p1.board_id);
            println!("[test_two_players_tournament_with_enlist_and_join_duel] Player2 game state - Status: {:?}, Board ID: {:?}", game_p2.status, game_p2.board_id);
            
            assert!(game_p1.board_id.is_some(), "Player1 should have board ID");
            assert!(game_p2.board_id.is_some(), "Player2 should have board ID");
            assert!(game_p1.board_id == game_p2.board_id, "Both players should have same board ID");
            
            // Read board details
            let board: Board = world.read_model(board_id_p2);
            let (player1_addr, _, _) = board.player1;
            let (player2_addr, _, _) = board.player2;
            println!("[test_two_players_tournament_with_enlist_and_join_duel] Board details - Player1: {:?}, Player2: {:?}, Game State: {:?}", player1_addr, player2_addr, board.game_state);
            
        } else {
            println!("[test_two_players_tournament_with_enlist_and_join_duel] No match found - both players in queue");
        }

        // Verify tournament token ownership
        let owner_p1 = tournament_token_dispatcher.owner_of(token_id_p1.into());
        let owner_p2 = tournament_token_dispatcher.owner_of(token_id_p2.into());
        assert!(owner_p1 == player1_address, "Player1 should own their token");
        assert!(owner_p2 == player2_address, "Player2 should own their token");
        println!("[test_two_players_tournament_with_enlist_and_join_duel] Token ownership verified - P1 owns token {}, P2 owns token {}", token_id_p1, token_id_p2);

        // Verify balances were deducted correctly
        let balance_after_p1 = evlt_token_dispatcher.balance_of(player1_address);
        let balance_after_p2 = evlt_token_dispatcher.balance_of(player2_address);
        println!("[test_two_players_tournament_with_enlist_and_join_duel] Balances after entry - P1: {}, P2: {}", balance_after_p1, balance_after_p2);
        assert!(balance_after_p1 == EIGHT_NINETY_NINE_EVLT, "Player1 should have 899 EVLT after entry and join_duel");
        assert!(balance_after_p2 == EIGHT_NINETY_NINE_EVLT, "Player2 should have 899 EVLT after entry and join_duel");
        println!("[test_two_players_tournament_with_enlist_and_join_duel] Entry fee deductions verified - P1: {}, P2: {}", balance_after_p1, balance_after_p2);

        // Verify entry numbers
        assert!(entry_number_p1 == 1, "Player1 should be entry #1");
        assert!(entry_number_p2 == 2, "Player2 should be entry #2");
        println!("[test_two_players_tournament_with_enlist_and_join_duel] Entry numbers verified");

        println!("[test_two_players_tournament_with_enlist_and_join_duel] ALL TESTS PASSED! Comprehensive test completed successfully");
        println!("[test_two_players_tournament_with_enlist_and_join_duel] Summary:");
        println!("[test_two_players_tournament_with_enlist_and_join_duel] - Tournament created with ID {}", tournament.id);
        println!("[test_two_players_tournament_with_enlist_and_join_duel] - Both players entered tournament and paid entry fees");
        println!("[test_two_players_tournament_with_enlist_and_join_duel] - Both players enlisted in tournament token system");
        println!("[test_two_players_tournament_with_enlist_and_join_duel] - Both players joined duels through proper tournament_token flow");
        if board_id_p2 != 0 {
            println!("[test_two_players_tournament_with_enlist_and_join_duel] - Players successfully matched via tournament token auto-matchmaking");
        }
        println!("[test_two_players_tournament_with_enlist_and_join_duel] - All verifications passed");
    }
}
