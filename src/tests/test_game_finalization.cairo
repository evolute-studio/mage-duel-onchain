// #[cfg(test)]
// mod tests {
//     use core::starknet::testing;
//     use dojo::model::{ModelStorage, Model};
//     use dojo::world::{WorldStorage, IWorldDispatcher};
//     use starknet::{ContractAddress, get_block_timestamp};
//     use alexandria_data_structures::vec::{NullableVec};

//     use evolute_duel::{
//         models::{
//             game::{Board, Game, Rules},
//             player::{Player},
//             scoring::{UnionFind},
//         },
//         types::packing::{GameState, GameStatus, PlayerSide, UnionNode},
//         libs::{
//             game_finalization::{GameFinalizationTrait, GameFinalizationData},
//         },
//         tests::test_helpers::trait_test_helpers::{TraitTestHelpersTrait},
//     };

//     use dojo::utils::test::{spawn_test_world, deploy_contract};

//     fn setup_world() -> WorldStorage {
//         let world = spawn_test_world(
//             array![
//                 evolute_duel::models::game::board::TEST_CLASS_HASH,
//                 evolute_duel::models::game::game::TEST_CLASS_HASH,
//                 evolute_duel::models::game::rules::TEST_CLASS_HASH,
//                 evolute_duel::models::player::player::TEST_CLASS_HASH,
//                 evolute_duel::models::scoring::union_find::TEST_CLASS_HASH,
//             ]
//         );
        
//         let mut world_storage = WorldStorage { dispatcher: world };
//         TraitTestHelpersTrait::setup_world_with_models(world_storage);
//         world_storage
//     }

//     #[test]
//     fn test_calculate_final_points() {
//         let board = TraitTestHelpersTrait::create_test_board_finished();
//         let joker_number1 = 2; // Blue player
//         let joker_number2 = 1; // Red player
//         let joker_price = 5;
        
//         let (blue_points, red_points) = GameFinalizationTrait::calculate_final_points(
//             @board, joker_number1, joker_number2, joker_price
//         );
        
//         // board.blue_score = (150, 120), joker_number1 = 2, joker_price = 5
//         // Expected: 150 + 120 + (2 * 5) = 280
//         assert!(blue_points == 280, "Blue points calculation incorrect");
        
//         // board.red_score = (140, 110), joker_number2 = 1, joker_price = 5  
//         // Expected: 140 + 110 + (1 * 5) = 255
//         assert!(red_points == 255, "Red points calculation incorrect");
//     }

//     #[test]
//     fn test_determine_winner_blue_wins() {
//         let blue_points = 280;
//         let red_points = 255;
        
//         let winner = GameFinalizationTrait::determine_winner(blue_points, red_points);
//         assert!(winner == Option::Some(1), "Blue should win");
//     }

//     #[test]
//     fn test_determine_winner_red_wins() {
//         let blue_points = 200;
//         let red_points = 250;
        
//         let winner = GameFinalizationTrait::determine_winner(blue_points, red_points);
//         assert!(winner == Option::Some(2), "Red should win");
//     }

//     #[test]
//     fn test_determine_winner_draw() {
//         let blue_points = 250;
//         let red_points = 250;
        
//         let winner = GameFinalizationTrait::determine_winner(blue_points, red_points);
//         assert!(winner == Option::Some(0), "Should be a draw");
//     }

//     #[test]
//     fn test_update_player_stats_blue_player() {
//         let mut world = setup_world();
//         let (player1, player2) = TraitTestHelpersTrait::create_test_player_addresses();
//         let blue_points = 280;
//         let red_points = 255;
        
//         // Player1 is blue side
//         GameFinalizationTrait::update_player_stats(
//             player1, player2, PlayerSide::Blue, blue_points, red_points, world
//         );
        
//         let updated_player1: Player = world.read_model(player1);
//         let updated_player2: Player = world.read_model(player2);
        
//         // Player1 (blue) should get blue_points, Player2 should get red_points
//         assert!(updated_player1.balance == 1000 + blue_points.into(), "Player1 balance incorrect");
//         assert!(updated_player2.balance == 1000 + red_points.into(), "Player2 balance incorrect");
//         assert!(updated_player1.games_played == 6, "Player1 games_played should increment");
//         assert!(updated_player2.games_played == 6, "Player2 games_played should increment");
//     }

//     #[test]
//     fn test_update_player_stats_red_player() {
//         let mut world = setup_world();
//         let (player1, player2) = TraitTestHelpersTrait::create_test_player_addresses();
//         let blue_points = 280;
//         let red_points = 255;
        
//         // Player1 is red side
//         GameFinalizationTrait::update_player_stats(
//             player1, player2, PlayerSide::Red, blue_points, red_points, world
//         );
        
//         let updated_player1: Player = world.read_model(player1);
//         let updated_player2: Player = world.read_model(player2);
        
//         // Player1 (red) should get red_points, Player2 should get blue_points
//         assert!(updated_player1.balance == 1000 + red_points.into(), "Player1 balance incorrect");
//         assert!(updated_player2.balance == 1000 + blue_points.into(), "Player2 balance incorrect");
//     }

//     #[test]
//     fn test_update_game_status() {
//         let mut world = setup_world();
//         let (player1, player2) = TraitTestHelpersTrait::create_test_player_addresses();
        
//         GameFinalizationTrait::update_game_status(player1, player2, world);
        
//         let game1: Game = world.read_model(player1);
//         let game2: Game = world.read_model(player2);
        
//         assert!(game1.status == GameStatus::Finished, "Player1 game should be finished");
//         assert!(game2.status == GameStatus::Finished, "Player2 game should be finished");
//     }

//     #[test]
//     fn test_update_board_final_state() {
//         let mut world = setup_world();
//         let board = TraitTestHelpersTrait::create_test_board_finished();
        
//         GameFinalizationTrait::update_board_final_state(@board, world);
        
//         let updated_board: Board = world.read_model(board.id);
//         assert!(updated_board.game_state == GameState::Finished, "Board should be finished");
//         assert!(updated_board.blue_score == board.blue_score, "Blue score should be preserved");
//         assert!(updated_board.red_score == board.red_score, "Red score should be preserved");
//     }

//     #[test]
//     fn test_finalize_game_integration() {
//         let mut world = setup_world();
//         let (player1, player2) = TraitTestHelpersTrait::create_test_player_addresses();
        
//         let mut board = TraitTestHelpersTrait::create_test_board_finished();
//         let joker_number1 = 2;
//         let joker_number2 = 1;
        
//         let finalization_data = GameFinalizationData {
//             board_id: board.id,
//             player1_address: player1,
//             player2_address: player2,
//             player1_side: PlayerSide::Blue,
//             joker_number1,
//             joker_number2,
//         };
        
//         let mut city_nodes: NullableVec<UnionNode> = NullableVec::new();
//         let mut road_nodes: NullableVec<UnionNode> = NullableVec::new();
//         let potential_city_contests = array![].span();
//         let potential_road_contests = array![].span();
        
//         // Before finalization - check initial states
//         let initial_player1: Player = world.read_model(player1);
//         let initial_player2: Player = world.read_model(player2);
//         let initial_balance1 = initial_player1.balance;
//         let initial_balance2 = initial_player2.balance;
        
//         GameFinalizationTrait::finalize_game(
//             finalization_data,
//             ref board,
//             potential_city_contests,
//             potential_road_contests,
//             ref city_nodes,
//             ref road_nodes,
//             world,
//         );
        
//         // After finalization - verify all updates
//         let final_board: Board = world.read_model(board.id);
//         let final_player1: Player = world.read_model(player1);
//         let final_player2: Player = world.read_model(player2);
//         let final_game1: Game = world.read_model(player1);
//         let final_game2: Game = world.read_model(player2);
        
//         // Board should be finished
//         assert!(final_board.game_state == GameState::Finished, "Board should be finished");
        
//         // Games should be finished
//         assert!(final_game1.status == GameStatus::Finished, "Game1 should be finished");
//         assert!(final_game2.status == GameStatus::Finished, "Game2 should be finished");
        
//         // Players should have updated balances and stats
//         assert!(final_player1.balance > initial_balance1, "Player1 balance should increase");
//         assert!(final_player2.balance > initial_balance2, "Player2 balance should increase");
//         assert!(final_player1.games_played == 6, "Player1 games_played should increment");
//         assert!(final_player2.games_played == 6, "Player2 games_played should increment");
        
//         // Calculate expected points
//         let rules: Rules = world.read_model(0);
//         let joker_price = rules.joker_price;
//         let blue_total = board.blue_score.0 + board.blue_score.1 + (joker_number1.into() * joker_price.into());
//         let red_total = board.red_score.0 + board.red_score.1 + (joker_number2.into() * joker_price.into());
        
//         // Player1 is blue, so should get blue_total points
//         assert!(final_player1.balance == initial_balance1 + blue_total.into(), "Player1 should get blue points");
//         assert!(final_player2.balance == initial_balance2 + red_total.into(), "Player2 should get red points");
//     }

//     #[test]
//     fn test_process_achievements_blue_wins() {
//         let mut world = setup_world();
//         let (player1, player2) = TraitTestHelpersTrait::create_test_player_addresses();
//         let winner = Option::Some(1); // Blue wins
        
//         // This test would require mocking AchievementsTrait calls
//         // For now, we just test that the function doesn't panic
//         GameFinalizationTrait::process_achievements(winner, player1, player2, world);
//     }

//     #[test]
//     fn test_process_achievements_red_wins() {
//         let mut world = setup_world();
//         let (player1, player2) = TraitTestHelpersTrait::create_test_player_addresses();
//         let winner = Option::Some(2); // Red wins
        
//         GameFinalizationTrait::process_achievements(winner, player1, player2, world);
//     }

//     #[test]
//     fn test_process_achievements_draw() {
//         let mut world = setup_world();
//         let (player1, player2) = TraitTestHelpersTrait::create_test_player_addresses();
//         let winner = Option::Some(0); // Draw
        
//         GameFinalizationTrait::process_achievements(winner, player1, player2, world);
//     }
// }