// --------------------------------------
// Scoring Models
// --------------------------------------

/// Represents potential city contests in a game.
///
/// - `board_id`: The associated board ID.
/// - `roots`: Array of root positions representing potential contested cities.
#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::model]
pub struct PotentialCityContests {
    #[key]
    pub board_id: felt252,
    pub roots: Array<u8>,
}

/// Represents a city node involved in a potential contest.
///
/// - `board_id`: The associated board ID.
/// - `position`: Encoded position of the city node.
/// - `parent`: Parent node reference for union-find structure.
/// - `rank`: Rank in the disjoint set for contest resolution.
/// - `blue_points`: Points earned by the blue player.
/// - `red_points`: Points earned by the red player.
/// - `open_edges`: Number of open edges in this city.
/// - `contested`: Boolean flag indicating if the city is contested.
#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::model]
pub struct CityNode {
    #[key]
    pub board_id: felt252,
    //It is a number of TEdge position in the board
    // tile pos = tedge_position / 4 {
    // col = tile_pos % 8
    // row = tile_pos / 8
    //}
    // edge diraction = tedge_position % 4
    #[key]
    pub position: u8,
    pub parent: u8,
    pub rank: u8,
    pub blue_points: u16,
    pub red_points: u16,
    pub open_edges: u8,
    pub contested: bool,
}


/// Represents potential road contests in a game.
///
/// - `board_id`: The associated board ID.
/// - `roots`: Array of root positions representing potential contested roads.
#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::model]
pub struct PotentialRoadContests {
    #[key]
    pub board_id: felt252,
    pub roots: Array<u8>,
}


/// Represents a road node involved in a potential contest.
///
/// - `board_id`: The associated board ID.
/// - `position`: Encoded position of the road node.
/// - `parent`: Parent node reference for union-find structure.
/// - `rank`: Rank in the disjoint set for contest resolution.
/// - `blue_points`: Points earned by the blue player.
/// - `red_points`: Points earned by the red player.
/// - `open_edges`: Number of open edges in this road.
/// - `contested`: Boolean flag indicating if the road is contested.
#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::model]
pub struct RoadNode {
    #[key]
    pub board_id: felt252,
    //It is a number of TEdge position in the board
    // tile pos = tedge_position / 4 {
    // col = tile_pos % 8
    // row = tile_pos / 8
    //}
    // edge diraction = tedge_position % 4
    #[key]
    pub position: u8,
    pub parent: u8,
    pub rank: u8,
    pub blue_points: u16,
    pub red_points: u16,
    pub open_edges: u8,
    pub contested: bool,
}