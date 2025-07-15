use starknet::ContractAddress;

/// Interface defining core game actions and player interactions.
#[starknet::interface]
pub trait IGame<T> {
    /// Creates a new game session.
    fn create_game(ref self: T);

    /// Cancels an ongoing or pending game session.
    fn cancel_game(ref self: T);

    /// Allows a player to join an existing game hosted by another player.
    fn join_game(ref self: T, host_player: ContractAddress);

    /// Commits tiles to the game state.
    /// - `commitments`: A span of tile commitments to be added to the game state.
    fn commit_tiles(ref self: T, commitments: Span<u32>);
    /// Reveals a tile to all players.
    /// - `tile_index`: Index of the tile to be revealed.
    /// - `nonce`: Nonce used for the tile reveal.
    /// - `c`: A constant value used in the reveal process.
    fn reveal_tile(ref self: T, tile_index: u8, nonce: felt252, c: u8);

    fn request_next_tile(ref self: T, tile_index: u8, nonce: felt252, c: u8);
    /// Makes a move by placing a tile on the board.
    /// - `joker_tile`: Optional joker tile played during the move.
    /// - `rotation`: Rotation applied to the placed tile.
    /// - `col`: Column where the tile is placed.
    /// - `row`: Row where the tile is placed.
    fn make_move(ref self: T, joker_tile: Option<u8>, rotation: u8, col: u8, row: u8);

    /// Skips the current player's move.
    fn skip_move(ref self: T);

    /// Finishes the game and determines the winner.
    fn finish_game(ref self: T, board_id: felt252);
}


// dojo decorator
#[dojo::contract]
pub mod game {
    use super::{IGame};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use evolute_duel::{
        models::{
            game::{Board, Rules, Move, Game, TileCommitments, AvailableTiles},
            scoring::{PotentialContests},
        },
        events::{
            GameCreated, GameCreateFailed, GameStarted, GameCanceled,
            PlayerNotInGame,
            Skiped, 
        },
        systems::helpers::{
            board::{BoardTrait},
        },
        types::packing::{GameStatus, GameState, PlayerSide},
    };

    use evolute_duel::libs::{ // store::{Store, StoreTrait},
        asserts::{AssertsTrait},
        timing::{TimingTrait}, scoring::{ScoringTrait},
        move_execution::{MoveExecutionTrait, MoveData},
        tile_reveal::{TileRevealTrait, TileRevealData},
        game_finalization::{GameFinalizationTrait, GameFinalizationData},
        phase_management::{PhaseManagementTrait},
    };
    use evolute_duel::utils::hash::{
        hash_values, hash_sha256_to_felt252,
    };
    use evolute_duel::types::trophies::index::{TROPHY_COUNT, Trophy, TrophyTrait};

    use dojo::event::EventStorage;
    use dojo::model::{ModelStorage, Model};

    use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use origami_random::dice::DiceTrait;


    use achievement::components::achievable::AchievableComponent;
    component!(path: AchievableComponent, storage: achievable, event: AchievableEvent);
    impl AchievableInternalImpl = AchievableComponent::InternalImpl<ContractState>;

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AchievableEvent: AchievableComponent::Event,
    }

    #[storage]
    struct Storage {
        board_id_generator: felt252,
        move_id_generator: felt252,
        snapshot_id_generator: felt252,
        #[substorage(v0)]
        achievable: AchievableComponent::Storage,
    }

    const CREATING_TIME : u64 = 65; // 1 min
    const REVEAL_TIME : u64 = 65; // 1 min
    const MOVE_TIME : u64 = 65; // 1 min

    fn dojo_init(self: @ContractState) {
        let mut world = self.world_default();
        let id = 0;
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
        let edges = (1, 1);
        let joker_number = 3;
        let joker_price = 5;

        let rules = Rules { id, deck, edges, joker_number, joker_price };

        world.write_model(@rules);

        let mut trophy_id: u8 = TROPHY_COUNT;
        while trophy_id > 0 {
            let trophy: Trophy = trophy_id.into();
            self
                .achievable
                .create(
                    world,
                    id: trophy.identifier(),
                    hidden: trophy.hidden(),
                    index: trophy.index(),
                    points: trophy.points(),
                    start: 0,
                    end: 0,
                    group: trophy.group(),
                    icon: trophy.icon(),
                    title: trophy.title(),
                    description: trophy.description(),
                    tasks: trophy.tasks(),
                    data: trophy.data(),
                );

            trophy_id -= 1;
        };
    }

    #[abi(embed_v0)]
    impl GameImpl of IGame<ContractState> {
        fn create_game(ref self: ContractState) {
            let mut world = self.world_default();

            let host_player = get_caller_address();

            let mut game: Game = world.read_model(host_player);

            if !AssertsTrait::assert_ready_to_create_game(@game, world) {
                return;
            }

            game.status = GameStatus::Created;
            game.board_id = Option::None;

            world.write_model(@game);

            world.emit_event(@GameCreated { host_player, status: game.status });
        }

        fn cancel_game(ref self: ContractState) {
            let mut world = self.world_default();

            let host_player = get_caller_address();

            let mut game: Game = world.read_model(host_player);
            let status = game.status;

            if status == GameStatus::InProgress && game.board_id.is_some() {
                let mut board: Board = world.read_model(game.board_id.unwrap());
                let board_id = board.id.clone();
                let (player1_address, _, _) = board.player1;
                let (player2_address, _, _) = board.player2;

                let another_player = if player1_address == host_player {
                    player2_address
                } else {
                    player1_address
                };

                let mut game: Game = world.read_model(another_player);
                let new_status = GameStatus::Canceled;
                game.status = new_status;
                game.board_id = Option::None;

                world.write_model(@game);
                world.emit_event(@GameCanceled { host_player: another_player, status: new_status });

                world
                    .write_member(
                        Model::<Board>::ptr_from_keys(board_id),
                        selector!("game_state"),
                        GameState::Finished,
                    );
            }

            let new_status = GameStatus::Canceled;
            game.status = new_status;
            game.board_id = Option::None;

            world.write_model(@game);
            world.emit_event(@GameCanceled { host_player, status: new_status });
        }

        fn join_game(ref self: ContractState, host_player: ContractAddress) {
            let mut world = self.world_default();
            let guest_player = get_caller_address();

            let mut host_game: Game = world.read_model(host_player);
            let mut guest_game: Game = world.read_model(guest_player);

            if !AssertsTrait::assert_ready_to_join_game(@guest_game, @host_game, world) {
                return;
            }

            let board_id: felt252 = {
                let board = BoardTrait::create_board(
                    world, host_player, guest_player, self.board_id_generator,
                );
                board.id
            };

            println!("Board created with ID: {:?}", board_id);

            host_game.board_id = Option::Some(board_id);
            host_game.status = GameStatus::InProgress;
            host_game.status = GameStatus::InProgress;
            guest_game.board_id = Option::Some(board_id);
            guest_game.status = GameStatus::InProgress;
            guest_game.status = GameStatus::InProgress;

            world.write_model(@host_game);
            world.write_model(@guest_game);
            world.emit_event(@GameStarted { host_player, guest_player, board_id });

            let mut board: Board = world.read_model(board_id);

            PhaseManagementTrait::transition_to_creating_phase(
                board_id,
                board.top_tile,
                board.commited_tile,
                world,
            );
        }

        fn commit_tiles(ref self: ContractState, commitments: Span<u32>) {
            let mut world = self.world_default();
            let player = get_caller_address();

            let mut game: Game = world.read_model(player);

            if game.board_id.is_none() {
                world.emit_event(@PlayerNotInGame { player_id: player, board_id: 0 });
                return;
            }

            let board_id = game.board_id.unwrap();
            let mut board: Board = world.read_model(board_id);

            if game.status != GameStatus::InProgress {
                return panic!("[Commit Error] Game status is {:?}", game.status);
            }

            if board.game_state != GameState::Creating {
                return panic!("[Commit Error] Game state is {:?}", board.game_state);
            }

            let timestamp = get_block_timestamp();

            if timestamp > board.phase_started_at + CREATING_TIME {
                world.emit_event(@GameCreateFailed { host_player: player, status: game.status });
                println!(
                    "[ERROR] Commit timeout: {:?} > {:?} + {:?}",
                    timestamp, board.phase_started_at, CREATING_TIME
                );
                return;
            }

            let mut tile_commitments = array![];
            // println!("comitments length: {:?}", commitments.len());
            if commitments.len() % 8 != 0 {
                return panic!("[ERROR] Commitments length is not a multiple of 8");
            }
            for i in 0..(commitments.len() / 8) {
                let commitment: Span<u32> = commitments.slice(i * 8, 8);
                // println!("sha256 commitments[{}]: {:?}", i, commitment);
                let tile_commitment = hash_sha256_to_felt252(commitment);
                tile_commitments.append(tile_commitment);
            };
            let tile_commitments = tile_commitments.span();

            world.write_model(@TileCommitments { board_id, player, tile_commitments });

            let (player1_address, _player1_side, _joker_number1) = board.player1;
            let (player2_address, _player2_side, _joker_number2) = board.player2;

            let another_player = if player == player1_address {
                player2_address
            } else if player == player2_address {
                player1_address
            } else {
                world.emit_event(@PlayerNotInGame { player_id: player, board_id });
                return;
            };

            let another_player_commitments: TileCommitments = world.read_model((board_id, another_player));

            if another_player_commitments.tile_commitments.len() == tile_commitments.len() {
                game.status = GameStatus::InProgress;
                let mut another_player_game: Game = world.read_model(another_player);
                another_player_game.status = GameStatus::InProgress;
                world.write_model(@another_player_game);
                world.write_model(@game);

                let mut dice = DiceTrait::new(tile_commitments.len().try_into().unwrap(), 'SEED' + get_block_timestamp().into() + board_id.into());

                let commited_tile = Option::Some(dice.roll() - 1);

                board.commited_tile = commited_tile;
                world.write_member(
                    Model::<Board>::ptr_from_keys(board_id),
                    selector!("commited_tile"),
                    board.commited_tile,
                );

                PhaseManagementTrait::transition_to_reveal_phase(
                    board_id,
                    board.top_tile,
                    board.commited_tile,
                    world,
                );
            }
        }
           

        fn reveal_tile(ref self: ContractState, tile_index: u8, nonce: felt252, c: u8) {
            let mut world = self.world_default();
            let player = get_caller_address();

            let game: Game = world.read_model(player);

            if game.board_id.is_none() {
                world.emit_event(@PlayerNotInGame { player_id: player, board_id: 0 });
                return;
            }

            let board_id = game.board_id.unwrap();
            let mut board: Board = world.read_model(board_id);

            let reveal_data = TileRevealData {
                board_id,
                player,
                tile_index,
                nonce,
                c,
            };

            if !TileRevealTrait::perform_tile_reveal_validation(reveal_data, @board, REVEAL_TIME, world) {
                return;
            }


            TileRevealTrait::reveal_tile_and_update_board(board_id, tile_index, world);

            PhaseManagementTrait::transition_to_request_phase(
                board_id,
                Option::Some(tile_index),
                Option::None,
                world,
            );

            TileRevealTrait::update_available_tiles(board_id, player, c, world);
        }

        fn request_next_tile(ref self: ContractState, tile_index: u8, nonce: felt252, c: u8){
            let mut world = self.world_default();
            let player = get_caller_address();

            let game: Game = world.read_model(player);

            if game.board_id.is_none() {
                world.emit_event(@PlayerNotInGame { player_id: player, board_id: 0 });
                return;
            }

            let board_id = game.board_id.unwrap();
            let mut board: Board = world.read_model(board_id);

            assert!(board.top_tile.is_some(), "[REQUEST ERROR] Tile is not revealed yet");

            assert!(
                board.commited_tile.is_none(),
                "[REQUEST ERROR] Tile still committed, can't request next tile"
            );

            assert!(
                board.game_state == GameState::Request,
                "[REQUEST ERROR] Game state is not Request: {:?}",
                board.game_state
            );

            if get_block_timestamp() > board.phase_started_at + REVEAL_TIME {
                println!(
                    "[REQUEST ERROR] Reveal timeout: {:?} > {:?} + {:?}",
                    get_block_timestamp(),
                    board.phase_started_at,
                    REVEAL_TIME
                );
                return;
            }

            assert!(
                board.top_tile.unwrap() == tile_index,
                "[REQUEST ERROR] Tile mismatch: expected {}, got {}",
                board.top_tile.unwrap(),
                tile_index
            );

            // Check committed tile

            let tile_commitments_entry: TileCommitments = world.read_model((board_id, player));
            let tile_commitments = tile_commitments_entry.tile_commitments;

            let saved_tile_commitment = *tile_commitments.at(tile_index.into());
            let tile_commitment = hash_values([tile_index.into(), nonce, c.into()].span());

            // Check if the tile commitment matches the saved one
            assert!(
                saved_tile_commitment == tile_commitment,
                "[ERROR] Tile commitment mismatch: expected {}, got {}",
                saved_tile_commitment, tile_commitment
            );


            let player_available_tiles_entry: AvailableTiles = world.read_model((board_id, player));

            let mut player_available_tiles = player_available_tiles_entry.available_tiles;
            // println!("player_available_tiles: {:?}", player_available_tiles);
            let mut new_available_tiles: Array<u8> = array![];
            for i in 0..player_available_tiles.len() {
                if *player_available_tiles.at(i.into()) != c {
                    new_available_tiles.append(*player_available_tiles.at(i.into()));
                }
            };
            // println!("new_available_tiles: {:?}", new_available_tiles);
            world.write_model(@AvailableTiles {
                board_id,
                player,
                available_tiles: new_available_tiles.span(),
            });


            if new_available_tiles.len() > 0 {
                // Redraw the tile from the deck
                let mut dice = DiceTrait::new(new_available_tiles.len().try_into().unwrap(), 
                    'SEED',
                    // nonce
                );

                // Roll the dice to get a new tile index
                let new_tile_index = dice.roll() - 1;
                let commited_tile = *new_available_tiles.at(new_tile_index.into());
                // Update the board with the new tile
                board.commited_tile = Option::Some(commited_tile);
                world.write_member(
                    Model::<Board>::ptr_from_keys(board_id),
                    selector!("commited_tile"),
                    board.commited_tile,
                );
            }

            PhaseManagementTrait::transition_to_move_phase(
                board_id,
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
            col += 1; // Adjusting to 1-based indexing
            row += 1; // Adjusting to 1-based indexing
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

            if get_block_timestamp() > board.phase_started_at + MOVE_TIME {
                println!(
                    "[ERROR] Move timeout: {:?} > {:?} + {:?}",
                    get_block_timestamp(),
                    board.phase_started_at,
                    MOVE_TIME
                );
                return;
            }

            let (player1_address, _, _) = board.player1;
            let (player2_address, _, _) = board.player2;

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

            let tile = MoveExecutionTrait::get_tile_for_move(joker_tile, @board);

            if !MoveExecutionTrait::validate_move(board_id, tile.into(), rotation, col, row, world) {
                let move_id = self.move_id_generator.read();
                let move_data = MoveData { tile, rotation, col, row, is_joker, player_side, top_tile: board.top_tile };
                let move_record = MoveExecutionTrait::create_move_record(move_id, move_data, board.last_move_id, board_id);
                MoveExecutionTrait::emit_invalid_move_event(move_record, board_id, player, world);
                println!("[Invalid move] \nBoard: {:?}, Move: {:?}", board, move_record);
                return;
            }
            
            println!("Validation passed, proceeding with move execution");

            let scoring_result = ScoringTrait::calculate_move_scoring(
                tile, rotation, col.into(), row.into(), player_side, player, board_id, 10, world
            );

            println!("Scoring result: {:?}", scoring_result);

            ScoringTrait::apply_scoring_results(scoring_result, player_side, ref board);

            println!("Scoring applied, updating board");

            let move_data = MoveData { tile, rotation, col, row, is_joker, player_side, top_tile: board.top_tile };
            let top_tile = MoveExecutionTrait::update_board_after_move(move_data, ref board, is_joker);

            println!("Board updated, creating move record");

            let move_id = self.move_id_generator.read();
            let move_record = MoveExecutionTrait::create_move_record(move_id, move_data, board.last_move_id, board_id);

            println!("Move record created: {:?}", move_record);
            
            board.last_move_id = Option::Some(move_id);
            self.move_id_generator.write(move_id + 1);

            let available_tiles_player1: AvailableTiles =
                world.read_model((board_id, player1_address));
            let available_tiles_player2: AvailableTiles =
                world.read_model((board_id, player2_address));

            let (updated_joker1, updated_joker2) = board.get_joker_numbers();
            if MoveExecutionTrait::should_finish_game(
                updated_joker1, 
                updated_joker2, 
                available_tiles_player1.available_tiles.len(), 
                available_tiles_player2.available_tiles.len()
            ) {
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

            PhaseManagementTrait::transition_after_move(
                board_id,
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

            // Check phase timing
            if !TimingTrait::validate_phase_timing(@board, MOVE_TIME) {
                println!("[ERROR] Phase timeout exceeded");
                return;
            }

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
            
            let skip_move_record = MoveExecutionTrait::create_skip_move_record(
                self.move_id_generator.read() - 1, 
                player_side, 
                board.last_move_id, 
                board_id,
                board.top_tile
            );
            

            board.top_tile = Option::None;
            world
                .write_member(
                    Model::<Board>::ptr_from_keys(board_id),
                    selector!("top_tile"),
                    board.top_tile,
                );
            
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

            PhaseManagementTrait::transition_after_move(
                board_id,
                board.top_tile,
                board.commited_tile,
                world,
            );
        }

        fn finish_game(ref self: ContractState, board_id: felt252) {
            let player = get_caller_address();

            let mut world = self.world_default();
            let game: Game = world.read_model(player);

            if !AssertsTrait::assert_player_in_game(@game, Option::Some(board_id), world) {
                return;
            }

            let mut board: Board = world.read_model(board_id);

            if !AssertsTrait::assert_game_is_in_progress(@game, world) {
                return;
            }

            // Check if current phase has timed out OR if it's been too long since last update
            let phase_timeout = TimingTrait::validate_phase_timeout(@board, CREATING_TIME, REVEAL_TIME, MOVE_TIME);
            
            if phase_timeout {
                //FINISH THE GAME
                let potential_contests_model: PotentialContests = world.read_model(board_id);
                self
                    ._finish_game(
                        ref board,
                        potential_contests_model.potential_contests.span(),
                    );

                return;
            } else {
                println!("Cannot finish game: no phase timeout");
                return;
            }
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
            move_id_generator.write(move_id + 1);

            world.write_model(@move);

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
                world,
            );
        }
    }
}