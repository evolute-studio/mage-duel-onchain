use starknet::ContractAddress;
use evolute_duel::models::{Board, Rules, Tile};


// define the interface
#[starknet::interface]
pub trait IGame<T> {
    // fn initiate_board(ref self: T, player1: ContractAddress, player2: ContractAddress) -> Board;
    // fn move(
    //     ref self: T,
    //     board_id: felt252,
    //     player: ContractAddress,
    //     tile: Option<Tile>,
    //     rotation: u8,
    //     is_joker: bool,
    //     col: u8,
    //     row: u8,
    // );

    fn create_game(ref self: T);
    fn cancel_game(ref self: T);
    fn join_game(ref self: T, host_player: ContractAddress);
    fn make_move(ref self: T, board_id: felt252 // player: ContractAddress,
    // tile: Option<Tile>,
    // rotation: u8,
    // is_joker: bool,
    // col: u8,
    // row: u8,
    );
}

// dojo decorator
#[dojo::contract]
pub mod game {
    use dojo::world::IWorldDispatcherTrait;
    use starknet::storage_access::Store;
    use dojo::event::EventStorage;
    use super::{IGame};
    use starknet::{ContractAddress, get_caller_address};
    use evolute_duel::models::{Board, TEdge, GameState, Tile, Rules, Move, Game, GameStatus};

    use dojo::model::{ModelStorage};
    use origami_random::deck::{DeckTrait};
    use origami_random::dice::{Dice, DiceTrait};
    use core::dict::Felt252Dict;

    use evolute_duel::events::{
        BoardCreated, RulesCreated, InvalidMove, GameCreated, GameCreateFailed, GameFinished,
        GameJoinFailed, GameStarted, GameCanceled,
    };

    use evolute_duel::systems::helpers::board::{create_board};


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
            let status = game.status;

            if status == GameStatus::InProgress || status == GameStatus::Created {
                world.emit_event(@GameCreateFailed { host_player, status });
                return;
            }

            game.status = GameStatus::Created;

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

                world.write_model(@game);

                world.emit_event(@GameCanceled { host_player, status: new_status });
            }
        }

        fn join_game(ref self: ContractState, host_player: ContractAddress) {
            let mut world = self.world_default();

            let guest_player = get_caller_address();

            let mut game: Game = world.read_model(host_player);
            let status = game.status;

            if status != GameStatus::Created || host_player == guest_player {
                world.emit_event(@GameJoinFailed { host_player, guest_player, status });
                return;
            }
            game.status = GameStatus::InProgress;

            //todo: let board_id = initialize_board(host_player, guest_player);
            let board = create_board(world, host_player, guest_player);
            let board_id = board.id;
            game.board_id = Option::Some(board_id);

            world.write_model(@game);

            world.emit_event(@GameStarted { host_player, guest_player, board_id });
        }

        fn make_move(ref self: ContractState, board_id: felt252 // player: ContractAddress,
        // tile: Option<Tile>,
        // rotation: u8,
        // is_joker: bool,
        // col: u8,
        // row: u8,
        ) {
            let mut world = self.world_default();
            let mut board: Board = world.read_model(board_id);

            let mut world = self.world_default();
            let mut board: Board = world.read_model(board_id);

            let avaliable_tiles: Array<Tile> = board.available_tiles_in_deck.clone();
            let mut dice = DiceTrait::new(avaliable_tiles.len().try_into().unwrap(), 'SEED');
            let mut next_tile = dice.roll();

            let tile: Tile = *avaliable_tiles.at(next_tile.into());

            world.write_model(@Move { id: 0, tile: Option::Some(tile) });

            // Remove the tile from the available tiles.
            let mut updated_available_tiles: Array<Tile> = ArrayTrait::new();
            for i in 0..avaliable_tiles.len() {
                if i != next_tile.into() {
                    updated_available_tiles.append(*avaliable_tiles.at(i.into()));
                }
            };

            board.available_tiles_in_deck = updated_available_tiles.clone();

            world.write_model(@board);
            // // Check if the game is in progress.
        // if board.state == GameState::InProgress {
        //     world.emit_event(@InvalidMove { move_id: 0, player });
        //     return;
        // }

            // // Check if the player is allowed to make a move.
        // let last_move: Move = world.read_model(board.last_move_id);
        // if !is_player_allowed_to_move(player, board.clone(), last_move) {
        //     world.emit_event(@InvalidMove { move_id: 0, player });
        //     return;
        // }

            // // Check if the move is valid.
        // if !is_move_valid(board.clone(), tile, rotation, col, row, is_joker) {
        //     world.emit_event(@InvalidMove { move_id: 0, player });
        //     return;
        // }
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

    // fn is_player_allowed_to_move(player: ContractAddress, board: Board, last_move: Move) -> bool
    // {
    //     if player != board.player1 && player != board.player2 {
    //         return false;
    //     }

    //     if last_move.player == player {
    //         return false;
    //     }

    //     return true;
    // }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"evolute_duel")
        }
    }
}
