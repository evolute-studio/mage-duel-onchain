use starknet::ContractAddress;

/// Interface defining actions for account migration management.
#[starknet::interface]
pub trait IAccountMigration<T> {
    /// Initiates migration from guest account to controller account.
    /// - `target_controller`: The controller address to migrate to.
    /// Only guest accounts that have completed the tutorial can initiate migration.
    fn initiate_migration(ref self: T, target_controller: ContractAddress);

    /// Confirms migration request by the controller account owner.
    /// - `guest_address`: The guest address requesting migration.
    /// Only the owner of the target controller can confirm.
    fn confirm_migration(ref self: T, guest_address: ContractAddress);

    /// Cancels pending migration request.
    /// Only the guest who initiated the migration can cancel.
    fn cancel_migration(ref self: T);

    /// Executes approved migration after confirmation.
    /// - `guest_address`: The guest address to migrate from.
    /// Can be called by anyone after migration is approved and not expired.
    fn execute_migration(ref self: T, guest_address: ContractAddress);

    /// Emergency function to cancel migration (admin only).
    /// - `guest_address`: The guest address with pending migration.
    fn emergency_cancel_migration(ref self: T, guest_address: ContractAddress);
}

// dojo decorator
#[dojo::contract]
pub mod account_migration {
    use super::IAccountMigration;
    use starknet::{get_caller_address, get_block_timestamp, ContractAddress};
    use core::num::traits::Zero;

    use dojo::event::EventStorage;
    use dojo::model::ModelStorage;

    use evolute_duel::{
        events::{
            MigrationInitiated, MigrationConfirmed, MigrationCompleted, MigrationCancelled,
            EmergencyMigrationCancelled,
        },
        models::{player::{Player}, migration::{MigrationRequest}}, libs::{asserts::AssertsTrait},
    };
    use openzeppelin_access::ownable::OwnableComponent;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // Ownable Mixin
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    // Constants
    const MIGRATION_TIMEOUT: u64 = 3600; // 1 hour for confirmation

    fn dojo_init(ref self: ContractState, creator_address: ContractAddress) {
        self.ownable.initializer(creator_address);
    }

    #[abi(embed_v0)]
    impl AccountMigrationImpl of IAccountMigration<ContractState> {
        fn initiate_migration(ref self: ContractState, target_controller: ContractAddress) {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let current_time = get_block_timestamp();

            let guest_player: Player = world.read_model(caller);
            let controller_player: Player = world.read_model(target_controller);
            // Check for existing active requests
            let existing_request: MigrationRequest = world.read_model(caller);

            // VALIDATION USING ASSERTS TRAIT:
            if !AssertsTrait::assert_guest_can_initiate_migration(
                @guest_player, target_controller, world,
            ) {
                return;
            }

            if !AssertsTrait::assert_controller_can_receive_migration(
                @controller_player, caller, world,
            ) {
                return;
            }

            if !AssertsTrait::assert_no_pending_migration(
                @guest_player, @existing_request, current_time, target_controller, world,
            ) {
                return;
            }

            // CREATE MIGRATION REQUEST:
            let migration_request = MigrationRequest {
                guest_address: caller,
                controller_address: target_controller,
                requested_at: current_time,
                expires_at: current_time + MIGRATION_TIMEOUT,
                status: 0 // pending
            };

            // Update guest account
            let mut updated_guest = guest_player;
            updated_guest.migration_target = target_controller;
            updated_guest.migration_initiated_at = current_time;

            world.write_model(@migration_request);
            world.write_model(@updated_guest);

            world
                .emit_event(
                    @MigrationInitiated {
                        guest_address: caller,
                        controller_address: target_controller,
                        expires_at: current_time + MIGRATION_TIMEOUT,
                    },
                );
        }

        fn confirm_migration(ref self: ContractState, guest_address: ContractAddress) {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let current_time = get_block_timestamp();

            let mut migration_request: MigrationRequest = world.read_model(guest_address);

            // VALIDATION USING ASSERTS TRAIT:
            if !AssertsTrait::assert_can_confirm_migration(
                @migration_request, caller, current_time, world,
            ) {
                return;
            }

            // Confirm the request
            migration_request.status = 1; // approved
            world.write_model(@migration_request);

            world
                .emit_event(
                    @MigrationConfirmed {
                        guest_address, controller_address: caller, confirmed_at: current_time,
                    },
                );
        }

        fn execute_migration(ref self: ContractState, guest_address: ContractAddress) {
            let mut world = self.world_default();
            let current_time = get_block_timestamp();

            let migration_request: MigrationRequest = world.read_model(guest_address);
            let guest_player: Player = world.read_model(guest_address);
            let mut controller_player: Player = world
                .read_model(migration_request.controller_address);

            // VALIDATION USING ASSERTS TRAIT:
            if !AssertsTrait::assert_can_execute_migration(
                @migration_request, @guest_player, current_time, world,
            ) {
                return;
            }

            // EXECUTE MIGRATION:
            let balance_to_transfer = guest_player.balance;
            let games_to_transfer = guest_player.games_played;

            controller_player.balance += guest_player.balance;
            controller_player.games_played += guest_player.games_played;
            controller_player.tutorial_completed = true;
            controller_player.migration_used = true;

            // Transfer better skin if guest has one
            if guest_player.active_skin > controller_player.active_skin {
                controller_player.active_skin = guest_player.active_skin;
            }

            // Clean guest account
            let mut cleaned_guest = guest_player;
            cleaned_guest.balance = 0;
            cleaned_guest.games_played = 0;
            cleaned_guest.tutorial_completed = false;
            cleaned_guest.active_skin = 0;
            cleaned_guest.migration_target = Zero::zero();
            cleaned_guest.migration_initiated_at = 0;
            cleaned_guest.migration_used = true; // Mark as used to prevent re-migration

            // Close the request
            let mut completed_request = migration_request;
            completed_request.status = 3; // completed

            world.write_model(@controller_player);
            world.write_model(@cleaned_guest);
            world.write_model(@completed_request);

            world
                .emit_event(
                    @MigrationCompleted {
                        guest_address,
                        controller_address: migration_request.controller_address,
                        balance_transferred: balance_to_transfer,
                        games_transferred: games_to_transfer,
                    },
                );
        }

        fn cancel_migration(ref self: ContractState) {
            let mut world = self.world_default();
            let caller = get_caller_address();

            let mut migration_request: MigrationRequest = world.read_model(caller);
            let mut guest_player: Player = world.read_model(caller);

            // VALIDATION USING ASSERTS TRAIT:
            if !AssertsTrait::assert_can_cancel_migration(@migration_request, caller, world) {
                return;
            }

            // Cancel the request
            migration_request.status = 2; // rejected
            guest_player.migration_target = Zero::zero();
            guest_player.migration_initiated_at = 0;

            world.write_model(@migration_request);
            world.write_model(@guest_player);

            world
                .emit_event(
                    @MigrationCancelled {
                        guest_address: caller,
                        controller_address: migration_request.controller_address,
                        cancelled_at: get_block_timestamp(),
                    },
                );
        }

        fn emergency_cancel_migration(ref self: ContractState, guest_address: ContractAddress) {
            self.ownable.assert_only_owner();
            let mut world = self.world_default();
            let admin = get_caller_address();

            let mut migration_request: MigrationRequest = world.read_model(guest_address);
            let mut guest_player: Player = world.read_model(guest_address);

            // Force cancel with logging
            migration_request.status = 2; // rejected
            guest_player.migration_target = Zero::zero();
            guest_player.migration_initiated_at = 0;

            world.write_model(@migration_request);
            world.write_model(@guest_player);

            world
                .emit_event(
                    @EmergencyMigrationCancelled {
                        guest_address,
                        admin_address: admin,
                        reason: "Emergency cancellation by admin",
                    },
                );
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"evolute_duel")
        }
    }
}
