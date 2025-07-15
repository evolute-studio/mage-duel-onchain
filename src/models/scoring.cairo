use evolute_duel::types::packing::{PlayerSide, TEdge}; 

// --------------------------------------
// Scoring Models
// --------------------------------------

/// Represents a node involved in a potential contest.
///
/// - `parent`: Parent node reference for union-find structure.
/// - `rank`: Rank in the disjoint set for contest resolution.
/// - `blue_points`: Points earned by the blue player.
/// - `red_points`: Points earned by the red player.
/// - `open_edges`: Number of open edges in this city.
/// - `contested`: Boolean flag indicating if the city is contested.
#[derive(Drop, Serde, Copy, Introspect, PartialEq, Debug)]
#[dojo::model]
pub struct UnionNode {
    #[key]
    pub board_id: felt252, // Board ID to which this node belongs
    #[key]
    pub position: u32, // Position in the union-find structure
    pub parent: u32,
    pub rank: u8,
    pub blue_points: u16,
    pub red_points: u16,
    pub open_edges: u8,
    pub contested: bool,
    pub node_type: TEdge, // 0: None, 1: City, 2: Road
    pub player_side: PlayerSide, // 0: None, 1: Blue, 2: Red
}


#[derive(Drop, Destruct, Serde, Introspect, PartialEq, Debug)]
#[dojo::model]
pub struct PotentialContests {
    #[key]
    pub board_id: felt252, // Board ID to which this node belongs
    pub potential_contests: Array<u32>, // Array of potential contests
}

