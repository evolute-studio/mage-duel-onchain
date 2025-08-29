use starknet::ContractAddress;
use evolute_duel::{
    models::{game::{Board, TileCommitments, AvailableTiles}}, types::packing::{GameState},
    libs::{timing::{TimingTrait}, player_data::{PlayerDataTrait}},
};
use dojo::{model::{ModelStorage, Model}};
use evolute_duel::utils::hash::{hash_values};

#[derive(Drop, Copy)]
pub struct TileRevealData {
    pub board_id: felt252,
    pub player: ContractAddress,
    pub tile_index: u8,
    pub nonce: felt252,
    pub c: u8,
}

#[generate_trait]
pub impl TileRevealImpl of TileRevealTrait {
    fn validate_tile_reveal_state(board: @Board, expected_state: GameState) -> bool {
        (*board.top_tile).is_none()
            && (*board.commited_tile).is_some()
            && *board.game_state == expected_state
    }

    fn validate_tile_reveal_timing(board: @Board, timeout_duration: u64) -> bool {
        TimingTrait::validate_phase_timing(board, timeout_duration)
    }

    fn validate_committed_tile_match(board: @Board, c: u8) -> bool {
        (*board.commited_tile).unwrap() == c
    }

    fn validate_tile_commitment(
        tile_commitments: Span<felt252>, tile_index: u8, nonce: felt252, c: u8,
    ) -> bool {
        let saved_tile_commitment = *tile_commitments.at(tile_index.into());
        let tile_commitment = hash_values([tile_index.into(), nonce, c.into()].span());
        saved_tile_commitment == tile_commitment
    }

    fn update_available_tiles(
        board_id: felt252, player: ContractAddress, c: u8, mut world: dojo::world::WorldStorage,
    ) -> Span<u8> {
        let player_available_tiles_entry: AvailableTiles = world.read_model((board_id, player));
        let player_available_tiles = player_available_tiles_entry.available_tiles;

        let mut new_available_tiles: Array<u8> = array![];
        for i in 0..player_available_tiles.len() {
            if *player_available_tiles.at(i.into()) != c {
                new_available_tiles.append(*player_available_tiles.at(i.into()));
            }
        };

        world
            .write_model(
                @AvailableTiles { board_id, player, available_tiles: new_available_tiles.span() },
            );

        new_available_tiles.span()
    }

    fn reveal_tile_and_update_board(
        board_id: felt252, tile_index: u8, mut world: dojo::world::WorldStorage,
    ) {
        world
            .write_member(
                Model::<Board>::ptr_from_keys(board_id),
                selector!("top_tile"),
                Option::Some(tile_index),
            );

        world
            .write_member(
                Model::<Board>::ptr_from_keys(board_id),
                selector!("commited_tile"),
                Option::<u8>::None,
            );
    }

    fn perform_complete_tile_reveal_validation(
        reveal_data: TileRevealData,
        board: @Board,
        timeout_duration: u64,
        mut world: dojo::world::WorldStorage,
    ) -> bool {
        // Basic tile reveal validations
        if !Self::validate_tile_reveal_state(board, GameState::Reveal) {
            return false;
        }

        if !Self::validate_tile_reveal_timing(board, timeout_duration) {
            return false;
        }

        if !Self::validate_committed_tile_match(board, reveal_data.c) {
            return false;
        }

        let tile_commitments_entry: TileCommitments = world
            .read_model((reveal_data.board_id, reveal_data.player));
        let tile_commitments = tile_commitments_entry.tile_commitments;

        if !Self::validate_tile_commitment(
            tile_commitments, reveal_data.tile_index, reveal_data.nonce, reveal_data.c,
        ) {
            return false;
        }

        // Player and turn validations
        let player_data =
            match PlayerDataTrait::validate_player_and_get_data(board, reveal_data.player, world) {
            Option::Some(data) => data,
            Option::None => { return false; },
        };

        if !TimingTrait::validate_current_player_turn(
            board, reveal_data.player, player_data.side, world,
        ) {
            return false;
        }

        true
    }

    fn perform_tile_reveal_validation(
        reveal_data: TileRevealData,
        board: @Board,
        timeout_duration: u64,
        mut world: dojo::world::WorldStorage,
    ) -> bool {
        Self::perform_complete_tile_reveal_validation(reveal_data, board, timeout_duration, world)
    }
}
