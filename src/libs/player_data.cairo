use starknet::ContractAddress;
use evolute_duel::{
    models::game::Board,
    events::PlayerNotInGame,
    types::packing::PlayerSide,
};
use dojo::event::EventStorage;

#[derive(Drop, Copy)]
pub struct PlayerData {
    pub side: PlayerSide,
    pub joker_number: u8,
}

#[generate_trait]
pub impl PlayerDataImpl of PlayerDataTrait {
    fn get_player_data(
        board: @Board,
        player: ContractAddress,
        mut world: dojo::world::WorldStorage,
    ) -> Option<PlayerData> {
        let (player1_address, player1_side, joker_number1) = *board.player1;
        let (player2_address, player2_side, joker_number2) = *board.player2;

        if player == player1_address {
            Option::Some(PlayerData { side: player1_side, joker_number: joker_number1 })
        } else if player == player2_address {
            Option::Some(PlayerData { side: player2_side, joker_number: joker_number2 })
        } else {
            world.emit_event(@PlayerNotInGame { player_id: player, board_id: *board.id });
            Option::None
        }
    }

    fn get_player_side(
        board: @Board,
        player: ContractAddress,
        mut world: dojo::world::WorldStorage,
    ) -> Option<PlayerSide> {
        match Self::get_player_data(board, player, world) {
            Option::Some(data) => Option::Some(data.side),
            Option::None => Option::None,
        }
    }

    fn validate_player_and_get_data(
        board: @Board,
        player: ContractAddress,
        mut world: dojo::world::WorldStorage,
    ) -> Option<PlayerData> {
        Self::get_player_data(board, player, world)
    }
}