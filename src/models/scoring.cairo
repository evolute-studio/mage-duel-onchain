use dojo::world::{WorldStorage};
use dojo::model::{Model, ModelStorage};
use evolute_duel::types::packing::{UnionNode};
// --------------------------------------
// Scoring Models
// --------------------------------------

#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::model]
pub struct UnionFind {
    #[key]
    pub board_id: felt252,
    pub nodes_parents: Span<u8>,
    pub nodes_ranks: Span<u8>,
    pub nodes_blue_points: Span<u16>,
    pub nodes_red_points: Span<u16>,
    pub nodes_open_edges: Span<u8>,
    pub nodes_contested: Span<bool>,
    pub nodes_types: Span<u8>, // 0 - None, 1 - City, 2 - Road
    pub potential_city_contests: Array<u8>,
    pub potential_road_contests: Array<u8>,
}

#[generate_trait]
pub impl UnionFindImpl of UnionFindTrait {
    fn new(board_id: felt252) -> UnionFind {
        let mut nodes_parents = array![];
        let mut nodes_ranks = array![];
        let mut nodes_blue_points = array![];
        let mut nodes_red_points = array![];
        let mut nodes_open_edges = array![];
        let mut nodes_contested = array![];
        let mut nodes_types = array![];
        for i in 0..256_u16 {
            nodes_parents.append(i.try_into().unwrap());
            nodes_ranks.append(0);
            nodes_blue_points.append(0);
            nodes_red_points.append(0);
            nodes_open_edges.append(0);
            nodes_contested.append(false);
            nodes_types.append(2); // 0 - Сity, 1 - Road, 2 - None
        };
        let mut potential_city_contests = array![];
        let potential_road_contests = array![];
        let union_find = UnionFind {
            board_id: board_id,
            nodes_parents: nodes_parents.span(),
            nodes_ranks: nodes_ranks.span(),
            nodes_blue_points: nodes_blue_points.span(),
            nodes_red_points: nodes_red_points.span(),
            nodes_open_edges: nodes_open_edges.span(),
            nodes_contested: nodes_contested.span(),
            nodes_types: nodes_types.span(),
            potential_city_contests: potential_city_contests,
            potential_road_contests: potential_road_contests,
        };

        union_find
    }
    fn write_empty(board_id: felt252, mut world: WorldStorage) {
        let union_find = UnionFind {
            board_id: board_id,
            nodes_parents: array![].span(),
            nodes_ranks: array![].span(),
            nodes_blue_points: array![].span(),
            nodes_red_points: array![].span(),
            nodes_open_edges: array![].span(),
            nodes_contested: array![].span(),
            nodes_types: array![].span(),
            potential_city_contests: array![],
            potential_road_contests: array![],
        };
        world.write_model(@union_find);
    }
    fn write(ref self: UnionFind, mut world: WorldStorage) {
        world
            .write_member(
                Model::<UnionFind>::ptr_from_keys(self.board_id),
                selector!("nodes_types"),
                self.nodes_types.clone(),
            );

        world
            .write_member(
                Model::<UnionFind>::ptr_from_keys(self.board_id),
                selector!("nodes_parents"),
                self.nodes_parents.clone(),
            );

        world
            .write_member(
                Model::<UnionFind>::ptr_from_keys(self.board_id),
                selector!("nodes_ranks"),
                self.nodes_ranks.clone(),
            );
        world
            .write_member(
                Model::<UnionFind>::ptr_from_keys(self.board_id),
                selector!("nodes_ranks"),
                self.nodes_ranks.clone(),
            );
        world
            .write_member(
                Model::<UnionFind>::ptr_from_keys(self.board_id),
                selector!("nodes_blue_points"),
                self.nodes_blue_points.clone(),
            );
        world
            .write_member(
                Model::<UnionFind>::ptr_from_keys(self.board_id),
                selector!("nodes_red_points"),
                self.nodes_red_points.clone(),
            );
        world
            .write_member(
                Model::<UnionFind>::ptr_from_keys(self.board_id),
                selector!("nodes_open_edges"),
                self.nodes_open_edges.clone(),
            );
        world
            .write_member(
                Model::<UnionFind>::ptr_from_keys(self.board_id),
                selector!("nodes_contested"),
                self.nodes_contested.clone(),
            );
        world
            .write_member(
                Model::<UnionFind>::ptr_from_keys(self.board_id),
                selector!("potential_city_contests"),
                self.potential_city_contests.clone(),
            );
        world
            .write_member(
                Model::<UnionFind>::ptr_from_keys(self.board_id),
                selector!("potential_road_contests"),
                self.potential_road_contests.clone(),
            );
    }

    fn from_union_nodes(
        road_nodes_arr: Array<UnionNode>,
        city_nodes_arr: Array<UnionNode>,
        potential_city_contests: Array<u8>,
        potential_road_contests: Array<u8>,
    ) -> UnionFind {
        let mut nodes_parents = array![];
        let mut nodes_ranks = array![];
        let mut nodes_blue_points = array![];
        let mut nodes_red_points = array![];
        let mut nodes_open_edges = array![];
        let mut nodes_contested = array![];
        let mut nodes_types = array![];

        for i in 0..road_nodes_arr.len() {
            let road_node = *road_nodes_arr[i];
            let city_node = *city_nodes_arr[i];
            if road_node.node_type == 1 {
                nodes_parents.append(road_node.parent);
                nodes_ranks.append(road_node.rank);
                nodes_blue_points.append(road_node.blue_points);
                nodes_red_points.append(road_node.red_points);
                nodes_open_edges.append(road_node.open_edges);
                nodes_contested.append(road_node.contested);
                nodes_types.append(1); // 0 - Сity, 1 - Road, 2 - None
            } else if city_node.node_type == 0 {
                nodes_parents.append(city_node.parent);
                nodes_ranks.append(city_node.rank);
                nodes_blue_points.append(city_node.blue_points);
                nodes_red_points.append(city_node.red_points);
                nodes_open_edges.append(city_node.open_edges);
                nodes_contested.append(city_node.contested);
                nodes_types.append(0); // 0 - Сity, 1 - Road, 2 - None
            } else {
                nodes_parents.append(i.try_into().unwrap());
                nodes_ranks.append(0);
                nodes_blue_points.append(0);
                nodes_red_points.append(0);
                nodes_open_edges.append(0);
                nodes_contested.append(false);
                nodes_types.append(2); // 0 - Сity, 1 - Road, 2 - None
            }
        };

        let union_find = UnionFind {
            board_id: 0,
            nodes_parents: nodes_parents.span(),
            nodes_ranks: nodes_ranks.span(),
            nodes_blue_points: nodes_blue_points.span(),
            nodes_red_points: nodes_red_points.span(),
            nodes_open_edges: nodes_open_edges.span(),
            nodes_contested: nodes_contested.span(),
            nodes_types: nodes_types.span(),
            potential_city_contests: potential_city_contests,
            potential_road_contests: potential_road_contests,
        };

        union_find
    }
}
