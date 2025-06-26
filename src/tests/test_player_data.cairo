#[cfg(test)]
mod tests {
    use core::starknet::testing;
    use dojo::model::{ModelStorage, Model};
    use dojo::world::{WorldStorage, IWorldDispatcher};
    use starknet::{ContractAddress, contract_address_const};

    use evolute_duel::{
        models::{
            game::{Board},
        },
        types::packing::{PlayerSide},
        libs::{
            player_data::{PlayerDataTrait, PlayerData},
        },
        tests::test_helpers::trait_test_helpers::{TraitTestHelpersTrait},
        events::{PlayerNotInGame},
    };

    use dojo::utils::test::{spawn_test_world, deploy_contract};

    fn setup_world() -> WorldStorage {
        let world = spawn_test_world(
            array![
                evolute_duel::models::game::board::TEST_CLASS_HASH,
            ]
        );
        
        let mut world_storage = WorldStorage { dispatcher: world };
        TraitTestHelpersTrait::setup_world_with_models(world_storage);
        world_storage
    }

    #[test]
    fn test_get_player_data_player1() {
        let mut world = setup_world();
        let (player1, player2) = TraitTestHelpersTrait::create_test_player_addresses();
        let board = TraitTestHelpersTrait::create_test_board();
        
        let player_data = PlayerDataTrait::get_player_data(@board, player1, world);
        
        match player_data {
            Option::Some(data) => {
                assert!(data.side == PlayerSide::Blue, "Player1 should be Blue side");
                assert!(data.joker_number == 3, "Player1 should have 3 jokers");
            },
            Option::None => {
                panic!("Player1 should be found in the game");
            }
        }
    }

    #[test]
    fn test_get_player_data_player2() {
        let mut world = setup_world();
        let (player1, player2) = TraitTestHelpersTrait::create_test_player_addresses();
        let board = TraitTestHelpersTrait::create_test_board();
        
        let player_data = PlayerDataTrait::get_player_data(@board, player2, world);
        
        match player_data {
            Option::Some(data) => {
                assert!(data.side == PlayerSide::Red, "Player2 should be Red side");
                assert!(data.joker_number == 3, "Player2 should have 3 jokers");
            },
            Option::None => {
                panic!("Player2 should be found in the game");
            }
        }
    }

    #[test]
    fn test_get_player_data_invalid_player() {
        let mut world = setup_world();
        let invalid_player = contract_address_const::<0x999>();
        let board = TraitTestHelpersTrait::create_test_board();
        
        let player_data = PlayerDataTrait::get_player_data(@board, invalid_player, world);
        
        assert!(player_data.is_none(), "Invalid player should not be found");
    }

    #[test]
    fn test_get_player_side_player1() {
        let mut world = setup_world();
        let (player1, _) = TraitTestHelpersTrait::create_test_player_addresses();
        let board = TraitTestHelpersTrait::create_test_board();
        
        let player_side = PlayerDataTrait::get_player_side(@board, player1, world);
        
        match player_side {
            Option::Some(side) => {
                assert!(side == PlayerSide::Blue, "Player1 should be Blue side");
            },
            Option::None => {
                panic!("Player1 side should be found");
            }
        }
    }

    #[test]
    fn test_get_player_side_player2() {
        let mut world = setup_world();
        let (_, player2) = TraitTestHelpersTrait::create_test_player_addresses();
        let board = TraitTestHelpersTrait::create_test_board();
        
        let player_side = PlayerDataTrait::get_player_side(@board, player2, world);
        
        match player_side {
            Option::Some(side) => {
                assert!(side == PlayerSide::Red, "Player2 should be Red side");
            },
            Option::None => {
                panic!("Player2 side should be found");
            }
        }
    }

    #[test]
    fn test_get_player_side_invalid_player() {
        let mut world = setup_world();
        let invalid_player = contract_address_const::<0x999>();
        let board = TraitTestHelpersTrait::create_test_board();
        
        let player_side = PlayerDataTrait::get_player_side(@board, invalid_player, world);
        
        assert!(player_side.is_none(), "Invalid player should not have a side");
    }

    #[test]
    fn test_validate_player_and_get_data_valid_player() {
        let mut world = setup_world();
        let (player1, _) = TraitTestHelpersTrait::create_test_player_addresses();
        let board = TraitTestHelpersTrait::create_test_board();
        
        let player_data = PlayerDataTrait::validate_player_and_get_data(@board, player1, world);
        
        match player_data {
            Option::Some(data) => {
                assert!(data.side == PlayerSide::Blue, "Player1 should be Blue side");
                assert!(data.joker_number == 3, "Player1 should have 3 jokers");
            },
            Option::None => {
                panic!("Valid player should return data");
            }
        }
    }

    #[test]
    fn test_validate_player_and_get_data_invalid_player() {
        let mut world = setup_world();
        let invalid_player = contract_address_const::<0x999>();
        let board = TraitTestHelpersTrait::create_test_board();
        
        let player_data = PlayerDataTrait::validate_player_and_get_data(@board, invalid_player, world);
        
        assert!(player_data.is_none(), "Invalid player should return None");
    }

    #[test]
    fn test_player_data_struct_creation() {
        let player_data = PlayerData {
            side: PlayerSide::Blue,
            joker_number: 5,
        };
        
        assert!(player_data.side == PlayerSide::Blue, "Side should be Blue");
        assert!(player_data.joker_number == 5, "Joker number should be 5");
    }

    #[test]
    fn test_player_data_struct_red_side() {
        let player_data = PlayerData {
            side: PlayerSide::Red,
            joker_number: 2,
        };
        
        assert!(player_data.side == PlayerSide::Red, "Side should be Red");
        assert!(player_data.joker_number == 2, "Joker number should be 2");
    }

    #[test]
    fn test_board_with_different_joker_numbers() {
        let mut world = setup_world();
        let (player1, player2) = TraitTestHelpersTrait::create_test_player_addresses();
        
        // Create board with different joker numbers
        let mut board = TraitTestHelpersTrait::create_test_board();
        board.player1 = (player1, PlayerSide::Blue, 5); // 5 jokers
        board.player2 = (player2, PlayerSide::Red, 1);  // 1 joker
        
        let player1_data = PlayerDataTrait::get_player_data(@board, player1, world);
        let player2_data = PlayerDataTrait::get_player_data(@board, player2, world);
        
        match player1_data {
            Option::Some(data) => {
                assert!(data.joker_number == 5, "Player1 should have 5 jokers");
            },
            Option::None => panic!("Player1 should be found"),
        }
        
        match player2_data {
            Option::Some(data) => {
                assert!(data.joker_number == 1, "Player2 should have 1 joker");
            },
            Option::None => panic!("Player2 should be found"),
        }
    }

    #[test]
    fn test_board_with_swapped_sides() {
        let mut world = setup_world();
        let (player1, player2) = TraitTestHelpersTrait::create_test_player_addresses();
        
        // Create board with swapped sides
        let mut board = TraitTestHelpersTrait::create_test_board();
        board.player1 = (player1, PlayerSide::Red, 3);  // Player1 is Red
        board.player2 = (player2, PlayerSide::Blue, 3); // Player2 is Blue
        
        let player1_data = PlayerDataTrait::get_player_data(@board, player1, world);
        let player2_data = PlayerDataTrait::get_player_data(@board, player2, world);
        
        match player1_data {
            Option::Some(data) => {
                assert!(data.side == PlayerSide::Red, "Player1 should be Red side");
            },
            Option::None => panic!("Player1 should be found"),
        }
        
        match player2_data {
            Option::Some(data) => {
                assert!(data.side == PlayerSide::Blue, "Player2 should be Blue side");
            },
            Option::None => panic!("Player2 should be found"),
        }
    }

    #[test]
    fn test_multiple_calls_same_player() {
        let mut world = setup_world();
        let (player1, _) = TraitTestHelpersTrait::create_test_player_addresses();
        let board = TraitTestHelpersTrait::create_test_board();
        
        // Call multiple times for the same player
        let data1 = PlayerDataTrait::get_player_data(@board, player1, world);
        let data2 = PlayerDataTrait::get_player_data(@board, player1, world);
        let side1 = PlayerDataTrait::get_player_side(@board, player1, world);
        let side2 = PlayerDataTrait::get_player_side(@board, player1, world);
        
        // All calls should return the same data
        assert!(data1.is_some() && data2.is_some(), "Both calls should succeed");
        assert!(side1.is_some() && side2.is_some(), "Both side calls should succeed");
        
        let data1_unwrap = data1.unwrap();
        let data2_unwrap = data2.unwrap();
        let side1_unwrap = side1.unwrap();
        let side2_unwrap = side2.unwrap();
        
        assert!(data1_unwrap.side == data2_unwrap.side, "Sides should be consistent");
        assert!(data1_unwrap.joker_number == data2_unwrap.joker_number, "Joker numbers should be consistent");
        assert!(side1_unwrap == side2_unwrap, "Sides should be consistent across calls");
    }

    #[test]
    fn test_edge_case_zero_jokers() {
        let mut world = setup_world();
        let (player1, player2) = TraitTestHelpersTrait::create_test_player_addresses();
        
        // Create board with zero jokers
        let mut board = TraitTestHelpersTrait::create_test_board();
        board.player1 = (player1, PlayerSide::Blue, 0); // 0 jokers
        board.player2 = (player2, PlayerSide::Red, 0);  // 0 jokers
        
        let player1_data = PlayerDataTrait::get_player_data(@board, player1, world);
        let player2_data = PlayerDataTrait::get_player_data(@board, player2, world);
        
        match player1_data {
            Option::Some(data) => {
                assert!(data.joker_number == 0, "Player1 should have 0 jokers");
            },
            Option::None => panic!("Player1 should be found"),
        }
        
        match player2_data {
            Option::Some(data) => {
                assert!(data.joker_number == 0, "Player2 should have 0 jokers");
            },
            Option::None => panic!("Player2 should be found"),
        }
    }
}