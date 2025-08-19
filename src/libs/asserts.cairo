use dojo::{world::WorldStorage, event::EventStorage, model::{ModelStorage}};
use evolute_duel::{
    models::{
        game::Game, 
        player::{Player, PlayerTrait}, 
        migration::{MigrationRequest, MigrationRequestTrait},
        // tournament_balance::{TournamentBalance, TournamentBalanceTrait, EevltBurned}
    },
    events::{GameCreateFailed, GameJoinFailed, PlayerNotInGame, GameFinished, MigrationError, ErrorEvent},
    types::{packing::{GameStatus, GameMode}},
    // interfaces::{ievlt_token::{IEvltTokenDispatcher, IEvltTokenDispatcherTrait}},
    // libs::store::{Store, StoreTrait},
};
use starknet::ContractAddress;
#[generate_trait]
pub impl AssersImpl of AssertsTrait {
    fn assert_ready_to_create_game(self: @Game, mut world: WorldStorage) -> bool {
        let status = *self.status;
        if status == GameStatus::InProgress || status == GameStatus::Created {
            world.emit_event(@GameCreateFailed { host_player: *self.player, status });
            println!("Game already created or in progress");
            return false;
        }
        true
    }

    fn assert_ready_to_join_game(guest: @Game, host: @Game, mut world: WorldStorage) -> bool {
        if *host.status != GameStatus::Created
            || *guest.status == GameStatus::Created
            || *guest.status == GameStatus::InProgress
            || host.player == guest.player {
            world
                .emit_event(
                    @GameJoinFailed {
                        host_player: *host.player,
                        guest_player: *guest.player,
                        host_game_status: *host.status,
                        guest_game_status: *guest.status,
                    },
                );
            println!("Game join failed");
            return false;
        }
        true
    }

    fn assert_player_in_game(
        game: @Game, board_id: Option<felt252>, mut world: WorldStorage,
    ) -> bool {
        if game.board_id.is_none()
            || (board_id.is_some() && (*game.board_id).unwrap() != board_id.unwrap()) || *game.status == GameStatus::Finished {
            world.emit_event(@PlayerNotInGame { player_id: *game.player, board_id: 0 });
            println!("Player is not in game");
            return false;
        }
        true
    }

    fn assert_game_is_in_progress(game: @Game, mut world: WorldStorage) -> bool {
        if *game.status == GameStatus::Finished {
            world
                .emit_event(
                    @GameFinished { player: *game.player, board_id: (*game.board_id).unwrap() },
                );
            println!("Game is already finished");
            return false;
        }
        true
    }

    // Migration validation functions
    fn assert_guest_can_initiate_migration(
        guest: @Player, 
        controller_address: ContractAddress, 
        mut world: WorldStorage
    ) -> bool {
        if !guest.is_guest() {
            world.emit_event(@MigrationError {
                guest_address: *guest.player_id,
                controller_address,
                status: 'Error',
                error_context: "Guest validation failed - caller is not a guest account",
                error_message: "Only guest can initiate migration"
            });
            return false;
        }

        if *guest.migration_used {
            world.emit_event(@MigrationError {
                guest_address: *guest.player_id,
                controller_address,
                status: 'Error',
                error_context: "Guest validation failed - migration already used",
                error_message: "Migration already used"
            });
            return false;
        }

        true
    }

    fn assert_controller_can_receive_migration(
        controller: @Player,
        guest_address: ContractAddress,
        mut world: WorldStorage
    ) -> bool {
        if !controller.is_controller() {
            world.emit_event(@MigrationError {
                guest_address,
                controller_address: *controller.player_id,
                status: 'Error',
                error_context: "Controller validation failed - target is not a controller account",
                error_message: "Target must be controller"
            });
            return false;
        }

        // YOU CAN ONLY MIGRATE ONCE
        if *controller.migration_used {
            world.emit_event(@MigrationError {
                guest_address,
                controller_address: *controller.player_id,
                status: 'Error',
                error_context: "Controller validation failed - already received migration",
                error_message: "Controller already received migration"
            });
            return false;
        }

        true
    }

    fn assert_no_pending_migration(
        guest: @Player,
        existing_request: @MigrationRequest,
        current_time: u64,
        controller_address: ContractAddress,
        mut world: WorldStorage
    ) -> bool {
        if !existing_request.is_expired(current_time) && guest.has_pending_migration() {
            world.emit_event(@MigrationError {
                guest_address: *guest.player_id,
                controller_address,
                status: 'Error',
                error_context: "Guest validation failed - already has pending migration",
                error_message: "Migration already initiated"
            });
            return false;
        }
        true
    }

    fn assert_can_confirm_migration(
        migration_request: @MigrationRequest,
        caller_address: ContractAddress,
        current_time: u64,
        mut world: WorldStorage
    ) -> bool {
        if *migration_request.controller_address != caller_address {
            world.emit_event(@MigrationError {
                guest_address: *migration_request.guest_address,
                controller_address: caller_address,
                status: 'Error',
                error_context: "Controller authorization failed - not the controller owner",
                error_message: "Only controller owner can confirm"
            });
            return false;
        }

        if !migration_request.is_pending() {
            world.emit_event(@MigrationError {
                guest_address: *migration_request.guest_address,
                controller_address: caller_address,
                status: 'Error',
                error_context: "Request status invalid - not in pending state",
                error_message: "Request not pending"
            });
            return false;
        }

        if migration_request.is_expired(current_time) {
            world.emit_event(@MigrationError {
                guest_address: *migration_request.guest_address,
                controller_address: caller_address,
                status: 'Error',
                error_context: "Request timeout - migration request has expired",
                error_message: "Request expired"
            });
            return false;
        }

        true
    }

    fn assert_can_execute_migration(
        migration_request: @MigrationRequest,
        guest: @Player,
        current_time: u64,
        mut world: WorldStorage
    ) -> bool {
        if !migration_request.can_be_executed(current_time) {
            world.emit_event(@MigrationError {
                guest_address: *migration_request.guest_address,
                controller_address: *migration_request.controller_address,
                status: 'Error',
                error_context: "Execution validation failed - migration cannot be executed at this time",
                error_message: "Cannot execute migration"
            });
            return false;
        }

        if *guest.migration_target != *migration_request.controller_address {
            world.emit_event(@MigrationError {
                guest_address: *migration_request.guest_address,
                controller_address: *migration_request.controller_address,
                status: 'Error',
                error_context: "Target validation failed - guest migration target does not match request",
                error_message: "Target mismatch"
            });
            return false;
        }

        true
    }

    fn assert_can_cancel_migration(
        migration_request: @MigrationRequest,
        caller_address: ContractAddress,
        mut world: WorldStorage
    ) -> bool {
        if !migration_request.is_pending() {
            world.emit_event(@MigrationError {
                guest_address: caller_address,
                controller_address: *migration_request.controller_address,
                status: 'Error',
                error_context: "Cancellation failed - request is not in pending state",
                error_message: "Can only cancel pending requests"
            });
            return false;
        }

        true
    }

    // GameMode access control functions
    fn assert_game_mode_access(
        game: @Game,
        allowed_modes: Span<GameMode>,
        caller: ContractAddress,
        action: felt252,
        mut world: WorldStorage
    ) -> bool {
        let current_mode = *game.game_mode;
        
        let mut is_allowed_mode = false;

        for mode in allowed_modes {
            if current_mode == *mode {
                is_allowed_mode = true;
                break;
            }
        };
        
        if is_allowed_mode {
            return true;
        }

        world.emit_event(@ErrorEvent {
            player_address: caller,
            name: 'Access Denied',
            message: format!("Action {} not allowed for GameMode {:?}", action, current_mode),
        });
        
        false
    }

    fn assert_tutorial_game_access(
        game: @Game,
        caller: ContractAddress,
        action: felt252,
        mut world: WorldStorage
    ) -> bool {
        if *game.game_mode != GameMode::Tutorial {
            world.emit_event(@ErrorEvent {
                player_address: caller,
                name: 'Invalid Game Mode',
                message: format!("Tutorial action {} requires Tutorial mode, got {:?}", action, *game.game_mode),
            });
            return false;
        }
        true
    }

    fn assert_regular_game_access(
        game: @Game,
        caller: ContractAddress,
        action: felt252,
        mut world: WorldStorage
    ) -> bool {
        let current_mode = *game.game_mode;
        if current_mode != GameMode::Ranked && current_mode != GameMode::Casual {
            world.emit_event(@ErrorEvent {
                player_address: caller,
                name: 'Invalid Game Mode',
                message: format!("Regular game action {} not allowed for GameMode {:?}", action, current_mode),
            });
            return false;
        }
        true
    }

    // // Tournament game access and payment validation
    // fn assert_can_enter_tournament_game(
    //     player_address: ContractAddress,
    //     tournament_id: u64,
    //     mut world: WorldStorage
    // ) -> bool {
    //     let mut store: Store = StoreTrait::new(world);
        
    //     // Try to get existing tournament balance
    //     let mut tournament_balance: TournamentBalance = store.get_tournament_balance(player_address, tournament_id);
        
    //     // Check if player has eEVLT tokens for this tournament
    //     if tournament_balance.can_spend(1) {
    //         // Spend 1 eEVLT for tournament game
    //         tournament_balance.spend_balance(1);
    //         store.set_tournament_balance(@tournament_balance);
            
    //         // Emit eEVLT burned event
    //         world.emit_event(@EevltBurned {
    //             player_address,
    //             tournament_id,
    //             amount: 1,
    //         });
            
    //         return true;
    //     }
        
    //     // No eEVLT available, try to spend EVLT token instead
    //     let evlt_dispatcher = store.evlt_token_dispatcher();
    //     let evlt_balance = evlt_dispatcher.balance_of(player_address);
        
    //     // Check if player has enough EVLT (1 EVLT = 1 tournament game)
    //     if evlt_balance >= 1 {
    //         // Burn 1 EVLT token
    //         evlt_dispatcher.burn(player_address, 1);
    //         return true;
    //     }
        
    //     // Neither eEVLT nor EVLT available
    //     world.emit_event(@ErrorEvent {
    //         player_address,
    //         name: 'Insufficient Tokens',
    //         message: "Not enough eEVLT or EVLT tokens to enter tournament game",
    //     });
        
    //     false
    // }
}


#[cfg(test)]
mod tests {
    use super::*;
    use dojo::world::WorldStorage;
    use evolute_duel::{
        models::{
            game::{Game, m_Game},
            player::{Player, m_Player},
            migration::{MigrationRequest, m_MigrationRequest}
        },
        types::packing::{GameStatus, GameMode},
        events::{
            e_GameCreateFailed, e_GameJoinFailed, e_PlayerNotInGame, e_GameFinished, e_MigrationError,
        },
    };
    use dojo_cairo_test::{spawn_test_world, NamespaceDef, TestResource};
    use starknet::{ContractAddress, contract_address_const};

    fn setup_world() -> WorldStorage {
        let namespace_def = NamespaceDef {
            namespace: "evolute_duel", resources: [
                TestResource::Model(m_Game::TEST_CLASS_HASH),
                TestResource::Model(m_Player::TEST_CLASS_HASH),
                TestResource::Model(m_MigrationRequest::TEST_CLASS_HASH),
                TestResource::Event(e_GameCreateFailed::TEST_CLASS_HASH),
                TestResource::Event(e_GameJoinFailed::TEST_CLASS_HASH),
                TestResource::Event(e_PlayerNotInGame::TEST_CLASS_HASH),
                TestResource::Event(e_GameFinished::TEST_CLASS_HASH),
                TestResource::Event(e_MigrationError::TEST_CLASS_HASH),
            ].span()
        };
        spawn_test_world([namespace_def].span())
    }

    fn create_game(player: ContractAddress, status: GameStatus, board_id: Option<felt252>) -> Game {
        Game {
            player,
            status,
            board_id,
            game_mode: GameMode::Tutorial,
        }
    }

    #[test]
    fn test_assert_ready_to_create_game_success() {
        let world = setup_world();
        let game = create_game(contract_address_const::<0x123>(), GameStatus::Finished, Option::None);
        
        let result = game.assert_ready_to_create_game(world);
        
        assert!(result == true, "Should be ready to create game");
    }

    #[test]
    fn test_assert_ready_to_create_game_already_created() {
        let world = setup_world();
        let game = create_game(contract_address_const::<0x123>(), GameStatus::Created, Option::None);
        
        let result = game.assert_ready_to_create_game(world);
        
        assert!(result == false, "Should not be ready to create game when already created");
    }

    #[test]
    fn test_assert_ready_to_create_game_in_progress() {
        let world = setup_world();
        let game = create_game(contract_address_const::<0x123>(), GameStatus::InProgress, Option::None);
        
        let result = game.assert_ready_to_create_game(world);
        
        assert!(result == false, "Should not be ready to create game when in progress");
    }

    #[test]
    fn test_assert_ready_to_join_game_success() {
        let world = setup_world();
        let host = create_game(contract_address_const::<0x123>(), GameStatus::Created, Option::None);
        let guest = create_game(contract_address_const::<0x456>(), GameStatus::Finished, Option::None);

        println!("Host: {:?}", host);
        println!("Guest: {:?}", guest);
        
        let result = AssertsTrait::assert_ready_to_join_game(@guest, @host, world);
        
        assert!(result == true, "Should be ready to join game");
    }

    #[test]
    fn test_assert_ready_to_join_game_host_not_created() {
        let world = setup_world();
        let host = create_game(contract_address_const::<0x123>(), GameStatus::InProgress, Option::None);
        let guest = create_game(contract_address_const::<0x456>(), GameStatus::Finished, Option::None);
        
        let result = AssertsTrait::assert_ready_to_join_game(@guest, @host, world);
        
        assert!(result == false, "Should not be ready to join when host not created");
    }

    #[test]
    fn test_assert_ready_to_join_game_guest_already_created() {
        let world = setup_world();
        let host = create_game(contract_address_const::<0x123>(), GameStatus::Created, Option::None);
        let guest = create_game(contract_address_const::<0x456>(), GameStatus::Created, Option::None);
        
        let result = AssertsTrait::assert_ready_to_join_game(@guest, @host, world);
        
        assert!(result == false, "Should not be ready to join when guest already created");
    }

    #[test]
    fn test_assert_ready_to_join_game_same_player() {
        let world = setup_world();
        let host = create_game(contract_address_const::<0x123>(), GameStatus::Created, Option::None);
        let guest = create_game(contract_address_const::<0x123>(), GameStatus::Finished, Option::None);
        
        let result = AssertsTrait::assert_ready_to_join_game(@guest, @host, world);
        
        assert!(result == false, "Should not be ready to join when same player");
    }

    #[test]
    fn test_assert_player_in_game_success() {
        let world = setup_world();
        let game = create_game(contract_address_const::<0x123>(), GameStatus::InProgress, Option::Some(456));
        
        let result = AssertsTrait::assert_player_in_game(@game, Option::Some(456), world);
        
        assert!(result == true, "Should be in game");
    }

    #[test]
    fn test_assert_player_in_game_no_board() {
        let world = setup_world();
        let game = create_game(contract_address_const::<0x123>(), GameStatus::InProgress, Option::None);
        
        let result = AssertsTrait::assert_player_in_game(@game, Option::Some(456), world);
        
        assert!(result == false, "Should not be in game when no board");
    }

    #[test]
    fn test_assert_player_in_game_wrong_board() {
        let world = setup_world();
        let game = create_game(contract_address_const::<0x123>(), GameStatus::InProgress, Option::Some(456));
        
        let result = AssertsTrait::assert_player_in_game(@game, Option::Some(789), world);
        
        assert!(result == false, "Should not be in game when wrong board");
    }

    #[test]
    fn test_assert_game_is_in_progress_success() {
        let world = setup_world();
        let game = create_game(contract_address_const::<0x123>(), GameStatus::InProgress, Option::Some(456));
        
        let result = AssertsTrait::assert_player_in_game(@game, Option::Some(456), world);
        
        assert!(result == true, "Should be in progress");
    }

    #[test]
    fn test_assert_game_is_in_progress_finished() {
        let world = setup_world();
        let game = create_game(contract_address_const::<0x123>(), GameStatus::Finished, Option::Some(456));
        
        let result = AssertsTrait::assert_player_in_game(@game, Option::None, world);
        
        assert!(result == false, "Should not be in progress when finished");
    }
}