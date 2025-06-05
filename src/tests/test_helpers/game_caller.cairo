use dojo::model::{ModelStorage, Model};
use dojo::world::WorldStorage;
use dojo::world::WorldStorageTrait;


use evolute_duel::{
    models::{
        game::{Game, m_Game, Board, m_Board, Move, m_Move, Rules, m_Rules, Snapshot, m_Snapshot, TileCommitments, m_TileCommitments, AvailableTiles, m_AvailableTiles,},
        scoring::{UnionFind, m_UnionFind,},
        player::{ Player, m_Player,},
        skins::{Shop, m_Shop,},
    },
    events::{
        BoardCreated, e_BoardCreated, BoardCreatedFromSnapshot, e_BoardCreatedFromSnapshot,
        BoardCreateFromSnapshotFalied, e_BoardCreateFromSnapshotFalied, SnapshotCreated,
        e_SnapshotCreated, SnapshotCreateFailed, e_SnapshotCreateFailed, BoardUpdated,
        e_BoardUpdated, RulesCreated, e_RulesCreated, Moved, e_Moved, Skiped, e_Skiped,
        InvalidMove, e_InvalidMove, GameFinished, e_GameFinished, GameStarted, e_GameStarted,
        GameCreated, e_GameCreated, GameCreateFailed, e_GameCreateFailed, GameJoinFailed,
        e_GameJoinFailed, GameCanceled, e_GameCanceled, GameCanceleFailed, e_GameCanceleFailed,
        PlayerNotInGame, e_PlayerNotInGame, NotYourTurn, e_NotYourTurn, NotEnoughJokers,
        e_NotEnoughJokers, GameIsAlreadyFinished, e_GameIsAlreadyFinished, CantFinishGame,
        e_CantFinishGame, CityContestWon, e_CityContestWon, CityContestDraw, e_CityContestDraw,
        RoadContestWon, e_RoadContestWon, RoadContestDraw, e_RoadContestDraw,
        CurrentPlayerBalance, e_CurrentPlayerBalance, CurrentPlayerUsername,
        e_CurrentPlayerUsername, CurrentPlayerActiveSkin, e_CurrentPlayerActiveSkin,
        PlayerUsernameChanged, e_PlayerUsernameChanged, PlayerSkinChanged, e_PlayerSkinChanged,
        PlayerSkinChangeFailed, e_PlayerSkinChangeFailed, PhaseStarted, e_PhaseStarted,
    },
    packing::{GameStatus},
    systems::{
        helpers::board::{create_board},
        game::{game, IGameDispatcher, IGameDispatcherTrait},
        player_profile_actions::{
            player_profile_actions, IPlayerProfileActionsDispatcher,
            IPlayerProfileActionsDispatcherTrait,
        },
    },
};

use starknet::{testing, ContractAddress};
use core::dict::Felt252Dict;
use origami_random::deck::{Deck, DeckTrait};
use evolute_duel::utils::hash::hash_values;
use evolute_duel::packing::{GameState};
use evolute_duel::systems::helpers::tile_helpers::{create_extended_tile};

#[derive(Drop, Debug, Clone)]
struct PlayerData {
    address: ContractAddress,
    tile_commitments: Array<felt252>,
    nonces: Array<felt252>,
    permutation: Array<u8>,
}

#[generate_trait]
impl PlayerDataImpl of PlayerDataTrait {
    fn new(address: ContractAddress) -> PlayerData {
        PlayerData {
            address,
            tile_commitments: array![],
            nonces: array![],
            permutation: array![],
        }
    }

    fn commitments_exists(ref self: PlayerData) -> bool {
        !self.tile_commitments.is_empty()
    }

    fn generate_commitments(
        ref self: PlayerData, n: u8, game_type: GameType,
    ) {
        self.generate_permutation(n);
        println!("Permutation generated and saved: {:?}", self.permutation);
        self.generate_nonces(n);
        println!("Nonces generated and saved: {:?}", self.nonces);
        let mut commitments = array![];
        for i in 0..n {
            let commitment = hash_values(array![i.into(), (*self.nonces.at(i.into())).into(), (*self.permutation.at(i.into())).into()].span());
            commitments.append(commitment);
        };
        self.tile_commitments = commitments
    }

    fn generate_permutation(
        ref self: PlayerData, n: u8
    ) {
       let mut deck = DeckTrait::new(self.address.into(), n.into());
        let mut permutation = array![];
        for _ in 0..n {
            let tile = deck.draw() - 1; // Convert to 0-based index
            permutation.append(tile);
        };
        self.permutation = permutation;
    }

    fn generate_nonces(
        ref self: PlayerData, n: u8
    ) {
        let mut deck = DeckTrait::new(self.address.into(), n.into());
        let mut nonces = array![];
        for _ in 0..n {
            let nonce = deck.draw() - 1; // Convert to 0-based index
            nonces.append(hash_values(array![nonce.into()].span()));
        };
        self.nonces = nonces
    }

    fn get_reveal_data(ref self: PlayerData, c: u8) -> (u8, felt252, u8) // Returns (tile_index, nonce, c)
    {
        println!("Purmutation: {:?}", self.permutation);
    
        let mut tile_index = 65;
        for i in 0..self.permutation.len() {
            if *self.permutation.at(i) == c {
                tile_index = i;
            }
        };
        assert(tile_index < 65, 'Tile not found in permutation');

        let nonce = *self.nonces.at(tile_index);

        (tile_index.try_into().unwrap(), nonce, c)
    }

    fn get_request_data(ref self: PlayerData, tile_index: u8) -> (u8, felt252, u8) // Returns (tile_index, nonce, c)
    {
        assert(tile_index < 65, 'Tile index out of bounds');
        let c = *self.permutation.at(tile_index.into());
        let nonce = *self.nonces.at(tile_index.into());
        (tile_index, nonce, c)
    }
}
    
#[derive(Drop, Debug, Copy)]
pub enum GameType {
    Standard,
    Snapshot: u8,
}

#[derive(Drop, Debug, Copy)]
pub enum Turn {
    Host,
    Guest,
}

#[derive(Drop, Clone)]
struct GameCaller {
    world: WorldStorage,
    // The address of the game contract.
    game_system: IGameDispatcher,
    game_type: GameType,
    host_player_data: PlayerData,
    guest_player_data: PlayerData,
    turn: Turn,
    commited_tile: u8
}

#[generate_trait]
pub impl GameCallerImpl of GameCallerTrait {
    fn new(world: WorldStorage, game_address: ContractAddress, host_player: ContractAddress, guest_player: ContractAddress, game_type: GameType) -> GameCaller {
        let game_system = IGameDispatcher { contract_address: game_address };
        GameCaller {
            world, 
            game_system,
            host_player_data: PlayerDataTrait::new(host_player),
            guest_player_data: PlayerDataTrait::new(guest_player),
            game_type,
            turn: Turn::Host,
            commited_tile: 0
        }
    }

    fn create_game(ref self: GameCaller) {
        let host_player_address = self.host_player_data.address;
        testing::set_contract_address(host_player_address);
        self.game_system.create_game();
    }

    fn join_game(ref self: GameCaller) {
        testing::set_contract_address(self.guest_player_data.address);
        self.game_system.join_game(self.host_player_data.address);

        self.update_commited_tile();
    }

    fn commit_tiles(ref self: GameCaller) {
        // Generate a random permutation of tiles and nonces
        match self.game_type {
            GameType::Standard => {
                let n = 64;
                self.host_player_data.generate_commitments(n, self.game_type);
                self.guest_player_data.generate_commitments(n, self.game_type);
            },
            GameType::Snapshot(moves_done) => {
                let n = 64 - moves_done;
                self.host_player_data.generate_commitments(n, self.game_type);
                self.guest_player_data.generate_commitments(n, self.game_type);
            },
        }
        // Commit tiles for both players
        testing::set_contract_address(self.host_player_data.address);
        self.game_system.commit_tiles(self.host_player_data.tile_commitments.span());
        println!("Host player committed tiles: {:?}", self.host_player_data.tile_commitments);

        testing::set_contract_address(self.guest_player_data.address);
        self.game_system.commit_tiles(self.guest_player_data.tile_commitments.span());
        println!("Guest player committed tiles: {:?}", self.guest_player_data.tile_commitments);

        self.turn = Turn::Host;
    }

    fn process_reveal_phase(ref self: GameCaller, c: u8) -> Option<u8> {
        let mut tile: u8 = 65; // Default value if no tile is found
        match self.turn {
            Turn::Host => {
                testing::set_contract_address(self.host_player_data.address);
                println!("Host player is revealing tile with c: {}", c);
                let (tile_index, nonce, c) = self.host_player_data.get_reveal_data(c);
                tile = tile_index;
                self.game_system.reveal_tile(tile_index, nonce, c);
                println!("Host player revealed tile: {}", tile_index);
            },
            Turn::Guest => {
                println!("Guest player is revealing tile with c: {}", c);
                testing::set_contract_address(self.guest_player_data.address);
                let (tile_index, nonce, c) = self.guest_player_data.get_reveal_data(c);
                tile = tile_index;
                self.game_system.reveal_tile(tile_index, nonce, c);
                println!("Guest player revealed tile: {}", tile_index);
            },
        }

        match self.turn {
            Turn::Host => {
                println!("Guest player requested tile");
                testing::set_contract_address(self.guest_player_data.address);
                let (tile_index, nonce, c) = self.guest_player_data.get_request_data(tile);
                let commited_tile = self.game_system.request_next_tile(tile_index, nonce, c);
                println!("Guest player received tile: {}", commited_tile.unwrap());
                self.commited_tile = commited_tile.unwrap();
                commited_tile
            },
            Turn::Guest => {
                println!("Host player requested tile");
                testing::set_contract_address(self.host_player_data.address);
                let (tile_index, nonce, c) = self.host_player_data.get_request_data(tile);
                let commited_tile = self.game_system.request_next_tile(tile_index, nonce, c);
                println!("Host player received tile: {}", commited_tile.unwrap());
                self.commited_tile = commited_tile.unwrap();
                commited_tile
            },
        }
    }

    fn process_move(ref self: GameCaller, joker_tile: Option<u8>, rotation: u8, col: u8, row: u8) {
        match self.turn {
            Turn::Host => {
                testing::set_contract_address(self.host_player_data.address);
                self.game_system.make_move(joker_tile, rotation, col, row);
                self.turn = Turn::Guest;
            },
            Turn::Guest => {
                testing::set_contract_address(self.guest_player_data.address);
                self.game_system.make_move(joker_tile, rotation, col, row);
                self.turn = Turn::Host;
            },
        }
    }

    fn process_multiple_moves(
        ref self: GameCaller, moves: Array<(Option<u8>, u8, u8, u8)>
    ) {
        self.update_commited_tile();
        let mut i = 0;
        for (joker_tile, rotation, col, row) in moves {
            println!("{}", i);
            self.commited_tile = self.process_reveal_phase(self.commited_tile).unwrap();
            self.process_move(joker_tile, rotation, col, row);
            i += 1;
        }
    }

    fn update_commited_tile(ref self: GameCaller) {
        let board_id: Option<felt252> = self.world.read_member(
            Model::<Game>::ptr_from_keys(self.host_player_data.address), selector!("board_id")
        );
        println!("Board ID: {:?}", board_id);
        let board: Board = self.world.read_model(board_id.unwrap());
        println!("Updated commited tile: {:?}", board.commited_tile);
        self.commited_tile = board.commited_tile.unwrap();
    }
}