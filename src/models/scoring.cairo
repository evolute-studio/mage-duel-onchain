use dojo::world::{WorldStorage};
use dojo::model::{Model, ModelStorage};
use evolute_duel::types::packing::{UnionNode};
use alexandria_data_structures::vec::{
    NullableVec, VecTrait,
}; // --------------------------------------
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
        ref road_nodes: NullableVec<UnionNode>,
        ref city_nodes: NullableVec<UnionNode>,
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

        for i in 0..road_nodes.len() {
            let road_node = road_nodes.at(i.into());
            let city_node = city_nodes.at(i.into());
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

    fn update_with_union_nodes(
        ref self: UnionFind,
        ref city_nodes: NullableVec<UnionNode>,
        ref road_nodes: NullableVec<UnionNode>,
    ) {
        self =
            Self::from_union_nodes(
                ref road_nodes,
                ref city_nodes,
                self.potential_city_contests.clone(),
                self.potential_road_contests.clone(),
            );
    }

    fn to_nullable_vecs(ref self: UnionFind) -> (NullableVec<UnionNode>, NullableVec<UnionNode>) {
        let mut city_nodes = VecTrait::<NullableVec, UnionNode>::new();
        let mut road_nodes = VecTrait::<NullableVec, UnionNode>::new();

        for i in 0..self.nodes_parents.len() {
            let mut node: UnionNode = Default::default();
            node.node_type = *self.nodes_types.at(i.into());
            node.parent = *self.nodes_parents.at(i.into());
            node.rank = *self.nodes_ranks.at(i.into());
            node.blue_points = *self.nodes_blue_points.at(i.into());
            node.red_points = *self.nodes_red_points.at(i.into());
            node.open_edges = *self.nodes_open_edges.at(i.into());
            node.contested = *self.nodes_contested.at(i.into());
            if node.node_type == 0 {
                road_nodes
                    .push(
                        UnionNode {
                            parent: i.try_into().unwrap(),
                            rank: 0,
                            blue_points: 0,
                            red_points: 0,
                            open_edges: 0,
                            contested: false,
                            node_type: 2 // 0 - City, 1 - Road, 2 - None
                        },
                    );
                city_nodes.push(node);
            } else if node.node_type == 1 {
                road_nodes.push(node);
                city_nodes
                    .push(
                        UnionNode {
                            parent: i.try_into().unwrap(),
                            rank: 0,
                            blue_points: 0,
                            red_points: 0,
                            open_edges: 0,
                            contested: false,
                            node_type: 2 // 0 - City, 1 - Road, 2 - None
                        },
                    );
            } else {
                road_nodes
                    .push(
                        UnionNode {
                            parent: i.try_into().unwrap(),
                            rank: 0,
                            blue_points: 0,
                            red_points: 0,
                            open_edges: 0,
                            contested: false,
                            node_type: 2 // 0 - City, 1 - Road, 2 - None
                        },
                    );
                city_nodes
                    .push(
                        UnionNode {
                            parent: i.try_into().unwrap(),
                            rank: 0,
                            blue_points: 0,
                            red_points: 0,
                            open_edges: 0,
                            contested: false,
                            node_type: 2 // 0 - City, 1 - Road, 2 - None
                        },
                    );
            }
        };

        return (city_nodes, road_nodes);
    }
}
