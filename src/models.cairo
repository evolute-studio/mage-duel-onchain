use starknet::{ContractAddress};
use evolute_duel::packing::{GameState, GameStatus, PlayerSide};


#[derive(Drop, Serde, Debug, Introspect, Clone)]
#[dojo::model]
pub struct Board {
    #[key]
    pub id: felt252,
    pub initial_edge_state: Array<u8>,
    pub available_tiles_in_deck: Array<u8>,
    pub top_tile: Option<u8>,
    // (u8, u8) => (tile_number, rotation)
    pub state: Array<(u8, u8)>,
    //(address, side, joker_number)
    pub player1: (ContractAddress, PlayerSide, u8),
    //(address, side, joker_number)
    pub player2: (ContractAddress, PlayerSide, u8),
    pub last_move_id: Option<felt252>,
    pub game_state: GameState,
}

#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::model]
pub struct Move {
    #[key]
    pub id: felt252,
    pub player_side: PlayerSide,
    pub prev_move_id: Option<felt252>,
    pub tile: Option<u8>,
    // 0 - if no rotation
    pub rotation: u8,
    pub col: u8,
    pub row: u8,
    pub is_joker: bool,
}

#[derive(Drop, Introspect, Serde)]
#[dojo::model]
pub struct Rules {
    #[key]
    pub id: felt252,
    // How many tiles of each type in the deck. The index of the array is the tile type, according
    // to Tile enum.
    // 0 => CCCC
    // 1 => FFFF
    // 2 => RRRR
    pub deck: Array<u8>,
    // How many (cities, roads) at the beginning of the game for each edge
    pub edges: (u8, u8),
    // How many jokers for each player
    pub joker_number: u8,
}
// impl PointSerde of Serde<[u8; 24]> {
//     fn serialize(self: @[u8; 24], ref output: Array<felt252>) {
//         for el in self.span() {
//             let felt_el: felt252 = (*el).into();
//             output.append(felt_el);
//         };
//     }

//     fn deserialize(ref serialized: Span<felt252>) -> Option<[u8; 24]> {
//         let mut output: [u8; 24] = [0; 24];

//         for mut el in output.span() {
//             let converted: u8 = (*serialized.pop_front().unwrap()).try_into().unwrap();
//             el = @converted;
//         };

//         Option::Some(output)
//     }
// }

#[derive(Drop, Serde, Debug)]
#[dojo::model]
pub struct Game {
    #[key]
    pub player: ContractAddress,
    pub status: GameStatus,
    pub board_id: Option<felt252>,
}


#[derive(Drop, Serde, Debug)]
#[dojo::model]
pub struct Player {
    #[key]
    pub player_id: ContractAddress,
    pub username: felt252,
    pub balance: felt252,
    pub xp: felt252,
    pub games_played: felt252,
    pub skins: Array<u8>,
}

#[derive(Drop, Serde, Debug)]
#[dojo::model]
pub struct Shop {
    #[key]
    pub shop_id: felt252,
    pub skin_prices: Array<felt252>,
}
