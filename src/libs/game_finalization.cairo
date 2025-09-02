use starknet::ContractAddress;
use evolute_duel::{
    models::{game::{Board, Game, Rules}, player::{Player}, tournament::{TournamentBoard}}, 
    events::{GameFinished, BoardUpdated},
    types::packing::{GameState, GameStatus, PlayerSide, GameMode},
    libs::{
        scoring::{ScoringTrait}, achievements::{AchievementsTrait},
        rating_system::{RatingSystemTrait},
    },
};
use dojo::{model::{ModelStorage, Model}, event::EventStorage};

#[derive(Drop, Copy)]
pub struct GameFinalizationData {
    pub board_id: felt252,
    pub player1_address: ContractAddress,
    pub player2_address: ContractAddress,
    pub player1_side: PlayerSide,
    pub joker_number1: u8,
    pub joker_number2: u8,
}

#[generate_trait]
pub impl GameFinalizationImpl of GameFinalizationTrait {
    fn calculate_final_points(
        board: @Board, joker_number1: u8, joker_number2: u8, joker_price: u16,
    ) -> (u16, u16) {
        println!("[calculate_final_points] Starting calculation with joker_price: {}", joker_price);

        let blue_joker_points = joker_number1.into() * joker_price.into();
        let red_joker_points = joker_number2.into() * joker_price.into();
        println!(
            "[calculate_final_points] Blue jokers: {} * {} = {}",
            joker_number1,
            joker_price,
            blue_joker_points,
        );
        println!(
            "[calculate_final_points] Red jokers: {} * {} = {}",
            joker_number2,
            joker_price,
            red_joker_points,
        );

        let (blue_city_points, blue_road_points) = *board.blue_score;
        let blue_points = blue_city_points + blue_road_points + blue_joker_points;
        println!(
            "[calculate_final_points] Blue score: {} cities + {} roads + {} jokers = {}",
            blue_city_points,
            blue_road_points,
            blue_joker_points,
            blue_points,
        );

        let (red_city_points, red_road_points) = *board.red_score;
        let red_points = red_city_points + red_road_points + red_joker_points;
        println!(
            "[calculate_final_points] Red score: {} cities + {} roads + {} jokers = {}",
            red_city_points,
            red_road_points,
            red_joker_points,
            red_points,
        );

        (blue_points, red_points)
    }

    fn determine_winner(blue_points: u16, red_points: u16) -> Option<u8> {
        println!("[determine_winner] Comparing scores: Blue {} vs Red {}", blue_points, red_points);

        if blue_points > red_points {
            println!("[determine_winner] Blue wins!");
            Option::Some(1) // Blue wins
        } else if blue_points < red_points {
            println!("[determine_winner] Red wins!");
            Option::Some(2) // Red wins
        } else {
            println!("[determine_winner] It's a draw!");
            Option::None // Draw
        }
    }

    fn update_player_stats(
        player1_address: ContractAddress,
        player2_address: ContractAddress,
        player1_side: PlayerSide,
        blue_points: u16,
        red_points: u16,
        add_points_to: u8, // 0 - both, 1 - blue only, 2 - red only
        mut world: dojo::world::WorldStorage,
    ) {
        println!("[update_player_stats] Starting player stats update");
        println!(
            "[update_player_stats] Player1 side: {:?}, Blue points: {}, Red points: {}",
            player1_side,
            blue_points,
            red_points,
        );

        let mut player1: Player = world.read_model(player1_address);
        let mut player2: Player = world.read_model(player2_address);

        println!(
            "[update_player_stats] Player1 current balance: {}, games_played: {}",
            player1.balance,
            player1.games_played,
        );
        println!(
            "[update_player_stats] Player2 current balance: {}, games_played: {}",
            player2.balance,
            player2.games_played,
        );

        // Determine which players get points based on add_points_to parameter
        match add_points_to {
            0 => {
                // Both players get their earned points (normal game completion)
                if player1_side == PlayerSide::Blue {
                    player1.balance += blue_points.into();
                    player2.balance += red_points.into();
                } else {
                    player1.balance += red_points.into();
                    player2.balance += blue_points.into();
                }
            },
            1 => {
                // Only blue player gets points (red player forfeited/timed out)
                if player1_side == PlayerSide::Blue {
                    player1.balance += blue_points.into();
                    // player2 gets 0 points
                } else {
                    // player1 gets 0 points
                    player2.balance += blue_points.into();
                }
                println!(
                    "[PENALTY] Only blue player awarded points due to red player timeout/forfeit",
                );
            },
            2 => {
                // Only red player gets points (blue player forfeited/timed out)
                if player1_side == PlayerSide::Blue {
                    // player1 gets 0 points
                    player2.balance += red_points.into();
                } else {
                    player1.balance += red_points.into();
                    // player2 gets 0 points
                }
                println!(
                    "[PENALTY] Only red player awarded points due to blue player timeout/forfeit",
                );
            },
            _ => {
                // Fallback to normal scoring for invalid values
                if player1_side == PlayerSide::Blue {
                    player1.balance += blue_points.into();
                    player2.balance += red_points.into();
                } else {
                    player1.balance += red_points.into();
                    player2.balance += blue_points.into();
                }
                println!(
                    "[WARNING] Invalid add_points_to value: {}, using normal scoring",
                    add_points_to,
                );
            },
        }

        player1.games_played += 1;
        player2.games_played += 1;

        println!(
            "[update_player_stats] Player1 new balance: {}, games_played: {}",
            player1.balance,
            player1.games_played,
        );
        println!(
            "[update_player_stats] Player2 new balance: {}, games_played: {}",
            player2.balance,
            player2.games_played,
        );

        world.write_model(@player1);
        world.write_model(@player2);
        println!("[update_player_stats] Player stats updated and written to world");
    }

    fn update_game_status(
        player1_address: ContractAddress,
        player2_address: ContractAddress,
        mut world: dojo::world::WorldStorage,
    ) {
        println!("[update_game_status] Updating game status to Finished");

        let mut host_game: Game = world.read_model(player1_address);
        let mut guest_game: Game = world.read_model(player2_address);

        println!("[update_game_status] Host game current status: {:?}", host_game.status);
        println!("[update_game_status] Guest game current status: {:?}", guest_game.status);

        host_game.status = GameStatus::Finished;
        host_game.game_mode = GameMode::None; // Reset game mode to None
        guest_game.status = GameStatus::Finished;
        guest_game.game_mode = GameMode::None; // Reset game mode to None

        world.write_model(@host_game);
        world.write_model(@guest_game);
        println!("[update_game_status] Both games marked as Finished and written to world");
    }

    /// Update tournament ratings after a tournament game finishes
    /// This should be called after determining the winner of the game
    fn update_tournament_ratings(
        winner_address: ContractAddress,
        loser_address: ContractAddress,
        tournament_id: u64,
        mut world: dojo::world::WorldStorage,
    ) {
        println!("[update_tournament_ratings] Updating ratings for tournament {}", tournament_id);

        // Call the rating system to update both players' ratings
        RatingSystemTrait::update_tournament_ratings(
            winner_address, loser_address, tournament_id, world,
        );
    }

    /// Check if game was tournament and update tournament stats if needed
    fn process_tournament_stats_if_needed(
        finalization_data: GameFinalizationData,
        winner: Option<u8>,
        mut world: dojo::world::WorldStorage,
    ) {
        println!("[process_tournament_stats_if_needed] Checking if tournament game");

        // Check if this was a tournament game
        let host_game: Game = world.read_model(finalization_data.player1_address);
        let was_tournament_game = host_game.game_mode == GameMode::Tournament;
        
        if !was_tournament_game {
            println!("[process_tournament_stats_if_needed] Regular (non-tournament) game - no tournament updates");
            return;
        }

        println!("[process_tournament_stats_if_needed] Tournament game detected - checking for tournament_id");

        // Try to get tournament board to find tournament_id
        let tournament_board: TournamentBoard = world.read_model(finalization_data.board_id);
        let tournament_id = tournament_board.tournament_id;

        if tournament_id == 0 {
            println!("[process_tournament_stats_if_needed] Tournament game but no valid tournament_id found");
            return;
        }

        println!("[process_tournament_stats_if_needed] Found tournament_id: {}", tournament_id);
        
        // Determine winner and loser based on game outcome and update ratings
        match winner {
            Option::Some(winner) => {
                match winner {
                    0 => {},
                    1 => {
                        // Blue wins
                        let (winner_addr, loser_addr) = if finalization_data.player1_side == PlayerSide::Blue {
                            (finalization_data.player1_address, finalization_data.player2_address)
                        } else {
                            (finalization_data.player2_address, finalization_data.player1_address)
                        };
                        
                        println!("[process_tournament_stats_if_needed] Blue wins - updating tournament ratings");
                        Self::update_tournament_ratings(winner_addr, loser_addr, tournament_id, world);},
                    2 => {
                        // Red wins  
                        let (winner_addr, loser_addr) = if finalization_data.player1_side == PlayerSide::Blue {
                            (finalization_data.player2_address, finalization_data.player1_address)
                        } else {
                            (finalization_data.player1_address, finalization_data.player2_address)
                        };
                        
                        println!("[process_tournament_stats_if_needed] Red wins - updating tournament ratings");
                        Self::update_tournament_ratings(winner_addr, loser_addr, tournament_id, world);
                    },
                    _ => {},
                }
                
            },
            Option::None => {
                // Draw case - winner is None
                println!("[process_tournament_stats_if_needed] Draw detected - updating both players' tournament ratings");
                RatingSystemTrait::update_tournament_ratings_draw(
                    finalization_data.player1_address,
                    finalization_data.player2_address,
                    tournament_id,
                    world
                );
            }
        }
    }

    fn emit_game_finished_events(
        player1_address: ContractAddress,
        player2_address: ContractAddress,
        board_id: felt252,
        mut world: dojo::world::WorldStorage,
    ) {
        println!(
            "[emit_game_finished_events] Emitting GameFinished events for board: {}", board_id,
        );

        world.emit_event(@GameFinished { player: player1_address, board_id });
        println!(
            "[emit_game_finished_events] GameFinished event emitted for player1: {:?}",
            player1_address,
        );

        world.emit_event(@GameFinished { player: player2_address, board_id });
        println!(
            "[emit_game_finished_events] GameFinished event emitted for player2: {:?}",
            player2_address,
        );
    }

    fn update_board_final_state(board: @Board, mut world: dojo::world::WorldStorage) {
        let board_id = *board.id;
        println!("[update_board_final_state] Updating board {} final state", board_id);

        let (blue_city, blue_road) = *board.blue_score;
        let (red_city, red_road) = *board.red_score;
        println!(
            "[update_board_final_state] Final scores - Blue: ({}, {}), Red: ({}, {})",
            blue_city,
            blue_road,
            red_city,
            red_road,
        );

        world
            .write_member(
                Model::<Board>::ptr_from_keys(board_id), selector!("blue_score"), *board.blue_score,
            );
        println!("[update_board_final_state] Blue score written to board");

        world
            .write_member(
                Model::<Board>::ptr_from_keys(board_id), selector!("red_score"), *board.red_score,
            );
        println!("[update_board_final_state] Red score written to board");

        world
            .write_member(
                Model::<Board>::ptr_from_keys(board_id),
                selector!("game_state"),
                GameState::Finished,
            );
        println!("[update_board_final_state] Game state set to Finished");
    }

    fn emit_board_updated_event(board: @Board, mut world: dojo::world::WorldStorage) {
        println!("[emit_board_updated_event] Emitting BoardUpdated event for board: {}", *board.id);
        println!(
            "[emit_board_updated_event] Moves done: {}, Last move ID: {:?}",
            *board.moves_done,
            *board.last_move_id,
        );

        world
            .emit_event(
                @BoardUpdated {
                    board_id: *board.id,
                    top_tile: *board.top_tile,
                    player1: *board.player1,
                    player2: *board.player2,
                    blue_score: *board.blue_score,
                    red_score: *board.red_score,
                    last_move_id: *board.last_move_id,
                    moves_done: *board.moves_done,
                    game_state: GameState::Finished,
                },
            );
        println!("[emit_board_updated_event] BoardUpdated event emitted with Finished state");
    }

    fn process_achievements(
        winner: Option<u8>,
        player1_address: ContractAddress,
        player2_address: ContractAddress,
        mut world: dojo::world::WorldStorage,
    ) {
        println!("[process_achievements] Processing achievements for game completion");
        println!("[process_achievements] Winner: {:?}", winner);

        AchievementsTrait::play_game(world, player1_address);
        println!("[process_achievements] Play game achievement processed for player1");

        AchievementsTrait::play_game(world, player2_address);
        println!("[process_achievements] Play game achievement processed for player2");

        if winner == Option::Some(1) {
            AchievementsTrait::win_game(world, player1_address);
            println!("[process_achievements] Win game achievement processed for player1 (Blue)");
        } else if winner == Option::Some(2) {
            AchievementsTrait::win_game(world, player2_address);
            println!("[process_achievements] Win game achievement processed for player2 (Red)");
        } else {
            println!("[process_achievements] No win achievement (draw or no winner)");
        }
    }

    fn finalize_game(
        finalization_data: GameFinalizationData,
        ref board: Board,
        potential_contests: Span<u32>,
        add_points_to: u8, // 0 - both, 1 - blue, 2 - red
        mut world: dojo::world::WorldStorage,
    ) {
        println!(
            "[finalize_game] Starting finalization for board ID: {}", finalization_data.board_id,
        );
        println!(
            "[finalize_game] Potential contests: {}, add_points_to: {}",
            potential_contests.len(),
            add_points_to,
        );

        ScoringTrait::calculate_final_scoring(potential_contests, ref board, world);
        println!("[finalize_game] Final scoring calculation completed");

        println!("[finalize_game] Finalizing game with board ID: {}", finalization_data.board_id);

        let rules: Rules = world.read_model(0);
        let joker_price = rules.joker_price;
        println!("[finalize_game] Retrieved joker price from rules: {}", joker_price);

        let (blue_points, red_points) = Self::calculate_final_points(
            @board, finalization_data.joker_number1, finalization_data.joker_number2, joker_price,
        );
        println!(
            "[finalize_game] Final points calculated - Blue: {}, Red: {}", blue_points, red_points,
        );

        let winner = Self::determine_winner(blue_points, red_points);
        println!("[finalize_game] Winner determined: {:?}", winner);

        board.game_state = GameState::Finished;
        println!("[finalize_game] Board game state set to Finished");

        Self::update_game_status(
            finalization_data.player1_address, finalization_data.player2_address, world,
        );

        Self::emit_game_finished_events(
            finalization_data.player1_address,
            finalization_data.player2_address,
            finalization_data.board_id,
            world,
        );

        Self::update_player_stats(
            finalization_data.player1_address,
            finalization_data.player2_address,
            finalization_data.player1_side,
            blue_points,
            red_points,
            add_points_to,
            world,
        );

        Self::update_board_final_state(@board, world);
        Self::emit_board_updated_event(@board, world);

        Self::process_achievements(
            winner, finalization_data.player1_address, finalization_data.player2_address, world,
        );

        // Process tournament stats if this was a tournament game
        Self::process_tournament_stats_if_needed(finalization_data, winner, world);

        println!("[finalize_game] Game finalization completed successfully");
    }
}
