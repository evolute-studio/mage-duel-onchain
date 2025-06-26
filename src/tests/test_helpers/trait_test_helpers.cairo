use dojo::model::{ModelStorage, Model};
use dojo::world::{WorldStorage, IWorldDispatcher};
use starknet::{ContractAddress, contract_address_const, get_block_timestamp};

use evolute_duel::{
    models::{
        game::{Board, Game, TileCommitments, AvailableTiles, Rules},
        player::{Player},
        scoring::{UnionFind},
    },
    types::packing::{GameState, GameStatus, PlayerSide},
    utils::hash::{hash_values},
};

// Test constants
const BOARD_ID: felt252 = 12345;
const PLAYER1_ADDRESS: felt252 = 0x1;
const PLAYER2_ADDRESS: felt252 = 0x2;
const TILE_INDEX: u8 = 5;
const NONCE: felt252 = 123456;
const TILE_TYPE: u8 = 42;

#[generate_trait]
pub impl TraitTestHelpersImpl of TraitTestHelpersTrait {
    fn create_test_player_addresses() -> (ContractAddress, ContractAddress) {
        (
            contract_address_const::<PLAYER1_ADDRESS>(),
            contract_address_const::<PLAYER2_ADDRESS>()
        )
    }

    fn create_test_board() -> Board {
        let (player1, player2) = Self::create_test_player_addresses();
        let available_tiles = array![1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
        let initial_edge_state = array![0, 0, 0, 0].span();
        
        Board {
            id: BOARD_ID,
            initial_edge_state,
            available_tiles_in_deck: available_tiles,
            top_tile: Option::Some(TILE_INDEX),
            state: array![],
            player1: (player1, PlayerSide::Blue, 3),
            player2: (player2, PlayerSide::Red, 3),
            blue_score: (100, 50),
            red_score: (80, 60),
            last_move_id: Option::None,
            game_state: GameState::Reveal,
            moves_done: 0,
            last_update_timestamp: get_block_timestamp(),
            commited_tile: Option::Some(TILE_TYPE),
            phase_started_at: get_block_timestamp(),
        }
    }

    fn create_test_board_with_state(game_state: GameState) -> Board {
        let mut board = Self::create_test_board();
        board.game_state = game_state;
        board
    }

    fn create_test_board_finished() -> Board {
        let mut board = Self::create_test_board();
        board.game_state = GameState::Finished;
        board.blue_score = (150, 120);
        board.red_score = (140, 110);
        board
    }

    fn create_test_game(player: ContractAddress, status: GameStatus) -> Game {
        Game {
            player,
            status,
            board_id: Option::Some(BOARD_ID),
            snapshot_id: Option::None,
        }
    }

    fn create_test_player(address: ContractAddress) -> Player {
        Player {
            player_id: address,
            balance: 1000,
            games_played: 5,
            username: 'TestPlayer',
            active_skin: 1,
            role: 1, // Controller
        }
    }

    fn create_test_tile_commitments(player: ContractAddress) -> TileCommitments {
        let commitment = hash_values([TILE_INDEX.into(), NONCE, TILE_TYPE.into()].span());
        let commitments = array![commitment, 111, 222, 333, 444];
        
        TileCommitments {
            board_id: BOARD_ID,
            player,
            tile_commitments: commitments.span(),
        }
    }

    fn create_test_available_tiles(player: ContractAddress) -> AvailableTiles {
        let tiles = array![TILE_TYPE, 10, 20, 30, 40];
        
        AvailableTiles {
            board_id: BOARD_ID,
            player,
            available_tiles: tiles.span(),
        }
    }

    fn create_test_rules() -> Rules {
        let deck = array![2, 0, 0, 4, 3, 6, 4, 0, 0, 4, 7, 6, 0, 9, 8, 0, 0, 0, 0, 0, 0, 3, 4, 4].span();
        Rules {
            id: 0,
            deck,
            edges: (1, 1),
            joker_number: 3,
            joker_price: 5,
        }
    }

    fn create_test_union_find() -> UnionFind {
        UnionFind {
            board_id: BOARD_ID,
            nodes_parents: array![].span(),
            nodes_ranks: array![].span(),
            nodes_blue_points: array![].span(),
            nodes_red_points: array![].span(),
            nodes_open_edges: array![].span(),
            nodes_contested: array![].span(),
            nodes_types: array![].span(),
            potential_city_contests: array![],
            potential_road_contests: array![],
        }
    }

    fn setup_world_with_models(mut world: WorldStorage) {
        let (player1, player2) = Self::create_test_player_addresses();
        
        // Setup board
        let board = Self::create_test_board();
        world.write_model(@board);
        
        // Setup games
        let game1 = Self::create_test_game(player1, GameStatus::InProgress);
        let game2 = Self::create_test_game(player2, GameStatus::InProgress);
        world.write_model(@game1);
        world.write_model(@game2);
        
        // Setup players
        let player1_model = Self::create_test_player(player1);
        let player2_model = Self::create_test_player(player2);
        world.write_model(@player1_model);
        world.write_model(@player2_model);
        
        // Setup tile commitments
        let commitments1 = Self::create_test_tile_commitments(player1);
        let commitments2 = Self::create_test_tile_commitments(player2);
        world.write_model(@commitments1);
        world.write_model(@commitments2);
        
        // Setup available tiles
        let available1 = Self::create_test_available_tiles(player1);
        let available2 = Self::create_test_available_tiles(player2);
        world.write_model(@available1);
        world.write_model(@available2);
        
        // Setup rules
        let rules = Self::create_test_rules();
        world.write_model(@rules);
        
        // Setup union find
        let union_find = Self::create_test_union_find();
        world.write_model(@union_find);
    }

    fn assert_board_game_state(world: WorldStorage, expected_state: GameState) {
        let board: Board = world.read_model(BOARD_ID);
        assert!(board.game_state == expected_state, "Game state mismatch");
    }

    fn assert_phase_started_at_updated(world: WorldStorage, previous_timestamp: u64) {
        let board: Board = world.read_model(BOARD_ID);
        assert!(board.phase_started_at > previous_timestamp, "Phase start time not updated");
    }

    fn get_test_commitment() -> felt252 {
        hash_values([TILE_INDEX.into(), NONCE, TILE_TYPE.into()].span())
    }
}