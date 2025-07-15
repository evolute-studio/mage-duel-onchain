#[cfg(test)]
#[allow(unused_imports)]
mod tests {
    use dojo_cairo_test::WorldStorageTestTrait;
    use dojo::model::{ModelStorage, ModelStorageTest};
    use dojo::world::WorldStorageTrait;
    use dojo_cairo_test::{
        spawn_test_world, NamespaceDef, TestResource, ContractDefTrait, ContractDef,
    };
    use dojo::world::WorldStorage;

    use evolute_duel::{
        models::{
            game::{
                Game, m_Game, Board, m_Board, Move, m_Move, Rules, m_Rules,
                TileCommitments, m_TileCommitments, AvailableTiles, m_AvailableTiles,
            },
            scoring::{UnionNode, m_UnionNode, PotentialContests, m_PotentialContests}, player::{Player, m_Player}, skins::{Shop, m_Shop},
        },
        events::{
            SnapshotCreated, e_SnapshotCreated, SnapshotCreateFailed, e_SnapshotCreateFailed,
            BoardUpdated, e_BoardUpdated, Moved, e_Moved, Skiped, e_Skiped, InvalidMove,
            e_InvalidMove, GameFinished, e_GameFinished, GameStarted, e_GameStarted, GameCreated,
            e_GameCreated, GameCreateFailed, e_GameCreateFailed, GameJoinFailed, e_GameJoinFailed,
            GameCanceled, e_GameCanceled, GameCanceleFailed, e_GameCanceleFailed, PlayerNotInGame,
            e_PlayerNotInGame, NotYourTurn, e_NotYourTurn, NotEnoughJokers, e_NotEnoughJokers,
            CityContestWon, e_CityContestWon, CityContestDraw, e_CityContestDraw, RoadContestWon,
            e_RoadContestWon, RoadContestDraw, e_RoadContestDraw, PlayerUsernameChanged,
            e_PlayerUsernameChanged, PlayerSkinChanged, e_PlayerSkinChanged, PlayerSkinChangeFailed,
            e_PlayerSkinChangeFailed, PhaseStarted, e_PhaseStarted,
        },
        types::packing::{GameStatus, GameState},
        systems::{
            helpers::board::{BoardTrait}, game::{game, IGameDispatcher, IGameDispatcherTrait},
            player_profile_actions::{
                player_profile_actions, IPlayerProfileActionsDispatcher,
                IPlayerProfileActionsDispatcherTrait,
            },
        },
        tests::test_helpers::game_caller::{
            GameCallerTrait, GameType,
        },
    };
    use starknet::{testing, ContractAddress};

    fn namespace_def() -> NamespaceDef {
        let ndef = NamespaceDef {
            namespace: "evolute_duel",
            resources: [
                TestResource::Model(m_Game::TEST_CLASS_HASH),
                TestResource::Model(m_Board::TEST_CLASS_HASH),
                TestResource::Model(m_Move::TEST_CLASS_HASH),
                TestResource::Model(m_Rules::TEST_CLASS_HASH),
                TestResource::Model(m_UnionNode::TEST_CLASS_HASH),
                TestResource::Model(m_PotentialContests::TEST_CLASS_HASH),
                TestResource::Model(m_TileCommitments::TEST_CLASS_HASH),
                TestResource::Model(m_AvailableTiles::TEST_CLASS_HASH),
                TestResource::Model(m_Player::TEST_CLASS_HASH),
                TestResource::Model(m_Shop::TEST_CLASS_HASH),
                TestResource::Event(e_SnapshotCreated::TEST_CLASS_HASH),
                TestResource::Event(e_SnapshotCreateFailed::TEST_CLASS_HASH),
                TestResource::Event(e_BoardUpdated::TEST_CLASS_HASH),
                TestResource::Event(e_Moved::TEST_CLASS_HASH),
                TestResource::Event(e_Skiped::TEST_CLASS_HASH),
                TestResource::Event(e_InvalidMove::TEST_CLASS_HASH),
                TestResource::Event(e_GameFinished::TEST_CLASS_HASH),
                TestResource::Event(e_GameStarted::TEST_CLASS_HASH),
                TestResource::Event(e_GameCreated::TEST_CLASS_HASH),
                TestResource::Event(e_GameCreateFailed::TEST_CLASS_HASH),
                TestResource::Event(e_GameJoinFailed::TEST_CLASS_HASH),
                TestResource::Event(e_GameCanceled::TEST_CLASS_HASH),
                TestResource::Event(e_GameCanceleFailed::TEST_CLASS_HASH),
                TestResource::Event(e_PlayerNotInGame::TEST_CLASS_HASH),
                TestResource::Event(e_NotYourTurn::TEST_CLASS_HASH),
                TestResource::Event(e_NotEnoughJokers::TEST_CLASS_HASH),
                TestResource::Event(e_CityContestWon::TEST_CLASS_HASH),
                TestResource::Event(e_CityContestDraw::TEST_CLASS_HASH),
                TestResource::Event(e_RoadContestWon::TEST_CLASS_HASH),
                TestResource::Event(e_RoadContestDraw::TEST_CLASS_HASH),
                TestResource::Event(e_PlayerUsernameChanged::TEST_CLASS_HASH),
                TestResource::Event(e_PlayerSkinChanged::TEST_CLASS_HASH),
                TestResource::Event(e_PlayerSkinChangeFailed::TEST_CLASS_HASH),
                TestResource::Event(e_PhaseStarted::TEST_CLASS_HASH),
                TestResource::Event(
                    achievement::events::index::e_TrophyCreation::TEST_CLASS_HASH
                        .try_into()
                        .unwrap(),
                ),
                TestResource::Event(
                    achievement::events::index::e_TrophyProgression::TEST_CLASS_HASH
                        .try_into()
                        .unwrap(),
                ),
                TestResource::Contract(game::TEST_CLASS_HASH),
                TestResource::Contract(player_profile_actions::TEST_CLASS_HASH),
            ]
                .span(),
        };

        ndef
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
        world.erase_model_test(@game);
        let mut game: Game = world.read_model(caller);
        assert(game.status == GameStatus::Finished, 'erase_model failed');
    }

    #[test]
    fn test_game_create() {
        let caller = starknet::contract_address_const::<'caller1'>();
        testing::set_contract_address(caller);
        assert(starknet::get_contract_address() == caller, 'set_contract_address failed');

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"game").unwrap();
        let game_system = IGameDispatcher { contract_address };

        let initial_game: Game = world.read_model(caller);
        assert(initial_game.status == GameStatus::Finished, 'initial game status is wrong');
        println!("Initial game: {:?}", initial_game);

        // Create a new game
        game_system.create_game();

        let mut new_game: Game = world.read_model(caller);
        assert(new_game.status == GameStatus::Created, 'game status is wrong');
        // //Try to create a new game after one has already been started
    // new_game.status = GameStatus::InProgress;
    // world.write_model_test(@new_game);
    // game_system.create_game();

        // let new_game: Game = world.read_model(caller);
    // assert(new_game.status == GameStatus::InProgress, 'game status is wrong');
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
    #[test]
    fn test_game_join() {
        let host_player = starknet::contract_address_const::<0x0>();
        let guest_player = starknet::contract_address_const::<0x1>();

        starknet::testing::set_contract_address(host_player);

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"game").unwrap();
        let game_system = IGameDispatcher { contract_address };

        let initial_game: Game = world.read_model(host_player);
        assert(initial_game.status == GameStatus::Finished, 'initial game status is wrong');

        // Create a new game
        game_system.create_game();

        let mut new_game: Game = world.read_model(host_player);
        assert(new_game.status == GameStatus::Created, 'game status is wrong');

        // Make geust_player the caller
        starknet::testing::set_contract_address(guest_player);
        assert(guest_player != host_player, 'same player');

        // Join the game
        game_system.join_game(host_player);

        let game1: Game = world.read_model(host_player);
        let game2: Game = world.read_model(guest_player);
        assert(game1.status == GameStatus::InProgress, 'game status is wrong');
        assert(game2.status == GameStatus::InProgress, 'game status is wrong');

        // println!("Game1: {:?}", game1);
        // println!("Game2: {:?}", game2);
        // println!("Board: {:?}", board);
    }

    fn move(
        game_system: IGameDispatcher,
        caller: ContractAddress,
        joker_tile: Option<u8>,
        rotation: u8,
        col: u8,
        row: u8,
    ) {
        starknet::testing::set_contract_address(caller);
        game_system.make_move(joker_tile, rotation, col, row);
    }

    fn skip(game_system: IGameDispatcher, caller: ContractAddress) {
        starknet::testing::set_contract_address(caller);
        game_system.skip_move();
    }

    // fn make_multiple_moves(
    //     ref world: WorldStorage,
    //     game_system: IGameDispatcher,
    //     player1: ContractAddress,
    //     player2: ContractAddress,
    //     moves: Array<(bool, Option<u8>, u8, u8, u8)>,
    //     moves_number: Option<u32>,
    //     move_for_snapshot: Option<u8>,
    // ) -> Board {
    //     let moves_number = match moves_number {
    //         Option::None => moves.len(),
    //         Option::Some(num) => num,
    //     };
    //     if moves_number.into() > moves.len() {
    //         return panic!("move_number is greater than moves length");
    //     }
    //     use evolute_duel::types::packing::{GameState, PlayerSide};
    //     let mut board_for_snapshot = Board {
    //         id: 0,
    //         initial_edge_state: array![].span(),
    //         available_tiles_in_deck: array![],
    //         top_tile: Option::None,
    //         state: array![],
    //         player1: (player1, PlayerSide::Blue, 3),
    //         player2: (player2, PlayerSide::Red, 3),
    //         blue_score: (0, 0),
    //         red_score: (0, 0),
    //         last_move_id: Option::None,
    //         moves_done: 0,
    //         game_state: GameState::Creating,
    //         last_update_timestamp: 0,
    //         commited_tile: Option::None,
    //         phase_started_at: 0,
    //     };

    //     for i in 0..moves_number {
    //         let (is_move, joker_tile, rotation, col, row) = *moves.at(i);
    //         let player = if i % 2 == 0 {
    //             player1
    //         } else {
    //             player2
    //         };
    //         if is_move {
    //             move(game_system, player, joker_tile, rotation, col, row);
    //         } else {
    //             skip(game_system, player);
    //         }
    //         let board: Board = world.read_model(0);
    //         println!("\n{i}. Board: {:?}", board);
    //         if move_for_snapshot.is_some() && move_for_snapshot.unwrap().into() == i + 1 {
    //             board_for_snapshot = board;
    //         }
    //     };
    //     board_for_snapshot
    // }

    #[test]
    #[ignore]
    #[available_gas(429465835234324)]
    fn test_game_move() {
        let host_player = starknet::contract_address_const::<0x0>();
        let guest_player = starknet::contract_address_const::<0x1>();
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"game").unwrap();
        let mut game_caller = GameCallerTrait::new(
            world, contract_address, host_player, guest_player, GameType::Standard,
        );

        let initial_game: Game = world.read_model(host_player);
        assert(initial_game.status == GameStatus::Finished, 'initial game status is wrong');

        // Create a new game
        game_caller.create_game();

        let mut new_game: Game = world.read_model(host_player);
        assert(new_game.status == GameStatus::Created, 'game status is wrong');

        // Join the game
        game_caller.join_game();
        println!("Game created and joined");
        game_caller.commit_tiles();

        let game1: Game = world.read_model(host_player);

        let board_id = game1.board_id.unwrap();

        let board: Board = world.read_model(board_id);

        println!("Board: {:?}", board);

        // // Make moves
        // //(joker_tile, rotation, col, row)
        // let moves = array![
        //     (Option::None, 1, 0, 7),
        //     (Option::None, 1, 0, 0),
        //     (Option::None, 3, 0, 1),
        //     (Option::None, 1, 1, 1),
        //     (Option::None, 1, 6, 0),
        //     (Option::None, 3, 1, 2),
        //     (Option::None, 1, 2, 2),
        //     (Option::None, 2, 1, 3),
        //     (Option::None, 1, 0, 6),
        //     (Option::None, 1, 0, 5),
        //     (Option::None, 1, 2, 3),
        //     (Option::None, 3, 0, 4),
        //     (Option::None, 2, 0, 3),
        //     (Option::None, 3, 1, 6),
        //     (Option::Some(10), 2, 0, 2),
        //     (Option::None, 2, 1, 5),
        // ];
        // game_caller.process_multiple_moves(moves);

        // Make automated moves
        game_caller.process_auto_multiple_moves(45);

        let board: Board = world.read_model(board_id);
        println!("Board: {:?}", board);
    }
}

