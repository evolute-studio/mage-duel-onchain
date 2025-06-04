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
            game::{Game, m_Game, Board, m_Board, Move, m_Move, Rules, m_Rules, Snapshot, m_Snapshot, TileCommitments, m_TileCommitments, AvailableTiles, m_AvailableTiles,},
            scoring::{UnionFind, m_UnionFind,},
            player::{ Player, m_Player,},
            skins::{Shop, m_Shop,},
        },
        events::{
            BoardCreated, e_BoardCreated, BoardCreatedFromSnapshot, e_BoardCreatedFromSnapshot,
            BoardCreateFromSnapshotFalied, e_BoardCreateFromSnapshotFalied, SnapshotCreated,
            e_SnapshotCreated, SnapshotCreateFailed, e_SnapshotCreateFailed, BoardUpdated,
            e_BoardUpdated, RulesCreated, e_RulesCreated, Moved, e_Moved, Skiped, e_Skiped,
            InvalidMove, e_InvalidMove, GameFinished, e_GameFinished, GameStarted, e_GameStarted,
            GameCreated, e_GameCreated, GameCreateFailed, e_GameCreateFailed, GameJoinFailed,
            e_GameJoinFailed, GameCanceled, e_GameCanceled, GameCanceleFailed, e_GameCanceleFailed,
            PlayerNotInGame, e_PlayerNotInGame, NotYourTurn, e_NotYourTurn, NotEnoughJokers,
            e_NotEnoughJokers, GameIsAlreadyFinished, e_GameIsAlreadyFinished, CantFinishGame,
            e_CantFinishGame, CityContestWon, e_CityContestWon, CityContestDraw, e_CityContestDraw,
            RoadContestWon, e_RoadContestWon, RoadContestDraw, e_RoadContestDraw,
            CurrentPlayerBalance, e_CurrentPlayerBalance, CurrentPlayerUsername,
            e_CurrentPlayerUsername, CurrentPlayerActiveSkin, e_CurrentPlayerActiveSkin,
            PlayerUsernameChanged, e_PlayerUsernameChanged, PlayerSkinChanged, e_PlayerSkinChanged,
            PlayerSkinChangeFailed, e_PlayerSkinChangeFailed, PhaseStarted, e_PhaseStarted,
        },
        packing::{GameStatus},
        systems::{
            helpers::board::{create_board},
            game::{game, IGameDispatcher, IGameDispatcherTrait},
            player_profile_actions::{
                player_profile_actions, IPlayerProfileActionsDispatcher,
                IPlayerProfileActionsDispatcherTrait,
            },
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
                TestResource::Model(m_Snapshot::TEST_CLASS_HASH),
                TestResource::Model(m_UnionFind::TEST_CLASS_HASH),
                TestResource::Model(m_TileCommitments::TEST_CLASS_HASH),
                TestResource::Model(m_AvailableTiles::TEST_CLASS_HASH),
                TestResource::Model(m_Player::TEST_CLASS_HASH),
                TestResource::Model(m_Shop::TEST_CLASS_HASH),
                TestResource::Event(e_BoardCreated::TEST_CLASS_HASH),
                TestResource::Event(e_BoardCreatedFromSnapshot::TEST_CLASS_HASH),
                TestResource::Event(e_BoardCreateFromSnapshotFalied::TEST_CLASS_HASH),
                TestResource::Event(e_SnapshotCreated::TEST_CLASS_HASH),
                TestResource::Event(e_SnapshotCreateFailed::TEST_CLASS_HASH),
                TestResource::Event(e_BoardUpdated::TEST_CLASS_HASH),
                TestResource::Event(e_RulesCreated::TEST_CLASS_HASH),
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
                TestResource::Event(e_GameIsAlreadyFinished::TEST_CLASS_HASH),
                TestResource::Event(e_CantFinishGame::TEST_CLASS_HASH),
                TestResource::Event(e_CityContestWon::TEST_CLASS_HASH),
                TestResource::Event(e_CityContestDraw::TEST_CLASS_HASH),
                TestResource::Event(e_RoadContestWon::TEST_CLASS_HASH),
                TestResource::Event(e_RoadContestDraw::TEST_CLASS_HASH),
                TestResource::Event(e_CurrentPlayerBalance::TEST_CLASS_HASH),
                TestResource::Event(e_CurrentPlayerUsername::TEST_CLASS_HASH),
                TestResource::Event(e_CurrentPlayerActiveSkin::TEST_CLASS_HASH),
                TestResource::Event(e_PlayerUsernameChanged::TEST_CLASS_HASH),
                TestResource::Event(e_PlayerSkinChanged::TEST_CLASS_HASH),
                TestResource::Event(e_PlayerSkinChangeFailed::TEST_CLASS_HASH),
                TestResource::Event(e_PhaseStarted::TEST_CLASS_HASH),
                TestResource::Event(achievement::events::index::e_TrophyCreation::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Event(achievement::events::index::e_TrophyProgression::TEST_CLASS_HASH.try_into().unwrap()),
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
        let mut board: Board = world.read_model(game1.board_id.unwrap());
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

    fn skip(
        game_system: IGameDispatcher,
        caller: ContractAddress,
    ) {
        starknet::testing::set_contract_address(caller);
        game_system.skip_move();
    }

    fn make_multiple_moves(
        ref world: WorldStorage,
        game_system: IGameDispatcher,
        player1: ContractAddress,
        player2: ContractAddress,
        moves: Array<(bool, Option<u8>, u8, u8, u8)>,
        moves_number: Option<u32>,
        move_for_snapshot: Option<u8>,
    ) -> Board {
        let moves_number = match moves_number {
            Option::None => moves.len(),
            Option::Some(num) => num,
        };
        if moves_number.into() > moves.len() {
            return println!("move_number is greater than moves length");
        }
        use evolute_duel::packing::{
            GameState,
            PlayerSide,
        };
        let mut board_for_snapshot = Board {
            id: 0,
            initial_edge_state: array![].span(),
            available_tiles_in_deck: array![],
            top_tile: Option::None,
            state: array![],
            player1: (player1, PlayerSide::Blue, 3),
            player2: (player2, PlayerSide::Red, 3),
            blue_score: (0, 0),
            red_score: (0, 0),
            last_move_id: Option::None,
            moves_done: 0,
            game_state: GameState::InProgress,
            last_update_timestamp: 0,
        };
            
        for i in 0..moves_number {
            let (is_move, joker_tile, rotation, col, row) = *moves.at(i);
            let player = if i % 2 == 0 {
                player1
            } else {
                player2
            };
            if is_move {
                move(game_system, player, joker_tile, rotation, col, row);
            } else {
                skip(game_system, player);
            }
            let board: Board = world.read_model(0);
            println!("\n{i}. Board: {:?}", board);
            if move_for_snapshot.is_some() && move_for_snapshot.unwrap().into() == i + 1 {
                board_for_snapshot = board;
            }
        };
        board_for_snapshot
    }

    #[test]
    fn test_game_move() {
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

        let board_id = game1.board_id.unwrap();

        let board: Board = world.read_model(board_id);

        println!("Board: {:?}", board);

        starknet::testing::set_contract_address(host_player);
        // Make moves
        //(joker_tile, rotation, col, row)
        let moves = array![
            (true, Option::None, 1, 0, 7),
            (true, Option::None, 1, 0, 0),
            (true, Option::None, 3, 0, 1),
            (true, Option::None, 1, 1, 1),
            (true, Option::None, 1, 6, 0),
            (true, Option::None, 3, 1, 2),
            (true, Option::None, 1, 2, 2),
            (true, Option::None, 2, 1, 3),
            (true, Option::None, 1, 0, 6),
            (true, Option::None, 1, 0, 5),
            (true, Option::None, 1, 2, 3),
            (true, Option::None, 3, 0, 4),
            (true, Option::None, 2, 0, 3),
            (true, Option::None, 3, 1, 6),
            (true, Option::Some(10), 2, 0, 2),
            (true, Option::None, 2, 1, 5),
            
        ];
        make_multiple_moves(ref world, game_system, host_player, guest_player, moves, Option::None, Option::None);

        let board: Board = world.read_model(board_id);
        println!("Board: {:?}", board);
    }

    #[test]
    #[available_gas(429465835234324)]
    fn test_snapshot() {
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

        starknet::testing::set_contract_address(host_player);
        // Make moves
        //(joker_tile, rotation, col, row)
        let moves = array![
            (true, Option::None, 1, 0, 7),
            (true, Option::None, 1, 0, 0),
            (true, Option::None, 3, 0, 1),
            (true, Option::None, 1, 1, 1),
        ];
        make_multiple_moves(ref world, game_system, host_player, guest_player, moves, Option::None, Option::None);

        let board_on_4th_move: Board = world.read_model(game1.board_id.unwrap());
        println!("Board after 4th move: {:?}", board_on_4th_move);

        let moves = array![
            (true, Option::None, 1, 6, 0),
            (true, Option::None, 3, 1, 2),
            (true, Option::None, 1, 2, 2),
            (true, Option::None, 2, 1, 3),
            (true, Option::None, 1, 0, 6),
            (true, Option::None, 1, 0, 5),
            (true, Option::None, 1, 2, 3),
            (true, Option::None, 3, 0, 4),
            (true, Option::None, 2, 0, 3),
            (true, Option::None, 3, 1, 6),
            (true, Option::Some(10), 2, 0, 2),
            (true, Option::None, 2, 1, 5),
        ];

        let board_on_16th_move: Board = world.read_model(game1.board_id.unwrap());
        println!("Board before 16th move: {:?}", board_on_16th_move);

        make_multiple_moves(ref world, game_system, host_player, guest_player, moves, Option::None, Option::None);

        let board_id = game1.board_id.unwrap();
        let board: Board = world.read_model(board_id);
        println!("Board: {:?}", board);

        // Cancel the game
        game_system.cancel_game();

        // Create a snapshot
        starknet::testing::set_contract_address(host_player);
        game_system.create_snapshot(board_id, 16);
        let snapshot: Snapshot = world.read_model(board_id);
        println!("Snapshot: {:?}", snapshot);

        // Create a new game from snapshot
        game_system.create_game_from_snapshot(0);

        let mut new_game: Game = world.read_model(host_player);
        assert(new_game.status == GameStatus::Created, 'game status is wrong');
        let new_board_id = new_game.board_id.unwrap();
        let new_board: Board = world.read_model(new_board_id);
        println!("New Board: {:?}", new_board);
        assert(new_board.state == board.state, 'state is not the same');
        assert(new_board.blue_score == board.blue_score, 'blue_score is not the same');
        assert(new_board.red_score == board.red_score, 'red_score is not the same');
    }

    #[test]
    #[available_gas(429465835234324)]
    fn full_game() {
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

        let board_id = game1.board_id.unwrap();

        let board: Board = world.read_model(board_id);

        println!("Board: {:?}", board);

        starknet::testing::set_contract_address(host_player);
        // Make moves
        //(joker_tile, rotation, col, row)
        //moves tooked from comment above the test backwards
        let moves = array![
            (true, Option::None, 2, 0, 0),
            (true, Option::None, 2, 0, 7),
            (true, Option::None, 1, 1, 0),
            (true, Option::None, 0, 1, 7),
            (true, Option::None, 1, 2, 0),
            (true, Option::None, 1, 1, 6),
            (true, Option::None, 1, 1, 1),
            (true, Option::None, 2, 0, 6),
            (true, Option::None, 3, 1, 2),
            (true, Option::None, 2, 0, 2),
            (true, Option::None, 1, 2, 2),
            (true, Option::None, 3, 0, 3),
            (true, Option::None, 1, 2, 3),
            (true, Option::None, 0, 0, 5),
            (true, Option::None, 2, 3, 0),
            (true, Option::None, 0, 2, 6),
            (true, Option::None, 1, 2, 4),
            (true, Option::None, 0, 1, 5),
            (true, Option::None, 2, 2, 7),
            (true, Option::None, 1, 3, 6),
            (true, Option::None, 1, 3, 1),
            (true, Option::None, 0, 3, 5),
            (true, Option::None, 2, 4, 0),
            (true, Option::None, 3, 4, 6),
            (true, Option::None, 1, 4, 1),
            (true, Option::None, 1, 4, 5),
            (true, Option::None, 1, 5, 0),
            (true, Option::None, 1, 3, 7),
            (true, Option::None, 0, 3, 3),
            (true, Option::None, 3, 4, 2),
            (true, Option::None, 1, 4, 4),
            (true, Option::None, 3, 4, 7),
            (true, Option::None, 2, 5, 2),
            (true, Option::None, 3, 5, 7),
            (true, Option::None, 1, 5, 4),
            (true, Option::None, 1, 1, 4),
            (true, Option::None, 3, 6, 4),
            (true, Option::None, 2, 6, 3),
            (true, Option::None, 2, 6, 0),
            (true, Option::Some(19), 0, 2, 5),
            (true, Option::None, 1, 6, 1),
            (true, Option::None, 1, 6, 5),
            (true, Option::None, 3, 5, 3),
            (true, Option::Some(5), 2, 0, 4),
            (true, Option::None, 2, 6, 2),
            (true, Option::None, 3, 7, 5),
            (true, Option::None, 1, 4, 3),
            (true, Option::None, 2, 6, 6),
            (true, Option::None, 1, 7, 1),
            (true, Option::None, 1, 7, 3),
            (true, Option::None, 1, 5, 5),
            (true, Option::Some(5), 0, 7, 6),
            (true, Option::Some(23), 2, 2, 1),
            //skip todo
            (false, Option::None, 0, 0, 0),
            (true, Option::None, 0, 7, 2),
            (true, Option::None, 2, 7, 7),
            (true, Option::Some(10), 0, 3, 2),
            //skip todo
            (false, Option::None, 0, 0, 0),
            (true, Option::Some(15), 1, 3, 4),
            //skip todo
            (false, Option::None, 0, 0, 0),
            //skip todo
            (false, Option::None, 0, 0, 0),
        ];
        let move_for_snapshot = 57;
        let board = make_multiple_moves(ref world, game_system, host_player, guest_player, moves, Option::None, Option::Some(move_for_snapshot));

        // Cancel the game
        game_system.cancel_game();

        // Create a snapshot
        starknet::testing::set_contract_address(host_player);
        game_system.create_snapshot(board_id, move_for_snapshot);
        let snapshot: Snapshot = world.read_model(board_id);
        println!("Snapshot: {:?}", snapshot);

        // Create a new game from snapshot
        game_system.create_game_from_snapshot(0);

        let mut new_game: Game = world.read_model(host_player);
        assert(new_game.status == GameStatus::Created, 'game status is wrong');
        let new_board_id = new_game.board_id.unwrap();
        let new_board: Board = world.read_model(new_board_id);
        println!("New Board: {:?}", new_board);
        assert(new_board.state == board.state, 'state is not the same');
        assert(new_board.blue_score == board.blue_score, 'blue_score is not the same');
        assert(new_board.red_score == board.red_score, 'red_score is not the same');
    }

    use origami_random::deck::{Deck, DeckTrait};
    use evolute_duel::utils::hash::hash_values;
    use evolute_duel::packing::{GameState};
    use evolute_duel::systems::helpers::tile_helpers::{create_extended_tile};
    fn generate_permutation(
        n: u8, player_address: ContractAddress,
    ) -> Array<u8> {
       let mut deck = DeckTrait::new(player_address.into(), n.into());
        let mut permutation = array![];
        for _ in 0..n {
            let tile = deck.draw() - 1; // Convert to 0-based index
            permutation.append(tile);
        };
        permutation
    }

    fn generate_nonces(
        n: u8, player_address: ContractAddress,
    ) -> Array<felt252> {
        let mut deck = DeckTrait::new(player_address.into() + n.into(), n.into());
        let mut nonces = array![];
        for _ in 0..n {
            let nonce = deck.draw() - 1; // Convert to 0-based index
            nonces.append(hash_values(array![nonce.into()].span()));
        };
        nonces
    }

    fn generate_commitments(
        n: u8, nonces: Array<felt252>, permutation: Array<u8>
    ) -> Array<felt252> {
        let mut commitments = array![];
        for i in 0..n {
            let commitment = hash_values(array![i.into(), (*nonces.at(i.into())).into(), (*permutation.at(i.into())).into()].span());
            commitments.append(commitment);
        };
        commitments
    }

    fn find_tile_to_reveal(c: u8, permutation: Array<u8>, nonces: Array<felt252>) -> u8{
        let mut result = 65;
        for i in 0..permutation.len() {
            if *permutation.at(i) == c {
                result = i;
            }
        };
        assert(result < 65, 'Tile not found in permutation');
        result.try_into().unwrap()
    }

    #[test]
    #[available_gas(429465835234324)]
    fn test_reveal_commit() {
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

        println!("Initial Game: {:?}", initial_game);
        // Create a new game
        game_system.create_game();

        let mut new_game: Game = world.read_model(host_player);
        assert(new_game.status == GameStatus::Created, 'game status is wrong');
        println!("New Game: {:?}", new_game);
        // Make geust_player the caller
        starknet::testing::set_contract_address(guest_player);
        assert(guest_player != host_player, 'same player');

        // Join the game
        game_system.join_game(host_player);

        let game1: Game = world.read_model(host_player);
        let game2: Game = world.read_model(guest_player);
        assert!(game1.status == GameStatus::Created, "game status is wrong: {:?}", game1.status);
        assert!(game2.status == GameStatus::Created, "game status is wrong: {:?}", game2.status);

        let board_id = game1.board_id.unwrap();

        let board: Board = world.read_model(board_id);

        println!("Board: {:?}", board);

        starknet::testing::set_contract_address(host_player);

        let first_player_permutation = generate_permutation(64, host_player);
        let first_player_nonces = generate_nonces(64, host_player);
        let first_player_commitments = generate_commitments(
            64, first_player_nonces.clone(), first_player_permutation.clone()
        );

        // println!("First Player Permutation: {:?}", first_player_permutation);
        // println!("First Player Nonces: {:?}", first_player_nonces);
        game_system.commit_tiles(
            first_player_commitments.span()
        );

        let first_player_commitments_model: TileCommitments = world.read_model((board_id, host_player));
        // println!("First Player Commitments: {:?}", first_player_commitments_model);

        starknet::testing::set_contract_address(guest_player);
        let second_player_permutation = generate_permutation(64, guest_player);
        let second_player_nonces = generate_nonces(64, guest_player);
        let second_player_commitments = generate_commitments(
            64, second_player_nonces.clone(), second_player_permutation.clone()
        );
        // println!("Second Player Permutation: {:?}", second_player_permutation);
        // println!("Second Player Nonces: {:?}", second_player_nonces);
        game_system.commit_tiles(
            second_player_commitments.span()
        );
        let second_player_commitments_model: TileCommitments = world.read_model((board_id, guest_player));
        // println!("Second Player Commitments: {:?}", second_player_commitments_model);

        let game1: Game = world.read_model(host_player);
        let game2: Game = world.read_model(guest_player);
        assert!(game1.status == GameStatus::InProgress, "game status is wrong: {:?}", game1.status);
        assert!(game2.status == GameStatus::InProgress, "game status is wrong: {:?}", game2.status);


        // Reveal the first player's tile
        starknet::testing::set_contract_address(host_player);
        let board: Board = world.read_model(board_id);
        let commited_tile = board.commited_tile.unwrap();
        println!("Committed Tile on the board: {:?}", commited_tile);
        let tile_to_reveal = find_tile_to_reveal(commited_tile, first_player_permutation.clone(), first_player_nonces.clone());
        
        let tile = tile_to_reveal;
        let nonce = *first_player_nonces.at(tile_to_reveal.into());
        let c = *first_player_permutation.at(tile_to_reveal.into());
        println!("Revealing tile: {:?}, nonce: {:?}, c: {:?}", tile, nonce, c);
        assert!(hash_values(array![tile.into(), nonce.into(), c.into()].span()) == *first_player_commitments.at(tile.into()), "Commitment does not match");
        game_system.reveal_tile(
            tile.into(), nonce, c
        );

        let board: Board = world.read_model(board_id);
        let top_tile = board.top_tile.unwrap();
        let commited_tile = board.commited_tile;
        assert!(top_tile == *board.available_tiles_in_deck.at(tile.into()), "Top tile is not the same as commited tile");
        assert!(commited_tile.is_none(), "Committed tile should be None after reveal");

        // Reveal the second player's tile
        starknet::testing::set_contract_address(guest_player);
        let nonce = *second_player_nonces.at(tile_to_reveal.into());
        let c = *second_player_permutation.at(tile_to_reveal.into());
        println!("Revealing tile: {:?}, nonce: {:?}, c: {:?}", tile, nonce, c);
        assert!(hash_values(array![tile.into(), nonce.into(), c.into()].span()) == *second_player_commitments.at(tile.into()), "Commitment does not match");
        let next_commitment = game_system.request_next_tile(
            tile.into(), nonce, c
        );
        println!("Next commitment: {:?}", next_commitment);

        let board: Board = world.read_model(board_id);
        let game_state = board.game_state;
        assert!(game_state == GameState::Move, "Game state is not 1 after reveal");

        // Check the top tile
        let top_tile = board.top_tile.unwrap();
        let expected_top_tile = *board.available_tiles_in_deck.at(tile.into());
        assert!(top_tile == expected_top_tile, "Top tile is not the same as expected");
        println!("Top tile after reveal: {:?}", top_tile);

        //Extended tile
        let extended_tile = create_extended_tile(top_tile.into(), 0);
        println!("Extended Tile: {:?}", extended_tile);
        println!("Board state: {:?}", board.state);
        println!("Board initial edge state: {:?}", board.initial_edge_state);

        let moves = array![
            (Option::None, 1, 0, 7),
            (Option::None, 1, 0, 0),
            (Option::None, 3, 0, 1),
            (Option::None, 1, 1, 1),
            (Option::None, 1, 6, 0),
            (Option::None, 3, 1, 2),
            (Option::None, 1, 2, 2),
            (Option::None, 2, 1, 3),
            (Option::None, 1, 0, 6),
            (Option::None, 1, 0, 5),
            (Option::None, 1, 2, 3),
            (Option::None, 3, 0, 4),
            (Option::None, 2, 0, 3),
            (Option::None, 3, 1, 6),
            (Option::Some(10), 2, 0, 2),
            (Option::None, 2, 1, 5),
        ];

        // Move by the host player
        starknet::testing::set_contract_address(host_player);
        let rotation = 0;
        let col = 7;
        let row = 0;
        game_system.make_move(
            Option::None, rotation, col, row,
        );

        let tile_to_reveal = find_tile_to_reveal(next_commitment.unwrap(), second_player_permutation.clone(), second_player_nonces.clone());
        let tile = tile_to_reveal;
        let nonce = *second_player_nonces.at(tile_to_reveal.into());
        let c = *second_player_permutation.at(tile_to_reveal.into());
        println!("Revealing tile: {:?}, nonce: {:?}, c: {:?}", tile, nonce, c);
        assert!(hash_values(array![tile.into(), nonce.into(), c.into()].span()) == *second_player_commitments.at(tile.into()), "Commitment does not match");
        
        starknet::testing::set_contract_address(guest_player);
        game_system.reveal_tile(
            tile.into(), nonce, c
        );


        let board: Board = world.read_model(board_id);
        let top_tile = board.top_tile.unwrap();
        println!("Top tile after second reveal: {:?}", top_tile);
        let expected_top_tile = *board.available_tiles_in_deck.at(tile.into());
        assert!(top_tile == expected_top_tile, "Top tile is not the same as expected after second reveal");

        let extended_tile = create_extended_tile(top_tile.into(), 0);
        println!("Extended Top Tile: {:?}", extended_tile);

        starknet::testing::set_contract_address(host_player);
        let nonce = *first_player_nonces.at(tile_to_reveal.into());
        let c = *first_player_permutation.at(tile_to_reveal.into());
        println!("Revealing tile: {:?}, nonce: {:?}, c: {:?}", tile, nonce, c);
        assert!(hash_values(array![tile.into(), nonce.into(), c.into()].span()) == *first_player_commitments.at(tile.into()), "Commitment does not match");
        let next_commitment = game_system.request_next_tile(
            tile.into(), nonce, c
        );
        println!("Next commitment: {:?}", next_commitment);

        let board: Board = world.read_model(board_id);
        let game_state = board.game_state;
        assert!(game_state == GameState::Move, "Game state is not 1 after second reveal");

        // Check the top tile
        let top_tile = board.top_tile.unwrap();
        let expected_top_tile = *board.available_tiles_in_deck.at(tile.into());
        assert!(top_tile == expected_top_tile, "Top tile is not the same as expected after second reveal");
        println!("Top tile after second reveal: {:?}", top_tile);
        let extended_tile = create_extended_tile(top_tile.into(), 0);
        println!("Extended Tile after second reveal: {:?}", extended_tile);

        // Move by the guest player
        starknet::testing::set_contract_address(guest_player);
        let rotation = 1;
        let col = 0;
        let row = 1;
        game_system.make_move(
            Option::None, rotation, col, row,
        );

        let board: Board = world.read_model(board_id);
        println!("Board after second move: {:?}", board);
    }
}


