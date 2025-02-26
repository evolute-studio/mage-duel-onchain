#[cfg(test)]
mod tests {
    use dojo_cairo_test::WorldStorageTestTrait;
    use dojo::model::{ModelStorage, ModelStorageTest};
    use dojo::world::WorldStorageTrait;
    use dojo_cairo_test::{
        spawn_test_world, NamespaceDef, TestResource, ContractDefTrait, ContractDef,
    };

    use evolute_duel::{models::{Game, m_Game}, events::{}, packing::{GameStatus}};
    use evolute_duel::systems::game::{game, IGameDispatcher, IGameDispatcherTrait};

    fn namespace_def() -> NamespaceDef {
        NamespaceDef {
            namespace: "evolute_duel",
            resources: [
                TestResource::Model(m_Game::TEST_CLASS_HASH),
                TestResource::Contract(game::TEST_CLASS_HASH),
            ]
                .span(),
        }
    }

    fn contract_defs() -> Span<ContractDef> {
        [
            ContractDefTrait::new(@"evolute_duel", @"game")
                .with_writer_of([dojo::utils::bytearray_hash(@"evolute_duel")].span())
        ]
            .span()
    }


    #[test]
    fn test_dict() {
        use core::dict::Felt252Dict;
        let mut dict: Felt252Dict<bool> = Default::default();
        let _check = dict.get(0);
        //println!("{:?}", check);
    }

    #[test]
    fn test_world_test_set() {
        // Initialize test environment
        let caller = starknet::contract_address_const::<0x0>();
        let ndef = namespace_def();

        // Register the resources.
        let mut world = spawn_test_world([ndef].span());

        // Ensures permissions and initializations are synced.
        world.sync_perms_and_inits(contract_defs());

        // Test initial position
        let mut game: Game = world.read_model(caller);
        assert(game.status == GameStatus::Finished, 'initial position wrong');

        // Test write_model_test
        game.status = GameStatus::Created;

        world.write_model_test(@game);

        let mut game: Game = world.read_model(caller);
        assert(game.status == GameStatus::Created, 'write_value_from_id failed');

        // Test model deletion
        world.erase_model(@game);
        let mut game: Game = world.read_model(caller);
        assert(game.status == GameStatus::Finished, 'erase_model failed');
    }

    #[test]
    fn test_game_create() {
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"game").unwrap();
        let game_system = IGameDispatcher { contract_address };

        let initial_game: Game = world.read_model(caller);
        assert(initial_game.status == GameStatus::Finished, 'initial game status is wrong');

        // Create a new game
        game_system.create_game();

        let mut new_game: Game = world.read_model(caller);
        assert(new_game.status == GameStatus::Created, 'game status is wrong');

        //Try to create a new game after one has already been started
        new_game.status = GameStatus::InProgress;
        world.write_model_test(@new_game);
        game_system.create_game();

        let new_game: Game = world.read_model(caller);
        assert(new_game.status == GameStatus::InProgress, 'game status is wrong');
    }

    #[test]
    fn test_game_cancel() {
        let caller = starknet::contract_address_const::<0x0>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"game").unwrap();
        let game_system = IGameDispatcher { contract_address };

        let initial_game: Game = world.read_model(caller);
        assert(initial_game.status == GameStatus::Finished, 'initial game status is wrong');

        // Create a new game
        game_system.create_game();

        let mut new_game: Game = world.read_model(caller);
        assert(new_game.status == GameStatus::Created, 'game status is wrong');

        // Cancel the game
        game_system.cancel_game();

        let new_game: Game = world.read_model(caller);
        assert(new_game.status == GameStatus::Canceled, 'game status is wrong');
    }
    // #[test]
// fn test_game_join() {
//     let host_player = starknet::contract_address_const::<0x0>();
//     let guest_player = starknet::contract_address_const::<0x1>();

    //     testing::set_caller_address(host_player);

    //     let ndef = namespace_def();
//     let mut world = spawn_test_world([ndef].span());
//     world.sync_perms_and_inits(contract_defs());

    //     let (contract_address, _) = world.dns(@"game").unwrap();
//     let game_system = IGameDispatcher { contract_address };

    //     let initial_game: Game = world.read_model(host_player);
//     assert(initial_game.status == GameStatus::Finished, 'initial game status is wrong');

    //     // Create a new game
//     game_system.create_game();

    //     let mut new_game: Game = world.read_model(host_player);
//     assert(new_game.status == GameStatus::Created, 'game status is wrong');

    //     // Make geust_player the caller
//     testing::set_caller_address(guest_player);
//     assert(starknet::get_caller_address() == guest_player, 'set_caller_address failed');
//     assert(guest_player != host_player, 'same player');

    //     let (contract_address, _) = world.dns(@"game").unwrap();
//     let game_system = IGameDispatcher { contract_address };

    //     // Join the game
//     game_system.join_game(host_player);

    //     let new_game: Game = world.read_model(host_player);
//     assert(new_game.status == GameStatus::InProgress, 'game status is wrong');
// }
}
