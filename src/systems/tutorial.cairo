use starknet::ContractAddress;

const MOVE_TIME: u64 = 65; // 1 min

/// Interface defining core game actions and player interactions.
#[starknet::interface]
pub trait ITutorial<T> {
    fn create_tutorial_game(
        ref self: T,
        bot_address: ContractAddress,
    );

    fn make_move(
        ref self: T, joker_tile: Option<u8>, rotation: u8, col: u8, row: u8,
    );

    fn skip_move(ref self: T);

}   


// dojo decorator
#[dojo::contract]
pub mod tutorial {
    use super::*;
    use starknet::{
        ContractAddress,
        get_caller_address,
        get_block_timestamp,
    };
    use dojo::{
        event::EventStorage,
        model::{ModelStorage, Model},
    };
    use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use evolute_duel::{
        libs::{
            asserts::AssertsTrait,
            timing::{TimingTrait},
            scoring::{ScoringTrait},
            move_execution::{MoveExecutionTrait, MoveData},
            game_finalization::{GameFinalizationTrait, GameFinalizationData},
            phase_management::{PhaseManagementTrait},
        },
        models::{
            game::{Game, Board, Move},
            scoring::{PotentialContests},
            player::{Player, PlayerTrait},
        },
        events::{TutorialCompleted},
        types::{
            packing::{GameStatus, GameState, PlayerSide},
        },
        systems::helpers::{
            board::{BoardTrait},
        },
        events::{GameCreated, GameStarted, Skiped},
    };
    
    #[storage]
    struct Storage {
        move_id_generator: felt252,
    }
    
    #[abi(embed_v0)]
    impl TutorialImpl of ITutorial<ContractState> {
        fn create_tutorial_game(
            ref self: ContractState,
            bot_address: ContractAddress,
        ) {
            let mut world = self.world_default();

            let host_player = get_caller_address();

            let mut game: Game = world.read_model(host_player);

            if !AssertsTrait::assert_ready_to_create_game(@game, world) {
                return;
            }

            let mut bot_game = world.read_model(bot_address);
            if !AssertsTrait::assert_ready_to_create_game(@bot_game, world) {
                return;
            }

            let board = BoardTrait::create_tutorial_board(
                world,
                host_player,
                bot_address,
            );
                

            game.status = GameStatus::InProgress;
            game.board_id = Option::Some(board.id);
            world.write_model(@game);

            
            bot_game.status = GameStatus::InProgress;
            bot_game.board_id = Option::Some(board.id);
            world.write_model(@bot_game);


            
            // For now, we will just emit an event indicating the game has been created
            world.emit_event(@GameCreated { 
                host_player,
                status: GameStatus::Created,
            });

            world.emit_event(@GameStarted {
                host_player,
                guest_player: bot_address,
                board_id: board.id,
            });

            PhaseManagementTrait::transition_to_move_phase(
                board.id,
                board.top_tile,
                board.commited_tile,
                world,
            );
        }

        fn make_move(
            ref self: ContractState, joker_tile: Option<u8>, rotation: u8, mut col: u8, mut row: u8,
        ) {
            let mut world = self.world_default();
            let player = get_caller_address();
           
            let game: Game = world.read_model(player);

            if !AssertsTrait::assert_player_in_game(@game, Option::None, world) {
                return;
            }
            let board_id = game.board_id.unwrap();
            let mut board: Board = world.read_model(board_id);

            if !AssertsTrait::assert_game_is_in_progress(@game, world) {
                return;
            }

            assert!(
                board.game_state == GameState::Move,
                "[ERROR] Game state is not Move: {:?}",
                board.game_state
            );

            let (player_side, joker_number) = match board.get_player_data(player, world) {
                Option::Some((side, joker_number)) => (side, joker_number),
                Option::None => {return;}
            };

            let is_joker = joker_tile.is_some();

            if !MoveExecutionTrait::validate_joker_usage(joker_tile, joker_number, player, board_id, world) {
                return;
            }

            if !TimingTrait::validate_move_turn(@board, player, player_side, world) {
                return;
            }

            let tile = match MoveExecutionTrait::get_tile_for_move(joker_tile, @board, world, player) {
                Option::Some(tile) => tile,
                Option::None => {
                    return;
                }
            };

            if !MoveExecutionTrait::validate_move(board_id, tile.into(), rotation, col, row, 7, world) {
                let move_id = self.move_id_generator.read();
                let move_data = MoveData { tile, rotation, col, row, is_joker, player_side, top_tile: board.top_tile };
                let move_record = MoveExecutionTrait::create_move_record(move_id, move_data, board.last_move_id, board_id);
                MoveExecutionTrait::emit_invalid_move_event(move_record, board_id, player, world);
                println!("[Invalid move] \nBoard: {:?}, Move: {:?}", board, move_record);
                return;
            }
            
            println!("Validation passed, proceeding with move execution");

            let scoring_result = ScoringTrait::calculate_move_scoring(
                tile, rotation, col.into(), row.into(), player_side, player, board_id, 7, world
            );

            println!("Scoring result: {:?}", scoring_result);

            ScoringTrait::apply_scoring_results(scoring_result, player_side, ref board);

            println!("Scoring applied, updating board");

            let move_data = MoveData { tile, rotation, col, row, is_joker, player_side, top_tile: board.top_tile };
            let top_tile = MoveExecutionTrait::update_board_after_move(move_data, ref board, is_joker, is_tutorial: true, world: world);

            println!("Board updated, creating move record");

            let move_id = self.move_id_generator.read();
            let move_record = MoveExecutionTrait::create_move_record(move_id, move_data, board.last_move_id, board_id);

            println!("Move record created: {:?}", move_record);
            
            board.last_move_id = Option::Some(move_id);
            self.move_id_generator.write(move_id + 1);

            let (updated_joker1, updated_joker2) = board.get_joker_numbers();
            
            if updated_joker1 == 0 && updated_joker2 == 0  && top_tile.is_none() {
                let potential_contests_model: PotentialContests = world.read_model(board_id);
                self._finish_game(
                    ref board,
                    potential_contests_model.potential_contests.span(),
                );
                return;
            }

            MoveExecutionTrait::persist_board_updates(@board, move_record, top_tile, world);
            println!("Board updates persisted, emitting move events");
            MoveExecutionTrait::emit_move_events(move_record, @board, player, world);
            println!("Move events emitted");

            PhaseManagementTrait::transition_to_move_phase(
                board.id,
                board.top_tile,
                board.commited_tile,
                world,
            );

            // println!(
            //     "Move made: {:?} \nBoard: {:?} \nUnion find: {:?}",
            //     move, board, union_find,
            // );
        }

        fn skip_move(ref self: ContractState) {
            let player = get_caller_address();

            let mut world = self.world_default();
            let game: Game = world.read_model(player);

            if !AssertsTrait::assert_player_in_game(@game, Option::None, world) {
                return;
            }

            let board_id = game.board_id.unwrap();
            let mut board: Board = world.read_model(board_id);

            if !AssertsTrait::assert_game_is_in_progress(@game, world) {
                return;
            }

            assert!(
                board.game_state == GameState::Move,
                "[ERROR] Game state is not Move: {:?}",
                board.game_state
            );

            // Get player data and validate turn
            let (player_side, _) = match board.get_player_data(player, world) {
                Option::Some((side, joker_number)) => (side, joker_number),
                Option::None => {return;}
            };

            // Validate it's current player's turn
            if !TimingTrait::validate_current_player_turn(@board, player, player_side, world) {
                return;
            }

            // Check if this will be two consecutive skips (game should end)
            let should_finish_game = TimingTrait::check_two_consecutive_skips(@board, world);

            // Execute skip move
            self._skip_move(player, player_side, ref board, self.move_id_generator, true);
            
            // If two consecutive skips, finish the game
            if should_finish_game {
                println!("Two consecutive skips detected, finishing the game");
                let potential_contests_model: PotentialContests = world.read_model(board_id);
                
                self._finish_game(
                    ref board,
                    potential_contests_model.potential_contests.span(),
                );
                
                return;
            }
            
            MoveExecutionTrait::emit_board_updated_event(
                @board, world,
            );

            PhaseManagementTrait::transition_to_move_phase(
                board.id,
                board.top_tile,
                board.commited_tile,
                world,
            );
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"evolute_duel")
        }

        fn _skip_move(
            self: @ContractState,
            player: ContractAddress,
            player_side: PlayerSide,
            ref board: Board,
            move_id_generator: core::starknet::storage::StorageBase::<
                core::starknet::storage::Mutable<core::felt252>,
            >,
            emit_event: bool,
        ) {
            let mut world = self.world_default();
            let move_id = self.move_id_generator.read();
            let board_id = board.id;

            let timestamp = get_block_timestamp();

            let move = Move {
                id: move_id,
                prev_move_id: board.last_move_id,
                player_side,
                tile: Option::None,
                rotation: 0,
                col: 0,
                row: 0,
                is_joker: false,
                first_board_id: board_id,
                timestamp,
                top_tile: match board.top_tile {
                    Option::Some(tile_index) => Option::Some(*board.available_tiles_in_deck.at(tile_index.into())),
                    Option::None => Option::None,
                },
            };

            board.last_move_id = Option::Some(move_id);
            board.moves_done = board.moves_done + 1;
            board.top_tile = MoveExecutionTrait::update_top_tile_in_tutorial(@board);
            move_id_generator.write(move_id + 1);

            world.write_model(@move);

            world.write_member(
                Model::<Board>::ptr_from_keys(board_id),
                    selector!("top_tile"),
                    board.top_tile,
            );
            world
                .write_member(
                    Model::<Board>::ptr_from_keys(board_id),
                    selector!("last_move_id"),
                    board.last_move_id,
                );

            world
                .write_member(
                    Model::<Board>::ptr_from_keys(board_id),
                    selector!("moves_done"),
                    board.moves_done,
                );
            if emit_event {
                world
                    .emit_event(
                        @Skiped {
                            move_id, player, prev_move_id: move.prev_move_id, board_id, timestamp,
                        },
                    );
            }
        }

        fn _finish_game(
            self: @ContractState,
            ref board: Board,
            potential_contests: Span<u32>,
        ) {
            let mut world = self.world_default();
            let (player1_address, player1_side, joker_number1) = board.player1;
            let (player2_address, _player2_side, joker_number2) = board.player2;

            let finalization_data = GameFinalizationData {
                board_id: board.id,
                player1_address,
                player2_address,
                player1_side,
                joker_number1,
                joker_number2,
            };

            GameFinalizationTrait::finalize_game(
                finalization_data,
                ref board,
                potential_contests,
                0, // Both
                world,
            );

            // Auto-complete tutorial for guest players
            let current_time = get_block_timestamp();
            
            // Check and complete tutorial for player1 if they are a guest
            let mut player1: Player = world.read_model(player1_address);
            if player1.is_guest() && !player1.tutorial_completed {
                player1.tutorial_completed = true;
                world.write_model(@player1);
                
                world.emit_event(@TutorialCompleted {
                    player_id: player1_address,
                    completed_at: current_time
                });
            }
            
            // Check and complete tutorial for player2 if they are a guest
            let mut player2: Player = world.read_model(player2_address);
            if player2.is_guest() && !player2.tutorial_completed {
                player2.tutorial_completed = true;
                world.write_model(@player2);
                
                world.emit_event(@TutorialCompleted {
                    player_id: player2_address,
                    completed_at: current_time
                });
            }
        }

    }
   
}