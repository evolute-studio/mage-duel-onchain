use starknet::{ContractAddress};
use evolute_duel::packing::{GameState, GameStatus, PlayerSide, UnionNode};
use dojo::world::WorldStorage;
use dojo::model::{ModelStorage, Model};


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
    pub initial_edge_state: Span<u8>,
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
    pub moves_done: u8,
    pub last_update_timestamp: u64,
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


// --------------------------------------
// Scoring Models
// --------------------------------------

#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::model]
pub struct UnionFind {
    #[key]
    pub board_id: felt252,

    pub city_nodes_parents: Span<u8>,
    pub city_nodes_ranks: Span<u8>,
    pub city_nodes_blue_points: Span<u16>,
    pub city_nodes_red_points: Span<u16>,
    pub city_nodes_open_edges: Span<u8>,
    pub city_nodes_contested: Span<bool>,

    pub road_nodes_parents: Span<u8>,
    pub road_nodes_ranks: Span<u8>,
    pub road_nodes_blue_points: Span<u16>,
    pub road_nodes_red_points: Span<u16>,
    pub road_nodes_open_edges: Span<u8>,
    pub road_nodes_contested: Span<bool>,

    pub potential_city_contests: Array<u8>,
    pub potential_road_contests: Array<u8>,
}

#[generate_trait]
pub impl UnionFindImpl of UnionFindTrait {
    fn new(board_id: felt252) -> UnionFind {
        let mut road_nodes_parents = array![];
        let mut road_nodes_ranks = array![];
        let mut road_nodes_blue_points = array![];
        let mut road_nodes_red_points = array![];
        let mut road_nodes_open_edges = array![];
        let mut road_nodes_contested = array![];
        let mut city_nodes_parents = array![];
        let mut city_nodes_ranks = array![];
        let mut city_nodes_blue_points = array![];
        let mut city_nodes_red_points = array![];
        let mut city_nodes_open_edges = array![];
        let mut city_nodes_contested = array![];
        for _ in 0..256_u16 {
            road_nodes_parents.append(0);
            road_nodes_ranks.append(0);
            road_nodes_blue_points.append(0);
            road_nodes_red_points.append(0);
            road_nodes_open_edges.append(0);
            road_nodes_contested.append(false);

            city_nodes_parents.append(0);
            city_nodes_ranks.append(0);
            city_nodes_blue_points.append(0);
            city_nodes_red_points.append(0);
            city_nodes_open_edges.append(0);
            city_nodes_contested.append(false);
        };
        let mut potential_city_contests = array![];
        let potential_road_contests = array![];
        let union_find = UnionFind {
            board_id: board_id,
            city_nodes_parents: city_nodes_parents.span(),
            city_nodes_ranks: city_nodes_ranks.span(),
            city_nodes_blue_points: city_nodes_blue_points.span(),
            city_nodes_red_points: city_nodes_red_points.span(),
            city_nodes_open_edges: city_nodes_open_edges.span(),
            city_nodes_contested: city_nodes_contested.span(),
            road_nodes_parents: road_nodes_parents.span(),
            road_nodes_ranks: road_nodes_ranks.span(),
            road_nodes_blue_points: road_nodes_blue_points.span(),
            road_nodes_red_points: road_nodes_red_points.span(),
            road_nodes_open_edges: road_nodes_open_edges.span(),
            road_nodes_contested: road_nodes_contested.span(),
            potential_city_contests: potential_city_contests,
            potential_road_contests: potential_road_contests,
        };

        union_find
    }

    fn write(ref self: UnionFind, mut world: WorldStorage) {
        world
            .write_member(
                Model::<UnionFind>::ptr_from_keys(self.board_id),
                selector!("city_nodes_parents"),
                self.city_nodes_parents.clone()
            );

        world
            .write_member(
                Model::<UnionFind>::ptr_from_keys(self.board_id),
                selector!("road_nodes_parents"),
                self.road_nodes_parents.clone()
            );
        world
            .write_member(
                Model::<UnionFind>::ptr_from_keys(self.board_id),
                selector!("city_nodes_ranks"),
                self.city_nodes_ranks.clone()
            );
        world
            .write_member(
                Model::<UnionFind>::ptr_from_keys(self.board_id),
                selector!("road_nodes_ranks"),
                self.road_nodes_ranks.clone()
            );
        world
            .write_member(
                Model::<UnionFind>::ptr_from_keys(self.board_id),
                selector!("city_nodes_blue_points"),
                self.city_nodes_blue_points.clone()
            );
        world
            .write_member(
                Model::<UnionFind>::ptr_from_keys(self.board_id),
                selector!("road_nodes_blue_points"),
                self.road_nodes_blue_points.clone()
            );
        world
            .write_member(
                Model::<UnionFind>::ptr_from_keys(self.board_id),
                selector!("city_nodes_red_points"),
                self.city_nodes_red_points.clone()
            );
        world
            .write_member(
                Model::<UnionFind>::ptr_from_keys(self.board_id),
                selector!("road_nodes_red_points"),
                self.road_nodes_red_points.clone()
            );
        world
            .write_member(
                Model::<UnionFind>::ptr_from_keys(self.board_id),
                selector!("city_nodes_open_edges"),
                self.city_nodes_open_edges.clone()
            );
        world
            .write_member(
                Model::<UnionFind>::ptr_from_keys(self.board_id),
                selector!("road_nodes_open_edges"),
                self.road_nodes_open_edges.clone()
            );
        world
            .write_member(
                Model::<UnionFind>::ptr_from_keys(self.board_id),
                selector!("city_nodes_contested"),
                self.city_nodes_contested.clone()
            );
        world
            .write_member(
                Model::<UnionFind>::ptr_from_keys(self.board_id),
                selector!("road_nodes_contested"),
                self.road_nodes_contested.clone()
            );

        world
            .write_member(
                Model::<UnionFind>::ptr_from_keys(self.board_id),
                selector!("potential_city_contests"),
                self.potential_city_contests.clone()
            );
        world
            .write_member(
                Model::<UnionFind>::ptr_from_keys(self.board_id),
                selector!("potential_road_contests"),
                self.potential_road_contests.clone()
            );
    }

    fn from_union_nodes(
        road_nodes_arr: Array<UnionNode>,
        city_nodes_arr: Array<UnionNode>,
        potential_city_contests: Array<u8>,
        potential_road_contests: Array<u8>
    ) -> UnionFind {
        let mut road_nodes_parents = array![];
        let mut road_nodes_ranks = array![];
        let mut road_nodes_blue_points = array![];
        let mut road_nodes_red_points = array![];
        let mut road_nodes_open_edges = array![];
        let mut road_nodes_contested = array![];
        let mut city_nodes_parents = array![];
        let mut city_nodes_ranks = array![];
        let mut city_nodes_blue_points = array![];
        let mut city_nodes_red_points = array![];
        let mut city_nodes_open_edges = array![];
        let mut city_nodes_contested = array![];

        for i in 0..road_nodes_arr.len() {
            let road_node = *road_nodes_arr[i];
            road_nodes_parents.append(road_node.parent);
            road_nodes_ranks.append(road_node.rank);
            road_nodes_blue_points.append(road_node.blue_points);
            road_nodes_red_points.append(road_node.red_points);
            road_nodes_open_edges.append(road_node.open_edges);
            road_nodes_contested.append(road_node.contested);
        };
        for i in 0..city_nodes_arr.len() {
            let city_node = *city_nodes_arr[i];
            city_nodes_parents.append(city_node.parent);
            city_nodes_ranks.append(city_node.rank);
            city_nodes_blue_points.append(city_node.blue_points);
            city_nodes_red_points.append(city_node.red_points);
            city_nodes_open_edges.append(city_node.open_edges);
            city_nodes_contested.append(city_node.contested);
        };
        let union_find = UnionFind {
            board_id: 0,
            city_nodes_parents: city_nodes_parents.span(),
            city_nodes_ranks: city_nodes_ranks.span(),
            city_nodes_blue_points: city_nodes_blue_points.span(),
            city_nodes_red_points: city_nodes_red_points.span(),
            city_nodes_open_edges: city_nodes_open_edges.span(),
            city_nodes_contested: city_nodes_contested.span(),
            road_nodes_parents: road_nodes_parents.span(),
            road_nodes_ranks: road_nodes_ranks.span(),
            road_nodes_blue_points: road_nodes_blue_points.span(),
            road_nodes_red_points: road_nodes_red_points.span(),
            road_nodes_open_edges: road_nodes_open_edges.span(),
            road_nodes_contested: road_nodes_contested.span(),
            potential_city_contests: potential_city_contests,
            potential_road_contests: potential_road_contests,
        };

        union_find
    }
}


// --------------------------------------
// Player Profile Models
// --------------------------------------

/// Represents a player profile, tracking in-game identity and statistics.
///
/// - `player_id`: Unique identifier for the player.
/// - `username`: Player's chosen in-game name.
/// - `balance`: Current balance of in-game currency or points.
/// - `games_played`: Total number of games played by the player.
/// - `active_skin`: The currently equipped skin or avatar.
#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::model]
pub struct Player {
    #[key]
    pub player_id: ContractAddress,
    pub username: felt252,
    pub balance: u16,
    pub games_played: felt252,
    pub active_skin: u8,
    pub is_bot: bool,
}

/// Represents a shop where players can purchase in-game items.
///
/// - `shop_id`: Unique identifier for the shop.
/// - `skin_prices`: List of prices for different skins available in the shop.
#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::model]
pub struct Shop {
    #[key]
    pub shop_id: felt252,
    pub skin_prices: Span<u16>,
}

