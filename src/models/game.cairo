use starknet::{ContractAddress};
use evolute_duel::packing::{GameState, GameStatus, PlayerSide};

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
    pub initial_edge_state: Array<u8>,
    pub available_tiles_in_deck: Array<u8>,
    pub top_tile: Option<u8>,
    // (u8, u8, u8) => (tile_number, rotation, side)
    pub state: Array<(u8, u8, u8)>,
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
#[derive(Drop, Serde, Introspect, Debug)]
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
    pub deck: Array<u8>,
    pub edges: (u8, u8),
    pub joker_number: u8,
    pub joker_price: u16,
}

/// Represents an active game session, tracking its state and progress.
///
/// - `player`: The player associated with this game instance.
/// - `status`: Current game status (active, completed, etc.).
/// - `board_id`: Reference to the board associated with the game.
/// - `snapshot_id`: ID of a game state snapshot if game was created from a snapshot.
#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::model]
pub struct Game {
    #[key]
    pub player: ContractAddress,
    pub status: GameStatus,
    pub board_id: Option<felt252>,
    pub snapshot_id: Option<felt252>,
}

/// Stores a snapshot of the game state at a specific move number.
///
/// - `snapshot_id`: Unique identifier for the snapshot.
/// - `player`: The player whose state is recorded.
/// - `board_id`: Reference to the board state.
/// - `move_number`: Move number associated with this snapshot.
#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::model]
pub struct Snapshot {
    #[key]
    pub snapshot_id: felt252,
    pub player: ContractAddress,
    pub board_id: felt252,
    pub move_number: u8,
}