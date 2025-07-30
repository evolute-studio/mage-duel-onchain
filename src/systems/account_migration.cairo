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
            EmergencyMigrationCancelled, MigrationError
        },
        models::{
            player::{Player, PlayerTrait}, 
            migration::{MigrationRequest, MigrationRequestTrait}
        },
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

            // VALIDATION OF GUEST ACCOUNT:
            if !guest_player.is_guest() {
                world.emit_event(@MigrationError {
                    guest_address: caller,
                    controller_address: target_controller,
                    status: 'Error',
                    error_context: "Guest validation failed - caller is not a guest account", 
                    error_message: "Only guest can initiate migration"
                });
                return;
            }
            
            if !guest_player.tutorial_completed {
                world.emit_event(@MigrationError {
                    guest_address: caller,
                    controller_address: target_controller,
                    status: 'Error',
                    error_context: "Guest validation failed - tutorial not completed",
                    error_message: "Tutorial not completed"
                });
                return;
            }
            
            if !existing_request.is_expired(current_time) && guest_player.has_pending_migration() {
                world.emit_event(@MigrationError {
                    guest_address: caller,
                    controller_address: target_controller,
                    status: 'Error',
                    error_context: "Guest validation failed - already has pending migration",
                    error_message: "Migration already initiated"
                });
                return;
            }
            
            if guest_player.migration_used {
                world.emit_event(@MigrationError {
                    guest_address: caller,
                    controller_address: target_controller,
                    status: 'Error',
                    error_context: "Guest validation failed - migration already used",
                    error_message: "Migration already used"
                });
                return;
            }

            // VALIDATION OF TARGET ACCOUNT:
            if !controller_player.is_controller() {
                world.emit_event(@MigrationError {
                    guest_address: caller,
                    controller_address: target_controller,
                    status: 'Error',
                    error_context: "Controller validation failed - target is not a controller account",
                    error_message: "Target must be controller"
                });
                return;
            }
            
            if controller_player.tutorial_completed {
                world.emit_event(@MigrationError {
                    guest_address: caller,
                    controller_address: target_controller,
                    status: 'Error',
                    error_context: "Controller validation failed - tutorial already completed",
                    error_message: "Controller completed tutorial"
                });
                return;
            }
            
            if controller_player.migration_used {
                world.emit_event(@MigrationError {
                    guest_address: caller,
                    controller_address: target_controller,
                    status: 'Error',
                    error_context: "Controller validation failed - already received migration",
                    error_message: "Controller already received migration"
                });
                return;
            }

            if !(existing_request.status == 0 || existing_request.is_expired(current_time) || existing_request.is_rejected()) {
                world.emit_event(@MigrationError {
                    guest_address: caller,
                    controller_address: target_controller,
                    status: 'Error',
                    error_context: "Request validation failed - active migration request exists",
                    error_message: "Active migration request exists"
                });
                return;
            }

            // CREATE MIGRATION REQUEST:
            let migration_request = MigrationRequest {
                guest_address: caller,
                controller_address: target_controller,
                requested_at: current_time,
                expires_at: current_time + MIGRATION_TIMEOUT,
                status: 0, // pending
            };

            // Update guest account
            let mut updated_guest = guest_player;
            updated_guest.migration_target = target_controller;
            updated_guest.migration_initiated_at = current_time;

            world.write_model(@migration_request);
            world.write_model(@updated_guest);

            world.emit_event(@MigrationInitiated {
                guest_address: caller,
                controller_address: target_controller,
                expires_at: current_time + MIGRATION_TIMEOUT
            });
            
            // Emit success event
            world.emit_event(@MigrationError {
                guest_address: caller,
                controller_address: target_controller,
                status: 'Success',
                error_context: "Migration initiation successful - all validations passed",
                error_message: "Migration initiated successfully"
            });
        }

        fn confirm_migration(ref self: ContractState, guest_address: ContractAddress) {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let current_time = get_block_timestamp();

            let mut migration_request: MigrationRequest = world.read_model(guest_address);

            // CRITICAL CHECK: only controller owner can confirm
            if migration_request.controller_address != caller {
                world.emit_event(@MigrationError {
                    guest_address: guest_address,
                    controller_address: caller,
                    status: 'Error',
                    error_context: "Controller authorization failed - not the controller owner",
                    error_message: "Only controller owner can confirm"
                });
                return;
            }
            
            if !migration_request.is_pending() {
                world.emit_event(@MigrationError {
                    guest_address: guest_address,
                    controller_address: caller,
                    status: 'Error',
                    error_context: "Request status invalid - not in pending state",
                    error_message: "Request not pending"
                });
                return;
            }
            
            if migration_request.is_expired(current_time) {
                world.emit_event(@MigrationError {
                    guest_address: guest_address,
                    controller_address: caller,
                    status: 'Error',
                    error_context: "Request timeout - migration request has expired",
                    error_message: "Request expired"
                });
                return;
            }

            // Confirm the request
            migration_request.status = 1; // approved
            world.write_model(@migration_request);

            world.emit_event(@MigrationConfirmed {
                guest_address,
                controller_address: caller,
                confirmed_at: current_time
            });
            
            // Emit success event
            world.emit_event(@MigrationError {
                guest_address: guest_address,
                controller_address: caller,
                status: 'Success',
                error_context: "Migration confirmation successful - controller approved the request",
                error_message: "Migration confirmed successfully"
            });
        }

        fn execute_migration(ref self: ContractState, guest_address: ContractAddress) {
            let mut world = self.world_default();
            let current_time = get_block_timestamp();

            let migration_request: MigrationRequest = world.read_model(guest_address);
            let guest_player: Player = world.read_model(guest_address);
            let mut controller_player: Player = world.read_model(migration_request.controller_address);

            // FINAL VALIDATION:
            if !migration_request.can_be_executed(current_time) {
                world.emit_event(@MigrationError {
                    guest_address: guest_address,
                    controller_address: migration_request.controller_address,
                    status: 'Error',
                    error_context: "Execution validation failed - migration cannot be executed at this time",
                    error_message: "Cannot execute migration"
                });
                return;
            }
            
            if guest_player.migration_target != migration_request.controller_address {
                world.emit_event(@MigrationError {
                    guest_address: guest_address,
                    controller_address: migration_request.controller_address,
                    status: 'Error',
                    error_context: "Target validation failed - guest migration target does not match request",
                    error_message: "Target mismatch"
                });
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

            world.emit_event(@MigrationCompleted {
                guest_address,
                controller_address: migration_request.controller_address,
                balance_transferred: balance_to_transfer,
                games_transferred: games_to_transfer
            });
            
            // Emit success event
            world.emit_event(@MigrationError {
                guest_address: guest_address,
                controller_address: migration_request.controller_address,
                status: 'Success',
                error_context: "Migration execution successful - data transferred to controller",
                error_message: "Migration executed successfully"
            });
        }

        fn cancel_migration(ref self: ContractState) {
            let mut world = self.world_default();
            let caller = get_caller_address();

            let mut migration_request: MigrationRequest = world.read_model(caller);
            let mut guest_player: Player = world.read_model(caller);

            if !migration_request.is_pending() {
                world.emit_event(@MigrationError {
                    guest_address: caller,
                    controller_address: migration_request.controller_address,
                    status: 'Error',
                    error_context: "Cancellation failed - request is not in pending state",
                    error_message: "Can only cancel pending requests"
                });
                return;
            }

            // Cancel the request
            migration_request.status = 2; // rejected
            guest_player.migration_target = Zero::zero();
            guest_player.migration_initiated_at = 0;

            world.write_model(@migration_request);
            world.write_model(@guest_player);

            world.emit_event(@MigrationCancelled {
                guest_address: caller,
                controller_address: migration_request.controller_address,
                cancelled_at: get_block_timestamp()
            });
            
            // Emit success event
            world.emit_event(@MigrationError {
                guest_address: caller,
                controller_address: migration_request.controller_address,
                status: 'Success',
                error_context: "Migration cancellation successful - request cancelled by guest",
                error_message: "Migration cancelled successfully"
            });
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

            world.emit_event(@EmergencyMigrationCancelled {
                guest_address,
                admin_address: admin,
                reason: "Emergency cancellation by admin"
            });
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"evolute_duel")
        }
    }
}