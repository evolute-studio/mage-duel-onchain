use evolute_duel::models::scoring::UnionNode;
use dojo::{world::{WorldStorage}, model::{ModelStorage}};
//Union find
pub fn find(mut world: WorldStorage, board_id: felt252, position: u32) -> u32 {
    // println!("[Union find] calles find({}, {})", nodes.len(), position);
    let mut current: UnionNode = world.read_model((board_id, position));
    if current.parent != position {
        current.parent = find(world, board_id, current.parent);
        world.write_model(@current);
    }
    current.parent
}

pub fn union(
    mut world: WorldStorage, board_id: felt252, position1: u32, position2: u32, in_tile: bool,
) -> UnionNode {
    let mut root1_pos: u32 = find(world, board_id, position1);
    let mut root1: UnionNode = world.read_model((board_id, root1_pos));
    let mut root2_pos: u32 = find(world, board_id, position2);
    let mut root2: UnionNode = world.read_model((board_id, root2_pos));

    if root1_pos == root2_pos {
        if !in_tile {
            root1.open_edges -= 2;
            world.write_model(@root1);
        }
        return root1;
    }
    if root1.rank > root2.rank {
        root2.parent = root1_pos;
        root1.blue_points += root2.blue_points;
        root1.red_points += root2.red_points;
        root1.open_edges += root2.open_edges;
        if !in_tile {
            root1.open_edges -= 2;
        }
        world.write_model(@root1);
        world.write_model(@root2);
        return root1;
    } else if root1.rank < root2.rank {
        root1.parent = root2_pos;
        root2.blue_points += root1.blue_points;
        root2.red_points += root1.red_points;
        root2.open_edges += root1.open_edges;
        if !in_tile {
            root2.open_edges -= 2;
        }
        world.write_model(@root2);
        world.write_model(@root1);
        return root2;
    } else {
        root2.parent = root1_pos;
        root1.rank += 1;
        root1.blue_points += root2.blue_points;
        root1.red_points += root2.red_points;
        root1.open_edges += root2.open_edges;
        if !in_tile {
            root1.open_edges -= 2;
        }
        world.write_model(@root1);
        world.write_model(@root2);
        return root1;
    }
}

pub fn connected(
    ref world: WorldStorage, board_id: felt252, position1: u32, position2: u32,
) -> bool {
    let root1_pos = find(world, board_id, position1);
    let root2_pos = find(world, board_id, position2);
    return root1_pos == root2_pos;
}

#[cfg(test)]
mod tests {
    use dojo::model::ModelStorageTest;
    use super::*;
    use dojo_cairo_test::WorldStorageTestTrait;
    use dojo::model::{ModelStorage};
    use dojo_cairo_test::{spawn_test_world, NamespaceDef, TestResource, ContractDef};

    use evolute_duel::{
        models::{game::{m_Board}, scoring::{m_UnionNode, UnionNode}}, events::{},
        types::packing::{TEdge, PlayerSide},
    };
    use evolute_duel::systems::game::{};

    fn namespace_def() -> NamespaceDef {
        NamespaceDef {
            namespace: "evolute_duel",
            resources: [
                TestResource::Model(m_Board::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_UnionNode::TEST_CLASS_HASH.try_into().unwrap()),
            ]
                .span(),
        }
    }

    fn contract_defs() -> Span<ContractDef> {
        [].span()
    }

    #[test]
    fn test_find() {
        // Initialize test environment
        let ndef = namespace_def();

        // Register the resources.
        let mut world = spawn_test_world([ndef].span());

        // Ensures permissions and initializations are synced.
        world.sync_perms_and_inits(contract_defs());

        let board_id = 0;
        let position = 0;
        world
            .write_model_test(
                @UnionNode {
                    board_id,
                    position,
                    parent: position,
                    rank: 0,
                    blue_points: 0,
                    red_points: 0,
                    open_edges: 0,
                    contested: false,
                    node_type: TEdge::None,
                    player_side: PlayerSide::None,
                },
            );
        let node_pos = find(world, board_id, position);
        let node: UnionNode = world.read_model((board_id, node_pos));
        assert!(node.parent == position, "Position should be the same");
    }
    // #[test]
// fn test_union() {
//     // Initialize test environment
//     let ndef = namespace_def();

    //     // Register the resources.
//     let mut world = spawn_test_world([ndef].span());

    //     // Ensures permissions and initializations are synced.
//     world.sync_perms_and_inits(contract_defs());
//     let board_id = 1;
//     world
//         .write_model(
//             @CityNode {
//                 board_id,
//                 position: 0,
//                 parent: 0,
//                 rank: 1,
//                 blue_points: 1,
//                 red_points: 2,
//                 open_edges: 4,
//                 contested: false,
//             },
//         );
//     world
//         .write_model(
//             @CityNode {
//                 board_id,
//                 position: 1,
//                 parent: 1,
//                 rank: 1,
//                 blue_points: 2,
//                 red_points: 3,
//                 open_edges: 4,
//                 contested: false,
//             },
//         );

    //     let _root = union(ref world, board_id, 0, 1, false);
//     let _root1 = find(ref world, board_id, 0);
//     let _root2 = find(ref world, board_id, 1);
//     assert!(
//         find(ref world, board_id, 0).position == find(ref world, board_id, 1).position,
//         "Position should be the same",
//     );
// }

    // #[test]
// fn test_connected() {
//     // Initialize test environment
//     let ndef = namespace_def();

    //     // Register the resources.
//     let mut world = spawn_test_world([ndef].span());

    //     // Ensures permissions and initializations are synced.
//     world.sync_perms_and_inits(contract_defs());
//     let board_id = 1;
//     world
//         .write_model(
//             @CityNode {
//                 board_id,
//                 position: 0,
//                 parent: 0,
//                 rank: 1,
//                 blue_points: 1,
//                 red_points: 2,
//                 open_edges: 4,
//                 contested: false,
//             },
//         );
//     world
//         .write_model(
//             @CityNode {
//                 board_id,
//                 position: 1,
//                 parent: 1,
//                 rank: 1,
//                 blue_points: 2,
//                 red_points: 3,
//                 open_edges: 4,
//                 contested: false,
//             },
//         );

    //     let _root = union(ref world, board_id, 0, 1, false);
//     let connected = connected(ref world, board_id, 0, 1);
//     assert!(connected, "Nodes should be connected");
// }
}

