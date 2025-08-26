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
        tournament_balance::{TournamentBalance, m_TournamentBalance}, player::{Player, m_Player},
        game::{GameModeConfig, m_GameModeConfig},
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
        }
    };

    use evolute_duel::types::packing::{GameMode};

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
                //Game
                TestResource::Model(m_GameModeConfig::TEST_CLASS_HASH.try_into().unwrap()),
                // Contracts
                TestResource::Contract(tournament_mock::TEST_CLASS_HASH),
                TestResource::Contract(tournament_token::TEST_CLASS_HASH),
                TestResource::Contract(evlt_topup::TEST_CLASS_HASH),
                TestResource::Contract(evlt_token::TEST_CLASS_HASH),
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
        ]
            .span()
    }

    fn deploy_tournament_system() -> (
        ITournamentMockDispatcher, 
        ITournamentTokenDispatcher,
        IEvltTokenDispatcher,
        IEvltTokenProtectedDispatcher,
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
        println!("[deploy_tournament_system] Contract addresses resolved - Tournament: {:?}, TournamentToken: {:?}, EvltToken: {:?}", tournament_address, tournament_token_address, evlt_token_address);

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

        (tournament_dispatcher, tournament_token_dispatcher, evlt_token_dispatcher, evlt_token_protected, world)
    }

    #[test]
    fn test_deploy_tournament_system() {
        println!("[test_deploy_tournament_system] Starting test");
        let (tournament_dispatcher, _, _, _, mut world) = deploy_tournament_system();
        println!("[test_deploy_tournament_system] Deployed tournament system successfully");
        println!("[test_deploy_tournament_system] Tournament address: {:?}", tournament_dispatcher.contract_address);
        println!("[test_deploy_tournament_system] Test completed");
    }
    #[test]
    fn test_create_tournament_with_evlt_entry_fee() {
        println!("[test_create_tournament_with_evlt_entry_fee] Starting test");
        let (tournament_dispatcher, tournament_token_dispatcher, evlt_token_dispatcher,
        evlt_protected, mut world) = deploy_tournament_system();
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
        evlt_protected.mint(player1_address, 1000); // Give player 1000 EVLT
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
            amount: 100, // 100 EVLT entry fee
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
        assert!(balance_before == 1000, "Player should have 1000 EVLT before entry");
        println!("[test_create_tournament_with_evlt_entry_fee] Player balance before entry: {}", balance_before);
        evlt_token_dispatcher.approve(tournament_address, 100); // Approve tournament to spend 100 EVLT
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
        assert!(balance_after == 900, "Player should have 900 EVLT after paying entry fee");
        println!("[test_create_tournament_with_evlt_entry_fee] Player balance after entry: {} (expected 900)", balance_after);

            // Check tournament entries increased
        println!("[test_create_tournament_with_evlt_entry_fee] Checking final tournament entries");
        let total_entries_after = tournament_dispatcher.tournament_entries(tournament.id);
        assert!(total_entries_after == 1, "Tournament should have 1 entry after registration");
        println!("[test_create_tournament_with_evlt_entry_fee] Final entries count: {}", total_entries_after);
        
        println!("[test_create_tournament_with_evlt_entry_fee] Test completed successfully");
    }
}
