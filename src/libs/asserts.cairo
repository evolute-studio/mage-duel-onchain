use dojo::{world::WorldStorage, event::EventStorage};
use evolute_duel::{
    models::{game::Game},
    events::{GameCreateFailed, GameJoinFailed, PlayerNotInGame, GameFinished},
    types::{packing::GameStatus},
};
#[generate_trait]
pub impl AssersImpl of AssertsTrait {
    fn assert_ready_to_create_game(self: @Game, mut world: WorldStorage) -> bool {
        let status = *self.status;
        if status == GameStatus::InProgress || status == GameStatus::Created {
            world.emit_event(@GameCreateFailed { host_player: *self.player, status });
            println!("Game already created or in progress");
            return false;
        }
        true
    }

    fn assert_ready_to_join_game(guest: @Game, host: @Game, mut world: WorldStorage) -> bool {
        if *host.status != GameStatus::Created
            || *guest.status == GameStatus::Created
            || *guest.status == GameStatus::InProgress
            || host.player == guest.player {
            world
                .emit_event(
                    @GameJoinFailed {
                        host_player: *host.player,
                        guest_player: *guest.player,
                        host_game_status: *host.status,
                        guest_game_status: *guest.status,
                    },
                );
            println!("Game join failed");
            return false;
        }
        true
    }

    fn assert_player_in_game(
        game: @Game, board_id: Option<felt252>, mut world: WorldStorage,
    ) -> bool {
        if game.board_id.is_none()
            || (board_id.is_some() && (*game.board_id).unwrap() != board_id.unwrap()) || *game.status == GameStatus::Finished {
            world.emit_event(@PlayerNotInGame { player_id: *game.player, board_id: 0 });
            println!("Player is not in game");
            return false;
        }
        true
    }

    fn assert_game_is_in_progress(game: @Game, mut world: WorldStorage) -> bool {
        if *game.status == GameStatus::Finished {
            world
                .emit_event(
                    @GameFinished { player: *game.player, board_id: (*game.board_id).unwrap() },
                );
            println!("Game is already finished");
            return false;
        }
        true
    }
}


#[cfg(test)]
mod tests {
    use super::*;
    use dojo::world::WorldStorage;
    use evolute_duel::{
        models::game::{Game, m_Game},
        types::packing::GameStatus,
        events::{
            e_GameCreateFailed, e_GameJoinFailed, e_PlayerNotInGame, e_GameFinished,
        },
    };
    use dojo_cairo_test::{spawn_test_world, NamespaceDef, TestResource};
    use starknet::{ContractAddress, contract_address_const};

    fn setup_world() -> WorldStorage {
        let namespace_def = NamespaceDef {
            namespace: "evolute_duel", resources: [
                TestResource::Model(m_Game::TEST_CLASS_HASH),
                TestResource::Event(e_GameCreateFailed::TEST_CLASS_HASH),
                TestResource::Event(e_GameJoinFailed::TEST_CLASS_HASH),
                TestResource::Event(e_PlayerNotInGame::TEST_CLASS_HASH),
                TestResource::Event(e_GameFinished::TEST_CLASS_HASH),
            ].span()
        };
        spawn_test_world([namespace_def].span())
    }

    fn create_game(player: ContractAddress, status: GameStatus, board_id: Option<felt252>) -> Game {
        Game {
            player,
            status,
            board_id,
        }
    }

    #[test]
    fn test_assert_ready_to_create_game_success() {
        let world = setup_world();
        let game = create_game(contract_address_const::<0x123>(), GameStatus::Finished, Option::None);
        
        let result = game.assert_ready_to_create_game(world);
        
        assert!(result == true, "Should be ready to create game");
    }

    #[test]
    fn test_assert_ready_to_create_game_already_created() {
        let world = setup_world();
        let game = create_game(contract_address_const::<0x123>(), GameStatus::Created, Option::None);
        
        let result = game.assert_ready_to_create_game(world);
        
        assert!(result == false, "Should not be ready to create game when already created");
    }

    #[test]
    fn test_assert_ready_to_create_game_in_progress() {
        let world = setup_world();
        let game = create_game(contract_address_const::<0x123>(), GameStatus::InProgress, Option::None);
        
        let result = game.assert_ready_to_create_game(world);
        
        assert!(result == false, "Should not be ready to create game when in progress");
    }

    #[test]
    fn test_assert_ready_to_join_game_success() {
        let world = setup_world();
        let host = create_game(contract_address_const::<0x123>(), GameStatus::Created, Option::None);
        let guest = create_game(contract_address_const::<0x456>(), GameStatus::Finished, Option::None);

        println!("Host: {:?}", host);
        println!("Guest: {:?}", guest);
        
        let result = AssertsTrait::assert_ready_to_join_game(@guest, @host, world);
        
        assert!(result == true, "Should be ready to join game");
    }

    #[test]
    fn test_assert_ready_to_join_game_host_not_created() {
        let world = setup_world();
        let host = create_game(contract_address_const::<0x123>(), GameStatus::InProgress, Option::None);
        let guest = create_game(contract_address_const::<0x456>(), GameStatus::Finished, Option::None);
        
        let result = AssertsTrait::assert_ready_to_join_game(@guest, @host, world);
        
        assert!(result == false, "Should not be ready to join when host not created");
    }

    #[test]
    fn test_assert_ready_to_join_game_guest_already_created() {
        let world = setup_world();
        let host = create_game(contract_address_const::<0x123>(), GameStatus::Created, Option::None);
        let guest = create_game(contract_address_const::<0x456>(), GameStatus::Created, Option::None);
        
        let result = AssertsTrait::assert_ready_to_join_game(@guest, @host, world);
        
        assert!(result == false, "Should not be ready to join when guest already created");
    }

    #[test]
    fn test_assert_ready_to_join_game_same_player() {
        let world = setup_world();
        let host = create_game(contract_address_const::<0x123>(), GameStatus::Created, Option::None);
        let guest = create_game(contract_address_const::<0x123>(), GameStatus::Finished, Option::None);
        
        let result = AssertsTrait::assert_ready_to_join_game(@guest, @host, world);
        
        assert!(result == false, "Should not be ready to join when same player");
    }

    #[test]
    fn test_assert_player_in_game_success() {
        let world = setup_world();
        let game = create_game(contract_address_const::<0x123>(), GameStatus::InProgress, Option::Some(456));
        
        let result = AssertsTrait::assert_player_in_game(@game, Option::Some(456), world);
        
        assert!(result == true, "Should be in game");
    }

    #[test]
    fn test_assert_player_in_game_no_board() {
        let world = setup_world();
        let game = create_game(contract_address_const::<0x123>(), GameStatus::InProgress, Option::None);
        
        let result = AssertsTrait::assert_player_in_game(@game, Option::Some(456), world);
        
        assert!(result == false, "Should not be in game when no board");
    }

    #[test]
    fn test_assert_player_in_game_wrong_board() {
        let world = setup_world();
        let game = create_game(contract_address_const::<0x123>(), GameStatus::InProgress, Option::Some(456));
        
        let result = AssertsTrait::assert_player_in_game(@game, Option::Some(789), world);
        
        assert!(result == false, "Should not be in game when wrong board");
    }

    #[test]
    fn test_assert_game_is_in_progress_success() {
        let world = setup_world();
        let game = create_game(contract_address_const::<0x123>(), GameStatus::InProgress, Option::Some(456));
        
        let result = AssertsTrait::assert_player_in_game(@game, Option::Some(456), world);
        
        assert!(result == true, "Should be in progress");
    }

    #[test]
    fn test_assert_game_is_in_progress_finished() {
        let world = setup_world();
        let game = create_game(contract_address_const::<0x123>(), GameStatus::Finished, Option::Some(456));
        
        let result = AssertsTrait::assert_player_in_game(@game, Option::None, world);
        
        assert!(result == false, "Should not be in progress when finished");
    }
}