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
    
    /// Initialize default game configurations for all modes.
    fn initialize_configs(ref self: T);
    
    /// Update configuration for a specific game mode (admin only).
    /// - `game_mode`: The game mode to update.
    /// - `board_size`: Size of the game board.
    /// - `deck_type`: Type of deck to use.
    /// - `initial_jokers`: Number of joker tiles per player.
    /// - `time_per_phase`: Time limit per phase in seconds.
    /// - `auto_match`: Whether to enable automatic matchmaking.
    fn update_config(
        ref self: T, 
        game_mode: u8, 
        board_size: u8, 
        deck_type: u8, 
        initial_jokers: u8, 
        time_per_phase: u64, 
        auto_match: bool
    );
    
    /// Automatic matchmaking - join queue and get matched automatically.
    /// - `game_mode`: The mode of the game (Tournament, Ranked, Casual).
    /// - `tournament_id`: Optional tournament ID for tournament mode.
    /// Returns: board_id if match found, 0 if waiting in queue.
    fn auto_match(ref self: T, game_mode: u8, tournament_id: Option<u64>) -> felt252;
}

// dojo decorator
#[dojo::contract]
pub mod matchmaking {
    use super::*;
    use starknet::{
        ContractAddress,
        get_caller_address,
    };
    use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use dojo::{
        event::EventStorage,
        model::{ModelStorage},
    };
    use evolute_duel::{
        libs::{
            asserts::AssertsTrait,
        },
        models::{
            game::{Game, GameConfig, MatchmakingState, PlayerMatchmaking},
        },
        events::{GameCreated, GameStarted, GameCanceled},
        types::{
            packing::{GameStatus, GameMode},
        },
        systems::helpers::{
            board::{BoardTrait},
        },
    };
    
    #[storage]
    struct Storage {
        board_id_generator: felt252,
    }
    
    #[abi(embed_v0)]
    impl MatchmakingImpl of IMatchmaking<ContractState> {
        fn create_game(ref self: ContractState, game_mode: u8, opponent: Option<ContractAddress>) {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let mode: GameMode = game_mode.into();
            
            // Get game configuration for this mode
            let config: GameConfig = world.read_model(mode);
            
            // Validate player can create game
            let mut game: Game = world.read_model(caller);
            if !AssertsTrait::assert_ready_to_create_game(@game, world) {
                return;
            }
            
            match mode {
                GameMode::Tutorial => {
                    // Tutorial requires bot opponent
                    let bot_address = opponent.expect('Bot address required');
                    self._create_tutorial_game(caller, bot_address, config);
                },
                GameMode::Ranked | GameMode::Casual => {
                    // Validate access to create regular games
                    if !AssertsTrait::assert_game_mode_access(
                        @game, 
                        array![GameMode::Ranked, GameMode::Casual].span(), 
                        caller, 
                        'create_game', 
                        world
                    ) {
                        return;
                    }
                    
                    // Regular games - create and wait for opponent
                    game.status = GameStatus::Created;
                    game.board_id = Option::None;
                    game.game_mode = mode;
                    world.write_model(@game);
                    
                    world.emit_event(@GameCreated { 
                        host_player: caller,
                        status: GameStatus::Created,
                    });
                },
                _ => {
                    // Handle other game modes if necessary
                },
            }
        }
        
        fn join_game(ref self: ContractState, host_player: ContractAddress) {
            let mut world = self.world_default();
            let guest_player = get_caller_address();
            
            // Get host game info
            let mut host_game: Game = world.read_model(host_player);
            let mut guest_game: Game = world.read_model(guest_player);
            
            // Validate join conditions
            if !AssertsTrait::assert_ready_to_join_game(@guest_game, @host_game, world) {
                return;
            }
            
            // Validate guest can join this game mode
            if !AssertsTrait::assert_game_mode_access(
                @host_game, 
                array![GameMode::Ranked, GameMode::Casual].span(), 
                guest_player, 
                'join_game', 
                world
            ) {
                return;
            }
            
            // Get configuration for this game mode
            let config: GameConfig = world.read_model(host_game.game_mode);
            
            // Create board based on game mode configuration
            let board = self._create_board_for_mode(
                host_player, 
                guest_player, 
                host_game.game_mode, 
                config,
                world
            );
            
            // Update both players' game state
            host_game.status = GameStatus::InProgress;
            host_game.board_id = Option::Some(board.id);
            world.write_model(@host_game);
            
            guest_game.status = GameStatus::InProgress;
            guest_game.board_id = Option::Some(board.id);
            guest_game.game_mode = host_game.game_mode;
            world.write_model(@guest_game);
            
            world.emit_event(@GameStarted {
                host_player,
                guest_player,
                board_id: board.id,
            });
        }
        
        fn cancel_game(ref self: ContractState) {
            let mut world = self.world_default();
            let caller = get_caller_address();
            
            let mut game: Game = world.read_model(caller);
            
            // Validate can cancel based on GameMode
            match game.game_mode {
                GameMode::Tutorial => {
                    // Tutorial games should be canceled through tutorial contract only
                    println!("[ERROR] Tutorial games must be canceled through tutorial contract");
                    return;
                },
                GameMode::Ranked | GameMode::Casual => {
                    // Regular games can be canceled through matchmaking
                    if !AssertsTrait::assert_regular_game_access(@game, caller, 'cancel_game', world) {
                        return;
                    }
                },
                _ => {
                    // Handle other game modes if necessary
                }
            }
            
            assert!(game.status == GameStatus::Created, "Can only cancel created games");
            
            game.status = GameStatus::Canceled;
            world.write_model(@game);

            world.emit_event(@GameCanceled { 
                host_player: caller, 
                status: GameStatus::Canceled 
            });
        }
        
        fn initialize_configs(ref self: ContractState) {
            let mut world = self.world_default();
            
            // Tutorial configuration
            let tutorial_config = GameConfig {
                game_mode: GameMode::Tutorial,
                board_size: 7,
                deck_type: 0, // Tutorial deck
                initial_jokers: 3,
                time_per_phase: 0, // No time limit
                auto_match: false,
            };
            world.write_model(@tutorial_config);
            
            // Ranked configuration
            let ranked_config = GameConfig {
                game_mode: GameMode::Ranked,
                board_size: 10,
                deck_type: 1, // Full randomized deck
                initial_jokers: 2,
                time_per_phase: 60, // 1 minute per phase
                auto_match: true,
            };
            world.write_model(@ranked_config);
            
            // Casual configuration
            let casual_config = GameConfig {
                game_mode: GameMode::Casual,
                board_size: 10,
                deck_type: 1, // Full randomized deck
                initial_jokers: 2,
                time_per_phase: 0, // No time limit
                auto_match: false,
            };
            world.write_model(@casual_config);
            
            // Tournament configuration
            let tournament_config = GameConfig {
                game_mode: GameMode::Tournament,
                board_size: 10,
                deck_type: 1, // Full randomized deck
                initial_jokers: 2,
                time_per_phase: 60, // 1 minute per phase
                auto_match: true, // Enable automatic matchmaking for tournaments
            };
            world.write_model(@tournament_config);
        }
        
        fn update_config(
            ref self: ContractState, 
            game_mode: u8, 
            board_size: u8, 
            deck_type: u8, 
            initial_jokers: u8, 
            time_per_phase: u64, 
            auto_match: bool
        ) {
            let mut world = self.world_default();
            let mode: GameMode = game_mode.into();
            
            // TODO: Add admin check here
            // assert!(is_admin(get_caller_address()), "Only admin can update configs");
            
            let config = GameConfig {
                game_mode: mode,
                board_size,
                deck_type,
                initial_jokers,
                time_per_phase,
                auto_match,
            };
            world.write_model(@config);
        }
        
        fn auto_match(ref self: ContractState, game_mode: u8, tournament_id: Option<u64>) -> felt252 {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let mode: GameMode = game_mode.into();
            let tid = tournament_id.unwrap_or(0);
            
            // Validate caller's game state
            let mut caller_game: Game = world.read_model(caller);
            if !AssertsTrait::assert_ready_to_create_game(@caller_game, world) {
                return 0;
            }
            
            // Get or create matchmaking queue state
            let mut queue_state: MatchmakingState = world.read_model((mode, tid));
            
            // Simple FIFO algorithm: check if there's a waiting player
            if queue_state.waiting_players.len() > 0 {
                // Match found! Get the first waiting player
                let mut waiting_players_vec = queue_state.waiting_players.span();
                let opponent = *waiting_players_vec[0];
                
                // Remove opponent from queue (create new array without first element)
                let mut new_waiting_players: Array<ContractAddress> = ArrayTrait::new();
                let mut i = 1;
                while i < waiting_players_vec.len() {
                    new_waiting_players.append(*waiting_players_vec[i]);
                    i += 1;
                };
                queue_state.waiting_players = new_waiting_players;
                world.write_model(@queue_state);
                
                // Remove opponent from PlayerMatchmaking
                let empty_opponent_mm = PlayerMatchmaking {
                    player: opponent,
                    game_mode: GameMode::None,
                    tournament_id: 0,
                    timestamp: 0,
                };
                world.write_model(@empty_opponent_mm);
                
                // Get opponent game state
                let mut opponent_game: Game = world.read_model(opponent);
                
                // Get game configuration
                let config: GameConfig = world.read_model(mode);
                
                // Create board for the match
                let board = self._create_board_for_mode(
                    opponent, // host_player (first in queue)
                    caller,   // guest_player (joining now)
                    mode,
                    config,
                    world
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
                
                // Emit events
                world.emit_event(@GameStarted {
                    host_player: opponent,
                    guest_player: caller,
                    board_id: board.id,
                });
                
                // Return board_id
                return board.id;
            } else {
                // No match found, add to queue
                queue_state.waiting_players.append(caller);
                world.write_model(@queue_state);
                
                // Create PlayerMatchmaking entry
                let player_mm = PlayerMatchmaking {
                    player: caller,
                    game_mode: mode,
                    tournament_id: tid,
                    timestamp: starknet::get_block_timestamp(),
                };
                world.write_model(@player_mm);
                
                // Update caller's game state to Created (waiting)
                caller_game.status = GameStatus::Created;
                caller_game.board_id = Option::None;
                caller_game.game_mode = mode;
                world.write_model(@caller_game);
                
                // Return 0 to indicate waiting in queue
                return 0;
            }
        }
    }
    
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"evolute_duel")
        }
        
        fn _create_tutorial_game(
            self: @ContractState,
            player_address: ContractAddress,
            bot_address: ContractAddress,
            config: GameConfig,
        ) {
            let mut world = self.world_default();
            
            // Validate bot can also create game
            let mut bot_game: Game = world.read_model(bot_address);
            if !AssertsTrait::assert_ready_to_create_game(@bot_game, world) {
                return;
            }
            
            // Validate player can access tutorial mode
            let mut player_game: Game = world.read_model(player_address);
            if !AssertsTrait::assert_game_mode_access(
                @player_game, 
                array![GameMode::Tutorial].span(), 
                player_address, 
                'create_tutorial', 
                world
            ) {
                return;
            }
            
            // Create tutorial board
            let board = BoardTrait::create_tutorial_board(
                world,
                player_address,
                bot_address,
            );
            
            // Update player game state (use the one we already read and validated)
            player_game.status = GameStatus::InProgress;
            player_game.board_id = Option::Some(board.id);
            player_game.game_mode = GameMode::Tutorial;
            world.write_model(@player_game);
            
            // Update bot game state
            bot_game.status = GameStatus::InProgress;
            bot_game.board_id = Option::Some(board.id);
            bot_game.game_mode = GameMode::Tutorial;
            world.write_model(@bot_game);
            
            world.emit_event(@GameCreated { 
                host_player: player_address,
                status: GameStatus::Created,
            });

            world.emit_event(@GameStarted {
                host_player: player_address,
                guest_player: bot_address,
                board_id: board.id,
            });
        }
        
        fn _create_board_for_mode(
            ref self: ContractState,
            host_player: ContractAddress,
            guest_player: ContractAddress,
            game_mode: GameMode,
            config: GameConfig,
            world: dojo::world::WorldStorage,
        ) -> evolute_duel::models::game::Board {
            match game_mode {
                GameMode::Tutorial => {
                    BoardTrait::create_tutorial_board(world, host_player, guest_player)
                },
                GameMode::Ranked | GameMode::Casual | GameMode::Tournament => {
                    BoardTrait::create_board(world, host_player, guest_player, self.board_id_generator)
                },
                _ => panic!("Unsupported game mode")
            }
        }
    }
}