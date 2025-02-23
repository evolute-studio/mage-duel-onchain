use starknet::ContractAddress;

// define the interface
#[starknet::interface]
pub trait IGame<T> {
    fn create_game(ref self: T);
    fn cancel_game(ref self: T);
    fn join_game(ref self: T, host_player: ContractAddress);
    fn make_move(ref self: T, joker_tile: Option<u8>, rotation: u8, col: u8, row: u8);
    fn skip_move(ref self: T);
    fn create_snapshot(ref self: T, board_id: felt252, move_delta: u8);
    fn create_game_from_snapshot(ref self: T, snapshot_id: felt252);
}

// dojo decorator
#[dojo::contract]
pub mod game {
    use super::{IGame};
    use starknet::{ContractAddress, get_caller_address};
    use evolute_duel::{
        models::{Board, Rules, Move, Game, Snapshot},
        events::{
            GameCreated, GameCreateFailed, GameJoinFailed, GameStarted, GameCanceled, BoardUpdated,
            PlayerNotInGame, NotYourTurn, NotEnoughJokers, GameFinished, GameIsAlreadyFinished,
            Skiped, Moved, SnapshotCreated, SnapshotCreateFailed, BoardCreateFromSnapshotFalied,
        },
        systems::helpers::{
            board::{
                create_board, draw_tile_from_board_deck, update_board_state,
                update_board_joker_number, create_board_from_snapshot,
            },
            city_scoring::{
                connect_city_edges_in_tile, connect_adjacent_city_edges, close_all_cities,
            },
            road_scoring::{
                connect_road_edges_in_tile, connect_adjacent_road_edges, close_all_roads,
            },
            tile_helpers::{calcucate_tile_points},
        },
        packing::{GameStatus, Tile, GameState, PlayerSide},
    };

    use dojo::event::EventStorage;
    use dojo::model::{ModelStorage, Model};

    use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    struct Storage {
        board_id_generator: felt252,
        move_id_generator: felt252,
        snapshot_id_generator: felt252,
    }


    fn dojo_init(self: @ContractState) {
        let mut world = self.world(@"evolute_duel");
        let id = 0;
        let deck: Array<u8> = array![
            1, // CCCC
            1, // FFFF
            0, // RRRR - not in the deck
            4, // CCCF
            3, // CCCR
            4, // CFFF
            0, // FFFR
            0, // CRRR - not in the deck
            4, // FRRR
            0, // CCFF - not in the deck
            6, // CFCF
            0, // CCRR - not in the deck
            0, // CRCR - not in the deck
            9, // FFRR
            8, // FRFR
            0, // CCFR - not in the deck
            0, // CCRF - not in the deck
            7, // CFCR
            4, // CFFR
            4, // CFRF
            0, // CRFF - not in the deck
            3, // CRRF
            4, // CRFR
            4 // CFRR
        ];
        let edges = (1, 1);
        let joker_number = 3;

        let rules = Rules { id, deck, edges, joker_number };
        world.write_model(@rules);
    }

    #[abi(embed_v0)]
    impl GameImpl of IGame<ContractState> {
        fn create_game(ref self: ContractState) {
            let mut world = self.world_default();

            let host_player = get_caller_address();

            let mut game: Game = world.read_model(host_player);
            let mut status = game.status;

            if status == GameStatus::InProgress || status == GameStatus::Created {
                world.emit_event(@GameCreateFailed { host_player, status });
                return;
            }

            status = GameStatus::Created;
            game.status = status;
            game.board_id = Option::None;

            world.write_model(@game);

            world.emit_event(@GameCreated { host_player, status });
        }

        fn create_snapshot(ref self: ContractState, board_id: felt252, move_delta: u8) {
            let mut world = self.world_default();
            let player = get_caller_address();

            let board: Board = world.read_model(board_id);
            if board.game_state != GameState::Finished || move_delta == 0 {
                world
                    .emit_event(
                        @SnapshotCreateFailed {
                            player, board_id, board_game_state: board.game_state, move_delta,
                        },
                    );
                return;
            }

            let snapshot_id = self.snapshot_id_generator.read();

            let snapshot = Snapshot { snapshot_id, player, board_id, move_delta };

            self.snapshot_id_generator.write(snapshot_id + 1);

            world.write_model(@snapshot);

            world.emit_event(@SnapshotCreated { snapshot_id, player, board_id, move_delta });
        }

        fn create_game_from_snapshot(ref self: ContractState, snapshot_id: felt252) {
            let mut world = self.world_default();

            let host_player = get_caller_address();

            let snapshot: Snapshot = world.read_model(snapshot_id);
            let board_id = snapshot.board_id;
            let move_delta = snapshot.move_delta;

            let board: Board = world.read_model(board_id);

            if board.game_state != GameState::Finished || move_delta == 0 {
                world
                    .emit_event(
                        @BoardCreateFromSnapshotFalied {
                            player: host_player, old_board_id: board_id, move_delta,
                        },
                    );
                return;
            }

            let mut game: Game = world.read_model(host_player);
            let mut status = game.status;

            if status == GameStatus::InProgress || status == GameStatus::Created {
                world.emit_event(@GameCreateFailed { host_player, status });
                return;
            }

            status = GameStatus::Created;
            game.status = status;
            game
                .board_id =
                    Option::Some(
                        create_board_from_snapshot(
                            ref world, board_id, move_delta, host_player, self.board_id_generator,
                        ),
                    );

            world.write_model(@game);

            world.emit_event(@GameCreated { host_player, status });
        }

        fn cancel_game(ref self: ContractState) {
            let mut world = self.world_default();

            let host_player = get_caller_address();

            let mut game: Game = world.read_model(host_player);
            let status = game.status;

            if status == GameStatus::Created {
                let new_status = GameStatus::Canceled;
                game.status = new_status;
                game.board_id = Option::None;

                world.write_model(@game);

                world.emit_event(@GameCanceled { host_player, status: new_status });
            } else {
                world.emit_event(@GameCreateFailed { host_player, status });
            }
        }

        fn join_game(ref self: ContractState, host_player: ContractAddress) {
            let mut world = self.world_default();
            let guest_player = get_caller_address();

            let mut host_game: Game = world.read_model(host_player);
            let host_game_status = host_game.status;

            let mut guest_game: Game = world.read_model(guest_player);
            let guest_game_status = guest_game.status;

            if host_game_status != GameStatus::Created
                || guest_game_status == GameStatus::Created
                || guest_game_status == GameStatus::InProgress
                || host_player == guest_player {
                world
                    .emit_event(
                        @GameJoinFailed {
                            host_player, guest_player, host_game_status, guest_game_status,
                        },
                    );
                return;
            }
            host_game.status = GameStatus::InProgress;
            guest_game.status = GameStatus::InProgress;

            let board_id: felt252 = if host_game.board_id.is_none() {
                let board = create_board(
                    ref world, host_player, guest_player, self.board_id_generator,
                );
                board.id
            } // When game is created from snapshot
            else {
                host_game.board_id.unwrap()
            };

            host_game.board_id = Option::Some(board_id);
            guest_game.board_id = Option::Some(board_id);

            world.write_model(@host_game);
            world.write_model(@guest_game);
            world.emit_event(@GameStarted { host_player, guest_player, board_id });
        }

        fn make_move(
            ref self: ContractState, joker_tile: Option<u8>, rotation: u8, col: u8, row: u8,
        ) {
            let mut world = self.world_default();
            let player = get_caller_address();
            let game: Game = world.read_model(player);

            if game.board_id.is_none() {
                world.emit_event(@PlayerNotInGame { player_id: player, board_id: 0 });
                return;
            }

            let board_id = game.board_id.unwrap();
            let mut board: Board = world.read_model(board_id);

            if game.status == GameStatus::Finished {
                world.emit_event(@GameIsAlreadyFinished { player_id: player, board_id });
                return;
            }

            let move_id = self.move_id_generator.read();

            let tile: Tile = match joker_tile {
                Option::Some(tile_index) => { tile_index.into() },
                Option::None => {
                    match @board.top_tile {
                        Option::Some(top_tile) => { (*top_tile).into() },
                        Option::None => {
                            //TODO: Error: no joker and no top tile. Move is impossible
                            return;
                        },
                    }
                },
            };

            let (player1_address, player1_side, joker_number1) = board.player1;
            let (player2_address, player2_side, joker_number2) = board.player2;

            let (player_side, joker_number) = if player == player1_address {
                (player1_side, joker_number1)
            } else if player == player2_address {
                (player2_side, joker_number2)
            } else {
                //Error: player is not in the game
                world.emit_event(@PlayerNotInGame { player_id: player, board_id });
                return;
            };

            let is_joker = joker_tile.is_some();

            //check if enough jokers
            if is_joker && joker_number == 0 {
                world.emit_event(@NotEnoughJokers { player_id: player, board_id });
                return;
            }

            //check if it is the player's turn
            let prev_move_id = board.last_move_id;
            if prev_move_id.is_some() {
                let prev_move_id = prev_move_id.unwrap();
                let prev_move: Move = world.read_model(prev_move_id);
                let prev_player_side = prev_move.player_side;

                if player_side == prev_player_side {
                    //Error: turn of the other player
                    world.emit_event(@NotYourTurn { player_id: player, board_id });
                    return;
                }
            };

            let move = Move {
                id: move_id,
                prev_move_id: board.last_move_id,
                player_side,
                tile: Option::Some(tile.into()),
                rotation: rotation,
                col,
                row,
                is_joker,
            };

            //TODO: check if the move is valid

            //Draw a tile from the board deck if it is not a joker
            let top_tile = if !is_joker {
                draw_tile_from_board_deck(ref board)
            } else {
                board.top_tile
            };

            //Tile scoring
            let tile_points = calcucate_tile_points(tile);
            if player_side == PlayerSide::Blue {
                board.blue_score += tile_points;
            } else {
                board.red_score += tile_points;
            }

            //City scoring
            let tile_position = (col * 8 + row).into();
            //TODO: use span instead of clone
            connect_city_edges_in_tile(
                ref world, board_id, tile_position, tile.into(), rotation, player_side.into(),
            );
            //TODO: use span instead of clone
            let city_contest_scoring_result = connect_adjacent_city_edges(
                ref world,
                board_id,
                board.state.clone(),
                board.initial_edge_state.clone(),
                tile_position,
                tile.into(),
                rotation,
                player_side.into(),
            );
            if city_contest_scoring_result.is_some() {
                let (winner, points_delta) = city_contest_scoring_result.unwrap();
                if winner == PlayerSide::Blue {
                    board.blue_score += points_delta;
                    board.red_score -= points_delta;
                } else {
                    board.red_score += points_delta;
                    board.blue_score -= points_delta;
                }
            }

            //Road scoring
            connect_road_edges_in_tile(
                ref world, board_id, tile_position, tile.into(), rotation, player_side.into(),
            );
            let road_contest_scoring_results = connect_adjacent_road_edges(
                ref world,
                board_id,
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
                        board.blue_score += points_delta;
                        board.red_score -= points_delta;
                    } else {
                        board.red_score += points_delta;
                        board.blue_score -= points_delta;
                    }
                }
            };

            //Update board state
            update_board_state(ref board, tile, rotation, col, row, is_joker, player_side);

            //Update joker number
            let (joker_number1, joker_number2) = update_board_joker_number(
                ref board, player_side, is_joker,
            );

            board.last_move_id = Option::Some(move_id);
            self.move_id_generator.write(move_id + 1);

            if top_tile.is_none() && joker_number1 == 0 && joker_number2 == 0 {
                //FINISH THE GAME

                //Score all potantial cities and roads
                let city_scoring_results = close_all_cities(ref world, board_id);
                for i in 0..city_scoring_results.len() {
                    let city_scoring_result = *city_scoring_results.at(i.into());
                    if city_scoring_result.is_some() {
                        let (winner, points_delta) = city_scoring_result.unwrap();
                        if winner == PlayerSide::Blue {
                            board.blue_score += points_delta;
                            board.red_score -= points_delta;
                        } else {
                            board.red_score += points_delta;
                            board.blue_score -= points_delta;
                        }
                    }
                };

                let road_scoring_results = close_all_roads(ref world, board_id);
                for i in 0..road_scoring_results.len() {
                    let road_scoring_result = *road_scoring_results.at(i.into());
                    if road_scoring_result.is_some() {
                        let (winner, points_delta) = road_scoring_result.unwrap();
                        if winner == PlayerSide::Blue {
                            board.blue_score += points_delta;
                            board.red_score -= points_delta;
                        } else {
                            board.red_score += points_delta;
                            board.blue_score -= points_delta;
                        }
                    }
                };

                board.game_state = GameState::Finished;
                let mut host_game: Game = world.read_model(player1_address);
                let mut guest_game: Game = world.read_model(player2_address);
                host_game.status = GameStatus::Finished;
                guest_game.status = GameStatus::Finished;

                world.write_model(@host_game);
                world.write_model(@guest_game);

                world.emit_event(@GameFinished { host_player: player1_address, board_id });
                world.emit_event(@GameFinished { host_player: player2_address, board_id });
            }

            world.write_model(@move);

            world
                .write_member(
                    Model::<Board>::ptr_from_keys(board_id),
                    selector!("available_tiles_in_deck"),
                    board.available_tiles_in_deck.clone(),
                );

            world
                .write_member(
                    Model::<Board>::ptr_from_keys(board_id),
                    selector!("top_tile"),
                    top_tile,
                );

            world
                .write_member(
                    Model::<Board>::ptr_from_keys(board_id),
                    selector!("state"),
                    board.state.clone(),
                );

            world
                .write_member(
                    Model::<Board>::ptr_from_keys(board_id),
                    selector!("player1"),
                    board.player1,
                );

            world   
                .write_member(
                    Model::<Board>::ptr_from_keys(board_id),
                    selector!("player2"),
                    board.player2,
                );
            
            world   
                .write_member(
                    Model::<Board>::ptr_from_keys(board_id),
                    selector!("blue_score"),
                    board.blue_score,
                );

            world
                .write_member(
                    Model::<Board>::ptr_from_keys(board_id),
                    selector!("red_score"),
                    board.red_score,
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
                    selector!("game_state"),
                    board.game_state,
                );

            world
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
                        board_id,
                    },
                );
            world
                .emit_event(
                    @BoardUpdated {
                        board_id: board.id,
                        available_tiles_in_deck: board.available_tiles_in_deck,
                        top_tile: board.top_tile,
                        state: board.state,
                        player1: board.player1,
                        player2: board.player2,
                        last_move_id: board.last_move_id,
                        game_state: board.game_state,
                    },
                );
            // // Check if the game is in progress.

        }

        fn skip_move(ref self: ContractState) {
            let mut world = self.world_default();
            let player = get_caller_address();
            let game: Game = world.read_model(player);

            if game.board_id.is_none() {
                world.emit_event(@PlayerNotInGame { player_id: player, board_id: 0 });
                return;
            }

            let board_id = game.board_id.unwrap();
            let mut board: Board = world.read_model(board_id);

            if game.status == GameStatus::Finished {
                world.emit_event(@GameIsAlreadyFinished { player_id: player, board_id });
                return;
            }

            let move_id = self.move_id_generator.read();

            let (player1_address, player1_side, _) = board.player1;
            let (player2_address, player2_side, _) = board.player2;

            let player_side = if player == player1_address {
                player1_side
            } else if player == player2_address {
                player2_side
            } else {
                //TODO: Error: player is not in the game
                world.emit_event(@PlayerNotInGame { player_id: player, board_id });
                return;
            };

            //check if it is the player's turn
            let prev_move_id = board.last_move_id;
            if prev_move_id.is_some() {
                let prev_move_id = prev_move_id.unwrap();
                let prev_move: Move = world.read_model(prev_move_id);
                let prev_player_side = prev_move.player_side;

                if player_side == prev_player_side {
                    //TODO: Error: turn of the other player
                    world.emit_event(@NotYourTurn { player_id: player, board_id });
                    return;
                }

                //check if last move was a skip
                if prev_move.tile.is_none() && !prev_move.is_joker {
                    //FINISH THE GAME
                    let city_scoring_results = close_all_cities(ref world, board_id);
                    for i in 0..city_scoring_results.len() {
                        let city_scoring_result = *city_scoring_results.at(i.into());
                        if city_scoring_result.is_some() {
                            let (winner, points_delta) = city_scoring_result.unwrap();
                            if winner == PlayerSide::Blue {
                                board.blue_score += points_delta;
                                board.red_score -= points_delta;
                            } else {
                                board.red_score += points_delta;
                                board.blue_score -= points_delta;
                            }
                        }
                    };

                    let road_scoring_results = close_all_roads(ref world, board_id);
                    for i in 0..road_scoring_results.len() {
                        let road_scoring_result = *road_scoring_results.at(i.into());
                        if road_scoring_result.is_some() {
                            let (winner, points_delta) = road_scoring_result.unwrap();
                            if winner == PlayerSide::Blue {
                                board.blue_score += points_delta;
                                board.red_score -= points_delta;
                            } else {
                                board.red_score += points_delta;
                                board.blue_score -= points_delta;
                            }
                        }
                    };

                    board.game_state = GameState::Finished;
                    let mut host_game: Game = world.read_model(player1_address);
                    let mut guest_game: Game = world.read_model(player2_address);
                    host_game.status = GameStatus::Finished;
                    guest_game.status = GameStatus::Finished;

                    world.write_model(@host_game);
                    world.write_model(@guest_game);

                    world.emit_event(@GameFinished { host_player: player1_address, board_id });
                    world.emit_event(@GameFinished { host_player: player2_address, board_id })
                }
            };

            let move = Move {
                id: move_id,
                prev_move_id: board.last_move_id,
                player_side,
                tile: Option::None,
                rotation: 0,
                col: 0,
                row: 0,
                is_joker: false,
            };

            board.last_move_id = Option::Some(move_id);
            self.move_id_generator.write(move_id + 1);

            world.write_model(@move);
            world.write_model(@board);

            world
                .emit_event(@Skiped { move_id, player, prev_move_id: move.prev_move_id, board_id });
            world
                .emit_event(
                    @BoardUpdated {
                        board_id: board.id,
                        available_tiles_in_deck: board.available_tiles_in_deck,
                        top_tile: board.top_tile,
                        state: board.state,
                        player1: board.player1,
                        player2: board.player2,
                        last_move_id: board.last_move_id,
                        game_state: board.game_state,
                    },
                );
        }
    }


    // fn is_move_valid(
    //     mut board: Board, mut tile: Option<Tile>, rotation: u8, col: u8, row: u8, is_joker: bool,
    // ) -> bool {
    //     // Check if the tile on top of the random deck.
    //     if board.random_deck.is_empty() {
    //         return false;
    //     }

    //     if is_joker {
    //         if tile == Option::None {
    //             return false;
    //         }
    //     } else {
    //         tile = Option::Some(board.random_deck.pop_front().unwrap().into());
    //     }

    //     // Check if the tile is already placed on the board.
    //     if board.tiles.get((col + row * 8).into()).is_some() {
    //         return false;
    //     }

    //     let tile: TileStruct = tile.unwrap().into();
    //     // Check if the tile can be placed on the board.
    //     if !is_tile_allowed_to_place(board, tile, rotation, col, row) {
    //         return false;
    //     }

    //     return true;
    // }

    // fn is_tile_allowed_to_place(
    //     board: Board, tile: TileStruct, rotation: u8, col: u8, row: u8,
    // ) -> bool {
    //     let edges: [TEdge; 4] = [
    //         *tile.edges.span()[((0 + rotation) % 4).into()],
    //         *tile.edges.span()[((1 + rotation) % 4).into()],
    //         *tile.edges.span()[((2 + rotation) % 4).into()],
    //         *tile.edges.span()[((3 + rotation) % 4).into()],
    //     ];
    //     let edges = edges.span();

    //     let mut is_move_valid = true;

    //     for i in 0..4_u8 {
    //         let mut neighbor_col = col;
    //         let mut neighbor_row = row;
    //         if (i == 0) {
    //             if neighbor_row == 0 {
    //                 continue;
    //             }
    //             neighbor_row -= 1;
    //         } else if (i == 1) {
    //             if neighbor_col == 7 {
    //                 continue;
    //             }
    //             neighbor_col += 1;
    //         } else if (i == 2) {
    //             if neighbor_row == 7 {
    //                 continue;
    //             }
    //             neighbor_row += 1;
    //         } else {
    //             if neighbor_col == 0 {
    //                 continue;
    //             }
    //             neighbor_col -= 1;
    //         }

    //         let neighbor_tile: Option<TileStruct> = *board
    //             .tiles
    //             .at((neighbor_col + neighbor_row * 8).into());

    //         if neighbor_tile.is_some() {
    //             let neighbor_tile: TileStruct = neighbor_tile.unwrap();
    //             let neighbor_edges = neighbor_tile.edges.span();
    //             let neighbor_edge: TEdge = *neighbor_edges.at(((i + 2) % 4).into());

    //             if *edges.at(i.into()) != neighbor_edge {
    //                 is_move_valid = false;
    //                 break;
    //             }
    //         }
    //     };

    //     return true;
    // }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"evolute_duel")
        }
    }
}
