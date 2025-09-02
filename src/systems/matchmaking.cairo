use starknet::ContractAddress;

/// Interface for universal matchmaking system supporting all game modes.
#[starknet::interface]
pub trait IMatchmaking<T> {
    /// Create a new game in the specified mode.
    /// - `game_mode`: The mode of the game (Tutorial, Ranked, Casual).
    /// - `opponent`: Optional opponent address (required for tutorial, optional for others).
    fn create_game(ref self: T, game_mode: u8, opponent: Option<ContractAddress>);

    /// Join an existing game created by another player.
    /// - `host_player`: Address of the player who created the game.
    fn join_game(ref self: T, host_player: ContractAddress);

    /// Cancel a created game that hasn't been joined yet.
    fn cancel_game(ref self: T);


    /// Update configuration for a specific game mode (admin only).
    /// - `game_mode`: The game mode to update.
    /// - `board_size`: Size of the game board.
    /// - `deck_type`: Type of deck to use.
    /// - `initial_jokers`: Number of joker tiles per player.
    /// - `time_per_phase`: Time limit per phase in seconds.
    /// - `auto_match`: Whether to enable automatic matchmaking.
    /// - `deck`: Defines the number of each tile type in the deck.
    /// - `edges`: Initial setup of city and road elements on the board edges.
    /// - `joker_price`: Cost of using a joker tile.
    fn update_config(
        ref self: T,
        game_mode: u8,
        board_size: u8,
        deck_type: u8,
        initial_jokers: u8,
        time_per_phase: u64,
        auto_match: bool,
        deck: Span<u8>,
        edges: (u8, u8),
        joker_price: u16,
    );

    /// Automatic matchmaking - join queue and get matched automatically.
    /// - `game_mode`: The mode of the game (Tournament, Ranked, Casual).
    /// - `tournament_id`: Optional tournament ID for tournament mode.
    /// Returns: board_id if match found, 0 if waiting in queue.
    fn auto_match(ref self: T, game_mode: u8, tournament_id: Option<u64>) -> felt252;

    /// Admin function to cancel any game (admin only).
    /// - `player_address`: Address of the player whose game should be canceled.
    fn admin_cancel_game(ref self: T, player_address: ContractAddress);

    /// Set the admin address (current admin only).
    /// - `new_admin`: Address of the new admin.
    fn admin_set_admin(ref self: T, new_admin: ContractAddress);
}

// dojo decorator
#[dojo::contract]
pub mod matchmaking {
    use super::*;
    use starknet::{ContractAddress, get_caller_address};
    use core::starknet::storage::{StoragePointerWriteAccess};
    use dojo::{event::EventStorage, model::{ModelStorage}};
    use dojo::world::{WorldStorage};
    use evolute_duel::{
        libs::{asserts::AssertsTrait, phase_management::{PhaseManagementTrait}},
        models::{game::{Game, GameModeConfig, MatchmakingState, PlayerMatchmaking}, tournament_matchmaking::{TournamentELOTrait}, tournament::{TournamentBoard}},
        events::{GameCreated, GameStarted, GameCanceled}, types::{packing::{GameStatus, GameMode}},
        systems::helpers::{board::{BoardTrait}},
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

    fn dojo_init(ref self: ContractState, initial_owner: ContractAddress) {
        self.ownable.initializer(initial_owner);

        let mut world = self.world_default();

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

        // Initialize default game configurations for all modes
        // Tutorial configuration
        let tutorial_config = GameModeConfig {
            game_mode: GameMode::Tutorial,
            board_size: 7,
            deck_type: 0, // Tutorial deck
            initial_jokers: 3,
            time_per_phase: 0, // No time limit
            auto_match: false,
            deck,
            edges,
            joker_price,
        };
        world.write_model(@tutorial_config);

        // Ranked configuration
        let ranked_config = GameModeConfig {
            game_mode: GameMode::Ranked,
            board_size: 10,
            deck_type: 1, // Full randomized deck
            initial_jokers: 2,
            time_per_phase: 60, // 1 minute per phase
            auto_match: true,
            deck,
            edges,
            joker_price,
        };
        world.write_model(@ranked_config);

        // Casual configuration
        let casual_config = GameModeConfig {
            game_mode: GameMode::Casual,
            board_size: 10,
            deck_type: 1, // Full randomized deck
            initial_jokers: 2,
            time_per_phase: 0, // No time limit
            auto_match: false,
            deck,
            edges,
            joker_price,
        };
        world.write_model(@casual_config);

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
        world.write_model(@tournament_config);
    }


    #[abi(embed_v0)]
    impl MatchmakingImpl of IMatchmaking<ContractState> {
        fn create_game(ref self: ContractState, game_mode: u8, opponent: Option<ContractAddress>) {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let mode: GameMode = game_mode.into();

            println!(
                "[MATCHMAKING] create_game: caller={:x}, game_mode={}, mode={:?}",
                caller,
                game_mode,
                mode,
            );

            // Get game configuration for this mode
            let config: GameModeConfig = world.read_model(mode);
            println!(
                "[MATCHMAKING] create_game: config loaded - board_size={}, deck_type={}, jokers={}, time={}, auto_match={}",
                config.board_size,
                config.deck_type,
                config.initial_jokers,
                config.time_per_phase,
                config.auto_match,
            );

            // Validate player can create game
            let mut game: Game = world.read_model(caller);
            println!(
                "[MATCHMAKING] create_game: current game state - status={:?}, game_mode={:?}, board_id={:?}",
                game.status,
                game.game_mode,
                game.board_id,
            );

            if !AssertsTrait::assert_ready_to_create_game(@game, world) {
                println!("[MATCHMAKING] create_game: FAILED - player not ready to create game");
                return;
            }

            println!("[MATCHMAKING] create_game: player validation passed");

            if !AssertsTrait::assert_game_mode_access(
                @game, array![GameMode::None].span(), caller, 'create_game', world,
            ) {
                println!("[MATCHMAKING] create_game: FAILED - no access to game mode");
                return;
            }

            println!("[MATCHMAKING] create_game: game mode access granted");

            match mode {
                GameMode::Tutorial => {
                    println!("[MATCHMAKING] create_game: entering Tutorial mode");
                    // Tutorial requires bot opponent
                    let bot_address = opponent.expect('Bot address required');
                    println!("[MATCHMAKING] create_game: Tutorial bot_address={:x}", bot_address);
                    self._create_tutorial_game(caller, bot_address, config);
                },
                GameMode::Ranked |
                GameMode::Casual => {
                    println!("[MATCHMAKING] create_game: entering Ranked/Casual mode");
                    // Validate access to create regular games
                    // Regular games - create and wait for opponent
                    game.status = GameStatus::Created;
                    game.board_id = Option::None;
                    game.game_mode = mode;
                    world.write_model(@game);

                    println!(
                        "[MATCHMAKING] create_game: game created successfully - waiting for opponent",
                    );

                    world
                        .emit_event(
                            @GameCreated { host_player: caller, status: GameStatus::Created },
                        );
                },
                _ => { println!("[MATCHMAKING] create_game: unsupported game mode"); },
            }

            println!("[MATCHMAKING] create_game: function completed");
        }

        fn join_game(ref self: ContractState, host_player: ContractAddress) {
            let mut world = self.world_default();
            let guest_player = get_caller_address();

            println!("[MATCHMAKING] join_game: guest={:x}, host={:x}", guest_player, host_player);

            // Get host game info
            let mut host_game: Game = world.read_model(host_player);
            let mut guest_game: Game = world.read_model(guest_player);

            println!(
                "[MATCHMAKING] join_game: host_game - status={:?}, mode={:?}, board_id={:?}",
                host_game.status,
                host_game.game_mode,
                host_game.board_id,
            );
            println!(
                "[MATCHMAKING] join_game: guest_game - status={:?}, mode={:?}, board_id={:?}",
                guest_game.status,
                guest_game.game_mode,
                guest_game.board_id,
            );

            // Validate join conditions
            if !AssertsTrait::assert_ready_to_join_game(@guest_game, @host_game, world) {
                println!("[MATCHMAKING] join_game: FAILED - guest not ready to join game");
                return;
            }

            println!("[MATCHMAKING] join_game: join conditions validated");

            // Validate guest can join this game mode
            if !AssertsTrait::assert_game_mode_access(
                @host_game,
                array![GameMode::Ranked, GameMode::Casual].span(),
                guest_player,
                'join_game',
                world,
            ) {
                println!("[MATCHMAKING] join_game: FAILED - guest has no access to game mode");
                return;
            }

            println!("[MATCHMAKING] join_game: game mode access granted");

            // Get configuration for this game mode
            let config: GameModeConfig = world.read_model(host_game.game_mode);
            println!("[MATCHMAKING] join_game: config loaded for mode={:?}", host_game.game_mode);

            // Create board based on game mode configuration
            println!("[MATCHMAKING] join_game: creating board for game mode");
            let board = self
                ._create_board_for_mode(
                    host_player, guest_player, host_game.game_mode, config, 0, world,
                );
            println!("[MATCHMAKING] join_game: board created with id={}", board.id);

            // Update both players' game state
            host_game.status = GameStatus::InProgress;
            host_game.board_id = Option::Some(board.id);
            world.write_model(@host_game);
            println!("[MATCHMAKING] join_game: host game updated to InProgress");

            guest_game.status = GameStatus::InProgress;
            guest_game.board_id = Option::Some(board.id);
            guest_game.game_mode = host_game.game_mode;
            world.write_model(@guest_game);
            println!("[MATCHMAKING] join_game: guest game updated to InProgress");

            world.emit_event(@GameStarted { host_player, guest_player, board_id: board.id });

            println!("[MATCHMAKING] join_game: GameStarted event emitted, function completed");
        }

        fn cancel_game(ref self: ContractState) {
            let caller = get_caller_address();

            println!("[MATCHMAKING] cancel_game: caller={:x}", caller);

            // Use internal function with permission checks enabled
            self._cancel_game(caller);
        }


        fn update_config(
            ref self: ContractState,
            game_mode: u8,
            board_size: u8,
            deck_type: u8,
            initial_jokers: u8,
            time_per_phase: u64,
            auto_match: bool,
            deck: Span<u8>,
            edges: (u8, u8),
            joker_price: u16,
        ) {
            let mut world = self.world_default();
            let mode: GameMode = game_mode.into();

            // TODO: Add admin check here
            // assert!(is_admin(get_caller_address()), "Only admin can update configs");

            let config = GameModeConfig {
                game_mode: mode,
                board_size,
                deck_type,
                initial_jokers,
                time_per_phase,
                auto_match,
                deck,
                edges,
                joker_price,
            };
            world.write_model(@config);
        }

        fn auto_match(
            ref self: ContractState, game_mode: u8, tournament_id: Option<u64>,
        ) -> felt252 {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let mode: GameMode = game_mode.into();
            let tid = tournament_id.unwrap_or(0);

            println!(
                "[MATCHMAKING] auto_match: caller={:x}, mode={:?}, tournament_id={:?}",
                caller,
                mode,
                tournament_id,
            );

            // Validate caller's game state
            let mut caller_game: Game = world.read_model(caller);
            println!(
                "[MATCHMAKING] auto_match: caller_game - status={:?}, mode={:?}, board_id={:?}",
                caller_game.status,
                caller_game.game_mode,
                caller_game.board_id,
            );

            if !AssertsTrait::assert_ready_to_create_game(@caller_game, world) {
                println!(
                    "[MATCHMAKING] auto_match: FAILED - caller not ready to create game, returning 0",
                );
                return 0;
            }

            println!("[MATCHMAKING] auto_match: caller validation passed");

            // For Tournament mode, use modernized ELO-based matchmaking with radius
            if mode == GameMode::Tournament && tid > 0 {
                println!("[MATCHMAKING] auto_match: Using modernized tournament ELO matchmaking with radius");
                
                // Use tournament ELO system to find opponent within radius
                match TournamentELOTrait::find_tournament_opponent(caller, tid, world) {
                    Option::Some(opponent) => {
                        println!("[MATCHMAKING] auto_match: Tournament opponent found: {:x}", opponent);
                        
                        // Charge tokens for both players - if either fails, handle gracefully
                        let caller_charged = AssertsTrait::try_charge_player(caller, tid, world);
                        let opponent_charged = AssertsTrait::try_charge_player(opponent, tid, world);
                        
                        println!("[MATCHMAKING] auto_match: Token charging - caller: {}, opponent: {}", caller_charged, opponent_charged);
                        
                        match (caller_charged, opponent_charged) {
                            (true, true) => {
                                println!("[MATCHMAKING] auto_match: Both players successfully charged - proceeding with match");
                                
                                // Get opponent game state
                                let mut opponent_game: Game = world.read_model(opponent);
                                
                                // Get game configuration
                                let config: GameModeConfig = world.read_model(mode);
                                
                                // Create board for the match
                                let board = self._create_board_for_mode(
                                    opponent, caller, mode, config, tid, world,
                                );
                                
                                // Update both players' game states
                                opponent_game.status = GameStatus::InProgress;
                                opponent_game.board_id = Option::Some(board.id);
                                opponent_game.game_mode = mode;
                                world.write_model(@opponent_game);
                                
                                caller_game.status = GameStatus::InProgress;
                                caller_game.board_id = Option::Some(board.id);
                                caller_game.game_mode = mode;
                                world.write_model(@caller_game);
                                
                                // Emit events for both players
                                world.emit_event(
                                    @GameStarted {
                                        host_player: opponent, guest_player: caller, board_id: board.id,
                                    },
                                );
                                
                                println!("[MATCHMAKING] auto_match: Tournament match successful! board_id={}", board.id);
                                return board.id;
                            },
                            (false, true) => {
                                println!("[MATCHMAKING] auto_match: Caller failed to pay, opponent charged successfully - removing caller from queue, keeping opponent");
                                self._remove_from_tournament_queue(caller, tid, world);
                                return 0; // Caller fails, returns 0
                            },
                            (true, false) => {
                                println!("[MATCHMAKING] auto_match: Opponent failed to pay, caller charged successfully - removing opponent from queue, keeping caller in queue");
                                self._remove_from_tournament_queue(opponent, tid, world);
                                return 0; // Opponent fails, returns 0
                            },
                            (false, false) => {
                                println!("[MATCHMAKING] auto_match: Both players failed to pay - removing both from queue");
                                self._remove_from_tournament_queue(caller, tid, world);
                                self._remove_from_tournament_queue(opponent, tid, world);
                                return 0; // Both fail, caller returns 0
                            },
                        }
                    },
                    Option::None => {
                        println!("[MATCHMAKING] auto_match: No opponent found within league radius, player added to tournament queue");
                        
                        // Player was automatically added to their league by find_tournament_opponent
                        // Update caller's game state to Created (waiting)
                        caller_game.status = GameStatus::Created;
                        caller_game.board_id = Option::None;
                        caller_game.game_mode = mode;
                        world.write_model(@caller_game);
                        
                        // Emit GameCreated event for convenient client interface
                        world.emit_event(
                            @GameCreated { host_player: caller, status: GameStatus::Created },
                        );
                        
                        println!("[MATCHMAKING] auto_match: Player added to queue, GameCreated event emitted");
                        return 0;
                    }
                }
            } else {
                // Non-tournament modes: use existing FIFO algorithm
                println!("[MATCHMAKING] auto_match: Using FIFO matchmaking for non-tournament mode");
                
                // Get or create matchmaking queue state
                let mut queue_state: MatchmakingState = world.read_model((mode, tid));
                println!(
                    "[MATCHMAKING] auto_match: queue state - waiting_players.len()={}",
                    queue_state.waiting_players.len(),
                );

                // Simple FIFO algorithm: check if there's a waiting player
                if queue_state.waiting_players.len() > 0 {
                    println!(
                        "[MATCHMAKING] auto_match: MATCH FOUND! Processing existing waiting player",
                    );
                    // Match found! Get the first waiting player
                    let mut waiting_players_vec = queue_state.waiting_players.span();
                    let opponent = *waiting_players_vec[0];
                    println!("[MATCHMAKING] auto_match: opponent={:x}", opponent);

                    // Remove opponent from queue (create new array without first element)
                    let mut new_waiting_players: Array<ContractAddress> = ArrayTrait::new();
                    let mut i = 1;
                    while i < waiting_players_vec.len() {
                        new_waiting_players.append(*waiting_players_vec[i]);
                        i += 1;
                    };
                    queue_state.waiting_players = new_waiting_players.clone();
                    world.write_model(@queue_state);
                    println!(
                        "[MATCHMAKING] auto_match: opponent removed from queue, new queue size={}",
                        new_waiting_players.len(),
                    );

                    // Remove opponent from PlayerMatchmaking
                    let empty_opponent_mm = PlayerMatchmaking {
                        player: opponent, game_mode: GameMode::None, tournament_id: 0, timestamp: 0,
                    };
                    world.write_model(@empty_opponent_mm);
                    println!("[MATCHMAKING] auto_match: opponent PlayerMatchmaking cleared");

                    // Get opponent game state
                    let mut opponent_game: Game = world.read_model(opponent);
                    println!(
                        "[MATCHMAKING] auto_match: opponent_game - status={:?}, mode={:?}",
                        opponent_game.status,
                        opponent_game.game_mode,
                    );

                    // Get game configuration
                    let config: GameModeConfig = world.read_model(mode);
                    println!("[MATCHMAKING] auto_match: config loaded for mode={:?}", mode);

                    // Create board for the match
                    println!("[MATCHMAKING] auto_match: creating board for match");
                    let board = self
                        ._create_board_for_mode(
                            opponent, // host_player (first in queue)
                            caller, // guest_player (joining now)
                            mode,
                            config,
                            tid, // tournament_id
                            world,
                        );
                    println!("[MATCHMAKING] auto_match: board created with id={}", board.id);

                    // Update both players' game states
                    opponent_game.status = GameStatus::InProgress;
                    opponent_game.board_id = Option::Some(board.id);
                    opponent_game.game_mode = mode;
                    world.write_model(@opponent_game);
                    println!("[MATCHMAKING] auto_match: opponent game updated to InProgress");

                    caller_game.status = GameStatus::InProgress;
                    caller_game.board_id = Option::Some(board.id);
                    caller_game.game_mode = mode;
                    world.write_model(@caller_game);
                    println!("[MATCHMAKING] auto_match: caller game updated to InProgress");

                    // Emit events
                    world
                        .emit_event(
                            @GameStarted {
                                host_player: opponent, guest_player: caller, board_id: board.id,
                            },
                        );
                    println!("[MATCHMAKING] auto_match: GameStarted event emitted");

                    // Return board_id
                    println!(
                        "[MATCHMAKING] auto_match: MATCH SUCCESSFUL! Returning board_id={}", board.id,
                    );
                    return board.id;
                } else {
                    println!("[MATCHMAKING] auto_match: NO MATCH FOUND, adding caller to queue");
                    // No match found, add to queue
                    queue_state.waiting_players.append(caller);
                    world.write_model(@queue_state);
                    println!(
                        "[MATCHMAKING] auto_match: caller added to queue, queue size={}",
                        queue_state.waiting_players.len(),
                    );

                    // Create PlayerMatchmaking entry
                    let player_mm = PlayerMatchmaking {
                        player: caller,
                        game_mode: mode,
                        tournament_id: tid,
                        timestamp: starknet::get_block_timestamp(),
                    };
                    world.write_model(@player_mm);
                    println!("[MATCHMAKING] auto_match: PlayerMatchmaking entry created");

                    // Update caller's game state to Created (waiting)
                    caller_game.status = GameStatus::Created;
                    caller_game.board_id = Option::None;
                    caller_game.game_mode = mode;
                    world.write_model(@caller_game);
                    println!(
                        "[MATCHMAKING] auto_match: caller game state updated to Created (waiting)",
                    );

                    // Return 0 to indicate waiting in queue
                    println!("[MATCHMAKING] auto_match: returning 0 (waiting in queue)");
                    return 0;
                }
            }
        }

        /// Admin function to cancel any player's game
        fn admin_cancel_game(ref self: ContractState, player_address: ContractAddress) {
            // Check that caller is the owner
            self.ownable.assert_only_owner();

            println!(
                "[MATCHMAKING] admin_cancel_game: admin canceling game for player={:?}",
                player_address,
            );

            // Use internal function with permission checks disabled
            self._cancel_game(player_address);
        }

        /// Transfer ownership to a new admin
        fn admin_set_admin(ref self: ContractState, new_admin: ContractAddress) {
            // Transfer ownership using OpenZeppelin's transfer_ownership
            self.ownable.transfer_ownership(new_admin);
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"evolute_duel")
        }

        fn _create_tutorial_game(
            ref self: ContractState,
            player_address: ContractAddress,
            bot_address: ContractAddress,
            config: GameModeConfig,
        ) {
            let mut world = self.world_default();

            println!(
                "[MATCHMAKING] _create_tutorial_game: player={:x}, bot={:x}",
                player_address,
                bot_address,
            );

            // Validate bot can also create game
            let mut bot_game: Game = world.read_model(bot_address);
            println!(
                "[MATCHMAKING] _create_tutorial_game: bot_game - status={:?}, mode={:?}",
                bot_game.status,
                bot_game.game_mode,
            );

            if !AssertsTrait::assert_ready_to_create_game(@bot_game, world) {
                println!(
                    "[MATCHMAKING] _create_tutorial_game: FAILED - bot not ready to create game",
                );
                return;
            }

            println!("[MATCHMAKING] _create_tutorial_game: bot validation passed");

            // Validate player can access tutorial mode
            let mut player_game: Game = world.read_model(player_address);
            println!(
                "[MATCHMAKING] _create_tutorial_game: player_game - status={:?}, mode={:?}",
                player_game.status,
                player_game.game_mode,
            );

            println!("[MATCHMAKING] _create_tutorial_game: player tutorial access validated");

            // Create tutorial board
            println!("[MATCHMAKING] _create_tutorial_game: creating tutorial board");
            let board = BoardTrait::create_tutorial_board(
                world, player_address, bot_address,
            );
            println!(
                "[MATCHMAKING] _create_tutorial_game: tutorial board created with id={}", board.id,
            );

            // Update player game state (use the one we already read and validated)
            player_game.status = GameStatus::InProgress;
            player_game.board_id = Option::Some(board.id);
            player_game.game_mode = GameMode::Tutorial;
            world.write_model(@player_game);
            println!("[MATCHMAKING] _create_tutorial_game: player game updated to InProgress");

            // Update bot game state
            bot_game.status = GameStatus::InProgress;
            bot_game.board_id = Option::Some(board.id);
            bot_game.game_mode = GameMode::Tutorial;
            world.write_model(@bot_game);
            println!("[MATCHMAKING] _create_tutorial_game: bot game updated to InProgress");

            world
                .emit_event(
                    @GameCreated { host_player: player_address, status: GameStatus::Created },
                );
            println!("[MATCHMAKING] _create_tutorial_game: GameCreated event emitted");

            world
                .emit_event(
                    @GameStarted {
                        host_player: player_address, guest_player: bot_address, board_id: board.id,
                    },
                );
            println!("[MATCHMAKING] _create_tutorial_game: GameStarted event emitted");

            // Transition to move phase for tutorial game
            PhaseManagementTrait::transition_to_move_phase(
                board.id, board.top_tile, board.commited_tile, world,
            );
            println!(
                "[MATCHMAKING] _create_tutorial_game: Transitioned to move phase, function completed",
            );
        }

        fn _create_board_for_mode(
            ref self: ContractState,
            host_player: ContractAddress,
            guest_player: ContractAddress,
            game_mode: GameMode,
            config: GameModeConfig,
            tournament_id: u64,
            world: dojo::world::WorldStorage,
        ) -> evolute_duel::models::game::Board {
            println!(
                "[MATCHMAKING] _create_board_for_mode: mode={:?}, host={:?}, guest={:?}, tournament_id={}",
                game_mode,
                host_player,
                guest_player,
                tournament_id,
            );

            let mut world_ref = world;
            let board = match game_mode {
                GameMode::Tutorial => {
                    println!("[MATCHMAKING] _create_board_for_mode: creating tutorial board");
                    let board = BoardTrait::create_tutorial_board(
                        world_ref, host_player, guest_player,
                    );
                    println!(
                        "[MATCHMAKING] _create_board_for_mode: tutorial board created with id={}",
                        board.id,
                    );
                    board
                },
                GameMode::Ranked | GameMode::Casual |
                GameMode::Tournament => {
                    println!(
                        "[MATCHMAKING] _create_board_for_mode: creating regular board for mode={:?}",
                        game_mode,
                    );
                    let board = BoardTrait::create_board(
                        world_ref, host_player, guest_player, game_mode,
                    );
                    let tournament_board = TournamentBoard {
                        board_id: board.id.clone(),
                        tournament_id: tournament_id,
                    };
                    world_ref.write_model(@tournament_board);
                    println!(
                        "[MATCHMAKING] _create_board_for_mode: regular board created with id={}",
                        board.id,
                    );
                    board
                },
                _ => {
                    println!(
                        "[MATCHMAKING] _create_board_for_mode: PANIC - unsupported game mode={:?}",
                        game_mode,
                    );
                    panic!("Unsupported game mode")
                },
            };
            
            board
        }

        /// Internal function to cancel a player's game
        /// skip_checks: if true, skip game mode and access checks (for admin use)
        fn _cancel_game(ref self: ContractState, player_address: ContractAddress) {
            let mut world = self.world_default();
            let mut game: Game = world.read_model(player_address);
            println!(
                "[MATCHMAKING] _cancel_game: current game - status={:?}, mode={:?}, board_id={:?}",
                game.status,
                game.game_mode,
                game.board_id,
            );

            let status = game.status;
            println!("[MATCHMAKING] _cancel_game: current status={:?}", status);

            // Check if player is in tournament queue waiting for opponent
            if status == GameStatus::Created && game.game_mode == GameMode::Tournament {
                println!("[MATCHMAKING] _cancel_game: player is in tournament queue, checking for active tournament");
                
                // Get player's active tournament ID from PlayerAssignment
                match evolute_duel::models::tournament_matchmaking::TournamentELOTrait::get_player_active_tournament_id(
                    player_address,
                    world
                ) {
                    Option::Some(tournament_id) => {
                        println!("[MATCHMAKING] _cancel_game: found active tournament_id={}, unsubscribing player", tournament_id);
                        evolute_duel::models::tournament_matchmaking::TournamentELOTrait::unsubscribe_tournament_player(
                            player_address,
                            tournament_id,
                            world
                        );
                        println!("[MATCHMAKING] _cancel_game: player unsubscribed from tournament queue");
                    },
                    Option::None => {
                        println!("[MATCHMAKING] _cancel_game: no active tournament found for player");
                    }
                }
            } else if status == GameStatus::InProgress && game.board_id.is_some() {
                println!("[MATCHMAKING] _cancel_game: canceling active game with board");
                let mut board: evolute_duel::models::game::Board = world
                    .read_model(game.board_id.unwrap());
                let board_id = board.id;
                let (player1_address, _, _) = board.player1;
                let (player2_address, _, _) = board.player2;

                println!(
                    "[MATCHMAKING] _cancel_game: board_id={}, player1={:?}, player2={:?}",
                    board_id,
                    player1_address,
                    player2_address,
                );

                let another_player = if player1_address == player_address {
                    player2_address
                } else {
                    player1_address
                };

                println!("[MATCHMAKING] _cancel_game: another_player={:x}", another_player);
                let mut another_game: Game = world.read_model(another_player);
                println!(
                    "[MATCHMAKING] _cancel_game: another_game before cancel - status={:?}",
                    another_game.status,
                );

                let new_status = GameStatus::Canceled;
                another_game.status = new_status;
                another_game.board_id = Option::None;
                another_game.game_mode = GameMode::None;
                world.write_model(@another_game);
                world.emit_event(@GameCanceled { host_player: another_player, status: new_status });
                println!(
                    "[MATCHMAKING] _cancel_game: another player game canceled and event emitted",
                );

                world
                    .write_member(
                        dojo::model::Model::<
                            evolute_duel::models::game::Board,
                        >::ptr_from_keys(board_id),
                        selector!("game_state"),
                        evolute_duel::types::packing::GameState::Finished,
                    );
                println!("[MATCHMAKING] _cancel_game: board game_state set to Finished");
            } else {
                println!("[MATCHMAKING] _cancel_game: canceling created game (no board)");
            }

            let new_status = GameStatus::Canceled;
            game.status = new_status;
            game.board_id = Option::None;
            game.game_mode = GameMode::None;
            world.write_model(@game);
            world.emit_event(@GameCanceled { host_player: player_address, status: new_status });

            println!("[MATCHMAKING] _cancel_game: player game canceled, function completed");
        }

        // Remove player from tournament queue (for insufficient tokens scenario)
        fn _remove_from_tournament_queue(
            ref self: ContractState,
            player_address: ContractAddress,
            tournament_id: u64,
            mut world: WorldStorage,
        ) {
            println!("[MATCHMAKING] _remove_from_tournament_queue: removing player {:x} from tournament {} queue", player_address, tournament_id);

            // Unsubscribe from tournament queue
            evolute_duel::models::tournament_matchmaking::TournamentELOTrait::unsubscribe_tournament_player(
                player_address,
                tournament_id,
                world
            );
            println!("[MATCHMAKING] _remove_from_tournament_queue: player unsubscribed from tournament queue");

            // Clear PlayerMatchmaking status
            let empty_mm = PlayerMatchmaking {
                player: player_address, 
                game_mode: GameMode::None, 
                tournament_id: 0,
                timestamp: starknet::get_block_timestamp(),
            };
            world.write_model(@empty_mm);
            println!("[MATCHMAKING] _remove_from_tournament_queue: PlayerMatchmaking cleared");

            // Update player game status to canceled
            let mut game: Game = world.read_model(player_address);
            game.status = GameStatus::Canceled;
            game.board_id = Option::None;
            game.game_mode = GameMode::None;
            world.write_model(@game);
            
            // Emit event
            world.emit_event(@GameCanceled { host_player: player_address, status: GameStatus::Canceled });
            println!("[MATCHMAKING] _remove_from_tournament_queue: player removed from tournament queue due to insufficient tokens");
        }
    }
}
