use dojo::{model::{ModelStorage}, world::{WorldStorage}, event::EventStorage};


use starknet::{ContractAddress};
use origami_random::{
    deck::{DeckTrait},
};

use evolute_duel::{
    models::{scoring::{UnionNode}, game::{Board, Rules, AvailableTiles}},
    types::packing::{GameState, TEdge, PlayerSide},
    events::{PlayerNotInGame},
};

use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

use core::starknet::get_block_timestamp;

#[generate_trait]
pub impl BoardImpl of BoardTrait {
    fn create_board(
        mut world: WorldStorage,
        player1: ContractAddress,
        player2: ContractAddress,
        mut board_id_generator: core::starknet::storage::StorageBase::<
            core::starknet::storage::Mutable<core::felt252>,
        >,
    ) -> Board {
        let board_id = board_id_generator.read();
        board_id_generator.write(board_id + 1);

        let rules: Rules = world.read_model(0);
        let mut deck_rules_flat = Self::flatten_deck_rules(rules.deck);

        let last_move_id = Option::None;
        let game_state = GameState::Creating;

        let mut board = Board {
            id: board_id,
            available_tiles_in_deck: deck_rules_flat,
            top_tile: Option::None,
            player1: (player1, PlayerSide::Blue, rules.joker_number),
            player2: (player2, PlayerSide::Red, rules.joker_number),
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
        let (cities_on_edges, roads_on_edges) = rules.edges;
        Self::generate_initial_board_state(
            cities_on_edges, roads_on_edges, board_id, world
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
        cities_on_edges: u8, roads_on_edges: u8, board_id: felt252, mut world: WorldStorage,
    ){
        let bases = array![
            0,
            9 * 10 * 4 + 3,
            (9 * 10 + 9) * 4 + 2,
            9 * 4 + 1,
        ].span();

        let steps: Span<i32> = array![10 * 4, 4, -10 * 4, -4].span();

        for side in 0..4_u8 {
            let mut deck = DeckTrait::new(
            ('SEED' + side.into() + get_block_timestamp().into() + board_id).into()
            , 8);
            for i in 0..cities_on_edges + roads_on_edges {
                let step_nums = deck.draw().into();
                let position = (*bases.at(side.into()) + (*steps.at(side.into())) * step_nums).try_into().unwrap();
                println!("Position while generating initial_edge_state: {}", position);
                let node_type = if i < cities_on_edges {TEdge::C.into()} else {TEdge::R.into()};
                world.write_model(@UnionNode {
                    board_id,
                    position,
                    parent: position,
                    rank: 0,
                    blue_points: 0,
                    red_points: 0,
                    open_edges: 1,
                    contested: false,
                    node_type,
                    player_side: PlayerSide::None, // No player assigned yet
                });
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
}
