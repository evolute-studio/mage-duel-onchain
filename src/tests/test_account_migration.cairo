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
    use starknet::{testing, ContractAddress, get_block_timestamp};
    use core::num::traits::Zero;

    use evolute_duel::{
        models::{
            player::{Player, m_Player, PlayerTrait},
            migration::{MigrationRequest, m_MigrationRequest, MigrationRequestTrait},
            game::{Game, m_Game, Board, m_Board}, skins::{Shop, m_Shop},
        },
        events::{
            MigrationInitiated, e_MigrationInitiated, MigrationConfirmed, e_MigrationConfirmed,
            MigrationCompleted, e_MigrationCompleted, MigrationCancelled, e_MigrationCancelled,
            TutorialCompleted, e_TutorialCompleted,
        },
        systems::{
            account_migration::{
                account_migration, IAccountMigrationDispatcher, IAccountMigrationDispatcherTrait,
            },
            tutorial::{tutorial, ITutorialDispatcher, ITutorialDispatcherTrait},
        },
        types::packing::{GameStatus, GameState},
    };

    // Test constants
    const GUEST_ADDRESS: felt252 = 0x123;
    const CONTROLLER_ADDRESS: felt252 = 0x456;
    const CONTROLLER_ADDRESS_2: felt252 = 0x789;
    const BOT_ADDRESS: felt252 = 0xabc;
    const ADMIN_ADDRESS: felt252 = 0xdef;

    fn namespace_def() -> NamespaceDef {
        let ndef = NamespaceDef {
            namespace: "evolute_duel",
            resources: [
                TestResource::Model(m_Player::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_MigrationRequest::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_Game::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_Board::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_Shop::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Event(e_MigrationInitiated::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Event(e_MigrationConfirmed::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Event(e_MigrationCompleted::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Event(e_MigrationCancelled::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Event(e_TutorialCompleted::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Contract(account_migration::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Contract(tutorial::TEST_CLASS_HASH.try_into().unwrap()),
            ]
                .span(),
        };

        ndef
    }

    fn contract_defs() -> Span<ContractDef> {
        [
            ContractDefTrait::new(@"evolute_duel", @"tutorial")
                .with_writer_of([dojo::utils::bytearray_hash(@"evolute_duel")].span()),
            ContractDefTrait::new(@"evolute_duel", @"account_migration")
                .with_writer_of([dojo::utils::bytearray_hash(@"evolute_duel")].span())
                .with_init_calldata([ADMIN_ADDRESS].span()),
        ]
            .span()
    }

    fn setup_world() -> (WorldStorage, IAccountMigrationDispatcher, ITutorialDispatcher) {
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (tutorial_contract_address, _) = world.dns(@"tutorial").unwrap();
        let tutorial_dispatcher = ITutorialDispatcher {
            contract_address: tutorial_contract_address,
        };

        let (migration_contract_address, _) = world.dns(@"account_migration").unwrap();
        let migration_dispatcher = IAccountMigrationDispatcher {
            contract_address: migration_contract_address,
        };

        (world, migration_dispatcher, tutorial_dispatcher)
    }

    fn create_guest_player(
        mut world: WorldStorage, address: ContractAddress, tutorial_completed: bool,
    ) -> Player {
        let player = Player {
            player_id: address,
            username: 'guest_user',
            balance: 100,
            games_played: 5,
            active_skin: 1,
            role: 0, // Guest
            tutorial_completed,
            migration_target: Zero::zero(),
            migration_initiated_at: 0,
            migration_used: false,
        };
        world.write_model_test(@player);
        player
    }

    fn create_controller_player(
        mut world: WorldStorage, address: ContractAddress, has_progress: bool,
    ) -> Player {
        let player = Player {
            player_id: address,
            username: 'controller_user',
            balance: if has_progress {
                50
            } else {
                0
            },
            games_played: if has_progress {
                2
            } else {
                0
            },
            active_skin: 0,
            role: 1, // Controller
            tutorial_completed: has_progress,
            migration_target: Zero::zero(),
            migration_initiated_at: 0,
            migration_used: false,
        };
        world.write_model_test(@player);
        player
    }

    fn create_bot_player(mut world: WorldStorage, address: ContractAddress) -> Player {
        let player = Player {
            player_id: address,
            username: 'bot_user',
            balance: 0,
            games_played: 0,
            active_skin: 0,
            role: 2, // Bot
            tutorial_completed: false,
            migration_target: Zero::zero(),
            migration_initiated_at: 0,
            migration_used: false,
        };
        world.write_model_test(@player);
        player
    }

    fn setup_basic_scenario() -> (
        WorldStorage,
        IAccountMigrationDispatcher,
        ITutorialDispatcher,
        ContractAddress,
        ContractAddress,
    ) {
        let (mut world, migration_dispatcher, tutorial_dispatcher) = setup_world();

        let guest_address: ContractAddress = GUEST_ADDRESS.try_into().unwrap();
        let controller_address: ContractAddress = CONTROLLER_ADDRESS.try_into().unwrap();

        create_guest_player(world, guest_address, true);
        create_controller_player(world, controller_address, false);

        (world, migration_dispatcher, tutorial_dispatcher, guest_address, controller_address)
    }

    // ===========================================
    // TESTS FOR INITIATE_MIGRATION
    // ===========================================

    #[test]
    fn test_initiate_migration_success() {
        let (mut world, migration_dispatcher, _, guest_address, controller_address) =
            setup_basic_scenario();
        println!("There");

        // Set caller to guest
        testing::set_contract_address(guest_address);
        testing::set_block_timestamp(1000);

        // Initiate migration
        migration_dispatcher.initiate_migration(controller_address);

        // Verify migration request created
        let request: MigrationRequest = world.read_model(guest_address);
        assert!(request.guest_address == guest_address, "Guest address mismatch");
        assert!(request.controller_address == controller_address, "Controller address mismatch");
        assert!(request.status == 0, "Status should be pending");
        assert!(request.requested_at == 1000, "Request time incorrect");
        assert!(request.expires_at == 4600, "Expire time incorrect"); // 1000 + 3600

        // Verify guest player updated
        let guest_player: Player = world.read_model(guest_address);
        assert!(guest_player.migration_target == controller_address, "Migration target not set");
        assert!(guest_player.migration_initiated_at == 1000, "Migration initiated time not set");
    }

    #[test]
    #[should_panic]
    fn test_initiate_migration_fails_non_guest() {
        let (mut world, migration_dispatcher, _, _, controller_address) = setup_basic_scenario();

        // Set caller to controller (not guest)
        testing::set_contract_address(controller_address);

        migration_dispatcher.initiate_migration(controller_address);
    }

    #[test]
    fn test_initiate_migration_fails_tutorial_not_completed() {
        let (mut world, migration_dispatcher, _, guest_address, controller_address) =
            setup_basic_scenario();

        // Update guest to not have completed tutorial
        let mut guest_player: Player = world.read_model(guest_address);
        guest_player.tutorial_completed = false;
        world.write_model_test(@guest_player);

        testing::set_contract_address(guest_address);
        migration_dispatcher.initiate_migration(controller_address);
    }

    #[test]
    #[should_panic]
    fn test_initiate_migration_fails_already_used() {
        let (mut world, migration_dispatcher, _, guest_address, controller_address) =
            setup_basic_scenario();

        // Mark guest as having used migration
        let mut guest_player: Player = world.read_model(guest_address);
        guest_player.migration_used = true;
        world.write_model_test(@guest_player);

        testing::set_contract_address(guest_address);
        migration_dispatcher.initiate_migration(controller_address);
    }

    #[test]
    #[should_panic]
    fn test_initiate_migration_fails_target_not_controller() {
        let (mut world, migration_dispatcher, _, guest_address, _) = setup_basic_scenario();

        let bot_address: ContractAddress = BOT_ADDRESS.try_into().unwrap();
        create_bot_player(world, bot_address);

        testing::set_contract_address(guest_address);
        migration_dispatcher.initiate_migration(bot_address);
    }

    #[test]
    fn test_initiate_migration_fails_controller_has_progress() {
        let (mut world, migration_dispatcher, _, guest_address, controller_address) =
            setup_basic_scenario();

        // Give controller tutorial completion (has progress)
        let mut controller_player: Player = world.read_model(controller_address);
        controller_player.tutorial_completed = true;
        world.write_model_test(@controller_player);

        testing::set_contract_address(guest_address);
        migration_dispatcher.initiate_migration(controller_address);
    }

    #[test]
    #[should_panic]
    fn test_initiate_migration_fails_pending_request() {
        let (mut world, migration_dispatcher, _, guest_address, controller_address) =
            setup_basic_scenario();

        testing::set_contract_address(guest_address);
        testing::set_block_timestamp(1000);

        // First migration request
        migration_dispatcher.initiate_migration(controller_address);

        // Try to initiate again immediately
        migration_dispatcher.initiate_migration(controller_address);
    }

    // ===========================================
    // TESTS FOR CONFIRM_MIGRATION
    // ===========================================

    #[test]
    fn test_confirm_migration_success() {
        let (mut world, migration_dispatcher, _, guest_address, controller_address) =
            setup_basic_scenario();

        // Initiate migration
        testing::set_contract_address(guest_address);
        testing::set_block_timestamp(1000);
        migration_dispatcher.initiate_migration(controller_address);

        // Confirm migration as controller
        testing::set_contract_address(controller_address);
        testing::set_block_timestamp(1500);
        migration_dispatcher.confirm_migration(guest_address);

        // Verify request status updated
        let request: MigrationRequest = world.read_model(guest_address);
        assert!(request.status == 1, "Status should be approved");
    }

    #[test]
    #[should_panic]
    fn test_confirm_migration_fails_wrong_caller() {
        let (mut world, migration_dispatcher, _, guest_address, controller_address) =
            setup_basic_scenario();

        // Initiate migration
        testing::set_contract_address(guest_address);
        migration_dispatcher.initiate_migration(controller_address);

        // Try to confirm from wrong address
        let wrong_address: ContractAddress = CONTROLLER_ADDRESS_2.try_into().unwrap();
        testing::set_contract_address(wrong_address);
        migration_dispatcher.confirm_migration(guest_address);
    }

    #[test]
    #[should_panic]
    fn test_confirm_migration_fails_expired() {
        let (mut world, migration_dispatcher, _, guest_address, controller_address) =
            setup_basic_scenario();

        // Initiate migration
        testing::set_contract_address(guest_address);
        testing::set_block_timestamp(1000);
        migration_dispatcher.initiate_migration(controller_address);

        // Try to confirm after expiration
        testing::set_contract_address(controller_address);
        testing::set_block_timestamp(5000); // Past expiry (1000 + 3600 = 4600)
        migration_dispatcher.confirm_migration(guest_address);
    }

    // ===========================================
    // TESTS FOR EXECUTE_MIGRATION
    // ===========================================

    #[test]
    fn test_execute_migration_success() {
        let (mut world, migration_dispatcher, _, guest_address, controller_address) =
            setup_basic_scenario();

        // Setup: initiate and confirm migration
        testing::set_contract_address(guest_address);
        testing::set_block_timestamp(1000);
        migration_dispatcher.initiate_migration(controller_address);

        testing::set_contract_address(controller_address);
        testing::set_block_timestamp(1500);
        migration_dispatcher.confirm_migration(guest_address);

        // Execute migration
        testing::set_block_timestamp(2000);
        migration_dispatcher.execute_migration(guest_address);

        // Verify controller received data
        let controller_player: Player = world.read_model(controller_address);
        assert!(controller_player.balance == 100, "Balance not transferred");
        assert!(controller_player.games_played == 5, "Games not transferred");
        assert!(controller_player.tutorial_completed == true, "Tutorial completion not set");
        assert!(controller_player.migration_used == true, "Migration used not marked");
        assert!(controller_player.active_skin == 1, "Better skin not transferred");

        // Verify guest cleaned
        let guest_player: Player = world.read_model(guest_address);
        assert!(guest_player.balance == 0, "Guest balance not cleared");
        assert!(guest_player.games_played == 0, "Guest games not cleared");
        assert!(guest_player.tutorial_completed == false, "Guest tutorial not cleared");
        assert!(guest_player.migration_used == true, "Guest migration used not marked");
        assert!(guest_player.active_skin == 0, "Guest skin not cleared");
        assert!(guest_player.migration_target.is_zero(), "Guest migration target not cleared");

        // Verify request marked complete
        let request: MigrationRequest = world.read_model(guest_address);
        assert!(request.status == 3, "Request not marked completed");
    }

    #[test]
    #[should_panic]
    fn test_execute_migration_fails_not_approved() {
        let (mut world, migration_dispatcher, _, guest_address, controller_address) =
            setup_basic_scenario();

        // Initiate but don't confirm
        testing::set_contract_address(guest_address);
        testing::set_block_timestamp(1000);
        migration_dispatcher.initiate_migration(controller_address);

        // Try to execute without confirmation
        testing::set_block_timestamp(1500);
        migration_dispatcher.execute_migration(guest_address);
    }

    #[test]
    #[should_panic]
    fn test_execute_migration_fails_expired() {
        let (mut world, migration_dispatcher, _, guest_address, controller_address) =
            setup_basic_scenario();

        // Setup: initiate and confirm
        testing::set_contract_address(guest_address);
        testing::set_block_timestamp(1000);
        migration_dispatcher.initiate_migration(controller_address);

        testing::set_contract_address(controller_address);
        testing::set_block_timestamp(1500);
        migration_dispatcher.confirm_migration(guest_address);

        // Try to execute after expiration
        testing::set_block_timestamp(5000);
        migration_dispatcher.execute_migration(guest_address);
    }

    // ===========================================
    // TESTS FOR CANCEL_MIGRATION
    // ===========================================

    #[test]
    fn test_cancel_migration_success() {
        let (mut world, migration_dispatcher, _, guest_address, controller_address) =
            setup_basic_scenario();

        // Initiate migration
        testing::set_contract_address(guest_address);
        testing::set_block_timestamp(1000);
        migration_dispatcher.initiate_migration(controller_address);

        // Cancel migration
        testing::set_block_timestamp(1500);
        migration_dispatcher.cancel_migration();

        // Verify request cancelled
        let request: MigrationRequest = world.read_model(guest_address);
        assert!(request.status == 2, "Request not marked rejected");

        // Verify guest player reset
        let guest_player: Player = world.read_model(guest_address);
        assert!(guest_player.migration_target.is_zero(), "Migration target not cleared");
        assert!(guest_player.migration_initiated_at == 0, "Migration initiated time not cleared");
    }

    #[test]
    #[should_panic]
    fn test_cancel_migration_fails_already_approved() {
        let (mut world, migration_dispatcher, _, guest_address, controller_address) =
            setup_basic_scenario();

        // Setup: initiate and confirm
        testing::set_contract_address(guest_address);
        testing::set_block_timestamp(1000);
        migration_dispatcher.initiate_migration(controller_address);

        testing::set_contract_address(controller_address);
        testing::set_block_timestamp(1500);
        migration_dispatcher.confirm_migration(guest_address);

        // Try to cancel after approval
        testing::set_contract_address(guest_address);
        migration_dispatcher.cancel_migration();
    }

    // ===========================================
    // INTEGRATION TESTS
    // ===========================================

    #[test]
    fn test_full_migration_flow() {
        let (mut world, migration_dispatcher, _, guest_address, controller_address) =
            setup_basic_scenario();

        let initial_guest_balance = 100;
        let initial_guest_games = 5;

        // Step 1: Initiate
        testing::set_contract_address(guest_address);
        testing::set_block_timestamp(1000);
        migration_dispatcher.initiate_migration(controller_address);

        // Step 2: Confirm
        testing::set_contract_address(controller_address);
        testing::set_block_timestamp(1500);
        migration_dispatcher.confirm_migration(guest_address);

        // Step 3: Execute
        testing::set_block_timestamp(2000);
        migration_dispatcher.execute_migration(guest_address);

        // Verify full transfer
        let controller_player: Player = world.read_model(controller_address);
        assert!(controller_player.balance == initial_guest_balance, "Full migration failed");
        assert!(controller_player.games_played == initial_guest_games, "Games transfer failed");

        let guest_player: Player = world.read_model(guest_address);
        assert!(guest_player.balance == 0, "Guest not fully cleaned");
        assert!(guest_player.migration_used == true, "Guest not marked as used");
    }

    #[test]
    fn test_retry_after_cancellation() {
        let (mut world, migration_dispatcher, _, guest_address, controller_address) =
            setup_basic_scenario();

        // First attempt: initiate and cancel
        testing::set_contract_address(guest_address);
        testing::set_block_timestamp(1000);
        migration_dispatcher.initiate_migration(controller_address);
        migration_dispatcher.cancel_migration();

        // Second attempt should work immediately
        testing::set_block_timestamp(1100); // No need to wait
        migration_dispatcher.initiate_migration(controller_address);

        let request: MigrationRequest = world.read_model(guest_address);
        assert!(request.status == 0, "Retry after cancellation failed");
    }

    #[test]
    fn test_retry_after_expiration() {
        let (mut world, migration_dispatcher, _, guest_address, controller_address) =
            setup_basic_scenario();

        // First attempt: let it expire
        testing::set_contract_address(guest_address);
        testing::set_block_timestamp(1000);
        migration_dispatcher.initiate_migration(controller_address);

        // Second attempt after expiration
        testing::set_block_timestamp(5000); // Past expiry
        migration_dispatcher.initiate_migration(controller_address);

        let request: MigrationRequest = world.read_model(guest_address);
        assert!(request.requested_at == 5000, "Retry after expiration failed");
    }

    #[test]
    #[should_panic]
    fn test_no_retry_after_successful_migration() {
        let (mut world, migration_dispatcher, _, guest_address, controller_address) =
            setup_basic_scenario();

        // Complete full migration
        testing::set_contract_address(guest_address);
        testing::set_block_timestamp(1000);
        migration_dispatcher.initiate_migration(controller_address);

        testing::set_contract_address(controller_address);
        testing::set_block_timestamp(1500);
        migration_dispatcher.confirm_migration(guest_address);

        testing::set_block_timestamp(2000);
        migration_dispatcher.execute_migration(guest_address);

        // Guest completes tutorial again (hypothetically)
        let mut guest_player: Player = world.read_model(guest_address);
        guest_player.tutorial_completed = true;
        world.write_model_test(@guest_player);

        // Try to migrate again - should fail
        testing::set_contract_address(guest_address);
        let new_controller: ContractAddress = CONTROLLER_ADDRESS_2.try_into().unwrap();
        create_controller_player(world, new_controller, false);
        migration_dispatcher.initiate_migration(new_controller);
    }

    // ===========================================
    // EDGE CASE TESTS
    // ===========================================

    #[test]
    fn test_skin_transfer_logic() {
        let (mut world, migration_dispatcher, _, guest_address, controller_address) =
            setup_basic_scenario();

        // Setup: guest has better skin
        let mut guest_player: Player = world.read_model(guest_address);
        guest_player.active_skin = 5;
        world.write_model_test(@guest_player);

        let mut controller_player: Player = world.read_model(controller_address);
        controller_player.active_skin = 2;
        world.write_model_test(@controller_player);

        // Complete migration
        testing::set_contract_address(guest_address);
        testing::set_block_timestamp(1000);
        migration_dispatcher.initiate_migration(controller_address);

        testing::set_contract_address(controller_address);
        testing::set_block_timestamp(1500);
        migration_dispatcher.confirm_migration(guest_address);

        testing::set_block_timestamp(2000);
        migration_dispatcher.execute_migration(guest_address);

        // Verify better skin transferred
        let final_controller: Player = world.read_model(controller_address);
        assert!(final_controller.active_skin == 5, "Better skin not transferred");
    }

    #[test]
    fn test_skin_not_downgraded() {
        let (mut world, migration_dispatcher, _, guest_address, controller_address) =
            setup_basic_scenario();

        // Setup: controller has better skin
        let mut guest_player: Player = world.read_model(guest_address);
        guest_player.active_skin = 2;
        world.write_model_test(@guest_player);

        let mut controller_player: Player = world.read_model(controller_address);
        controller_player.active_skin = 5;
        world.write_model_test(@controller_player);

        // Complete migration
        testing::set_contract_address(guest_address);
        testing::set_block_timestamp(1000);
        migration_dispatcher.initiate_migration(controller_address);

        testing::set_contract_address(controller_address);
        testing::set_block_timestamp(1500);
        migration_dispatcher.confirm_migration(guest_address);

        testing::set_block_timestamp(2000);
        migration_dispatcher.execute_migration(guest_address);

        // Verify skin not downgraded
        let final_controller: Player = world.read_model(controller_address);
        assert!(final_controller.active_skin == 5, "Skin should not be downgraded");
    }

    #[test]
    #[should_panic]
    fn test_controller_cannot_receive_multiple_migrations() {
        let (mut world, migration_dispatcher, _, _, controller_address) = setup_basic_scenario();

        // Create two guest accounts
        let guest1: ContractAddress = 0x111.try_into().unwrap();
        let guest2: ContractAddress = 0x222.try_into().unwrap();

        create_guest_player(world, guest1, true);
        create_guest_player(world, guest2, true);

        // First guest migrates successfully
        testing::set_contract_address(guest1);
        testing::set_block_timestamp(1000);
        migration_dispatcher.initiate_migration(controller_address);

        testing::set_contract_address(controller_address);
        testing::set_block_timestamp(1500);
        migration_dispatcher.confirm_migration(guest1);

        testing::set_block_timestamp(2000);
        migration_dispatcher.execute_migration(guest1);

        // Second guest tries to migrate to same controller - should fail at initiation
        testing::set_contract_address(guest2);
        testing::set_block_timestamp(3000);
        migration_dispatcher.initiate_migration(controller_address);
    }
}
