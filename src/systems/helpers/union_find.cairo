use evolute_duel::{
    types::packing::UnionNode,
};
use dojo::world::{WorldStorage};
use alexandria_data_structures::vec::{VecTrait, NullableVec};
//Union find
pub fn find(
    ref world: WorldStorage, ref nodes: NullableVec<UnionNode>, position: u8
) -> u8 {
    // println!("[Union find] calles find({}, {})", nodes.len(), position);
    if let Option::Some(node) = nodes.get(position.into()) {
        let mut current = node;
        if current.parent != position {
            current.parent = find(ref world, ref nodes, current.parent);
        }
        current.parent
    } else {
        return panic!("[UnionFind error] Index out of bounds.");
    }
}

pub fn union(
    ref world: WorldStorage, ref nodes: NullableVec<UnionNode>, position1: u8, position2: u8, in_tile: bool,
) -> UnionNode {
    let mut root1_pos: u32 = find(ref world, ref nodes, position1).into();
    let mut root1 = nodes.at(root1_pos);
    let mut root2_pos: u32 = find(ref world, ref nodes, position2).into();
    let mut root2 = nodes.at(root2_pos.into());

    if root1_pos == root2_pos {
        if !in_tile {
            root1.open_edges -= 2;
        }
        nodes.set(root1_pos, root1);
        return root1;
    }
    if root1.rank > root2.rank {
        root2.parent = root1_pos.try_into().unwrap();
        root1.blue_points += root2.blue_points;
        root1.red_points += root2.red_points;
        root1.open_edges += root2.open_edges;
        if !in_tile {
            root1.open_edges -= 2;
        }
        nodes.set(root2_pos, root2);
        nodes.set(root1_pos, root1);
        return root1;
    } else if root1.rank < root2.rank {
        root1.parent = root2_pos.try_into().unwrap();
        root2.blue_points += root1.blue_points;
        root2.red_points += root1.red_points;
        root2.open_edges += root1.open_edges;
        if !in_tile {
            root2.open_edges -= 2;
        }
        nodes.set(root1_pos, root1);
        nodes.set(root2_pos, root2);
        return root2;
    } else {
        root2.parent = root1_pos.try_into().unwrap();
        root1.rank += 1;
        root1.blue_points += root2.blue_points;
        root1.red_points += root2.red_points;
        root1.open_edges += root2.open_edges;
        if !in_tile {
            root1.open_edges -= 2;
        }
        nodes.set(root2_pos, root2);
        nodes.set(root1_pos, root1);
        return root1;
    }
}

pub fn connected(
    ref world: WorldStorage, ref nodes: NullableVec<UnionNode>, position1: u8, position2: u8
) -> bool {
    let root1_pos = find(ref world, ref nodes, position1);
    let root2_pos = find(ref world, ref nodes, position2);
    return root1_pos == root2_pos;
}

// #[cfg(test)]
// mod tests {
//     use super::*;
//     use dojo_cairo_test::WorldStorageTestTrait;
//     use dojo::model::{ModelStorage};
//     use dojo_cairo_test::{spawn_test_world, NamespaceDef, TestResource, ContractDef};

//     use evolute_duel::{models::{m_Board, CityNode, m_CityNode}, events::{}, packing::{}};
//     use evolute_duel::systems::game::{};

//     fn namespace_def() -> NamespaceDef {
//         NamespaceDef {
//             namespace: "evolute_duel",
//             resources: [
//                 TestResource::Model(m_Board::TEST_CLASS_HASH),
//                 TestResource::Model(m_CityNode::TEST_CLASS_HASH),
//             ]
//                 .span(),
//         }
//     }

//     fn contract_defs() -> Span<ContractDef> {
//         [].span()
//     }

//     #[test]
//     fn test_find() {
//         // Initialize test environment
//         let ndef = namespace_def();

//         // Register the resources.
//         let mut world = spawn_test_world([ndef].span());

//         // Ensures permissions and initializations are synced.
//         world.sync_perms_and_inits(contract_defs());

//         let nodes = Felt252Vec::<UnionNode>::new();
//         nodes.push(
//             @UnionNode {
//                 parent: 0,
//                 rank: 0,
//                 blue_points: 0,
//                 red_points: 0,
//                 open_edges: 0,
//                 contested: false,
//             },
//         );
//         let position = 0;
//         let node = find(ref world, board_id, position);
//         assert!(node.parent == position, "Position should be the same");
//     }

//     #[test]
//     fn test_union() {
//         // Initialize test environment
//         let ndef = namespace_def();

//         // Register the resources.
//         let mut world = spawn_test_world([ndef].span());

//         // Ensures permissions and initializations are synced.
//         world.sync_perms_and_inits(contract_defs());
//         let board_id = 1;
//         world
//             .write_model(
//                 @CityNode {
//                     board_id,
//                     position: 0,
//                     parent: 0,
//                     rank: 1,
//                     blue_points: 1,
//                     red_points: 2,
//                     open_edges: 4,
//                     contested: false,
//                 },
//             );
//         world
//             .write_model(
//                 @CityNode {
//                     board_id,
//                     position: 1,
//                     parent: 1,
//                     rank: 1,
//                     blue_points: 2,
//                     red_points: 3,
//                     open_edges: 4,
//                     contested: false,
//                 },
//             );

//         let _root = union(ref world, board_id, 0, 1, false);
//         let _root1 = find(ref world, board_id, 0);
//         let _root2 = find(ref world, board_id, 1);
//         assert!(
//             find(ref world, board_id, 0).position == find(ref world, board_id, 1).position,
//             "Position should be the same",
//         );
//     }

//     #[test]
//     fn test_connected() {
//         // Initialize test environment
//         let ndef = namespace_def();

//         // Register the resources.
//         let mut world = spawn_test_world([ndef].span());

//         // Ensures permissions and initializations are synced.
//         world.sync_perms_and_inits(contract_defs());
//         let board_id = 1;
//         world
//             .write_model(
//                 @CityNode {
//                     board_id,
//                     position: 0,
//                     parent: 0,
//                     rank: 1,
//                     blue_points: 1,
//                     red_points: 2,
//                     open_edges: 4,
//                     contested: false,
//                 },
//             );
//         world
//             .write_model(
//                 @CityNode {
//                     board_id,
//                     position: 1,
//                     parent: 1,
//                     rank: 1,
//                     blue_points: 2,
//                     red_points: 3,
//                     open_edges: 4,
//                     contested: false,
//                 },
//             );

//         let _root = union(ref world, board_id, 0, 1, false);
//         let connected = connected(ref world, board_id, 0, 1);
//         assert!(connected, "Nodes should be connected");
//     }
// }
