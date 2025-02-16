use starknet::ContractAddress;
use dojo_starter::models::{Board, Rules};


// define the interface
#[starknet::interface]
pub trait IActions<T> {
    fn initiate_board(ref self: T, player1: ContractAddress, player2: ContractAddress) -> Board;
    fn initiate_rules(ref self: T) -> Rules;
}

// dojo decorator
#[dojo::contract]
pub mod actions {
    use super::{IActions};
    use starknet::{ContractAddress};
    use dojo_starter::models::{Board, TEdge, GameState, Tile, Rules};

    use dojo::model::{ModelStorage};
    use origami_random::deck::{DeckTrait};
    use core::dict::Felt252Dict;


    fn generate_initial_state(cities_on_edges: u8, roads_on_edges: u8) -> Array<TEdge> {
        let mut initial_state = ArrayTrait::new();

        for side in 0..4_u8 {
            let mut deck = DeckTrait::new(('SEED' + side.into()).into(), 8);
            let mut edge: Felt252Dict<u8> = Default::default();
            for i in 0..8_u8 {
                edge.insert(i.into(), 0);
            };
            for _ in 0..cities_on_edges {
                edge.insert(deck.draw().into() - 1, 1);
            };
            for _ in 0..roads_on_edges {
                edge.insert(deck.draw().into() - 1, 2);
            };

            //TODO: No sense to do transformation 0 -> M, 1 -> C, 2 -> R. Why not doing deck.draw()
            //right in loop and get rid of edge variable?
            for i in 0..8_u8 {
                match edge.get(i.into()) {
                    0 => { initial_state.append(TEdge::M); },
                    1 => { initial_state.append(TEdge::C); },
                    _ => { initial_state.append(TEdge::R); },
                }
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
            Tile::CCRF,
            Tile::CCFR,
            Tile::CFRF,
            Tile::CRRF,
            Tile::CRFF,
            Tile::FFCR,
            Tile::FFRF,
            Tile::FRRF,
            Tile::FFCC,
            Tile::RRFF,
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

    #[abi(embed_v0)]
    impl ActionsImpl of IActions<ContractState> {
        fn initiate_rules(ref self: ContractState) -> Rules {
            // Get the default world.
            let mut world = self.world_default();

            // Create a new ruleset.
            let rules = Rules {
                id: 0, deck: array![4, 4, 11, 9, 9, 4, 4, 9, 4, 6], edges: (1, 1), joker_number: 3,
            };

            // Write the rules to the world.
            world.write_model(@rules);

            // // Emit an event to the world to notify about the rules creation.
            // world.emit_event(@RulesCreated { rules_id });

            return rules;
        }

        fn initiate_board(
            ref self: ContractState, player1: ContractAddress, player2: ContractAddress,
        ) -> Board {
            // Get the default world.
            let mut world = self.world_default();

            let rules: Rules = world.read_model(0);

            // Create an initial state for the board.
            let (cities_on_edges, roads_on_edges) = rules.edges;
            let initial_state = generate_initial_state(cities_on_edges, roads_on_edges);

            // Create a random deck for the board.
            let mut random_deck = generate_random_deck(@rules.deck);

            // Create an empty board.
            let mut tiles = ArrayTrait::new();
            tiles.append_span([Option::None; 64].span());

            // Create a new board.
            let board = Board {
                id: 0,
                initial_state,
                random_deck,
                tiles,
                player1,
                player2,
                last_move_id: 0,
                state: GameState::InProgress,
            };

            // Write the board to the world.
            world.write_model(@board);

            // // Emit an event to the world to notify about the board creation.
            // world.emit_event(@BoardCreated { board_id });
            return board;
        }
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
