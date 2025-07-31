use starknet::ContractAddress;
use evolute_duel::{
    models::{
        game::{Board, Game, Rules},
        player::{Player},
    },
    events::{GameFinished, BoardUpdated},
    types::packing::{GameState, GameStatus, PlayerSide},
    libs::{
        scoring::{ScoringTrait}, 
        achievements::{AchievementsTrait}
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
        board: @Board,
        joker_number1: u8,
        joker_number2: u8,
        joker_price: u16,
    ) -> (u16, u16) {
        let blue_joker_points = joker_number1.into() * joker_price.into();
        let red_joker_points = joker_number2.into() * joker_price.into();
        let (blue_city_points, blue_road_points) = *board.blue_score;
        let blue_points = blue_city_points + blue_road_points + blue_joker_points;
        let (red_city_points, red_road_points) = *board.red_score;
        let red_points = red_city_points + red_road_points + red_joker_points;
        
        (blue_points, red_points)
    }

    fn determine_winner(blue_points: u16, red_points: u16) -> Option<u8> {
        if blue_points > red_points {
            Option::Some(1) // Blue wins
        } else if blue_points < red_points {
            Option::Some(2) // Red wins
        } else {
            Option::Some(0) // Draw
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
        let mut player1: Player = world.read_model(player1_address);
        let mut player2: Player = world.read_model(player2_address);

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
                println!("[PENALTY] Only blue player awarded points due to red player timeout/forfeit");
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
                println!("[PENALTY] Only red player awarded points due to blue player timeout/forfeit");
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
                println!("[WARNING] Invalid add_points_to value: {}, using normal scoring", add_points_to);
            }
        }

        player1.games_played += 1;
        player2.games_played += 1;

        world.write_model(@player1);
        world.write_model(@player2);
    }

    fn update_game_status(
        player1_address: ContractAddress,
        player2_address: ContractAddress,
        mut world: dojo::world::WorldStorage,
    ) {
        let mut host_game: Game = world.read_model(player1_address);
        let mut guest_game: Game = world.read_model(player2_address);
        
        host_game.status = GameStatus::Finished;
        guest_game.status = GameStatus::Finished;

        world.write_model(@host_game);
        world.write_model(@guest_game);
    }

    fn emit_game_finished_events(
        player1_address: ContractAddress,
        player2_address: ContractAddress,
        board_id: felt252,
        mut world: dojo::world::WorldStorage,
    ) {
        world.emit_event(@GameFinished { player: player1_address, board_id });
        world.emit_event(@GameFinished { player: player2_address, board_id });
    }

    fn update_board_final_state(
        board: @Board,
        mut world: dojo::world::WorldStorage,
    ) {
        let board_id = *board.id;
        
        world.write_member(
            Model::<Board>::ptr_from_keys(board_id),
            selector!("blue_score"),
            *board.blue_score,
        );

        world.write_member(
            Model::<Board>::ptr_from_keys(board_id),
            selector!("red_score"),
            *board.red_score,
        );

        world.write_member(
            Model::<Board>::ptr_from_keys(board_id),
            selector!("game_state"),
            GameState::Finished,
        );
    }

    fn emit_board_updated_event(
        board: @Board,
        mut world: dojo::world::WorldStorage,
    ) {
        world.emit_event(
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
    }

    fn process_achievements(
        winner: Option<u8>,
        player1_address: ContractAddress,
        player2_address: ContractAddress,
        mut world: dojo::world::WorldStorage,
    ) {
        AchievementsTrait::play_game(world, player1_address);
        AchievementsTrait::play_game(world, player2_address);

        if winner == Option::Some(1) {
            AchievementsTrait::win_game(world, player1_address);
        } else if winner == Option::Some(2) {
            AchievementsTrait::win_game(world, player2_address);
        }
    }

    fn finalize_game(
        finalization_data: GameFinalizationData,
        ref board: Board,
        potential_contests: Span<u32>,
        add_points_to: u8, // 0 - both, 1 - blue, 2 - red
        mut world: dojo::world::WorldStorage,
    ) {
        ScoringTrait::calculate_final_scoring(
            potential_contests,
            ref board,
            world,
        );

        println!("Finalizing game with board ID: {}", finalization_data.board_id);

        let rules: Rules = world.read_model(0);
        let joker_price = rules.joker_price;
        
        let (blue_points, red_points) = Self::calculate_final_points(
            @board, finalization_data.joker_number1, finalization_data.joker_number2, joker_price
        );

        let winner = Self::determine_winner(blue_points, red_points);

        board.game_state = GameState::Finished;

        Self::update_game_status(
            finalization_data.player1_address,
            finalization_data.player2_address,
            world,
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
            winner,
            finalization_data.player1_address,
            finalization_data.player2_address,
            world,
        );
    }
}