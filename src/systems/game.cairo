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

    /// Makes a move by placing a tile on the board.
    /// - `joker_tile`: Optional joker tile played during the move.
    /// - `rotation`: Rotation applied to the placed tile.
    /// - `col`: Column where the tile is placed.
    /// - `row`: Row where the tile is placed.
    fn make_move(ref self: T, joker_tile: Option<u8>, rotation: u8, col: u8, row: u8);

    /// Skips the current player's move.
    fn skip_move(ref self: T);

    /// Creates a snapshot of the current game state.
    /// - `board_id`: ID of the board being saved.
    /// - `move_number`: Move number at the time of snapshot.
    fn create_snapshot(ref self: T, board_id: felt252, move_number: u8);

    /// Restores a game session from a snapshot.
    /// - `snapshot_id`: ID of the snapshot to restore from.
    fn create_game_from_snapshot(ref self: T, snapshot_id: felt252);

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
            game::{Board, Rules, Move, Game, Snapshot},
            player::{Player},
            scoring::{UnionFind, UnionFindTrait},
        },
        events::{
            GameCreated, GameCreateFailed, GameJoinFailed, GameStarted, GameCanceled, BoardUpdated,
            PlayerNotInGame, NotYourTurn, NotEnoughJokers, GameFinished, GameIsAlreadyFinished,
            Skiped, Moved, SnapshotCreated, SnapshotCreateFailed, CurrentPlayerBalance, InvalidMove,
            CantFinishGame,
        },
        systems::helpers::{
            board::{
                create_board, draw_tile_from_board_deck, update_board_state,
                update_board_joker_number, create_board_from_snapshot, redraw_tile_from_board_deck,
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
        packing::{GameStatus, GameState, PlayerSide, UnionNode},
    };

    use evolute_duel::libs::{
        // store::{Store, StoreTrait},
        achievements::{AchievementsTrait},
    };
    use evolute_duel::types::trophies::index::{TROPHY_COUNT, Trophy, TrophyTrait};

    use dojo::event::EventStorage;
    use dojo::model::{ModelStorage, Model};

    use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use core::dict::Felt252Dict;

    use alexandria_data_structures::vec::{NullableVec, VecTrait};

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
        ].span();
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
            let mut status = game.status;

            if status == GameStatus::InProgress || status == GameStatus::Created {
                world.emit_event(@GameCreateFailed { host_player, status });
                println!("Game already created or in progress");
                return ;
            }

            status = GameStatus::Created;
            game.status = status;
            game.board_id = Option::None;
            game.snapshot_id = Option::None;

            world.write_model(@game);

            world.emit_event(@GameCreated { host_player, status });

            //[Achievements] Create game
            AchievementsTrait::create_game(world, host_player);
        }

        fn create_snapshot(ref self: ContractState, board_id: felt252, move_number: u8) {
            let mut world = self.world_default();
            let player = get_caller_address();

            let board: Board = world.read_model(board_id);
            let max_move_number = board.moves_done;

            if move_number > max_move_number {
                world
                    .emit_event(
                        @SnapshotCreateFailed {
                            player, board_id, board_game_state: board.game_state, move_number,
                        },
                    );
                println!("Snapshot create failed, move number is greater than max move number");
                return;
            }

            let snapshot_id = self.snapshot_id_generator.read();

            let snapshot = Snapshot { snapshot_id, player, board_id, move_number };

            self.snapshot_id_generator.write(snapshot_id + 1);

            world.write_model(@snapshot);

            world.emit_event(@SnapshotCreated { snapshot_id, player, board_id, move_number });
        }

        fn create_game_from_snapshot(ref self: ContractState, snapshot_id: felt252) {
            let mut world = self.world_default();

            let host_player = get_caller_address();

            let snapshot: Snapshot = world.read_model(snapshot_id);
            let board_id = snapshot.board_id;
            let move_number = snapshot.move_number;

            // println!("Move number: {:?}", move_number);

            let mut game: Game = world.read_model(host_player);
            let mut status = game.status;

            if status == GameStatus::InProgress || status == GameStatus::Created {
                world.emit_event(@GameCreateFailed { host_player, status });
                println!("Game already created or in progress");
                return ;
            }

            status = GameStatus::Created;
            game.status = status;
            game
                .board_id =
                    Option::Some(
                        create_board_from_snapshot(
                            ref world, board_id, host_player, move_number, self.board_id_generator,
                        ),
                    );
            game.snapshot_id = Option::Some(snapshot_id);

            world.write_model(@game);

            world.emit_event(@GameCreated { host_player, status });
        }

        fn cancel_game(ref self: ContractState) {
            let mut world = self.world_default();

            let host_player = get_caller_address();

            let mut game: Game = world.read_model(host_player);
            let status = game.status;

            if status == GameStatus::InProgress {
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
                game.snapshot_id = Option::None;

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
            game.snapshot_id = Option::None;

            world.write_model(@game);
            world.emit_event(@GameCanceled { host_player, status: new_status });
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
                println!("Game join failed");
                return ;
            }
            host_game.status = GameStatus::InProgress;
            guest_game.status = GameStatus::InProgress;

            let board_id: felt252 = if host_game.board_id.is_none() {
                let board = create_board(
                    ref world, host_player, guest_player, self.board_id_generator,
                );
                let mut union_find = UnionFindTrait::new(board.id);
                // println!("Union find: {:?}", union_find);
                UnionFindTrait::write_empty(board.id, world);
                union_find.write(world); 

                board.id
            } // When game is created from snapshot
            else {
                let board_id = host_game.board_id.unwrap();
                let mut board: Board = world.read_model(board_id);
                let (_, player1_side, joker_number1) = board.player2;
                board.player2 = (guest_player, player1_side, joker_number1);
                world
                    .write_member(
                        Model::<Board>::ptr_from_keys(board.id),
                        selector!("player2"),
                        board.player2,
                    );
                
                world
                    .write_member(
                        Model::<Board>::ptr_from_keys(board.id),
                        selector!("last_update_timestamp"),
                        get_block_timestamp(),
                    );

                board_id
            };

            host_game.board_id = Option::Some(board_id);
            guest_game.board_id = Option::Some(board_id);
            guest_game.snapshot_id = host_game.snapshot_id;

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
                println!("Player is not in game");
                return;
            }

            let board_id = game.board_id.unwrap();
            let mut board: Board = world.read_model(board_id);

            if game.status == GameStatus::Finished {
                world.emit_event(@GameIsAlreadyFinished { player_id: player, board_id });
                println!("Game is already finished");
                return;
            }

            let (player1_address, player1_side, joker_number1) = board.player1;
            let (player2_address, player2_side, joker_number2) = board.player2;

            let (player_side, joker_number) = if player == player1_address {
                (player1_side, joker_number1)
            } else if player == player2_address {
                (player2_side, joker_number2)
            } else {
                world.emit_event(@PlayerNotInGame { player_id: player, board_id });
                println!("Player is not in game");
                return;
            };

            let is_joker = joker_tile.is_some();

            if is_joker && joker_number == 0 {
                world.emit_event(@NotEnoughJokers { player_id: player, board_id });
                println!("Not enough jokers");
                return;
            }

            let prev_move_id = board.last_move_id;
            if prev_move_id.is_some() {
                let prev_move_id = prev_move_id.unwrap();
                let prev_move: Move = world.read_model(prev_move_id);
                let prev_player_side = prev_move.player_side;
                let time = get_block_timestamp();
                let last_update_timestamp = board.last_update_timestamp;
                let time_delta = time - last_update_timestamp;

                if player_side == prev_player_side {
                    if time_delta > MOVE_TIME && time_delta <= 2 * MOVE_TIME {
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
                                false,
                            )
                    }

                    if time_delta <= MOVE_TIME || time_delta > 2 * MOVE_TIME {
                        world.emit_event(@NotYourTurn { player_id: player, board_id });
                        println!("[Not your turn]");
                        return ;
                    }
                } else {
                    if time_delta > MOVE_TIME {
                        world.emit_event(@NotYourTurn { player_id: player, board_id });
                        println!("[Not your turn] Move time is over");
                        return ;
                    }
                }
            };

            let tile = match joker_tile {
                Option::Some(tile_index) => { tile_index },
                Option::None => {
                    match @board.top_tile {
                        Option::Some(top_tile) => { *top_tile },
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
                first_board_id: board_id,
                timestamp: get_block_timestamp(),
            };

            // TODO: revert invalid move when it's stable
            if !is_valid_move(
                tile.into(), rotation, col, row, board.state.span(), board.initial_edge_state,
            ) {
                world
                    .emit_event(
                        @InvalidMove {
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
                println!("[Invalid move] \nBoard: {:?} \nMove: {:?}", board, move);
                return ;
            }

            let top_tile = if !is_joker {
                draw_tile_from_board_deck(ref board)
            } else {
                board.top_tile
            };

            let mut union_find: UnionFind = world.read_model(board_id);

            let mut city_nodes = VecTrait::<NullableVec, UnionNode>::new();
            let mut road_nodes = VecTrait::<NullableVec, UnionNode>::new();
            // println!("Union find: {:?}", union_find);
            // println!("Union find sizes. node_parents: {:?}, node_types: {:?}, node_ranks: {:?}, node_blue_points: {:?}, node_red_points: {:?}, node_open_edges: {:?}, node_contested: {:?}, node_types: {:?}", union_find.nodes_parents.len(), union_find.nodes_types.len(), union_find.nodes_ranks.len(), union_find.nodes_blue_points.len(), union_find.nodes_red_points.len(), union_find.nodes_open_edges.len(), union_find.nodes_contested.len(), union_find.nodes_types.len());
            for i in 0..union_find.nodes_parents.len() {
                // println!("i: {}", i);
                let mut node: UnionNode = Default::default();
                node.node_type = *union_find.nodes_types.at(i.into());
                node.parent = *union_find.nodes_parents.at(i.into());
                node.rank = *union_find.nodes_ranks.at(i.into());
                node.blue_points = *union_find.nodes_blue_points.at(i.into());
                node.red_points = *union_find.nodes_red_points.at(i.into());
                node.open_edges = *union_find.nodes_open_edges.at(i.into());
                node.contested = *union_find.nodes_contested.at(i.into());
                if node.node_type == 1 {
                    road_nodes.push(UnionNode {
                        parent: i.try_into().unwrap(),
                        rank: 0,
                        blue_points: 0,
                        red_points: 0,
                        open_edges: 0,
                        contested: false,
                        node_type: 2, // 0 - City, 1 - Road, 2 - None
                    });
                    city_nodes.push(node);
                } else if node.node_type == 2 {
                    road_nodes.push(node);
                    city_nodes.push(UnionNode {
                        parent: i.try_into().unwrap(),
                        rank: 0,
                        blue_points: 0,
                        red_points: 0,
                        open_edges: 0,
                        contested: false,
                        node_type: 2, // 0 - City, 1 - Road, 2 - None
                    });
                } else {
                    road_nodes.push(UnionNode {
                        parent: i.try_into().unwrap(),
                        rank: 0,
                        blue_points: 0,
                        red_points: 0,
                        open_edges: 0,
                        contested: false,
                        node_type: 2, // 0 - City, 1 - Road, 2 - None
                    });
                    city_nodes.push(UnionNode {
                        parent: i.try_into().unwrap(),
                        rank: 0,
                        blue_points: 0,
                        red_points: 0,
                        open_edges: 0,
                        contested: false,
                        node_type: 2, // 0 - City, 1 - Road, 2 - None
                    });
                }
            };

            // print!("0");

            let (tile_city_points, tile_road_points) = calcucate_tile_points(tile.into());
            let (edges_city_points, edges_road_points) = calculate_adjacent_edge_points(
                ref board.initial_edge_state, col, row, tile.into(), rotation,
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

            let mut visited: Felt252Dict<bool> = Default::default();
            let tile_position = (col * 8 + row).into();

            // print!("1");
            connect_city_edges_in_tile(
                ref world, ref city_nodes, tile_position, tile.into(), rotation, player_side.into(),
            );
            //println!("2");
            let city_contest_scoring_result = connect_adjacent_city_edges(
                ref world,
                board_id,
                board.state.span(),
                ref board.initial_edge_state,
                ref city_nodes,
                tile_position,
                tile.into(),
                rotation,
                player_side.into(),
                player,
                ref visited,
                ref union_find.potential_city_contests,
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

            //println!("3");
            connect_road_edges_in_tile(
                ref world, ref road_nodes, tile_position, tile.into(), rotation, player_side.into(),
            );
            //println!("4");
            let road_contest_scoring_results = connect_adjacent_road_edges(
                ref world,
                board_id,
                board.state.span(),
                ref board.initial_edge_state,
                ref road_nodes,
                tile_position,
                tile.into(),
                rotation,
                player_side.into(),
                player,
                ref visited,
                ref union_find.potential_road_contests,
            );
            //println!("5");
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

            update_board_state(ref board, tile.into(), rotation, col, row, is_joker, player_side);

            let (joker_number1, joker_number2) = update_board_joker_number(
                ref board, player_side, is_joker,
            );

            board.last_move_id = Option::Some(move_id);
            board.moves_done = board.moves_done + 1;    
            self.move_id_generator.write(move_id + 1);

            if top_tile.is_none() && joker_number1 == 0 && joker_number2 == 0 {
                //FINISH THE GAME
                self
                    ._finish_game(
                        ref board, 
                        union_find.potential_city_contests.span(), 
                        union_find.potential_road_contests.span(),
                        ref city_nodes,
                        ref road_nodes,
                    );
            }

            let mut new_nodes_parents = array![];
            let mut new_nodes_ranks = array![];
            let mut new_nodes_blue_points = array![];
            let mut new_nodes_red_points = array![];
            let mut new_nodes_open_edges = array![];
            let mut new_nodes_contested = array![];
            let mut new_nodes_types = array![];
            println!("Road nodes length: {:?}", road_nodes.len());
            println!("City nodes length: {:?}", city_nodes.len());
            for i in 0..256_usize {
                let road_node = road_nodes.at(i.into());
                let city_node = city_nodes.at(i.into());
                if road_node.node_type == 1 {
                    new_nodes_types.append(road_node.node_type);
                    new_nodes_parents.append(road_node.parent);
                    new_nodes_ranks.append(road_node.rank);
                    new_nodes_blue_points.append(road_node.blue_points);
                    new_nodes_red_points.append(road_node.red_points);
                    new_nodes_open_edges.append(road_node.open_edges);
                    new_nodes_contested.append(road_node.contested);
                } else if city_node.node_type == 0 {
                    new_nodes_types.append(city_node.node_type);
                    new_nodes_parents.append(city_node.parent);
                    new_nodes_ranks.append(city_node.rank);
                    new_nodes_blue_points.append(city_node.blue_points);
                    new_nodes_red_points.append(city_node.red_points);
                    new_nodes_open_edges.append(city_node.open_edges);
                    new_nodes_contested.append(city_node.contested);
                } else {
                    new_nodes_types.append(2); // 0 - City, 1 - Road, 2 - None
                    new_nodes_parents.append(i.try_into().unwrap());
                    new_nodes_ranks.append(0);
                    new_nodes_blue_points.append(0);
                    new_nodes_red_points.append(0);
                    new_nodes_open_edges.append(0);
                    new_nodes_contested.append(false);
                }
            };
            union_find.nodes_parents = new_nodes_parents.span();
            union_find.nodes_ranks = new_nodes_ranks.span();
            union_find.nodes_blue_points = new_nodes_blue_points.span();
            union_find.nodes_red_points = new_nodes_red_points.span();
            union_find.nodes_open_edges = new_nodes_open_edges.span();
            union_find.nodes_contested = new_nodes_contested.span();
            union_find.nodes_types = new_nodes_types.span();
        
            union_find.write(world); 

            world.write_model(@move);

            world
                .write_member(
                    Model::<Board>::ptr_from_keys(board_id),
                    selector!("available_tiles_in_deck"),
                    board.available_tiles_in_deck.clone(),
                );

            world
                .write_member(
                    Model::<Board>::ptr_from_keys(board_id), selector!("top_tile"), top_tile,
                );

            world
                .write_member(
                    Model::<Board>::ptr_from_keys(board_id),
                    selector!("state"),
                    board.state.clone(),
                );

            world
                .write_member(
                    Model::<Board>::ptr_from_keys(board_id), selector!("player1"), board.player1,
                );

            world
                .write_member(
                    Model::<Board>::ptr_from_keys(board_id), selector!("player2"), board.player2,
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
                    selector!("moves_done"),
                    board.moves_done,
                );

            world
                .write_member(
                    Model::<Board>::ptr_from_keys(board_id),
                    selector!("game_state"),
                    board.game_state,
                );

            world
                .write_member(
                    Model::<Board>::ptr_from_keys(board_id),
                    selector!("last_update_timestamp"),
                    get_block_timestamp(),
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
                        timestamp: move.timestamp,
                    },
                );
            world
                .emit_event(
                    @BoardUpdated {
                        board_id: board.id,
                        available_tiles_in_deck: board.available_tiles_in_deck.span(),
                        top_tile: board.top_tile,
                        state: board.state.span(),
                        player1: board.player1,
                        player2: board.player2,
                        blue_score: board.blue_score,
                        red_score: board.red_score,
                        last_move_id: board.last_move_id,
                        moves_done: board.moves_done,
                        game_state: board.game_state,
                    },
                );

            println!(
                "Move made: {:?} \nBoard: {:?} \nUnion find: {:?}",
                move, board, union_find,
            );
        }

        fn skip_move(ref self: ContractState) {
            let player = get_caller_address();

            let mut world = self.world_default();
            let game: Game = world.read_model(player);

            if game.board_id.is_none() {
                world.emit_event(@PlayerNotInGame { player_id: player, board_id: 0 });
                println!("Player is not in game");
                return;
            }

            let board_id = game.board_id.unwrap();
            let mut board: Board = world.read_model(board_id);

            if game.status == GameStatus::Finished {
                world.emit_event(@GameIsAlreadyFinished { player_id: player, board_id });
                println!("Game is already finished");
                return;
            }

            let (player1_address, player1_side, _) = board.player1;
            let (player2_address, player2_side, _) = board.player2;

            let player_side = if player == player1_address {
                player1_side
            } else if player == player2_address {
                player2_side
            } else {
                world.emit_event(@PlayerNotInGame { player_id: player, board_id });
                println!("Player is not in game");
                return;
            };

            let mut union_find: UnionFind = world.read_model(board_id);
            let mut city_nodes = VecTrait::<NullableVec, UnionNode>::new();
            let mut road_nodes = VecTrait::<NullableVec, UnionNode>::new();
            for i in 0..union_find.nodes_parents.len() {
                let mut node: UnionNode = Default::default();
                node.node_type = *union_find.nodes_types.at(i.into());
                node.parent = *union_find.nodes_parents.at(i.into());
                node.rank = *union_find.nodes_ranks.at(i.into());
                node.blue_points = *union_find.nodes_blue_points.at(i.into());
                node.red_points = *union_find.nodes_red_points.at(i.into());
                node.open_edges = *union_find.nodes_open_edges.at(i.into());
                node.contested = *union_find.nodes_contested.at(i.into());
                if node.node_type == 1 {
                    road_nodes.push(UnionNode {
                        parent: i.try_into().unwrap(),
                        rank: 0,
                        blue_points: 0,
                        red_points: 0,
                        open_edges: 0,
                        contested: false,
                        node_type: 2, // 0 - City, 1 - Road, 2 - None
                    });
                    city_nodes.push(node);
                } else if node.node_type == 2 {
                    road_nodes.push(node);
                    city_nodes.push(UnionNode {
                        parent: i.try_into().unwrap(),
                        rank: 0,
                        blue_points: 0,
                        red_points: 0,
                        open_edges: 0,
                        contested: false,
                        node_type: 2, // 0 - City, 1 - Road, 2 - None
                    });
                }
                else {
                    road_nodes.push(UnionNode {
                        parent: i.try_into().unwrap(),
                        rank: 0,
                        blue_points: 0,
                        red_points: 0,
                        open_edges: 0,
                        contested: false,
                        node_type: 2, // 0 - City, 1 - Road, 2 - None
                    });
                    city_nodes.push(UnionNode {
                        parent: i.try_into().unwrap(),
                        rank: 0,
                        blue_points: 0,
                        red_points: 0,
                        open_edges: 0,
                        contested: false,
                        node_type: 2, // 0 - City, 1 - Road, 2 - None
                    });
                }
            };

            let prev_move_id = board.last_move_id;
            if prev_move_id.is_some() {
                let prev_move_id = prev_move_id.unwrap();
                let prev_move: Move = world.read_model(prev_move_id);
                let prev_player_side = prev_move.player_side;

                let time = get_block_timestamp();
                let last_update_timestamp = board.last_update_timestamp;
                let time_delta = time - last_update_timestamp;

                if player_side == prev_player_side {
                    if time_delta > MOVE_TIME && time_delta <= 2 * MOVE_TIME {
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
                                false,  
                            )
                    }

                    if time_delta <= MOVE_TIME || time_delta > 2 * MOVE_TIME {
                        world.emit_event(@NotYourTurn { player_id: player, board_id });
                        println!("[Not your turn]");
                        return ;
                    }
                } else {
                    if time_delta > MOVE_TIME {
                        world.emit_event(@NotYourTurn { player_id: player, board_id });
                        println!("[Not your turn] Move time is over");
                        return;
                    }
                }

                let prev_move_id = board.last_move_id.unwrap();
                let prev_move: Move = world.read_model(prev_move_id);

                if prev_move.tile.is_none() && !prev_move.is_joker {
                    //FINISH THE GAME
                    self
                        ._finish_game(
                            ref board, 
                            union_find.potential_city_contests.span(), 
                            union_find.potential_road_contests.span(),
                            ref city_nodes,
                            ref road_nodes,
                        );
                    let mut new_nodes_parents = array![];
                    let mut new_nodes_ranks = array![];
                    let mut new_nodes_blue_points = array![];
                    let mut new_nodes_red_points = array![];
                    let mut new_nodes_open_edges = array![];
                    let mut new_nodes_contested = array![];
                    let mut new_nodes_types = array![];
                    for i in 0..256_usize {
                        let road_node = road_nodes.at(i.into());
                        let city_node = city_nodes.at(i.into());
                        if road_node.node_type == 1 {
                            new_nodes_types.append(road_node.node_type);
                            new_nodes_parents.append(road_node.parent);
                            new_nodes_ranks.append(road_node.rank);
                            new_nodes_blue_points.append(road_node.blue_points);
                            new_nodes_red_points.append(road_node.red_points);
                            new_nodes_open_edges.append(road_node.open_edges);
                            new_nodes_contested.append(road_node.contested);
                        } else if city_node.node_type == 0 {
                            new_nodes_types.append(city_node.node_type);
                            new_nodes_parents.append(city_node.parent);
                            new_nodes_ranks.append(city_node.rank);
                            new_nodes_blue_points.append(city_node.blue_points);
                            new_nodes_red_points.append(city_node.red_points);
                            new_nodes_open_edges.append(city_node.open_edges);
                            new_nodes_contested.append(city_node.contested);
                        } else {
                            new_nodes_types.append(2); // 0 - City, 1 - Road, 2 - None
                            new_nodes_parents.append(i.try_into().unwrap());
                            new_nodes_ranks.append(0);
                            new_nodes_blue_points.append(0);
                            new_nodes_red_points.append(0);
                            new_nodes_open_edges.append(0);
                            new_nodes_contested.append(false);
                        }
                    };
                    union_find.nodes_parents = new_nodes_parents.span();
                    union_find.nodes_ranks = new_nodes_ranks.span();
                    union_find.nodes_blue_points = new_nodes_blue_points.span();
                    union_find.nodes_red_points = new_nodes_red_points.span();
                    union_find.nodes_open_edges = new_nodes_open_edges.span();
                    union_find.nodes_contested = new_nodes_contested.span();
                    union_find.nodes_types = new_nodes_types.span();
                
                    union_find.write(world); 
                }
            };
            redraw_tile_from_board_deck(ref board);
            world
                .write_member(
                    Model::<Board>::ptr_from_keys(board_id),
                    selector!("available_tiles_in_deck"),
                    board.available_tiles_in_deck.clone(),
                );
            world
                .write_member(
                    Model::<Board>::ptr_from_keys(board_id), selector!("top_tile"), board.top_tile,
                );

            self._skip_move(player, player_side, ref board, self.move_id_generator, true);
            world
                .emit_event(
                    @BoardUpdated {
                        board_id: board.id,
                        available_tiles_in_deck: board.available_tiles_in_deck.span(),
                        top_tile: board.top_tile,
                        state: board.state.span(),
                        player1: board.player1,
                        player2: board.player2,
                        blue_score: board.blue_score,
                        red_score: board.red_score,
                        last_move_id: board.last_move_id,
                        game_state: board.game_state,
                        moves_done: board.moves_done,
                    },
                );
        }

        fn finish_game(ref self: ContractState, board_id: felt252) {
            let player = get_caller_address();

            let mut world = self.world_default();
            let game: Game = world.read_model(player);

            if game.board_id.is_none() || game.board_id.unwrap() != board_id {
                world.emit_event(@PlayerNotInGame { player_id: player, board_id: 0 });
                println!("Player is not in game");
                return ;
            }

            let mut board: Board = world.read_model(board_id);

            if game.status == GameStatus::Finished {
                world.emit_event(@GameIsAlreadyFinished { player_id: player, board_id });
                println!("Game is already finished");
                return;
            }

            let last_update_timestamp = board.last_update_timestamp;
            let timestamp = get_block_timestamp();
            let time_delta = timestamp - last_update_timestamp;
            if time_delta > 2 * MOVE_TIME {
                //FINISH THE GAME
                let mut union_find: UnionFind = world.read_model(board_id);
                let mut city_nodes = VecTrait::<NullableVec, UnionNode>::new();
                let mut road_nodes = VecTrait::<NullableVec, UnionNode>::new();
                for i in 0..union_find.nodes_parents.len() {
                    let mut node: UnionNode = Default::default();
                    node.node_type = *union_find.nodes_types.at(i.into());
                    node.parent = *union_find.nodes_parents.at(i.into());
                    node.rank = *union_find.nodes_ranks.at(i.into());
                    node.blue_points = *union_find.nodes_blue_points.at(i.into());
                    node.red_points = *union_find.nodes_red_points.at(i.into());
                    node.open_edges = *union_find.nodes_open_edges.at(i.into());
                    node.contested = *union_find.nodes_contested.at(i.into());
                    if node.node_type == 0 {
                        road_nodes.push(UnionNode {
                        parent: i.try_into().unwrap(),
                        rank: 0,
                        blue_points: 0,
                        red_points: 0,
                        open_edges: 0,
                        contested: false,
                        node_type: 2, // 0 - City, 1 - Road, 2 - None
                    });
                        city_nodes.push(node);
                    } else if node.node_type == 1 {
                        road_nodes.push(node);
                        city_nodes.push(UnionNode {
                        parent: i.try_into().unwrap(),
                        rank: 0,
                        blue_points: 0,
                        red_points: 0,
                        open_edges: 0,
                        contested: false,
                        node_type: 2, // 0 - City, 1 - Road, 2 - None
                    });
                    }
                    else {
                        road_nodes.push(UnionNode {
                        parent: i.try_into().unwrap(),
                        rank: 0,
                        blue_points: 0,
                        red_points: 0,
                        open_edges: 0,
                        contested: false,
                        node_type: 2, // 0 - City, 1 - Road, 2 - None
                    });
                        city_nodes.push(UnionNode {
                        parent: i.try_into().unwrap(),
                        rank: 0,
                        blue_points: 0,
                        red_points: 0,
                        open_edges: 0,
                        contested: false,
                        node_type: 2, // 0 - City, 1 - Road, 2 - None
                    });
                    }
                };
                self
                    ._finish_game(
                        ref board, 
                        union_find.potential_city_contests.span(), 
                        union_find.potential_road_contests.span(),
                        ref city_nodes,
                        ref road_nodes,
                    );
                return;
            } else {
                world.emit_event(@CantFinishGame { player_id: player, board_id });
                println!("Cant finish game, time delta is less than 2 * MOVE_TIME");
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
            emit_event: bool
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
                    selector!("last_update_timestamp"),
                    get_block_timestamp(),
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
            self: @ContractState, ref board: Board,
            potential_city_contests: Span<u8>,
            potential_road_contests: Span<u8>,
            ref city_nodes: NullableVec<UnionNode>,
            ref road_nodes: NullableVec<UnionNode>
        ) {
            //FINISH THE GAME
            let mut world = self.world_default();
            let city_scoring_results = close_all_cities(ref world, potential_city_contests, ref city_nodes, board.id);
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

            let road_scoring_results = close_all_roads(ref world, potential_road_contests, ref road_nodes, board.id);
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
            let mut host_game: Game = world.read_model(player1_address);
            let mut guest_game: Game = world.read_model(player2_address);
            host_game.status = GameStatus::Finished;
            guest_game.status = GameStatus::Finished;

            world.write_model(@host_game);
            world.write_model(@guest_game);

            world.emit_event(@GameFinished { host_player: player1_address, board_id: board.id });
            world.emit_event(@GameFinished { host_player: player2_address, board_id: board.id });

            let mut player1: Player = world.read_model(player1_address);
            let mut player2: Player = world.read_model(player2_address);

            let rules: Rules = world.read_model(0);
            let joker_price = rules.joker_price;
            let blue_joker_points = joker_number1.into() * joker_price;
            let red_joker_points = joker_number2.into() * joker_price;
            let (blue_city_points, blue_road_points) = board.blue_score;
            let blue_points = blue_city_points + blue_road_points + blue_joker_points;
            let (red_city_points, red_road_points) = board.red_score;
            let red_points = red_city_points + red_road_points + red_joker_points;
            if player1_side == PlayerSide::Blue {
                player1.balance += blue_points.into();
                player2.balance += red_points.into();
    
            } else if player1_side == PlayerSide::Red {
                player1.balance += red_points.into();
                player2.balance += blue_points.into();
            }

            player1.games_played += 1;
            player2.games_played += 1;

            //Finish challenge

            let winner = if blue_points > red_points {
                Option::Some(1)
            } else if blue_points < red_points {
                Option::Some(2)
            } else {
                Option::Some(0)
            };

            world.write_model(@player1);
            world.write_model(@player2);


            world
                .emit_event(
                    @CurrentPlayerBalance { player_id: player1_address, balance: player1.balance },
                );

            world
                .emit_event(
                    @CurrentPlayerBalance { player_id: player2_address, balance: player2.balance },
                );

            world
                .write_member(
                    Model::<Board>::ptr_from_keys(board.id),
                    selector!("blue_score"),
                    board.blue_score,
                );

            world
                .write_member(
                    Model::<Board>::ptr_from_keys(board.id),
                    selector!("red_score"),
                    board.red_score,
                );

            world
                .write_member(
                    Model::<Board>::ptr_from_keys(board.id),
                    selector!("game_state"),
                    board.game_state,
                );
            
            world
                .write_member(
                    Model::<Board>::ptr_from_keys(board.id),
                    selector!("last_update_timestamp"),
                    get_block_timestamp(),
                );

            world
                .emit_event(
                    @BoardUpdated {
                        board_id: board.id,
                        available_tiles_in_deck: board.available_tiles_in_deck.span(),
                        top_tile: board.top_tile,
                        state: board.state.span(),
                        player1: board.player1,
                        player2: board.player2,
                        blue_score: board.blue_score,
                        red_score: board.red_score,
                        last_move_id: board.last_move_id,
                        moves_done: board.moves_done,
                        game_state: board.game_state,
                    },
                );

            // [Achivement] Seasoned
            let mut world = self.world_default();
            AchievementsTrait::play_game(world, player1_address);
            AchievementsTrait::play_game(world, player2_address);

            // [Achivement] Winner
            if winner == Option::Some(1) {
                AchievementsTrait::win_game(world, player1_address);
            } else if winner == Option::Some(2) {
                AchievementsTrait::win_game(world, player2_address);
            }
        }
    }


}
