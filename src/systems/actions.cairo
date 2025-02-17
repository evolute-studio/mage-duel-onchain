use starknet::ContractAddress;
use dojo_starter::models::{Board, Rules, Tile};


// define the interface
#[starknet::interface]
pub trait IActions<T> {
    fn initiate_board(ref self: T, player1: ContractAddress, player2: ContractAddress) -> Board;
    fn initiate_rules(ref self: T, deck: Array<u8>, edges: (u8, u8), joker_number: u8) -> Rules;
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
}

// dojo decorator
#[dojo::contract]
pub mod actions {
    use dojo::event::EventStorage;
use super::{IActions};
    use starknet::{ContractAddress};
    use dojo_starter::models::{Board, TEdge, GameState, Tile, Rules, Move, TileStruct};

    use dojo::model::{ModelStorage};
    use origami_random::deck::{DeckTrait};
    use core::dict::Felt252Dict;

    use dojo_starter::events::{BoardCreated, RulesCreated, InvalidMove};

    #[abi(embed_v0)]
    impl ActionsImpl of IActions<ContractState> {
        fn initiate_rules(
            ref self: ContractState, deck: Array<u8>, edges: (u8, u8), joker_number: u8,
        ) -> Rules {
            // Get the default world.
            let mut world = self.world_default();

            // Create a new ruleset.
            let rules = Rules { id: 0, deck: deck.clone(), edges, joker_number };

            // Write the rules to the world.
            world.write_model(@rules);

            // // Emit an event to the world to notify about the rules creation.
            world.emit_event(@RulesCreated { rules_id: 0, deck, edges, joker_number });

            return rules;
        }

        fn initiate_board(
            ref self: ContractState, player1: ContractAddress, player2: ContractAddress,
        ) -> Board {
            // Get the default world.
            let mut world = self.world_default();

            // let board_id = world.uuid();
            // TODO: Generate unique id for board
            let board_id = 0;

            let rules: Rules = world.read_model(0);

            // Create an initial state for the board.
            let (cities_on_edges, roads_on_edges) = rules.edges;
            let initial_state = generate_initial_state(cities_on_edges, roads_on_edges);

            // Create a random deck for the board.
            let mut random_deck = generate_random_deck(@rules.deck);

            // Create an empty board.
            let mut tiles = ArrayTrait::new();
            tiles.append_span([Option::None; 64].span());

            let last_move_id = Option::None;

            let state = GameState::InProgress;

            // Create a new board.
            let board = Board {
                id: board_id,
                initial_state: initial_state.clone(),
                random_deck: random_deck.clone(),
                tiles: tiles.clone(),
                player1,
                player2,
                last_move_id,
                state,
            };

            // Write the board to the world.
            world.write_model(@board);

            // // Emit an event to the world to notify about the board creation.
            world.emit_event(@BoardCreated { board_id, initial_state, random_deck, tiles, player1, player2, last_move_id, state });

            return board;
        }

        fn move(
            ref self: ContractState,
            board_id: felt252,
            player: ContractAddress,
            tile: Option<Tile>,
            rotation: u8,
            is_joker: bool,
            col: u8,
            row: u8,
        ) {
            let mut world = self.world_default();
            let mut board: Board = world.read_model(board_id);

            // Check if the game is in progress.
            if board.state == GameState::InProgress {
                world.emit_event(@InvalidMove { move_id: 0, player });
                return;
            }

            // Check if the player is allowed to make a move.
            let last_move: Move = world.read_model(board.last_move_id);
            if !is_player_allowed_to_move(player, board.clone(), last_move) {
                world.emit_event(@InvalidMove { move_id: 0, player });
                return;
            }

            // Check if the move is valid.
            if !is_move_valid(board.clone(), tile, rotation, col, row, is_joker) {
                world.emit_event(@InvalidMove { move_id: 0, player });
                return;
            }
        }
    }

    fn is_move_valid(mut board: Board, mut tile: Option<Tile>, rotation: u8, col: u8, row: u8, is_joker: bool) -> bool {
        // Check if the tile on top of the random deck.
        if board.random_deck.is_empty() {
            return false;
        }
        
        if is_joker {
            if tile == Option::None {
                return false;
            }
        } else {
            tile = Option::Some(board.random_deck.pop_front().unwrap().into());
        }

        // Check if the tile is already placed on the board.
        if board.tiles.get((col + row * 8).into()).is_some() {
            return false;
        }
        
        let tile: TileStruct = tile.unwrap().into();
        // Check if the tile can be placed on the board.
        if !is_tile_allowed_to_place(board, tile, rotation, col, row) {
            return false;
        }

        return true;
    }

    fn is_tile_allowed_to_place(board: Board, tile: TileStruct, rotation: u8, col: u8, row: u8) -> bool {

        let edges : [TEdge; 4] = [
            *tile.edges.span()[((0 + rotation) % 4).into()],
            *tile.edges.span()[((1 + rotation) % 4).into()],
            *tile.edges.span()[((2 + rotation) % 4).into()],
            *tile.edges.span()[((3 + rotation) % 4).into()]
        ];
        let edges = edges.span();

        let mut is_move_valid = true;

        for i in 0..4_u8 {
            let mut neighbor_col = col;
            let mut neighbor_row = row; 
            if(i == 0) {
                if neighbor_row == 0 {
                    continue;
                }
                neighbor_row -= 1;
            } else if(i == 1) {
                if neighbor_col == 7 {
                    continue;
                }
                neighbor_col += 1;
            } else if(i == 2) {
                if neighbor_row == 7 {
                    continue;
                }
                neighbor_row += 1;
            } else {
                if neighbor_col == 0 {
                    continue;
                }
                neighbor_col -= 1;
            } 

            let neighbor_tile: Option<TileStruct> = *board.tiles.at((neighbor_col + neighbor_row * 8).into());

            if neighbor_tile.is_some() {
                let neighbor_tile: TileStruct = neighbor_tile.unwrap();
                let neighbor_edges = neighbor_tile.edges.span();
                let neighbor_edge: TEdge = *neighbor_edges.at(((i + 2) % 4).into());

                if *edges.at(i.into()) != neighbor_edge {
                    is_move_valid = false;
                    break;
                }
            }
        };

        return true;
    }

    fn is_player_allowed_to_move(player: ContractAddress, board: Board, last_move: Move) -> bool {
        if player != board.player1 && player != board.player2 {
            return false;
        }

        if last_move.player == player {
            return false;
        }
        
        return true;
    }

    fn generate_initial_state(cities_on_edges: u8, roads_on_edges: u8) -> Array<TEdge> {
        let mut initial_state: Array<TEdge> = ArrayTrait::new();

        for side in 0..4_u8 {
            let mut deck = DeckTrait::new(('SEED' + side.into()).into(), 8);
            let mut edge: Felt252Dict<u8> = Default::default();
            for i in 0..8_u8 {
                edge.insert(i.into(), TEdge::M.into());
            };
            for _ in 0..cities_on_edges {
                edge.insert(deck.draw().into() - 1, TEdge::C.into());
            };
            for _ in 0..roads_on_edges {
                edge.insert(deck.draw().into() - 1, TEdge::R.into());
            };

            //TODO: No sense to do transformation 0 -> M, 1 -> C, 2 -> R. Why not doing deck.draw()
            //right in loop and get rid of edge variable?
            for i in 0..8_u8 {
                initial_state.append(edge.get(i.into()).into());
            };
        };
        return initial_state;
    }

    fn generate_random_deck(deck_rules: @Array<u8>) -> Array<Tile> {
        let TILES: Array<Tile> = array![
            //TODO: you separated this mapping in 2 different functions.
            // ----> deck: array![4, 4, 11, 9, 9, 4, 4, 9, 4, 6],
            // Let's make rules a struct and have this mapping in one place.
            // deck_rules: Map<Tile, u8>
            // Thus we can flixible change the rules and the mapping will be updated automatically.
            Tile::CCCC,
            Tile::FFFF,
            Tile::RRRR,
            Tile::CCCF,
            Tile::CCCR,
            Tile::CFFF,
            Tile::FFFR,
            Tile::CRRR,
            Tile::FRRR,
            Tile::CCFF,
            Tile::CFCF,
            Tile::CCRR,
            Tile::CRCR,
            Tile::FFRR,
            Tile::FRFR,
            Tile::CCFR, //2
            Tile::CCRF, // 1
            Tile::CFCR,
            Tile::CFFR,
            Tile::CFRF, //3
            Tile::CRFF, //5
            Tile::CRRF, //4
            Tile::CRFR,
            Tile::CFRR,
        ];

        let mut deck = DeckTrait::new('SEED'.into(), 64);
        let mut avaliable_tiles = ArrayTrait::new();
        for i in 0..deck_rules.len() {
            let tile_type = *TILES.at(i);
            let tile_amount: u8 = *deck_rules.at(i);
            for _ in 0..tile_amount {
                avaliable_tiles.append(tile_type);
            }
        };

        let mut random_deck: Array<Tile> = ArrayTrait::new();
        for _ in 0..64_u8 {
            let random_tile: Tile = *avaliable_tiles.at(deck.draw().into() - 1);
            random_deck.append(random_tile);
        };

        return random_deck;
    }


    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Use the default namespace "dojo_starter". This function is handy since the ByteArray
        /// can't be const.
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"dojo_starter")
        }
    }
}
