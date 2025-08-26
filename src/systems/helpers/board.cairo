use dojo::{model::{ModelStorage}, world::{WorldStorage}, event::EventStorage};
use starknet::{ContractAddress};
use origami_random::{deck::{DeckTrait}};

use evolute_duel::{
    models::{scoring::{UnionNode}, game::{Board, GameModeConfig, AvailableTiles, BoardCounter}},
    types::packing::{GameState, TEdge, Tile, PlayerSide, GameMode}, systems::helpers::{},
    events::{PlayerNotInGame},
};


use core::starknet::get_block_timestamp;


#[generate_trait]
pub impl BoardImpl of BoardTrait {
    fn create_board(
        mut world: WorldStorage,
        player1: ContractAddress,
        player2: ContractAddress,
        game_mode: GameMode,
    ) -> Board {
        println!("[BoardTrait::create_board] Creating board for players: {:?} vs {:?}", player1, player2);
        
        // Get current board counter from world storage
        const BOARD_COUNTER_KEY: felt252 = 'BOARD_COUNTER';
        let mut board_counter: BoardCounter = world.read_model(BOARD_COUNTER_KEY);
        println!("[BoardTrait::create_board] Current board counter: {}", board_counter.current_count);
        
        // Use current count as board_id and increment for next use
        let board_id = board_counter.current_count + 1;
        board_counter.current_count = board_counter.current_count + 1;
        
        // Save updated counter back to world storage
        world.write_model(@board_counter);
        println!("[BoardTrait::create_board] Board ID assigned: {}, counter updated to: {}", board_id, board_counter.current_count);

        let config: GameModeConfig = world.read_model(game_mode);
        assert!(config.deck.len() != 0, "[BoardTrait] Deck config is empty");
        let mut deck_rules_flat = Self::flatten_deck_rules(config.deck);

        let last_move_id = Option::None;
        let game_state = GameState::Creating;

        let mut board = Board {
            id: board_id,
            available_tiles_in_deck: deck_rules_flat,
            top_tile: Option::None,
            player1: (player1, PlayerSide::Blue, config.initial_jokers),
            player2: (player2, PlayerSide::Red, config.initial_jokers),
            blue_score: (0, 0),
            red_score: (0, 0),
            last_move_id,
            moves_done: 0,
            game_state,
            commited_tile: Option::None,
            phase_started_at: get_block_timestamp(),
        };

        world.write_model(@board);

        // Initialize edges using config.board_size
        let (cities_on_edges, roads_on_edges) = config.edges;
        Self::generate_initial_board_state(
            cities_on_edges, roads_on_edges, board_id, config.board_size, world,
        );

        // Create player available tiles.
        let mut available_tiles: Array<u8> = array![];
        for i in 0..deck_rules_flat.len() {
            available_tiles.append(i.try_into().unwrap());
        };

        world
            .write_model(
                @AvailableTiles {
                    board_id, player: player1, available_tiles: available_tiles.span(),
                },
            );

        world
            .write_model(
                @AvailableTiles {
                    board_id, player: player2, available_tiles: available_tiles.span(),
                },
            );

        return board;
    }

    fn update_board_joker_number(ref self: Board, side: PlayerSide, is_joker: bool) -> (u8, u8) {
        let (player1_address, player1_side, mut joker_number1) = self.player1;
        let (player2_address, player2_side, mut joker_number2) = self.player2;
        if is_joker {
            if side == player1_side {
                joker_number1 -= 1;
            } else {
                joker_number2 -= 1;
            }
        }

        self.player1 = (player1_address, player1_side, joker_number1);
        self.player2 = (player2_address, player2_side, joker_number2);

        (joker_number1, joker_number2)
    }

    fn generate_initial_board_state(
        cities_on_edges: u8,
        roads_on_edges: u8,
        board_id: felt252,
        board_size: u8,
        mut world: WorldStorage,
    ) {
        let board_size_i32: i32 = board_size.into();
        let max_coord = (board_size - 1).into();

        let bases = array![
            0,
            max_coord * board_size_i32 * 4 + 3,
            (max_coord * board_size_i32 + max_coord) * 4 + 2,
            max_coord * 4 + 1,
        ]
            .span();

        let steps: Span<i32> = array![board_size_i32 * 4, 4, -board_size_i32 * 4, -4].span();

        for side in 0..4_u8 {
            let mut deck = DeckTrait::new(
                ('SEED' + side.into() + get_block_timestamp().into() + board_id).into(), 8,
            );
            for i in 0..cities_on_edges + roads_on_edges {
                let step_nums = deck.draw().into();
                let position = (*bases.at(side.into()) + (*steps.at(side.into())) * step_nums)
                    .try_into()
                    .unwrap();
                println!("Position while generating initial_edge_state: {}", position);
                let node_type = if i < cities_on_edges {
                    TEdge::C.into()
                } else {
                    TEdge::R.into()
                };
                world
                    .write_model(
                        @UnionNode {
                            board_id,
                            position,
                            parent: position,
                            rank: 0,
                            blue_points: 0,
                            red_points: 0,
                            open_edges: 1,
                            contested: false,
                            node_type,
                            player_side: PlayerSide::None // No player assigned yet
                        },
                    );
            };
        };
    }

    fn flatten_deck_rules(deck_rules: Span<u8>) -> Span<u8> {
        let mut deck_rules_flat = ArrayTrait::new();
        for tile_index in 0..24_u8 {
            let tile_type: u8 = tile_index;
            let tile_amount: u8 = *deck_rules.at(tile_index.into());
            for _ in 0..tile_amount {
                deck_rules_flat.append(tile_type);
            }
        };

        return deck_rules_flat.span();
    }

    fn get_player_data(
        ref self: Board, player: ContractAddress, mut world: WorldStorage,
    ) -> Option<(PlayerSide, u8)> {
        let (player1_address, player1_side, joker_number1) = self.player1;
        let (player2_address, player2_side, joker_number2) = self.player2;

        return if player == player1_address {
            Option::Some((player1_side, joker_number1))
        } else if player == player2_address {
            Option::Some((player2_side, joker_number2))
        } else {
            world.emit_event(@PlayerNotInGame { player_id: player, board_id: self.id });
            println!("Player is not in game");
            Option::None
        };
    }

    fn get_joker_numbers(self: @Board) -> (u8, u8) {
        let (_, _, joker_number1) = *self.player1;
        let (_, _, joker_number2) = *self.player2;
        (joker_number1, joker_number2)
    }

    fn create_tutorial_board(
        mut world: WorldStorage,
        player_address: ContractAddress,
        bot_address: ContractAddress,
    ) -> Board {
        println!("[BoardTrait::create_tutorial_board] Creating tutorial board for player: {:?} vs bot: {:?}", player_address, bot_address);
        
        // Get current board counter from world storage
        const BOARD_COUNTER_KEY: felt252 = 'BOARD_COUNTER';
        let mut board_counter: BoardCounter = world.read_model(BOARD_COUNTER_KEY);
        println!("[BoardTrait::create_tutorial_board] Current board counter: {}", board_counter.current_count);
        
        // Use current count as board_id and increment for next use
        let board_id = board_counter.current_count + 1;
        board_counter.current_count = board_counter.current_count + 1;
        
        // Save updated counter back to world storage
        world.write_model(@board_counter);
        println!("[BoardTrait::create_tutorial_board] Board ID assigned: {}, counter updated to: {}", board_id, board_counter.current_count);

        let config: GameModeConfig = world.read_model(GameMode::Tutorial);
        let mut deck_rules_flat = Self::tutorial_deck(config.deck);

        let last_move_id = Option::None;
        let game_state = GameState::Move;

        let mut board = Board {
            id: board_id,
            available_tiles_in_deck: deck_rules_flat,
            top_tile: Option::Some(0),
            player1: (player_address, PlayerSide::Blue, config.initial_jokers),
            player2: (bot_address, PlayerSide::Red, config.initial_jokers),
            blue_score: (0, 0),
            red_score: (0, 0),
            last_move_id,
            moves_done: 0,
            game_state,
            commited_tile: Option::None,
            phase_started_at: get_block_timestamp(),
        };

        world.write_model(@board);

        // Initialize edges
        Self::generate_tutorial_initial_board_state(board_id, world);

        return board;
    }

    fn replace_tile_in_deck(ref self: Board, tile_index: u8, tile: Tile, world: WorldStorage) {
        let mut new_avaliable_tiles = array![];
        for i in 0..self.available_tiles_in_deck.len() {
            let current_tile = *self.available_tiles_in_deck.at(i.into());
            if i == tile_index.into() {
                new_avaliable_tiles.append(tile.into());
            } else {
                new_avaliable_tiles.append(current_tile);
            }
        };
        self.available_tiles_in_deck = new_avaliable_tiles.span();
    }

    fn tutorial_deck(deck_rules: Span<u8>) -> Span<u8> {
        // Example deck for tutorial
        let mut deck_rules_flat = ArrayTrait::new();
        deck_rules_flat.append(Tile::FFRR.into());
        deck_rules_flat.append(Tile::CRFR.into());
        deck_rules_flat.append(Tile::CCFR.into());
        deck_rules_flat.append(Tile::CCFF.into());
        //We have 24 tiles in total, so we can add more tiles to fill the deck
        // Add 1 of each tile type for simplicity
        let mut i: u8 = 4;
        let flatten_deck_rules = Self::flatten_deck_rules(deck_rules);
        let mut random_deck = DeckTrait::new(
            ('TUTORIAL_DECK' + get_block_timestamp().into()), flatten_deck_rules.len(),
        );
        while i < 25 {
            let tile_index = random_deck.draw().into() - 1;
            let tile_type = *flatten_deck_rules.at(tile_index);
            deck_rules_flat.append(tile_type);
            i += 1;
        };
        return deck_rules_flat.span();
    }

    fn generate_tutorial_initial_board_state(board_id: felt252, mut world: WorldStorage) {
        let bases = array![0, 6 * 7 * 4 + 3, (6 * 7 + 6) * 4 + 2, 6 * 4 + 1].span();

        let steps: Span<i32> = array![7 * 4, 4, -7 * 4, -4].span();

        let edges_positions = array![2, 2, 3, 4];

        let edges_types = array![TEdge::R, TEdge::C, TEdge::R, TEdge::C].span();

        for side in 0..4_u8 {
            let position = (*bases.at(side.into())
                + (*steps.at(side.into())) * (*edges_positions.at(side.into())));
            let node_type = *edges_types.at(side.into());
            world
                .write_model(
                    @UnionNode {
                        board_id,
                        position: position.try_into().unwrap(),
                        parent: position.try_into().unwrap(),
                        rank: 0,
                        blue_points: 0,
                        red_points: 0,
                        open_edges: 1,
                        contested: false,
                        node_type: node_type.into(),
                        player_side: PlayerSide::None // No player assigned yet
                    },
                );
        };
    }
}
