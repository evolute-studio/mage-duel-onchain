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
            TournamentPass, m_TournamentPass,
            Tournament, m_Tournament,
            TournamentSettings, m_TournamentSettings,
            PlayerTournamentIndex, m_PlayerTournamentIndex,
            TournamentState, TournamentType
        },
        tournament_balance::{TournamentBalance, m_TournamentBalance},
        player::{Player, m_Player},
    };

    // Tournament systems  
    use evolute_duel::systems::{
        tournament_mock::{
            tournament_mock, ITournamentMock as ITournament, ITournamentMockDispatcher as ITournamentDispatcher, ITournamentMockDispatcherTrait as ITournamentDispatcherTrait
        },
        tokens::tournament_token::{
            tournament_token, ITournamentTokenDispatcher, ITournamentTokenDispatcherTrait
        },
        tokens::evlt_token::{
            evlt_token, IEvltTokenDispatcher, IEvltTokenDispatcherTrait,
            IEvltTokenProtectedDispatcher, IEvltTokenProtectedDispatcherTrait
        },
    };

    // Budokan models
    use tournaments::components::models::{
        tournament::{
            Tournament as BudokanTournament, m_Tournament as m_BudokanTournament,
            Registration, m_Registration, TokenType, Metadata, GameConfig,
            EntryFee, EntryRequirement,
        },
        game::{
            TokenMetadata, m_TokenMetadata, 
            GameMetadata, m_GameMetadata,
            GameCounter, m_GameCounter,
        },
        schedule::{Schedule, Period},
    };

    // Test constants
    const ADMIN_ADDRESS: felt252 = 0x111;
    const PLAYER1_ADDRESS: felt252 = 0x123;
    const PLAYER2_ADDRESS: felt252 = 0x456;
    const PLAYER3_ADDRESS: felt252 = 0x789;
    const PASS_ID_1: u64 = 1;
    const PASS_ID_2: u64 = 2;
    const PASS_ID_3: u64 = 3;

    fn namespace_def() -> NamespaceDef {
        let ndef = NamespaceDef {
            namespace: "evolute_duel",
            resources: [
                // Tournament models
                TestResource::Model(m_TournamentPass::TEST_CLASS_HASH),
                TestResource::Model(m_Tournament::TEST_CLASS_HASH),
                TestResource::Model(m_TournamentSettings::TEST_CLASS_HASH),
                TestResource::Model(m_PlayerTournamentIndex::TEST_CLASS_HASH),
                TestResource::Model(m_TournamentBalance::TEST_CLASS_HASH),
                TestResource::Model(m_Player::TEST_CLASS_HASH),
                //Budokan models
                TestResource::Model(m_BudokanTournament::TEST_CLASS_HASH),
                TestResource::Model(m_Registration::TEST_CLASS_HASH),
                TestResource::Model(m_TokenMetadata::TEST_CLASS_HASH),
                TestResource::Model(m_GameMetadata::TEST_CLASS_HASH),
                TestResource::Model(m_GameCounter::TEST_CLASS_HASH),
                // Contracts
                TestResource::Contract(tournament_mock::TEST_CLASS_HASH),
                TestResource::Contract(tournament_token::TEST_CLASS_HASH),
                TestResource::Contract(evlt_token::TEST_CLASS_HASH),
            ].span()
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
            ContractDefTrait::new(@"evolute_duel", @"evlt_token")
                .with_writer_of([dojo::utils::bytearray_hash(@"evolute_duel")].span())
                .with_init_calldata([ADMIN_ADDRESS].span()),
        ].span()
    }

    fn deploy_tournament_system() -> (
        ITournamentDispatcher,
        ITournamentTokenDispatcher, 
        IEvltTokenDispatcher,
        IEvltTokenProtectedDispatcher,
        WorldStorage
    ) {
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());
        
        let (budokan_address, _) = world.dns(@"tournament_mock").unwrap();
        let (tournament_token_address, _) = world.dns(@"tournament_token").unwrap();
        let (evlt_token_address, _) = world.dns(@"evlt_token").unwrap();
        
        let budokan_dispatcher = ITournamentDispatcher { contract_address: budokan_address };
        let tournament_token_dispatcher = ITournamentTokenDispatcher { contract_address: tournament_token_address };
        let evlt_token_dispatcher = IEvltTokenDispatcher { contract_address: evlt_token_address };
        let evlt_token_protected = IEvltTokenProtectedDispatcher { contract_address: evlt_token_address };
        
        (budokan_dispatcher, tournament_token_dispatcher, evlt_token_dispatcher, evlt_token_protected, world)
    }

    fn setup_player(mut world: WorldStorage, player_address: ContractAddress, balance: u32) {
        let player = Player {
            player_id: player_address,
            username: 'TestPlayer',
            balance,
            games_played: 0,
            active_skin: 0,
            role: 1,
            tutorial_completed: true,
            migration_target: Zero::zero(),
            migration_initiated_at: 0,
            migration_used: false,
        };
        world.write_model(@player);
    }

    fn create_test_tournament(
        budokan_dispatcher: ITournamentDispatcher,
        tournament_token_address: ContractAddress,
        admin_address: ContractAddress
    ) -> u64 {
        testing::set_contract_address(admin_address);

        let metadata = Metadata {
            name: 'Test Tournament',
            description: "A test tournament for integration testing",
        };

        let current_time = starknet::get_block_timestamp();
        let schedule = Schedule {
            registration: Option::Some(Period {
                start: current_time,
                end: current_time + 3600, // 1 hour registration
            }),
            game: Period {
                start: current_time,
                end: current_time + 7200, // 2 hours game period  
            },
            submission_duration: 300, // 5 minutes for score submission
        };

        let game_config = GameConfig {
            address: tournament_token_address,
            settings_id: 1,
            prize_spots: 3,
        };

        let tournament = budokan_dispatcher.create_tournament(
            admin_address,
            metadata,
            schedule,
            game_config,
            Option::None, // No entry fee
            Option::None  // No entry requirement
        );

        tournament.id
    }

    fn create_budokan_tournament_with_evlt_entry_fee(
        budokan_dispatcher: ITournamentDispatcher,
        tournament_token_address: ContractAddress,
        evlt_token_address: ContractAddress,
        admin_address: ContractAddress,
        entry_fee_amount: u128
    ) -> u64 {
        testing::set_contract_address(admin_address);

        let metadata = Metadata {
            name: 'Budokan Tournament',
            description: "A budokan tournament with EVLT entry fee",
        };

        let current_time = starknet::get_block_timestamp();
        let schedule = Schedule {
            registration: Option::Some(Period {
                start: current_time,
                end: current_time + 3600, // 1 hour registration
            }),
            game: Period {
                start: current_time,
                end: current_time + 7200, // 2 hours game period  
            },
            submission_duration: 300, // 5 minutes for score submission
        };

        let game_config = GameConfig {
            address: tournament_token_address,
            settings_id: 1,
            prize_spots: 3,
        };

        // Entry fee configuration with EVLT tokens
        let entry_fee = EntryFee {
            token_address: evlt_token_address,
            amount: entry_fee_amount,
            distribution: [50, 30, 20].span(), // 1st, 2nd, 3rd place prize distribution
            tournament_creator_share: Option::None,
            game_creator_share: Option::None,
        };

        let tournament = budokan_dispatcher.create_tournament(
            admin_address,
            metadata,
            schedule,
            game_config,
            Option::Some(entry_fee),
            Option::None  // No entry requirement
        );

        tournament.id
    }

    // Helper functions for assertions
    fn assert_tournament_pass_state(
        world: WorldStorage, 
        pass_id: u64, 
        expected_player: ContractAddress,
        expected_tournament_id: u64
    ) {
        let pass: TournamentPass = world.read_model(pass_id);
        assert!(pass.player_address == expected_player, "Wrong player address");
        assert!(pass.tournament_id == expected_tournament_id, "Wrong tournament id");
    }

    fn assert_tournament_state(
        world: WorldStorage,
        tournament_id: u64,
        expected_state: TournamentState
    ) {
        let tournament: Tournament = world.read_model(tournament_id);
        assert!(tournament.state == expected_state, "Wrong tournament state");
    }

    // Basic Tournament Creation Tests
    #[test]
    fn test_tournament_creation() {
        let (budokan_dispatcher, tournament_token_dispatcher, _evlt_token_dispatcher, _evlt_protected, mut world) = deploy_tournament_system();
        let admin_address: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
        let tournament_token_address = tournament_token_dispatcher.contract_address;
        
        let tournament_id = create_test_tournament(budokan_dispatcher, tournament_token_address, admin_address);
        
        // Verify tournament was created
        assert!(tournament_id == 1, "Tournament should have ID 1");
        
        // Check that tournament exists in Budokan
        let budokan_tournament = budokan_dispatcher.tournament(tournament_id);
        assert!(budokan_tournament.id == tournament_id, "Tournament ID should match");
    }

    // Tournament Token Tests
    #[test] 
    fn test_tournament_token_minting() {
        let (budokan_dispatcher, tournament_token_dispatcher, _evlt_token_dispatcher, _evlt_protected, mut world) = deploy_tournament_system();
        let admin_address: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
        let player1_address: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let tournament_token_address = tournament_token_dispatcher.contract_address;
        
        // Create tournament first
        let tournament_id = create_test_tournament(budokan_dispatcher, tournament_token_address, admin_address);
        
        // Mint tournament token
        testing::set_contract_address(admin_address);
        let pass_id = tournament_token_dispatcher.mint(
            'player1',
            1, // settings_id
            Option::None, // start
            Option::None, // end  
            player1_address
        );
        
        assert!(pass_id == 1, "First pass should have ID 1");
        assert!(tournament_token_dispatcher.owner_of(pass_id.into()) == player1_address, "Player1 should own the pass");
    }

    // Tournament Registration Tests
    #[test]
    fn test_enlist_duelist_success() {
        let (budokan_dispatcher, tournament_token_dispatcher, _evlt_token_dispatcher, _evlt_protected, mut world) = deploy_tournament_system();
        let admin_address: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
        let player1_address: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let tournament_token_address = tournament_token_dispatcher.contract_address;
        
        setup_player(world, player1_address, 1000);
        
        // Create tournament
        let tournament_id = create_test_tournament(budokan_dispatcher, tournament_token_address, admin_address);
        
        // Mint pass and enter tournament  
        testing::set_contract_address(admin_address);
        let pass_id = tournament_token_dispatcher.mint(
            'player1',
            1,
            Option::None,
            Option::None,
            player1_address
        );
        
        // Enter tournament in Budokan
        let (token_id, entry_number) = budokan_dispatcher.enter_tournament(
            tournament_id,
            'player1',
            player1_address,
            Option::None
        );
        
        // Enlist duelist in tournament token
        testing::set_contract_address(player1_address);
        tournament_token_dispatcher.enlist_duelist(pass_id);
        
        // Check tournament pass was updated
        assert_tournament_pass_state(world, pass_id, player1_address, tournament_id);
        
        let pass: TournamentPass = world.read_model(pass_id);
        assert!(pass.entry_number == entry_number.try_into().unwrap(), "Entry number should match");
        assert!(pass.rating > 0, "Rating should be initialized");
    }

    #[test]
    fn test_enlist_duelist_without_nft_fails() {
        let (budokan_dispatcher, tournament_token_dispatcher, _evlt_token_dispatcher, _evlt_protected, mut world) = deploy_tournament_system();
        let admin_address: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
        let player1_address: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player2_address: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        let tournament_token_address = tournament_token_dispatcher.contract_address;
        
        setup_player(world, player1_address, 1000);
        setup_player(world, player2_address, 1000);
        
        // Create tournament
        create_test_tournament(budokan_dispatcher, tournament_token_address, admin_address);
        
        // Mint pass for player1 
        testing::set_contract_address(admin_address);
        let pass_id = tournament_token_dispatcher.mint(
            'player1',
            1,
            Option::None,
            Option::None,
            player1_address
        );
        
        // Try to enlist with player2 (doesn't own the NFT)
        testing::set_contract_address(player2_address);
        
        // This should fail - we can't easily test panics in dojo_cairo_test
        // but we can verify the can_enlist_duelist returns false
        assert!(!tournament_token_dispatcher.can_enlist_duelist(pass_id), "Player2 should not be able to enlist with player1's pass");
    }

    // Tournament Lifecycle Tests
    #[test]
    fn test_start_tournament() {
        let (budokan_dispatcher, tournament_token_dispatcher, _evlt_token_dispatcher, _evlt_protected, mut world) = deploy_tournament_system();
        let admin_address: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
        let player1_address: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let tournament_token_address = tournament_token_dispatcher.contract_address;
        
        setup_player(world, player1_address, 1000);
        
        // Create tournament and enlist player
        let tournament_id = create_test_tournament(budokan_dispatcher, tournament_token_address, admin_address);
        
        testing::set_contract_address(admin_address);
        let pass_id = tournament_token_dispatcher.mint('player1', 1, Option::None, Option::None, player1_address);
        budokan_dispatcher.enter_tournament(tournament_id, 'player1', player1_address, Option::None);
        
        testing::set_contract_address(player1_address);
        tournament_token_dispatcher.enlist_duelist(pass_id);
        
        // Start tournament
        let started_tournament_id = tournament_token_dispatcher.start_tournament(pass_id);
        
        assert!(started_tournament_id == tournament_id, "Started tournament ID should match");
        assert_tournament_state(world, tournament_id, TournamentState::InProgress);
    }

    #[test]
    fn test_can_start_tournament_checks() {
        let (budokan_dispatcher, tournament_token_dispatcher, _evlt_token_dispatcher, _evlt_protected, mut world) = deploy_tournament_system();
        let admin_address: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
        let player1_address: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let tournament_token_address = tournament_token_dispatcher.contract_address;
        
        setup_player(world, player1_address, 1000);
        
        // Create tournament
        let tournament_id = create_test_tournament(budokan_dispatcher, tournament_token_address, admin_address);
        
        testing::set_contract_address(admin_address);
        let pass_id = tournament_token_dispatcher.mint('player1', 1, Option::None, Option::None, player1_address);
        budokan_dispatcher.enter_tournament(tournament_id, 'player1', player1_address, Option::None);
        
        testing::set_contract_address(player1_address);
        tournament_token_dispatcher.enlist_duelist(pass_id);
        
        // Should be able to start
        assert!(tournament_token_dispatcher.can_start_tournament(pass_id), "Should be able to start tournament");
        
        // Start it
        tournament_token_dispatcher.start_tournament(pass_id);
        
        // Should not be able to start again
        assert!(!tournament_token_dispatcher.can_start_tournament(pass_id), "Should not be able to start tournament twice");
    }

    // Budokan Tournament with EVLT Entry Fee Tests
    #[test]
    fn test_budokan_tournament_with_evlt_entry_fee_creation() {
        let (budokan_dispatcher, tournament_token_dispatcher, evlt_token_dispatcher, evlt_protected, mut world) = deploy_tournament_system();
        let admin_address: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
        let tournament_token_address = tournament_token_dispatcher.contract_address;
        let evlt_token_address = evlt_token_dispatcher.contract_address;
        
        // Create budokan tournament with EVLT entry fee
        let tournament_id = create_budokan_tournament_with_evlt_entry_fee(
            budokan_dispatcher, 
            tournament_token_address, 
            evlt_token_address,
            admin_address, 
            100 // 100 EVLT entry fee
        );
        
        // Verify tournament was created
        assert!(tournament_id > 0, "Tournament should have valid ID");
        
        // Check tournament details
        let tournament = budokan_dispatcher.tournament(tournament_id);
        assert!(tournament.id == tournament_id, "Tournament ID should match");
    }

    #[test]  
    fn test_budokan_tournament_entry_with_evlt_payment() {
        let (budokan_dispatcher, tournament_token_dispatcher, evlt_token_dispatcher, evlt_protected, mut world) = deploy_tournament_system();
        let admin_address: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
        let player1_address: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let tournament_token_address = tournament_token_dispatcher.contract_address;
        let evlt_token_address = evlt_token_dispatcher.contract_address;
        let budokan_address = budokan_dispatcher.contract_address;
        
        setup_player(world, player1_address, 1000);
        
        // Mint EVLT tokens to player1
        testing::set_contract_address(admin_address);
        evlt_protected.mint(player1_address, 500); // Give player 500 EVLT
        
        // Allow budokan tournament to transfer EVLT tokens
        evlt_protected.set_transfer_allowed(budokan_address);
        
        // Create tournament with EVLT entry fee
        let tournament_id = create_budokan_tournament_with_evlt_entry_fee(
            budokan_dispatcher, 
            tournament_token_address, 
            evlt_token_address,
            admin_address, 
            100 // 100 EVLT entry fee
        );
        
        // Check player's balance before entry
        let balance_before = evlt_token_dispatcher.balance_of(player1_address);
        assert!(balance_before == 500, "Player should have 500 EVLT before entry");
        
        // Player enters tournament (should pay entry fee)
        testing::set_contract_address(player1_address);
        let (token_id, entry_number) = budokan_dispatcher.enter_tournament(
            tournament_id,
            'player1',
            player1_address,
            Option::None
        );
        
        // Check that entry fee was deducted
        let balance_after = evlt_token_dispatcher.balance_of(player1_address);
        assert!(balance_after == 400, "Player should have 400 EVLT after paying entry fee");
        
        // Check tournament entries increased
        let total_entries = budokan_dispatcher.tournament_entries(tournament_id);
        assert!(total_entries == 1, "Tournament should have 1 entry");
    }

    #[test]
    #[should_panic(expected: ('EVLT: Transfers disabled',))]
    fn test_evlt_transfer_blocked_for_regular_users() {
        let (_budokan_dispatcher, _tournament_token_dispatcher, evlt_token_dispatcher, evlt_protected, mut world) = deploy_tournament_system();
        let admin_address: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
        let player1_address: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player2_address: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        
        // Mint EVLT tokens to player1
        testing::set_contract_address(admin_address);
        evlt_protected.mint(player1_address, 500);
        
        // Try to transfer as player1 (should fail)
        testing::set_contract_address(player1_address);
        evlt_token_dispatcher.transfer(player2_address, 100);
    }

    #[test]
    fn test_evlt_transfer_allowed_for_budokan_tournament() {
        let (budokan_dispatcher, _tournament_token_dispatcher, evlt_token_dispatcher, evlt_protected, mut world) = deploy_tournament_system();
        let admin_address: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
        let player1_address: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player2_address: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        let budokan_address = budokan_dispatcher.contract_address;
        
        // Mint EVLT tokens to player1
        testing::set_contract_address(admin_address);
        evlt_protected.mint(player1_address, 500);
        
        // Allow budokan tournament to transfer EVLT tokens
        evlt_protected.set_transfer_allowed(budokan_address);
        
        // Check initial balances
        let balance1_before = evlt_token_dispatcher.balance_of(player1_address);
        let balance2_before = evlt_token_dispatcher.balance_of(player2_address);
        assert!(balance1_before == 500, "Player1 should have 500 EVLT");
        assert!(balance2_before == 0, "Player2 should have 0 EVLT");
        
        // Transfer as budokan tournament (should succeed)
        testing::set_contract_address(budokan_address);
        let success = evlt_token_dispatcher.transfer_from(player1_address, player2_address, 100);
        assert!(success, "Transfer should succeed for budokan tournament");
        
        // Check balances after transfer
        let balance1_after = evlt_token_dispatcher.balance_of(player1_address);
        let balance2_after = evlt_token_dispatcher.balance_of(player2_address);
        assert!(balance1_after == 400, "Player1 should have 400 EVLT after transfer");
        assert!(balance2_after == 100, "Player2 should have 100 EVLT after transfer");
    }
}