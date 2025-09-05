use starknet::ContractAddress;
use dojo::model::ModelStorage;
use origami_rating::elo::EloTrait;
use evolute_duel::models::tournament::{TournamentPass, PlayerTournamentIndex};
use evolute_duel::libs::store::{Store, StoreTrait};
use evolute_duel::constants::bitmap::{
    K_FACTOR_MAX, K_FACTOR_MIN, K_FACTOR_ADAPTATION_GAMES, K_FACTOR_TRANSITION_GAMES, K_FACTOR_DECAY_RATE
};
use core::num::traits::Zero;

/// Default values for ELO rating system
pub const INITIAL_RATING: u32 = 1200;
pub const K_FACTOR: u8 = 32;

#[generate_trait]
pub impl RatingSystemImpl of RatingSystemTrait {
    /// Calculate new ratings after a game using origami_rating ELO system with individual K-factors
    /// Returns (new_winner_rating, new_loser_rating)
    fn calculate_rating_change(winner_rating: u32, loser_rating: u32, winner_k_factor: u16, loser_k_factor: u16) -> (u32, u32) {
        // Calculate rating change for winner (outcome = 100 for win)
        let (winner_change, winner_is_negative): (u64, bool) = EloTrait::rating_change(
            winner_rating, // Winner's current rating
            loser_rating, // Loser's current rating  
            100_u16, // Outcome: 100 = win
            winner_k_factor // Individual K-factor for winner
        );

        // Calculate rating change for loser (outcome = 0 for loss)
        let (loser_change, loser_is_negative): (u64, bool) = EloTrait::rating_change(
            loser_rating, // Loser's current rating
            winner_rating, // Winner's current rating
            0_u16, // Outcome: 0 = loss  
            loser_k_factor // Individual K-factor for loser
        );

        // Apply rating changes
        let new_winner_rating = if winner_is_negative {
            if winner_rating > winner_change.try_into().unwrap() {
                winner_rating - winner_change.try_into().unwrap()
            } else {
                100 // Minimum rating
            }
        } else {
            winner_rating + winner_change.try_into().unwrap()
        };

        let new_loser_rating = if loser_is_negative {
            if loser_rating > loser_change.try_into().unwrap() {
                loser_rating - loser_change.try_into().unwrap()
            } else {
                100 // Minimum rating
            }
        } else {
            loser_rating + loser_change.try_into().unwrap()
        };

        (new_winner_rating, new_loser_rating)
    }

    /// Update tournament ratings for both players after a draw
    /// Returns ((player1_old_rating, player1_new_rating), (player2_old_rating, player2_new_rating))
    fn update_tournament_ratings_draw(
        player1_address: ContractAddress,
        player2_address: ContractAddress,
        tournament_id: u64,
        mut world: dojo::world::WorldStorage,
    ) -> Option<((u32, i32), (u32, i32))> {
        println!("[RATING] Processing draw for tournament {}", tournament_id);
        
        // Get tournament passes for both players
        let player1_passes = Self::get_player_tournament_pass(player1_address, tournament_id, @world);
        let player2_passes = Self::get_player_tournament_pass(player2_address, tournament_id, @world);

        match (player1_passes, player2_passes) {
            (
                Option::Some(mut player1_pass), Option::Some(mut player2_pass),
            ) => {
                println!(
                    "[RATING] Draw - Before: Player1: {:x} ({}), Player2: {:x} ({})",
                    player1_address,
                    player1_pass.rating,
                    player2_address,
                    player2_pass.rating,
                );

                // Calculate individual K-factors based on games played
                let player1_k_factor = Self::compute_k_from_games(player1_pass.games_played);
                let player2_k_factor = Self::compute_k_from_games(player2_pass.games_played);
                
                println!("[RATING] Draw Dynamic K-factors: Player1 K={} (games: {}), Player2 K={} (games: {})", 
                    player1_k_factor, player1_pass.games_played, player2_k_factor, player2_pass.games_played);

                // Calculate rating changes for draw (outcome = 50 for both players)
                let player1_k_u8: u8 = player1_k_factor.try_into().unwrap();
                let player2_k_u8: u8 = player2_k_factor.try_into().unwrap();
                
                let (player1_change, player1_is_negative): (u64, bool) = EloTrait::rating_change(
                    player1_pass.rating, // Player1's current rating
                    player2_pass.rating, // Player2's current rating  
                    50_u16, // Outcome: 50 = draw
                    player1_k_u8 // Individual K-factor for player1
                );

                let (player2_change, player2_is_negative): (u64, bool) = EloTrait::rating_change(
                    player2_pass.rating, // Player2's current rating
                    player1_pass.rating, // Player1's current rating
                    50_u16, // Outcome: 50 = draw  
                    player2_k_u8 // Individual K-factor for player2
                );

                // Apply rating changes for player1
                let new_player1_rating = if player1_is_negative {
                    if player1_pass.rating > player1_change.try_into().unwrap() {
                        player1_pass.rating - player1_change.try_into().unwrap()
                    } else {
                        100 // Minimum rating
                    }
                } else {
                    player1_pass.rating + player1_change.try_into().unwrap()
                };

                // Apply rating changes for player2
                let new_player2_rating = if player2_is_negative {
                    if player2_pass.rating > player2_change.try_into().unwrap() {
                        player2_pass.rating - player2_change.try_into().unwrap()
                    } else {
                        100 // Minimum rating
                    }
                } else {
                    player2_pass.rating + player2_change.try_into().unwrap()
                };

                let player1_rating_change: i32 = new_player1_rating.try_into().unwrap() - player1_pass.rating.try_into().unwrap();
                let player2_rating_change: i32 = new_player2_rating.try_into().unwrap() - player2_pass.rating.try_into().unwrap();

                // Update both players' stats (no wins/losses for draw)
                player1_pass.rating = new_player1_rating;
                player1_pass.games_played += 1;
                
                player2_pass.rating = new_player2_rating;
                player2_pass.games_played += 1;

                // Write updated passes back to world
                world.write_model(@player1_pass);
                world.write_model(@player2_pass);

                println!(
                    "[RATING] Draw - After: Player1: {:x} ({}), Player2: {:x} ({})",
                    player1_address,
                    new_player1_rating,
                    player2_address,
                    new_player2_rating,
                );

                // Return rating changes data
                return Option::Some(((player1_pass.rating, player1_rating_change), (player2_pass.rating, player2_rating_change)));
            },
            _ => {
                // One or both players don't have tournament passes, skip rating update
                println!(
                    "[RATING] Skipping draw rating update - missing tournament pass data for tournament {}",
                    tournament_id,
                );
                return Option::None;
            },
        }
    }

    /// Update tournament ratings for both players after a game
    /// Returns ((winner_old_rating, winner_new_rating), (loser_old_rating, loser_new_rating))
    fn update_tournament_ratings(
        winner_address: ContractAddress,
        loser_address: ContractAddress,
        tournament_id: u64,
        mut world: dojo::world::WorldStorage,
    ) -> Option<((u32, i32), (u32, i32))> {
        // Get tournament passes for both players
        let winner_passes = Self::get_player_tournament_pass(winner_address, tournament_id, @world);
        let loser_passes = Self::get_player_tournament_pass(loser_address, tournament_id, @world);

        match (winner_passes, loser_passes) {
            (
                Option::Some(mut winner_pass), Option::Some(mut loser_pass),
            ) => {
                println!(
                    "[RATING] Before - Winner: {:x} ({}), Loser: {:x} ({})",
                    winner_address,
                    winner_pass.rating,
                    loser_address,
                    loser_pass.rating,
                );

                // Calculate individual K-factors based on games played
                let winner_k_factor = Self::compute_k_from_games(winner_pass.games_played);
                let loser_k_factor = Self::compute_k_from_games(loser_pass.games_played);
                
                println!("[RATING] Dynamic K-factors: Winner K={} (games: {}), Loser K={} (games: {})", 
                    winner_k_factor, winner_pass.games_played, loser_k_factor, loser_pass.games_played);

                // Convert K-factors to u8 for compatibility
                let winner_k_u16: u16 = winner_k_factor.try_into().unwrap();
                let loser_k_u16: u16 = loser_k_factor.try_into().unwrap();
                
                // Calculate new ratings using origami_rating with individual K-factors
                let (new_winner_rating, new_loser_rating) = Self::calculate_rating_change(
                    winner_pass.rating, loser_pass.rating, winner_k_u16, loser_k_u16,
                );

                let winner_rating_change: i32 = new_winner_rating.try_into().unwrap() - winner_pass.rating.try_into().unwrap();
                let loser_rating_change: i32 = new_loser_rating.try_into().unwrap() - loser_pass.rating.try_into().unwrap();

                // Update winner stats
                winner_pass.rating = new_winner_rating;
                winner_pass.games_played += 1;
                winner_pass.wins += 1;

                // Update loser stats
                loser_pass.rating = new_loser_rating;
                loser_pass.games_played += 1;
                loser_pass.losses += 1;

                // Write updated passes back to world
                world.write_model(@winner_pass);
                world.write_model(@loser_pass);

                println!(
                    "[RATING] After - Winner: {:x} ({}), Loser: {:x} ({})",
                    Into::<ContractAddress, felt252>::into(winner_address),
                    new_winner_rating,
                    Into::<ContractAddress, felt252>::into(loser_address),
                    new_loser_rating,
                );

                // Return rating changes data
                return Option::Some(((winner_pass.rating, winner_rating_change), (loser_pass.rating, loser_rating_change)));
            },
            _ => {
                // One or both players don't have tournament passes, skip rating update
                println!(
                    "[RATING] Skipping rating update - missing tournament pass data for tournament {}",
                    tournament_id,
                );
                return Option::None;
            },
        }
    }

    /// Helper function to find a player's tournament pass using the index
    fn get_player_tournament_pass(
        player_address: ContractAddress, tournament_id: u64, world: @dojo::world::WorldStorage,
    ) -> Option<TournamentPass> {
        // Create store to access the index
        let store: Store = StoreTrait::new(*world);

        // Try to get the index entry for this player and tournament
        let index: PlayerTournamentIndex = store
            .get_player_tournament_index(player_address, tournament_id);

        // If pass_id is non-zero, we found an entry
        if index.pass_id.is_zero() {
            Option::None
        } else {
            let tournament_pass = store.get_tournament_pass(index.pass_id);
            Option::Some(tournament_pass)
        }
    }

    /// Initialize a new tournament participant with default rating
    fn initialize_tournament_rating(ref tournament_pass: TournamentPass) {
        tournament_pass.rating = INITIAL_RATING;
        tournament_pass.games_played = 0;
        tournament_pass.wins = 0;
        tournament_pass.losses = 0;
    }

    /// Calculate dynamic K-factor based on games played using piecewise + hyperbolic function
    fn compute_k_from_games(games_played: u32) -> u32 {
        println!("[K_FACTOR] Computing K-factor for games_played: {}", games_played);
        
        let k_factor = if games_played < K_FACTOR_ADAPTATION_GAMES {
            // Новые игроки: максимальный K-фактор
            println!("[K_FACTOR] New player - using max K-factor: {}", K_FACTOR_MAX);
            K_FACTOR_MAX
        } else if games_played < K_FACTOR_TRANSITION_GAMES {
            // Гиперболическое убывание: K = floor(K_MAX / (1 + decay_rate * (games - adaptation_games)))
            // Используем целочисленную арифметику: умножаем числитель и знаменатель на 100
            let numerator = K_FACTOR_MAX * 100; // K_MAX * 100
            let denom = 100 + K_FACTOR_DECAY_RATE * (games_played - K_FACTOR_ADAPTATION_GAMES); // 100 + decay_rate*(n-adaptation)
            let k = numerator / denom; // целочисленное деление -> floor
            let result = if k < K_FACTOR_MIN { K_FACTOR_MIN } else { k };
            println!("[K_FACTOR] Intermediate player - calculated K-factor: {} (from {}/{})", result, numerator, denom);
            result
        } else {
            // Опытные игроки: минимальный K-фактор
            println!("[K_FACTOR] Experienced player - using min K-factor: {}", K_FACTOR_MIN);
            K_FACTOR_MIN
        };
        
        println!("[K_FACTOR] Final K-factor: {}", k_factor);
        k_factor
    }
}
