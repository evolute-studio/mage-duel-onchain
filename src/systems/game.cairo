/// Interface defining core game actions and player interactions.
#[starknet::interface]
pub trait IGame<T> {
    /// Makes a move by placing a tile on the board.
    /// - `joker_tile`: Optional joker tile played during the move.
    /// - `rotation`: Rotation applied to the placed tile.
    /// - `col`: Column where the tile is placed.
    /// - `row`: Row where the tile is placed.
    fn make_move(ref self: T, joker_tile: Option<u8>, rotation: u8, col: u8, row: u8);

    /// Skips the current player's move.
    fn skip_move(ref self: T);

    /// Creates a snapshot of the current game state.
    /// - `duel_id`: ID of the board being saved.
    /// - `move_number`: Move number at the time of snapshot.
    fn create_snapshot(ref self: T, duel_id: felt252, move_number: u8);

    /// Finishes the game and determines the winner.
    fn finish_game(ref self: T, duel_id: felt252);
}


// dojo decorator
#[dojo::contract]
pub mod game {
    use super::{IGame};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use evolute_duel::{
        models::{
            game::{Board, Rules, Move, Snapshot},
            player::{Player, PlayerTrait},
            challenge::{Challenge, DuelType},
            scoreboard::{Scoreboard, ScoreboardTrait},
            pact::PactTrait,
        },
        events::{
            BoardUpdated,
            PlayerNotInGame, NotYourTurn, NotEnoughJokers, GameFinished,
            Skiped, Moved, CurrentPlayerBalance, InvalidMove,
            CantFinishGame,
        },
        systems::helpers::{
            board::{
                draw_tile_from_board_deck, update_board_state,
                update_board_joker_number, redraw_tile_from_board_deck,
            },
            city_scoring::{
                connect_city_edges_in_tile, connect_adjacent_city_edges, close_all_cities,
            },
            road_scoring::{
                connect_road_edges_in_tile, connect_adjacent_road_edges, close_all_roads,
            },
            tile_helpers::{calcucate_tile_points, calculate_adjacent_edge_points},
            validation::{is_valid_move},
        },
        packing::{Tile, GameState, PlayerSide},
        types::challenge_state::{ChallengeState, ChallengeStateTrait},
    };
    use evolute_duel::libs::store::{Store, StoreTrait};


    use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    struct Storage {
        duel_id_generator: felt252,
        move_id_generator: felt252,
        snapshot_id_generator: felt252,
    }

    const MOVE_TIME : u64 = 60; // 1 min


    fn dojo_init(self: @ContractState) {
        let mut store = StoreTrait::new(self.world_default());
        let id = 0;
        let deck: Array<u8> = array![
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
        ];
        let edges = (1, 1);
        let joker_number = 3;
        let joker_price = 5;

        let rules = Rules { id, deck, edges, joker_number, joker_price };
        store.set_rules(@rules);
    }

    #[abi(embed_v0)]
    impl GameImpl of IGame<ContractState> {
        fn create_snapshot(ref self: ContractState, duel_id: felt252, move_number: u8) {
            let mut store = StoreTrait::new(self.world_default());
            let player = get_caller_address();

            let board: Board = store.get_board(duel_id);
            let (_, _, joker_number1) = board.player1;
            let (_, _, joker_number2) = board.player2;
            let is_top_tipe = if board.top_tile.is_some() {
                1
            } else {
                0
            };
            let max_move_number: u32 = 70
                - board.available_tiles_in_deck.len()
                - is_top_tipe
                - joker_number1.into()
                - joker_number2.into();

            if move_number.into() > max_move_number {
                store
                    .emit_snapshot_create_failed(
                        player,
                        duel_id,
                        board.game_state,
                        move_number,
                    );
                return;
            }

            let snapshot_id = self.snapshot_id_generator.read();

            let snapshot = Snapshot { snapshot_id, player, board_id: duel_id, move_number };

            self.snapshot_id_generator.write(snapshot_id + 1);

            store.set_snapshot(@snapshot);

            store.emit_snapshot_created(@snapshot);
        }


        fn make_move(
            ref self: ContractState, joker_tile: Option<u8>, rotation: u8, col: u8, row: u8,
        ) {
            let mut store = StoreTrait::new(self.world_default());
            let player = get_caller_address();
            let assignment = store.get_player_challenge(player);
            let duel_id = assignment.duel_id;
            if duel_id == 0 {
                store.emit_event(@PlayerNotInGame { player_id: player, duel_id: 0 });
                return;
            }

            let mut challenge: Challenge = store.get_challenge(duel_id);

            assert!(challenge.state == ChallengeState::InProgress, "Challenge is not live");

            let mut board: Board = store.get_board(duel_id);

            let (player1_address, player1_side, joker_number1) = board.player1;
            let (player2_address, player2_side, joker_number2) = board.player2;

            let (player_side, joker_number) = if player == player1_address {
                (player1_side, joker_number1)
            } else if player == player2_address {
                (player2_side, joker_number2)
            } else {
                store.emit_event(@PlayerNotInGame { player_id: player, duel_id });
                return;
            };

            let is_joker = joker_tile.is_some();

            if is_joker && joker_number == 0 {
                store.emit_event(@NotEnoughJokers { player_id: player, duel_id });
                return;
            }

            let prev_move_id = board.last_move_id;
            if prev_move_id.is_some() {
                let prev_move_id = prev_move_id.unwrap();
                let prev_move: Move = store.get_move(prev_move_id);
                let prev_player_side = prev_move.player_side;
                let time = get_block_timestamp();
                let prev_move_time = prev_move.timestamp;
                let time_delta = time - prev_move_time;

                if player_side == prev_player_side {
                    if time_delta > MOVE_TIME {
                        //Skip the move of the previous player
                        let another_player = if player == player1_address {
                            player2_address
                        } else {
                            player1_address
                        };
                        let another_player_side = if player == player1_address {
                            player2_side
                        } else {
                            player1_side
                        };
                        self
                            ._skip_move(
                                another_player,
                                another_player_side,
                                ref board,
                                self.move_id_generator,
                            )
                    }

                    if time_delta <= MOVE_TIME || time_delta > 2 * MOVE_TIME {
                        store.emit_event(@NotYourTurn { player_id: player, duel_id });
                        return;
                    }
                } else {
                    if time_delta > MOVE_TIME {
                        store.emit_event(@NotYourTurn { player_id: player, duel_id });
                        return;
                    }
                }
            };

            let tile: Tile = match joker_tile {
                Option::Some(tile_index) => { tile_index.into() },
                Option::None => {
                    match @board.top_tile {
                        Option::Some(top_tile) => { (*top_tile).into() },
                        Option::None => { return panic!("No tiles in the deck"); },
                    }
                },
            };

            let move_id = self.move_id_generator.read();

            let move = Move {
                id: move_id,
                prev_move_id: board.last_move_id,
                player_side,
                tile: Option::Some(tile.into()),
                rotation: rotation,
                col,
                row,
                is_joker,
                first_board_id: duel_id,
                timestamp: get_block_timestamp(),
            };

            //TODO: revert invalid move when it's stable
            if !is_valid_move(
                tile, rotation, col, row, board.state.span(), board.initial_edge_state.span(),
            ) {
                store
                    .emit_event(
                        @InvalidMove {
                            player,
                            prev_move_id: move.prev_move_id,
                            tile: move.tile,
                            rotation: move.rotation,
                            col: move.col,
                            row: move.row,
                            is_joker: move.is_joker,
                            duel_id,
                        },
                    );
                return;
            }

            let top_tile = if !is_joker {
                draw_tile_from_board_deck(ref board)
            } else {
                board.top_tile
            };

            let (tile_city_points, tile_road_points) = calcucate_tile_points(tile);
            let (edges_city_points, edges_road_points) = calculate_adjacent_edge_points(
                board.initial_edge_state.clone(), col, row, tile.into(), rotation,
            );
            let (city_points, road_points) = (
                tile_city_points + edges_city_points, tile_road_points + edges_road_points,
            );
            if player_side == PlayerSide::Blue {
                let (old_city_points, old_road_points) = board.blue_score;
                board.blue_score = (old_city_points + city_points, old_road_points + road_points);
            } else {
                let (old_city_points, old_road_points) = board.red_score;
                board.red_score = (old_city_points + city_points, old_road_points + road_points);
            }

            let tile_position = (col * 8 + row).into();
            connect_city_edges_in_tile(
                ref store, duel_id, tile_position, tile.into(), rotation, player_side.into(),
            );
            let city_contest_scoring_result = connect_adjacent_city_edges(
                ref store,
                duel_id,
                board.state.clone(),
                board.initial_edge_state.clone(),
                tile_position,
                tile.into(),
                rotation,
                player_side.into(),
            );

            if city_contest_scoring_result.is_some() {
                let (winner, points_delta): (PlayerSide, u16) = city_contest_scoring_result
                    .unwrap();
                if winner == PlayerSide::Blue {
                    let (old_blue_city_points, old_blue_road_points) = board.blue_score;
                    board.blue_score = (old_blue_city_points + points_delta, old_blue_road_points);
                    let (old_red_city_points, old_red_road_points) = board.red_score;
                    board.red_score = (old_red_city_points - points_delta, old_red_road_points);
                } else {
                    let (old_blue_city_points, old_blue_road_points) = board.blue_score;
                    board.blue_score = (old_blue_city_points - points_delta, old_blue_road_points);
                    let (old_red_city_points, old_red_road_points) = board.red_score;
                    board.red_score = (old_red_city_points + points_delta, old_red_road_points);
                }
            }

            connect_road_edges_in_tile(
                ref store, duel_id, tile_position, tile.into(), rotation, player_side.into(),
            );
            let road_contest_scoring_results = connect_adjacent_road_edges(
                ref store,
                duel_id,
                board.state.clone(),
                board.initial_edge_state.clone(),
                tile_position,
                tile.into(),
                rotation,
                player_side.into(),
            );

            for i in 0..road_contest_scoring_results.len() {
                let road_scoring_result = *road_contest_scoring_results.at(i.into());
                if road_scoring_result.is_some() {
                    let (winner, points_delta) = road_scoring_result.unwrap();
                    if winner == PlayerSide::Blue {
                        let (old_blue_city_points, old_blue_road_points) = board.blue_score;
                        board
                            .blue_score =
                                (old_blue_city_points, old_blue_road_points + points_delta);
                        let (old_red_city_points, old_red_road_points) = board.red_score;
                        board.red_score = (old_red_city_points, old_red_road_points - points_delta);
                    } else {
                        let (old_blue_city_points, old_blue_road_points) = board.blue_score;
                        board
                            .blue_score =
                                (old_blue_city_points, old_blue_road_points - points_delta);
                        let (old_red_city_points, old_red_road_points) = board.red_score;
                        board.red_score = (old_red_city_points, old_red_road_points + points_delta);
                    }
                }
            };

            update_board_state(ref board, tile, rotation, col, row, is_joker, player_side);

            let (joker_number1, joker_number2) = update_board_joker_number(
                ref board, player_side, is_joker,
            );

            board.last_move_id = Option::Some(move_id);
            self.move_id_generator.write(move_id + 1);

            if top_tile.is_none() && joker_number1 == 0 && joker_number2 == 0 {
                //FINISH THE GAME
                self._finish_game(ref board, ref challenge);
            }

            store.set_move(@move);

            store
                .set_board_available_tiles_in_deck(
                    duel_id, board.available_tiles_in_deck.clone(),
                );

            store.set_board_top_tile(duel_id, top_tile);

            store.set_board_state(duel_id, board.state.clone());

            store.set_board_player1(
                duel_id,
                (player1_address, player1_side, joker_number1),
            );

            store
                .set_board_player2(
                    duel_id,
                    (player2_address, player2_side, joker_number2),
                );
            
            store.set_board_blue_score(
                duel_id,
                board.blue_score,
            );

            store.set_board_red_score(
                duel_id,
                board.red_score,
            );

            store.set_board_last_move_id(
                duel_id,
                board.last_move_id,
            );
            store.set_board_game_state(
                duel_id,
                board.game_state,
            );

            store
                .emit_event(
                    @Moved {
                        move_id,
                        player,
                        prev_move_id: move.prev_move_id,
                        tile: move.tile,
                        rotation: move.rotation,
                        col: move.col,
                        row: move.row,
                        is_joker: move.is_joker,
                        duel_id,
                        timestamp: move.timestamp,
                    },
                );
            store
                .emit_event(
                    @BoardUpdated {
                        duel_id: board.id,
                        available_tiles_in_deck: board.available_tiles_in_deck,
                        top_tile: board.top_tile,
                        state: board.state,
                        player1: board.player1,
                        player2: board.player2,
                        blue_score: board.blue_score,
                        red_score: board.red_score,
                        last_move_id: board.last_move_id,
                        game_state: board.game_state,
                    },
                );
        }

        fn skip_move(ref self: ContractState) {
            let mut store = StoreTrait::new(self.world_default());
            let player = get_caller_address();
            let assignment = store.get_player_challenge(player);
            let duel_id = assignment.duel_id;
            if duel_id == 0 {
                store.emit_event(@PlayerNotInGame { player_id: player, duel_id: 0 });
                return;
            }

            let mut challenge: Challenge = store.get_challenge(duel_id);

            assert!(challenge.state == ChallengeState::InProgress, "Challenge is not live");

            let mut board: Board = store.get_board(duel_id);

            let (player1_address, player1_side, _) = board.player1;
            let (player2_address, player2_side, _) = board.player2;

            let player_side = if player == player1_address {
                player1_side
            } else if player == player2_address {
                player2_side
            } else {
                store.emit_event(@PlayerNotInGame { player_id: player, duel_id });
                return;
            };

            let prev_move_id = board.last_move_id;
            if prev_move_id.is_some() {
                let prev_move_id = prev_move_id.unwrap();
                let prev_move: Move = store.get_move(prev_move_id);
                let prev_player_side = prev_move.player_side;

                let time = get_block_timestamp();
                let prev_move_time = prev_move.timestamp;
                let time_delta = time - prev_move_time;

                if player_side == prev_player_side {
                    if time_delta > MOVE_TIME {
                        //Skip the move of the previous player
                        let another_player = if player == player1_address {
                            player2_address
                        } else {
                            player1_address
                        };
                        let another_player_side = if player == player1_address {
                            player2_side
                        } else {
                            player1_side
                        };
                        self
                            ._skip_move(
                                another_player,
                                another_player_side,
                                ref board,
                                self.move_id_generator,
                            )
                    }

                    if time_delta <= MOVE_TIME || time_delta > 2 * MOVE_TIME {
                        store.emit_event(@NotYourTurn { player_id: player, duel_id });
                        return;
                    }
                } else {
                    if time_delta > MOVE_TIME {
                        store.emit_event(@NotYourTurn { player_id: player, duel_id });
                        return;
                    }
                }

                let prev_move_id = board.last_move_id.unwrap();
                let prev_move: Move = store.get_move(prev_move_id);

                if prev_move.tile.is_none() && !prev_move.is_joker {
                    //FINISH THE GAME
                    self._finish_game(ref board, ref challenge);
                }
            };
            redraw_tile_from_board_deck(ref board);
            store
                .set_board_available_tiles_in_deck(
                    duel_id, board.available_tiles_in_deck.clone(),
                );
            store
                .set_board_top_tile(duel_id, board.top_tile);

            self._skip_move(player, player_side, ref board, self.move_id_generator);
        }

        fn finish_game(ref self: ContractState, duel_id: felt252) {
            let mut store = StoreTrait::new(self.world_default());
            let player = get_caller_address();
            let assignment = store.get_player_challenge(player);
            let duel_id = assignment.duel_id;
            if duel_id == 0 {
                store.emit_event(@PlayerNotInGame { player_id: player, duel_id: 0 });
                return;
            }

            let mut challenge: Challenge = store.get_challenge(duel_id);

            assert!(challenge.state == ChallengeState::InProgress, "Challenge is not live");

            let mut board: Board = store.get_board(duel_id);

            let last_move: Move = store.get_move(board.last_move_id.unwrap());
            let timestamp = get_block_timestamp();
            let time_delta = timestamp - last_move.timestamp;
            if time_delta > 2 * MOVE_TIME {
                //FINISH THE GAME
                self._finish_game(ref board, ref challenge);
                return;
            } else {
                store.emit_event(@CantFinishGame { player_id: player, duel_id });
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
        ) {
            let mut store = StoreTrait::new(self.world_default());
            let move_id = self.move_id_generator.read();
            let duel_id = board.id;

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
                first_board_id: duel_id,
                timestamp,
            };

            board.last_move_id = Option::Some(move_id);
            move_id_generator.write(move_id + 1);

            store.set_move(@move);

            store
                .set_board_last_move_id(
                    duel_id,
                    board.last_move_id,
                );

            store
                .emit_event(
                    @Skiped {
                        move_id, player, prev_move_id: move.prev_move_id, duel_id, timestamp,
                    },
                );
            store
                .emit_event(
                    @BoardUpdated {
                        duel_id: board.id,
                        available_tiles_in_deck: board.available_tiles_in_deck.clone(),
                        top_tile: board.top_tile,
                        state: board.state.clone(),
                        player1: board.player1,
                        player2: board.player2,
                        blue_score: board.blue_score,
                        red_score: board.red_score,
                        last_move_id: board.last_move_id,
                        game_state: board.game_state,
                    },
                );
        }

        fn _finish_game(ref self: ContractState, ref board: Board, ref challenge: Challenge) {
            //FINISH THE GAME
            let mut store = StoreTrait::new(self.world_default());
            let city_scoring_results = close_all_cities(ref store, board.id);
            for i in 0..city_scoring_results.len() {
                let city_scoring_result = *city_scoring_results.at(i.into());
                if city_scoring_result.is_some() {
                    let (winner, points_delta) = city_scoring_result.unwrap();
                    if winner == PlayerSide::Blue {
                        let (old_blue_city_points, old_blue_road_points) = board.blue_score;
                        board
                            .blue_score =
                                (old_blue_city_points + points_delta, old_blue_road_points);
                        let (old_red_city_points, old_red_road_points) = board.red_score;
                        board.red_score = (old_red_city_points - points_delta, old_red_road_points);
                    } else {
                        let (old_blue_city_points, old_blue_road_points) = board.blue_score;
                        board
                            .blue_score =
                                (old_blue_city_points - points_delta, old_blue_road_points);
                        let (old_red_city_points, old_red_road_points) = board.red_score;
                        board.red_score = (old_red_city_points + points_delta, old_red_road_points);
                    }
                }
            };

            let road_scoring_results = close_all_roads(ref store, board.id);
            for i in 0..road_scoring_results.len() {
                let road_scoring_result = *road_scoring_results.at(i.into());
                if road_scoring_result.is_some() {
                    let (winner, points_delta) = road_scoring_result.unwrap();
                    if winner == PlayerSide::Blue {
                        let (old_blue_city_points, old_blue_road_points) = board.blue_score;
                        board
                            .blue_score =
                                (old_blue_city_points, old_blue_road_points + points_delta);
                        let (old_red_city_points, old_red_road_points) = board.red_score;
                        board.red_score = (old_red_city_points, old_red_road_points - points_delta);
                    } else {
                        let (old_blue_city_points, old_blue_road_points) = board.blue_score;
                        board
                            .blue_score =
                                (old_blue_city_points, old_blue_road_points - points_delta);
                        let (old_red_city_points, old_red_road_points) = board.red_score;
                        board.red_score = (old_red_city_points, old_red_road_points + points_delta);
                    }
                }
            };

            let (player1_address, player1_side, joker_number1) = board.player1;
            let (player2_address, _player2_side, joker_number2) = board.player2;

            board.game_state = GameState::Finished;
           


            store.emit_event(@GameFinished { host_player: player1_address, duel_id: board.id });
            store.emit_event(@GameFinished { host_player: player2_address, duel_id: board.id });

            let mut player1: Player = store.get_player(player1_address);
            let mut player2: Player = store.get_player(player2_address);

            let rules: Rules = store.get_rules();
            let joker_price = rules.joker_price;
            let blue_joker_points = joker_number1.into() * joker_price;
            let red_joker_points = joker_number2.into() * joker_price;
            let (blue_city_points, blue_road_points) = board.blue_score;
            let blue_points = blue_city_points + blue_road_points + blue_joker_points;
            let (red_city_points, red_road_points) = board.red_score;
            let red_points = red_city_points + red_road_points + red_joker_points;
            if player1_side == PlayerSide::Blue {
                player1.balance += blue_points;
                player2.balance += red_points;
    
            } else if player1_side == PlayerSide::Red {
                player1.balance += red_points;
                player2.balance += blue_points;
            }

            //Finish challenge

            let winner = if blue_points > red_points {
                Option::Some(1)
            } else if blue_points < red_points {
                Option::Some(2)
            } else {
                Option::Some(0)
            };
            
            self._finish_challenge(ref store, ref challenge, winner);


            store.set_player(@player1);
            store
                .emit_event(
                    @CurrentPlayerBalance { player_id: player1_address, balance: player1.balance },
                );

            store.set_player(@player2);
            store
                .emit_event(
                    @CurrentPlayerBalance { player_id: player2_address, balance: player2.balance },
                );


            store.set_board_blue_score(
                board.id,
                board.blue_score,
            );
            store.set_board_red_score(
                board.id,
                board.red_score,
            );
            store.set_board_game_state(
                board.id,
                board.game_state,
            );
            store
                .emit_event(
                    @BoardUpdated {
                        duel_id: board.id,
                        available_tiles_in_deck: board.available_tiles_in_deck.clone(),
                        top_tile: board.top_tile,
                        state: board.state.clone(),
                        player1: board.player1,
                        player2: board.player2,
                        blue_score: board.blue_score,
                        red_score: board.red_score,
                        last_move_id: board.last_move_id,
                        game_state: board.game_state,
                    },
                );
        }
        fn _finish_challenge(ref self: ContractState, ref store: Store, ref challenge: Challenge, winner: Option<u8>) {
            match winner {
                Option::Some(winner) => {
                    challenge.winner = winner;
                    challenge.state =
                        if (winner == 0) {ChallengeState::Draw}
                        else {ChallengeState::Resolved};
                },
                Option::None => {}
            }
            challenge.timestamps.end = starknet::get_block_timestamp();
            store.set_challenge(@challenge);
            // unset pact (if set)
            challenge.unset_pact(ref store);
            // exit challenge
            store.exit_challenge(challenge.address_a);
            store.exit_challenge(challenge.address_b);
            // distributions
            if (challenge.state.is_finished() && challenge.duel_type == DuelType::Tournament) {
                // transfer rewards
                let tournament_id: u64 = store.get_duel_tournament_keys(challenge.duel_id).tournament_id;
                // todo: calc rewards due to tournament rules
                let (mut rewards_a, mut rewards_b) = if (challenge.winner == 0) {
                    (1, 1)
                } else if (challenge.winner == 1) {
                    (3, 0)
                } else {
                    (0, 3)
                };

                // update leaderboards
                self._update_scoreboards(tournament_id, ref store, @challenge, rewards_a, rewards_b);
            }
        }

        fn _update_scoreboards(self: @ContractState, tournament_id: u64, ref store: Store, challenge: @Challenge, rewards_a: u16, rewards_b: u16) {
            // per season score
            let mut scoreboard_a: Scoreboard = store.get_scoreboard(tournament_id, *challenge.address_a);
            let mut scoreboard_b: Scoreboard = store.get_scoreboard(tournament_id, *challenge.address_b);
            scoreboard_a.apply_rewards(rewards_a);
            scoreboard_b.apply_rewards(rewards_b);
            // save
            store.set_scoreboard(@scoreboard_a);
            store.set_scoreboard(@scoreboard_b);
        }
    }
}
