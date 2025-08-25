use starknet::{ContractAddress};
use evolute_duel::types::packing::{GameState, GameStatus, PlayerSide, GameMode};

/// Represents the game board, including tile states, players, scores, and game progression.
///
/// - `id`: Unique identifier for the board.
/// - `initial_edge_state`: Initial state of tiles at board edges.
/// - `available_tiles_in_deck`: Remaining tiles in the deck.
/// - `top_tile`: The tile currently on top of the deck (if any).
/// - `state`: List of placed tiles with their encoding, rotation, and side.
/// - `player1`: First player's address, side, and joker count.
/// - `player2`: Second player's address, side, and joker count.
/// - `blue_score`: Tuple storing city and road scores for the blue side.
/// - `red_score`: Tuple storing city and road scores for the red side.
/// - `last_move_id`: ID of the last move made (if applicable).
/// - `game_state`: Represents the current game state (InProgress, Finished).
#[derive(Drop, Serde, Debug, Introspect, Clone)]
#[dojo::model]
pub struct Board {
    #[key]
    pub id: felt252,
    pub available_tiles_in_deck: Span<u8>,
    pub top_tile: Option<u8>,
    //(address, side, joker_number)
    pub player1: (ContractAddress, PlayerSide, u8),
    //(address, side, joker_number)
    pub player2: (ContractAddress, PlayerSide, u8),
    // (u16, u16) => (city_score, road_score)
    pub blue_score: (u16, u16),
    // (u16, u16) => (city_score, road_score)
    pub red_score: (u16, u16),
    pub last_move_id: Option<felt252>,
    pub game_state: GameState,
    pub moves_done: u8,
    pub commited_tile: Option<u8>,
    pub phase_started_at: u64,
}

/// Represents a player's move, tracking tile placement and game progression.
///
/// - `id`: Unique identifier for the move.
/// - `player_side`: The side of the player making the move.
/// - `prev_move_id`: ID of the previous move (if applicable).
/// - `tile`: Tile placed in the move (if any).
/// - `rotation`: Rotation of the placed tile (0 if no rotation).
/// - `col`: Column position of the tile.
/// - `row`: Row position of the tile.
/// - `is_joker`: Whether the move involved a joker tile.
///
/// If `tile` is `None`, this move represents a skip.
/// If `prev_move_id` is `None`, this move is the first move of the game.
/// If `is_joker` is `true`, the move involved a joker tile.
#[derive(Drop, Serde, Introspect, Debug, Copy)]
#[dojo::model]
pub struct Move {
    #[key]
    pub id: felt252,
    pub player_side: PlayerSide,
    pub prev_move_id: Option<felt252>,
    pub tile: Option<u8>,
    pub rotation: u8,
    pub col: u8,
    pub row: u8,
    pub is_joker: bool,
    pub first_board_id: felt252,
    pub timestamp: u64,
    pub top_tile: Option<u8>,
}

/// Defines the game rules, including deck composition, scoring mechanics, and special tile rules.
///
/// - `id`: Unique identifier for the rule set.
/// - `deck`: Defines the number of each tile type in the deck.
/// - `edges`: Initial setup of city and road elements on the board edges.
/// - `joker_number`: Number of joker tiles available per player.
/// - `joker_price`: Cost of using a joker tile.
#[derive(Drop, Introspect, Serde)]
#[dojo::model]
pub struct Rules {
    #[key]
    pub id: felt252,
    pub deck: Span<u8>,
    pub edges: (u8, u8),
    pub joker_number: u8,
    pub joker_price: u16,
}

/// Represents an active game session, tracking its state and progress.
///
/// - `player`: The player associated with this game instance.
/// - `status`: Current game status (active, completed, etc.).
/// - `board_id`: Reference to the board associated with the game.
/// - `game_mode`: The mode of the game (Tutorial, Ranked, Casual).
#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::model]
pub struct Game {
    #[key]
    pub player: ContractAddress,
    pub status: GameStatus,
    pub board_id: Option<felt252>,
    pub game_mode: GameMode,
}

#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::model]
pub struct TileCommitments {
    #[key]
    pub board_id: felt252,
    #[key]
    pub player: ContractAddress,
    pub tile_commitments: Span<felt252>,
}


#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::model]
pub struct AvailableTiles {
    #[key]
    pub board_id: felt252,
    #[key]
    pub player: ContractAddress,
    pub available_tiles: Span<u8>,
}

/// Configuration for different game modes.
///
/// - `game_mode`: The game mode this configuration applies to.
/// - `board_size`: Size of the game board (7 for tutorial, 10 for ranked/casual).
/// - `deck_type`: Type of deck to use (0: tutorial, 1: full randomized).
/// - `initial_jokers`: Number of joker tiles each player starts with.
/// - `time_per_phase`: Time limit for each phase in seconds (0 = no limit).
/// - `auto_match`: Whether to enable automatic matchmaking for this mode.
/// - `deck`: Defines the number of each tile type in the deck.
/// - `edges`: Initial setup of city and road elements on the board edges.
/// - `joker_price`: Cost of using a joker tile.
#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::model]
pub struct GameModeConfig {
    #[key]
    pub game_mode: GameMode,
    pub board_size: u8,
    pub deck_type: u8,
    pub initial_jokers: u8,
    pub time_per_phase: u64,
    pub auto_match: bool,
    pub deck: Span<u8>,
    pub edges: (u8, u8),
    pub joker_price: u16,
}

/// Represents the state of matchmaking queue for a specific game mode and tournament
#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::model]
pub struct MatchmakingState {
    #[key]
    pub game_mode: GameMode,
    #[key]
    pub tournament_id: u64, // 0 for non-tournament modes
    pub waiting_players: Array<ContractAddress>,
    pub queue_counter: u32, // for round-robin or other algorithms
}

/// Tracks individual player's matchmaking status
#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::model]
pub struct PlayerMatchmaking {
    #[key]
    pub player: ContractAddress,
    pub game_mode: GameMode,
    pub tournament_id: u64,
    pub timestamp: u64,
    // rating moved to TournamentPass model
}

