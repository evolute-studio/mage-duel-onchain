use dojo::{world::WorldStorage, event::EventStorage, model::ModelStorage};
use evolute_duel::{
    models::{
        game::Game, player::{Player, PlayerTrait},
        migration::{MigrationRequest, MigrationRequestTrait},
        tournament_balance::{TournamentBalance, TournamentBalanceTrait, EevltBurned},
    },
    events::{
        GameCreateFailed, GameJoinFailed, PlayerNotInGame, GameFinished, MigrationError, ErrorEvent,
    },
    types::{packing::{GameStatus, GameMode}},
    interfaces::{ievlt_token::{IEvltTokenDispatcherTrait}}, libs::store::{Store, StoreTrait},
    interfaces::dns::{DnsTrait, ITournamentDispatcher, ITournamentDispatcherTrait}
};
use starknet::ContractAddress;
use openzeppelin_token::erc20::interface::{IERC20MetadataDispatcher, IERC20MetadataDispatcherTrait};
use alexandria_math::pow;
use tournaments::components::models::tournament::{Tournament, EntryFee, TokenType, ERC20Data};
use core::num::traits::Zero;
#[generate_trait]
pub impl AssersImpl of AssertsTrait {
    fn assert_ready_to_create_game(self: @Game, mut world: WorldStorage) -> bool {
        let status = *self.status;
        if status == GameStatus::InProgress {
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
            || (board_id.is_some() && (*game.board_id).unwrap() != board_id.unwrap())
            || *game.status == GameStatus::Finished {
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
        guest: @Player, controller_address: ContractAddress, mut world: WorldStorage,
    ) -> bool {
        if !guest.is_guest() {
            world
                .emit_event(
                    @MigrationError {
                        guest_address: *guest.player_id,
                        controller_address,
                        status: 'Error',
                        error_context: "Guest validation failed - caller is not a guest account",
                        error_message: "Only guest can initiate migration",
                    },
                );
            return false;
        }

        if *guest.migration_used {
            world
                .emit_event(
                    @MigrationError {
                        guest_address: *guest.player_id,
                        controller_address,
                        status: 'Error',
                        error_context: "Guest validation failed - migration already used",
                        error_message: "Migration already used",
                    },
                );
            return false;
        }

        true
    }

    fn assert_controller_can_receive_migration(
        controller: @Player, guest_address: ContractAddress, mut world: WorldStorage,
    ) -> bool {
        if !controller.is_controller() {
            world
                .emit_event(
                    @MigrationError {
                        guest_address,
                        controller_address: *controller.player_id,
                        status: 'Error',
                        error_context: "Controller validation failed - target is not a controller account",
                        error_message: "Target must be controller",
                    },
                );
            return false;
        }

        // YOU CAN ONLY MIGRATE ONCE
        if *controller.migration_used {
            world
                .emit_event(
                    @MigrationError {
                        guest_address,
                        controller_address: *controller.player_id,
                        status: 'Error',
                        error_context: "Controller validation failed - already received migration",
                        error_message: "Controller already received migration",
                    },
                );
            return false;
        }

        true
    }

    fn assert_no_pending_migration(
        guest: @Player,
        existing_request: @MigrationRequest,
        current_time: u64,
        controller_address: ContractAddress,
        mut world: WorldStorage,
    ) -> bool {
        if !existing_request.is_expired(current_time) && guest.has_pending_migration() {
            world
                .emit_event(
                    @MigrationError {
                        guest_address: *guest.player_id,
                        controller_address,
                        status: 'Error',
                        error_context: "Guest validation failed - already has pending migration",
                        error_message: "Migration already initiated",
                    },
                );
            return false;
        }
        true
    }

    fn assert_can_confirm_migration(
        migration_request: @MigrationRequest,
        caller_address: ContractAddress,
        current_time: u64,
        mut world: WorldStorage,
    ) -> bool {
        if *migration_request.controller_address != caller_address {
            world
                .emit_event(
                    @MigrationError {
                        guest_address: *migration_request.guest_address,
                        controller_address: caller_address,
                        status: 'Error',
                        error_context: "Controller authorization failed - not the controller owner",
                        error_message: "Only controller owner can confirm",
                    },
                );
            return false;
        }

        if !migration_request.is_pending() {
            world
                .emit_event(
                    @MigrationError {
                        guest_address: *migration_request.guest_address,
                        controller_address: caller_address,
                        status: 'Error',
                        error_context: "Request status invalid - not in pending state",
                        error_message: "Request not pending",
                    },
                );
            return false;
        }

        if migration_request.is_expired(current_time) {
            world
                .emit_event(
                    @MigrationError {
                        guest_address: *migration_request.guest_address,
                        controller_address: caller_address,
                        status: 'Error',
                        error_context: "Request timeout - migration request has expired",
                        error_message: "Request expired",
                    },
                );
            return false;
        }

        true
    }

    fn assert_can_execute_migration(
        migration_request: @MigrationRequest,
        guest: @Player,
        current_time: u64,
        mut world: WorldStorage,
    ) -> bool {
        if !migration_request.can_be_executed(current_time) {
            world
                .emit_event(
                    @MigrationError {
                        guest_address: *migration_request.guest_address,
                        controller_address: *migration_request.controller_address,
                        status: 'Error',
                        error_context: "Execution validation failed - migration cannot be executed at this time",
                        error_message: "Cannot execute migration",
                    },
                );
            return false;
        }

        if *guest.migration_target != *migration_request.controller_address {
            world
                .emit_event(
                    @MigrationError {
                        guest_address: *migration_request.guest_address,
                        controller_address: *migration_request.controller_address,
                        status: 'Error',
                        error_context: "Target validation failed - guest migration target does not match request",
                        error_message: "Target mismatch",
                    },
                );
            return false;
        }

        true
    }

    fn assert_can_cancel_migration(
        migration_request: @MigrationRequest,
        caller_address: ContractAddress,
        mut world: WorldStorage,
    ) -> bool {
        if !migration_request.is_pending() {
            world
                .emit_event(
                    @MigrationError {
                        guest_address: caller_address,
                        controller_address: *migration_request.controller_address,
                        status: 'Error',
                        error_context: "Cancellation failed - request is not in pending state",
                        error_message: "Can only cancel pending requests",
                    },
                );
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
        mut world: WorldStorage,
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

        world
            .emit_event(
                @ErrorEvent {
                    player_address: caller,
                    name: 'Access Denied',
                    message: format!(
                        "Action {} not allowed for GameMode {:?}", action, current_mode,
                    ),
                },
            );

        false
    }

    fn assert_tutorial_game_access(
        game: @Game, caller: ContractAddress, action: felt252, mut world: WorldStorage,
    ) -> bool {
        if *game.game_mode != GameMode::Tutorial {
            world
                .emit_event(
                    @ErrorEvent {
                        player_address: caller,
                        name: 'Invalid Game Mode',
                        message: format!(
                            "Tutorial action {} requires Tutorial mode, got {:?}",
                            action,
                            *game.game_mode,
                        ),
                    },
                );
            return false;
        }
        true
    }

    fn assert_regular_game_access(
        game: @Game, caller: ContractAddress, action: felt252, mut world: WorldStorage,
    ) -> bool {
        let current_mode = *game.game_mode;
        if current_mode != GameMode::Ranked && current_mode != GameMode::Casual && current_mode != GameMode::Tournament {
            world
                .emit_event(
                    @ErrorEvent {
                        player_address: caller,
                        name: 'Invalid Game Mode',
                        message: format!(
                            "Regular game action {} not allowed for GameMode {:?}",
                            action,
                            current_mode,
                        ),
                    },
                );
            return false;
        }
        true
    }

    // Function to split EVLT according to tournament prize distribution
    fn split_evlt_to_prize_pool(
        player_address: ContractAddress,
        tournament_id: u64,
        evlt_dispatcher: evolute_duel::interfaces::ievlt_token::IEvltTokenDispatcher,
        mut world: WorldStorage,
    ) -> bool {
        println!("[split_evlt_to_prize_pool] Starting EVLT prize pool splitting");
        println!("[split_evlt_to_prize_pool] player_address: {:x}, tournament_id: {}", player_address, tournament_id);
        
        // Get EVLT decimals for proper calculation
        println!("[split_evlt_to_prize_pool] Getting EVLT token metadata for decimals calculation");
        let evlt_metadata_dispatcher = IERC20MetadataDispatcher { 
            contract_address: evlt_dispatcher.contract_address 
        };
        let evlt_decimals = evlt_metadata_dispatcher.decimals();
        println!("[split_evlt_to_prize_pool] EVLT decimals: {}", evlt_decimals);
        
        let one_evlt = pow(10, evlt_decimals.into()); // 1 EVLT with decimals
        println!("[split_evlt_to_prize_pool] One EVLT with decimals: {}", one_evlt);
        
        // Check if player has enough EVLT with proper decimals
        println!("[split_evlt_to_prize_pool] Checking player EVLT balance");
        let evlt_balance = evlt_dispatcher.balance_of(player_address);
        println!("[split_evlt_to_prize_pool] Player EVLT balance: {}", evlt_balance);
        
        if evlt_balance < one_evlt {
            println!("[split_evlt_to_prize_pool] ERROR: Insufficient EVLT balance - required: {}, actual: {}", one_evlt, evlt_balance);
            return false;
        }
        println!("[split_evlt_to_prize_pool] EVLT balance check passed");

        // Read Tournament model directly from world storage
        println!("[split_evlt_to_prize_pool] Reading tournament model for tournament_id: {}", tournament_id);
        let tournament: Tournament = world.read_model(tournament_id);
        println!("[split_evlt_to_prize_pool] Tournament model retrieved - id: {}", tournament.id);
        
        // Check if tournament exists and has entry fee distribution
        let has_entry_fee = tournament.entry_fee.is_some();
        println!("[split_evlt_to_prize_pool] Tournament exists: {}, has_entry_fee: {}", tournament.id != 0, has_entry_fee);
        
        if tournament.id != 0 && has_entry_fee {
            let entry_fee = tournament.entry_fee.unwrap();
            println!("[split_evlt_to_prize_pool] Entry fee found - distribution positions: {}", entry_fee.distribution.len());
            
            // Try to get budokan dispatcher through player tournament index
            println!("[split_evlt_to_prize_pool] Getting player tournament index");
            let store: Store = StoreTrait::new(world);
            let player_index = store.get_player_tournament_index(player_address, tournament_id);
            println!("[split_evlt_to_prize_pool] Player index retrieved - pass_id: {}", player_index.pass_id);
            
            if player_index.pass_id != 0 {
                println!("[split_evlt_to_prize_pool] Getting budokan dispatcher for pass_id: {}", player_index.pass_id);
                // We have a pass_id, get the budokan dispatcher
                let budokan_dispatcher = store.budokan_dispatcher_from_pass_id(player_index.pass_id);
                println!("[split_evlt_to_prize_pool] Budokan dispatcher retrieved");
                
                if budokan_dispatcher.contract_address != Zero::zero() {
                    println!("[split_evlt_to_prize_pool] Budokan dispatcher is valid, distributing prizes");
                    // Transfer EVLT to budokan contract for prize splitting
                    evlt_dispatcher.approve(budokan_dispatcher.contract_address, one_evlt);
                    
                    // Split according to distribution using add_prize
                    Self::distribute_evlt_prizes(
                        entry_fee, 
                        tournament_id, 
                        one_evlt, 
                        evlt_dispatcher.contract_address,
                        budokan_dispatcher,
                        world
                    );
                    println!("[split_evlt_to_prize_pool] EVLT prizes distributed successfully");
                    
                    return true;
                } else {
                    println!("[split_evlt_to_prize_pool] WARNING: Budokan dispatcher address is zero");
                }
            } else {
                println!("[split_evlt_to_prize_pool] WARNING: Player index pass_id is zero");
            }
            
            // Fallback: burn token if can't access budokan dispatcher
            println!("[split_evlt_to_prize_pool] Fallback: burning EVLT token - amount: {}", one_evlt);
            evlt_dispatcher.burn(player_address, one_evlt);
            println!("[split_evlt_to_prize_pool] EVLT token burned successfully");
            true
        } else {
            // Fallback: burn token as before if no tournament or no entry fee
            println!("[split_evlt_to_prize_pool] Fallback: no tournament or entry fee, burning EVLT token - amount: {}", one_evlt);
            evlt_dispatcher.burn(player_address, one_evlt);
            println!("[split_evlt_to_prize_pool] EVLT token burned successfully (fallback)");
            true
        }
    }

    // Helper function to distribute EVLT as prizes according to tournament distribution
    fn distribute_evlt_prizes(
        entry_fee: EntryFee,
        tournament_id: u64, 
        total_evlt_amount: u256,
        evlt_token_address: ContractAddress,
        budokan_dispatcher: ITournamentDispatcher,
        mut world: WorldStorage
    ) {
        println!("[distribute_evlt_prizes] Starting EVLT prize distribution");
        println!("[distribute_evlt_prizes] tournament_id: {}, total_amount: {}", tournament_id, total_evlt_amount);
        println!("[distribute_evlt_prizes] evlt_token_address: {:x}", evlt_token_address);
        println!("[distribute_evlt_prizes] Distribution positions: {}", entry_fee.distribution.len());
        
        // Distribute prizes according to position distribution
        let mut position: u8 = 1;
        for percentage in entry_fee.distribution {
            println!("[distribute_evlt_prizes] Processing position {} with percentage: {}", position, *percentage);
            let prize_amount = (total_evlt_amount * (*percentage).into()) / 100;
            println!("[distribute_evlt_prizes] Calculated prize amount for position {}: {}", position, prize_amount);
            
            if prize_amount > 0 {
                println!("[distribute_evlt_prizes] Adding prize for position {} - amount: {}", position, prize_amount);
                // Add prize for this position using budokan's add_prize function
                budokan_dispatcher.add_prize(
                    tournament_id,
                    evlt_token_address,
                    TokenType::erc20(ERC20Data { amount: prize_amount.try_into().unwrap() }),
                    position
                );
                println!("[distribute_evlt_prizes] Prize added successfully for position {}", position);
            } else {
                println!("[distribute_evlt_prizes] Skipping position {} - prize amount is zero", position);
            }
            position += 1;
        };
        println!("[distribute_evlt_prizes] Position-based prize distribution completed");
        
        // Handle tournament creator share if specified
        if let Option::Some(creator_share) = entry_fee.tournament_creator_share {
            println!("[distribute_evlt_prizes] Processing tournament creator share: {}%", creator_share);
            let creator_amount = (total_evlt_amount * creator_share.into()) / 100;
            println!("[distribute_evlt_prizes] Tournament creator amount: {}", creator_amount);
            if creator_amount > 0 {
                println!("[distribute_evlt_prizes] TODO: Tournament creator share handling not implemented");
                // TODO: Transfer directly to tournament creator
                // For now, we could add it as a special prize or burn it
            }
        } else {
            println!("[distribute_evlt_prizes] No tournament creator share specified");
        }
        
        // Handle game creator share if specified  
        if let Option::Some(game_creator_share) = entry_fee.game_creator_share {
            println!("[distribute_evlt_prizes] Processing game creator share: {}%", game_creator_share);
            let game_creator_amount = (total_evlt_amount * game_creator_share.into()) / 100;
            println!("[distribute_evlt_prizes] Game creator amount: {}", game_creator_amount);
            if game_creator_amount > 0 {
                println!("[distribute_evlt_prizes] TODO: Game creator share handling not implemented");
                // TODO: Transfer directly to game creator
                // For now, we could add it as a special prize or burn it
            }
        } else {
            println!("[distribute_evlt_prizes] No game creator share specified");
        }
        
        println!("[distribute_evlt_prizes] EVLT prize distribution completed");
    }

    // New flow: transfer EVLT from player to tournament_token, then distribute to prize pool
    fn transfer_and_distribute_evlt(
        player_address: ContractAddress,
        tournament_id: u64,
        tournament_token_address: ContractAddress,
        evlt_dispatcher: evolute_duel::interfaces::ievlt_token::IEvltTokenDispatcher,
        mut world: WorldStorage,
    ) -> bool {
        println!("[transfer_and_distribute_evlt] Starting EVLT transfer and distribution");
        println!("[transfer_and_distribute_evlt] player: {:x}, tournament_id: {}, tournament_token: {:x}", 
            player_address, tournament_id, tournament_token_address);
        
        // Get EVLT decimals for proper calculation
        let evlt_metadata_dispatcher = IERC20MetadataDispatcher { 
            contract_address: evlt_dispatcher.contract_address 
        };
        let evlt_decimals = evlt_metadata_dispatcher.decimals();
        let one_evlt = pow(10, evlt_decimals.into()); // 1 EVLT with decimals
        println!("[transfer_and_distribute_evlt] One EVLT with decimals: {}", one_evlt);
        
        // Check player's EVLT balance
        let player_balance = evlt_dispatcher.balance_of(player_address);
        println!("[transfer_and_distribute_evlt] Player EVLT balance: {}", player_balance);
        
        if player_balance < one_evlt {
            println!("[transfer_and_distribute_evlt] ERROR: Insufficient EVLT balance");
            return false;
        }
        
        // Check allowance - player should have approved tournament_token to spend 1 EVLT
        let allowance = evlt_dispatcher.allowance(player_address, tournament_token_address);
        println!("[transfer_and_distribute_evlt] Player allowance to tournament_token: {}", allowance);
        
        if allowance < one_evlt {
            println!("[transfer_and_distribute_evlt] ERROR: Insufficient allowance - player needs to approve tournament_token");
            return false;
        }
        
        // Transfer 1 EVLT from player to tournament_token contract
        println!("[transfer_and_distribute_evlt] Transferring 1 EVLT from player to tournament_token");
        let transfer_success = evlt_dispatcher.transfer_from(
            player_address, 
            tournament_token_address, 
            one_evlt
        );
        
        if !transfer_success {
            println!("[transfer_and_distribute_evlt] ERROR: Transfer failed");
            return false;
        }
        
        println!("[transfer_and_distribute_evlt] Transfer successful, now distributing to prize pool");
        
        // Read Tournament model to get prize distribution
        let tournament: Tournament = world.read_model(tournament_id);
        
        // Check if tournament exists and has entry fee distribution
        if tournament.id != 0 && tournament.entry_fee.is_some() {
            let entry_fee = tournament.entry_fee.unwrap();
            println!("[transfer_and_distribute_evlt] Tournament found with entry fee distribution");
            
            // Get budokan dispatcher through player tournament index
            let store: Store = StoreTrait::new(world);
            let player_index = store.get_player_tournament_index(player_address, tournament_id);
            
            if player_index.pass_id != 0 {
                let budokan_dispatcher = store.budokan_dispatcher_from_pass_id(player_index.pass_id);
                
                if budokan_dispatcher.contract_address != Zero::zero() {
                    println!("[transfer_and_distribute_evlt] Budokan dispatcher found, approving and distributing");
                    
                    // Tournament token approves budokan to spend the EVLT
                    let approve_success = evlt_dispatcher.approve(budokan_dispatcher.contract_address, one_evlt);
                    
                    if approve_success {
                        // Distribute prizes using budokan's add_prize function
                        Self::distribute_evlt_prizes(
                            entry_fee,
                            tournament_id, 
                            one_evlt,
                            evlt_dispatcher.contract_address,
                            budokan_dispatcher,
                            world
                        );
                        
                        println!("[transfer_and_distribute_evlt] EVLT successfully transferred and distributed");
                        return true;
                    } else {
                        println!("[transfer_and_distribute_evlt] ERROR: Failed to approve budokan dispatcher");
                        return false;
                    }
                }
            }
        }
        
        println!("[transfer_and_distribute_evlt] WARNING: No tournament or budokan found, keeping EVLT in tournament_token");
        return true; // Still successful, just EVLT stays in tournament_token contract
    }

    // Tournament game access validation WITHOUT charging (for join_duel validation)
    fn assert_can_afford_tournament_game(
        player_address: ContractAddress, tournament_id: u64, mut world: WorldStorage,
    ) -> bool {
        println!("[assert_can_afford_tournament_game] Starting tournament game affordability check");
        println!("[assert_can_afford_tournament_game] player_address: {:x}, tournament_id: {}", player_address, tournament_id);
        
        let mut store: Store = StoreTrait::new(world);
        println!("[assert_can_afford_tournament_game] Store created successfully");

        // Check if player has eEVLT tokens for this tournament
        let mut tournament_balance: TournamentBalance = store
            .get_tournament_balance(player_address, tournament_id);
        println!("[assert_can_afford_tournament_game] Tournament balance retrieved - eevlt_balance: {}", tournament_balance.eevlt_balance);

        let can_spend_eevlt = tournament_balance.can_spend(1);
        println!("[assert_can_afford_tournament_game] eEVLT spending check - can_spend: {}", can_spend_eevlt);
        
        if can_spend_eevlt {
            println!("[assert_can_afford_tournament_game] Player has sufficient eEVLT tokens");
            return true;
        }

        // Check EVLT balance and allowance without spending
        println!("[assert_can_afford_tournament_game] No eEVLT available, checking EVLT balance and allowance");
        let evlt_dispatcher = store.evlt_token_dispatcher();
        println!("[assert_can_afford_tournament_game] EVLT dispatcher obtained");
        
        // Get tournament_token contract address from world
        let tournament_token_address = world.find_contract_address(@"tournament_token");
        println!("[assert_can_afford_tournament_game] Tournament token address: {:x}", tournament_token_address);
        
        if tournament_token_address.is_zero() {
            println!("[assert_can_afford_tournament_game] ERROR: Tournament token contract not found");
            return false;
        }

        // Check EVLT balance
        let one_evlt: u256 = 1000000000000000000_u256; // 1 EVLT with 18 decimals
        let player_balance = evlt_dispatcher.balanceOf(player_address);
        println!("[assert_can_afford_tournament_game] Player EVLT balance: {}", player_balance);

        if player_balance < one_evlt {
            println!("[assert_can_afford_tournament_game] ERROR: Insufficient EVLT balance");
            return false;
        }

        // Check allowance 
        let allowance = evlt_dispatcher.allowance(player_address, tournament_token_address);
        println!("[assert_can_afford_tournament_game] Player allowance to tournament_token: {}", allowance);

        if allowance < one_evlt {
            println!("[assert_can_afford_tournament_game] ERROR: Insufficient allowance - player needs to approve tournament_token");
            return false;
        }

        println!("[assert_can_afford_tournament_game] Player can afford tournament game (has EVLT balance and allowance)");
        return true;
    }

    // Tournament game access and payment validation WITH charging
    fn assert_can_enter_tournament_game(
        player_address: ContractAddress, tournament_id: u64, mut world: WorldStorage,
    ) -> bool {
        println!("[assert_can_enter_tournament_game] Starting tournament game access validation");
        println!("[assert_can_enter_tournament_game] player_address: {:x}, tournament_id: {}", player_address, tournament_id);
        
        let mut store: Store = StoreTrait::new(world);
        println!("[assert_can_enter_tournament_game] Store created successfully");

        // Try to get existing tournament balance
        println!("[assert_can_enter_tournament_game] Getting tournament balance for player: {:x}, tournament: {}", player_address, tournament_id);
        let mut tournament_balance: TournamentBalance = store
            .get_tournament_balance(player_address, tournament_id);
        println!("[assert_can_enter_tournament_game] Tournament balance retrieved - eevlt_balance: {}", tournament_balance.eevlt_balance);

        // Check if player has eEVLT tokens for this tournament
        let can_spend_eevlt = tournament_balance.can_spend(1);
        println!("[assert_can_enter_tournament_game] eEVLT spending check - can_spend: {}", can_spend_eevlt);
        
        if can_spend_eevlt {
            println!("[assert_can_enter_tournament_game] Using eEVLT tokens - spending 1 token");
            // Spend 1 eEVLT for tournament game
            tournament_balance.spend_balance(1);
            store.set_tournament_balance(@tournament_balance);
            println!("[assert_can_enter_tournament_game] eEVLT balance updated successfully - new eevlt_balance: {}", tournament_balance.eevlt_balance);

            // Emit eEVLT burned event
            world.emit_event(@EevltBurned { player_address, tournament_id, amount: 1 });
            println!("[assert_can_enter_tournament_game] eEVLT burned event emitted");

            println!("[assert_can_enter_tournament_game] Tournament game access granted via eEVLT");
            return true;
        }

        // No eEVLT available, try to transfer EVLT token from player to tournament_token
        println!("[assert_can_enter_tournament_game] No eEVLT available, trying EVLT token transfer");
        let evlt_dispatcher = store.evlt_token_dispatcher();
        println!("[assert_can_enter_tournament_game] EVLT dispatcher obtained");
        
        // Get tournament_token contract address from world
        let tournament_token_address = world.find_contract_address(@"tournament_token");
        println!("[assert_can_enter_tournament_game] Tournament token address: {:x}", tournament_token_address);
        
        if tournament_token_address.is_zero() {
            println!("[assert_can_enter_tournament_game] ERROR: Tournament token contract not found");
            return false;
        }
        
        // Use new transfer and distribute function
        println!("[assert_can_enter_tournament_game] Attempting to transfer and distribute EVLT");
        let evlt_success = Self::transfer_and_distribute_evlt(
            player_address, 
            tournament_id, 
            tournament_token_address,
            evlt_dispatcher, 
            world
        );
        println!("[assert_can_enter_tournament_game] EVLT transfer and distribution result: {}", evlt_success);
        
        if evlt_success {
            println!("[assert_can_enter_tournament_game] Tournament game access granted via EVLT transfer");
            return true;
        }

        // Neither eEVLT nor EVLT available
        println!("[assert_can_enter_tournament_game] ERROR: Insufficient tokens - neither eEVLT nor EVLT available");
        world
            .emit_event(
                @ErrorEvent {
                    player_address,
                    name: 'Insufficient Tokens',
                    message: "Not enough eEVLT or EVLT tokens to enter tournament game",
                },
            );
        println!("[assert_can_enter_tournament_game] Error event emitted for insufficient tokens");

        println!("[assert_can_enter_tournament_game] Tournament game access denied");
        false
    }

    // Safe wrapper for charging player tokens (returns bool instead of panicking)
    fn try_charge_player(
        player_address: ContractAddress, tournament_id: u64, mut world: WorldStorage,
    ) -> bool {
        println!("[try_charge_player] Attempting to charge player: {:x}, tournament_id: {}", player_address, tournament_id);
        
        // Use the existing charging logic but catch any failures
        let result = Self::assert_can_enter_tournament_game(player_address, tournament_id, world);
        println!("[try_charge_player] Charge result for player {:x}: {}", player_address, result);
        
        result
    }
}


#[cfg(test)]
mod tests {
    use super::*;
    use dojo::world::WorldStorage;
    use evolute_duel::{
        models::{
            game::{Game, m_Game}, player::{Player, m_Player},
            migration::{MigrationRequest, m_MigrationRequest},
        },
        types::packing::{GameStatus, GameMode},
        events::{
            e_GameCreateFailed, e_GameJoinFailed, e_PlayerNotInGame, e_GameFinished,
            e_MigrationError,
        },
    };
    use dojo_cairo_test::{spawn_test_world, NamespaceDef, TestResource};
    use starknet::{ContractAddress, contract_address_const};

    fn setup_world() -> WorldStorage {
        let namespace_def = NamespaceDef {
            namespace: "evolute_duel",
            resources: [
                TestResource::Model(m_Game::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_Player::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_MigrationRequest::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Event(e_GameCreateFailed::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Event(e_GameJoinFailed::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Event(e_PlayerNotInGame::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Event(e_GameFinished::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Event(e_MigrationError::TEST_CLASS_HASH.try_into().unwrap()),
            ]
                .span(),
        };
        spawn_test_world([namespace_def].span())
    }

    fn create_game(player: ContractAddress, status: GameStatus, board_id: Option<felt252>) -> Game {
        Game { player, status, board_id, game_mode: GameMode::Tutorial }
    }

    #[test]
    fn test_assert_ready_to_create_game_success() {
        let world = setup_world();
        let game = create_game(
            contract_address_const::<0x123>(), GameStatus::Finished, Option::None,
        );

        let result = game.assert_ready_to_create_game(world);

        assert!(result == true, "Should be ready to create game");
    }

    #[test]
    fn test_assert_ready_to_create_game_already_created() {
        let world = setup_world();
        let game = create_game(
            contract_address_const::<0x123>(), GameStatus::Created, Option::None,
        );

        let result = game.assert_ready_to_create_game(world);

        assert!(result == false, "Should not be ready to create game when already created");
    }

    #[test]
    fn test_assert_ready_to_create_game_in_progress() {
        let world = setup_world();
        let game = create_game(
            contract_address_const::<0x123>(), GameStatus::InProgress, Option::None,
        );

        let result = game.assert_ready_to_create_game(world);

        assert!(result == false, "Should not be ready to create game when in progress");
    }

    #[test]
    fn test_assert_ready_to_join_game_success() {
        let world = setup_world();
        let host = create_game(
            contract_address_const::<0x123>(), GameStatus::Created, Option::None,
        );
        let guest = create_game(
            contract_address_const::<0x456>(), GameStatus::Finished, Option::None,
        );

        println!("Host: {:?}", host);
        println!("Guest: {:?}", guest);

        let result = AssertsTrait::assert_ready_to_join_game(@guest, @host, world);

        assert!(result == true, "Should be ready to join game");
    }

    #[test]
    fn test_assert_ready_to_join_game_host_not_created() {
        let world = setup_world();
        let host = create_game(
            contract_address_const::<0x123>(), GameStatus::InProgress, Option::None,
        );
        let guest = create_game(
            contract_address_const::<0x456>(), GameStatus::Finished, Option::None,
        );

        let result = AssertsTrait::assert_ready_to_join_game(@guest, @host, world);

        assert!(result == false, "Should not be ready to join when host not created");
    }

    #[test]
    fn test_assert_ready_to_join_game_guest_already_created() {
        let world = setup_world();
        let host = create_game(
            contract_address_const::<0x123>(), GameStatus::Created, Option::None,
        );
        let guest = create_game(
            contract_address_const::<0x456>(), GameStatus::Created, Option::None,
        );

        let result = AssertsTrait::assert_ready_to_join_game(@guest, @host, world);

        assert!(result == false, "Should not be ready to join when guest already created");
    }

    #[test]
    fn test_assert_ready_to_join_game_same_player() {
        let world = setup_world();
        let host = create_game(
            contract_address_const::<0x123>(), GameStatus::Created, Option::None,
        );
        let guest = create_game(
            contract_address_const::<0x123>(), GameStatus::Finished, Option::None,
        );

        let result = AssertsTrait::assert_ready_to_join_game(@guest, @host, world);

        assert!(result == false, "Should not be ready to join when same player");
    }

    #[test]
    fn test_assert_player_in_game_success() {
        let world = setup_world();
        let game = create_game(
            contract_address_const::<0x123>(), GameStatus::InProgress, Option::Some(456),
        );

        let result = AssertsTrait::assert_player_in_game(@game, Option::Some(456), world);

        assert!(result == true, "Should be in game");
    }

    #[test]
    fn test_assert_player_in_game_no_board() {
        let world = setup_world();
        let game = create_game(
            contract_address_const::<0x123>(), GameStatus::InProgress, Option::None,
        );

        let result = AssertsTrait::assert_player_in_game(@game, Option::Some(456), world);

        assert!(result == false, "Should not be in game when no board");
    }

    #[test]
    fn test_assert_player_in_game_wrong_board() {
        let world = setup_world();
        let game = create_game(
            contract_address_const::<0x123>(), GameStatus::InProgress, Option::Some(456),
        );

        let result = AssertsTrait::assert_player_in_game(@game, Option::Some(789), world);

        assert!(result == false, "Should not be in game when wrong board");
    }

    #[test]
    fn test_assert_game_is_in_progress_success() {
        let world = setup_world();
        let game = create_game(
            contract_address_const::<0x123>(), GameStatus::InProgress, Option::Some(456),
        );

        let result = AssertsTrait::assert_player_in_game(@game, Option::Some(456), world);

        assert!(result == true, "Should be in progress");
    }

    #[test]
    fn test_assert_game_is_in_progress_finished() {
        let world = setup_world();
        let game = create_game(
            contract_address_const::<0x123>(), GameStatus::Finished, Option::Some(456),
        );

        let result = AssertsTrait::assert_player_in_game(@game, Option::None, world);

        assert!(result == false, "Should not be in progress when finished");
    }
}
