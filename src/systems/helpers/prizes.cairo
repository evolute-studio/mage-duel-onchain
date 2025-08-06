use starknet::ContractAddress;
use evolute_duel::utils::random::{hash_u32_quad, hash_u32_pair, felt252_to_u32};

// Constants for prize system configuration
const PRIZE_DISTANCE: u32 = 10;  // Fixed distance for all prizes
const PRIZE_AMOUNT: u128 = 100; // Fixed prize amount

pub mod prize_system {
    use super::*;

    /// Main function: get prize amount at given position
    pub fn has_prize_at(
        player_address: ContractAddress,
        col: u32,
        row: u32,
        first_tile_col: u32,
        first_tile_row: u32,
        season_id: felt252
    ) -> Option<u128> {
        // Calculate distance from first tile
        let distance = calculate_distance(col, row, first_tile_col, first_tile_row);
        
        // Check if exactly at prize distance
        if distance != PRIZE_DISTANCE {
            return Option::None;
        }
        
        // Check if this position is one of the 4 selected prize positions
        if is_selected_prize_position(player_address, col, row, first_tile_col, first_tile_row, season_id) {
            Option::Some(PRIZE_AMOUNT)
        } else {
            Option::None
        }
    }

    /// Calculate Manhattan distance between two points
    pub fn calculate_distance(col1: u32, row1: u32, col2: u32, row2: u32) -> u32 {
        let col_diff = if col1 >= col2 { col1 - col2 } else { col2 - col1 };
        let row_diff = if row1 >= row2 { row1 - row2 } else { row2 - row1 };
        col_diff + row_diff
    }

    /// Check if position is one of the 4 selected prize positions at distance 7
    pub fn is_selected_prize_position(
        player_address: ContractAddress,
        col: u32,
        row: u32,
        first_tile_col: u32,
        first_tile_row: u32,
        season_id: felt252
    ) -> bool {
        // Generate seed for selecting positions
        let selection_seed = generate_selection_seed(player_address, first_tile_col, first_tile_row, season_id);
        
        // Each side has 6 positions (excluding corner positions)
        let positions_per_side = PRIZE_DISTANCE;
        
        // Check all 4 sides
        let mut side_id = 1;
        loop {
            if side_id > 4 {
                break false;
            }
            
            // Generate seed for this side
            let side_seed = hash_u32_pair(selection_seed, side_id);
            
            // Calculate selected position index for this side (1 to 6, excluding corners)
            let pos_idx = (side_seed % positions_per_side) + 1;
            
            // Calculate coordinates based on side_id
            let (selected_col, selected_row) = if side_id == 1 {
                // Side 1: (x₀ + 7 - i, y₀ + i)
                (first_tile_col + PRIZE_DISTANCE - pos_idx, first_tile_row + pos_idx)
            } else if side_id == 2 {
                // Side 2: (x₀ - i, y₀ + 7 - i)
                (first_tile_row + PRIZE_DISTANCE - pos_idx, first_tile_col - pos_idx)
            } else if side_id == 3 {
                // Side 3: (x₀ - 7 + i, y₀ - i)
                (first_tile_col - PRIZE_DISTANCE + pos_idx, first_tile_row + pos_idx)
            } else {
                // Side 4: (x₀ + i, y₀ - 7 + i)
                (first_tile_row - PRIZE_DISTANCE + pos_idx, first_tile_col - pos_idx)
            };
            
            // Check if current position matches this selected position
            if col == selected_col && row == selected_row {
                break true;
            }
            
            side_id += 1;
        }
    }

    /// Generate deterministic seed for selecting prize positions
    pub fn generate_selection_seed(
        player_address: ContractAddress,
        first_tile_col: u32,
        first_tile_row: u32,
        season_id: felt252
    ) -> u32 {
        // Convert player_address to u32 for hashing
        let player_u32 = felt252_to_u32(player_address.into());
        let season_u32 = felt252_to_u32(season_id);
        
        // Hash player info with first tile coordinates and season
        hash_u32_quad(player_u32, first_tile_col, first_tile_row, season_u32)
    }

    /// Get all positions at exact distance from center
    pub fn get_distance_positions(
        center_col: u32,
        center_row: u32,
        distance: u32
    ) -> Array<(u32, u32)> {
        let mut positions = ArrayTrait::new();
        
        let mut col_offset: u32 = 0;
        loop {
            if col_offset > distance {
                break;
            }
            
            let row_offset = distance - col_offset;
            
            // Add all 4 quadrants
            let positions_to_add = array![
                (center_col + col_offset, center_row + row_offset),
                (center_col + col_offset, center_row - row_offset),
                (center_col - col_offset, center_row + row_offset),
                (center_col - col_offset, center_row - row_offset),
            ];
            
            let mut i = 0;
            loop {
                if i >= positions_to_add.len() {
                    break;
                }
                let pos = *positions_to_add[i];
                
                // Check that position is unique
                let mut contains = false;
                let mut j = 0;
                loop {
                    if j >= positions.len() {
                        break;
                    }
                    if *positions[j] == pos {
                        contains = true;
                        break;
                    }
                    j += 1;
                };

                if !contains {
                    positions.append(pos);
                }
                i += 1;
            };
            
            col_offset += 1;
        };
        
        positions
    }

    /// Select one position from each of the 4 sides of the square
    pub fn select_four_side_positions(
        all_positions: Array<(u32, u32)>,
        seed: u32,
        center_col: u32,
        center_row: u32
    ) -> Array<(u32, u32)> {
        let mut selected = ArrayTrait::new();
        
        if all_positions.len() == 0 {
            return selected;
        }
        
        // For distance 7, we have 4 sides of the square
        let mut top_positions = ArrayTrait::new();
        let mut right_positions = ArrayTrait::new();
        let mut bottom_positions = ArrayTrait::new();
        let mut left_positions = ArrayTrait::new();
        
        // Categorize positions by side
        let mut i = 0;
        loop {
            if i >= all_positions.len() {
                break;
            }
            let (col, row) = *all_positions[i];
            
            // Determine which side this position belongs to
            if row > center_row && col >= center_col { // Top-right
                if (row - center_row) >= (col - center_col) {
                    top_positions.append((col, row));
                } else {
                    right_positions.append((col, row));
                }
            } else if row > center_row && col < center_col { // Top-left
                if (row - center_row) >= (center_col - col) {
                    top_positions.append((col, row));
                } else {
                    left_positions.append((col, row));
                }
            } else if row < center_row && col >= center_col { // Bottom-right
                if (center_row - row) >= (col - center_col) {
                    bottom_positions.append((col, row));
                } else {
                    right_positions.append((col, row));
                }
            } else if row < center_row && col < center_col { // Bottom-left
                if (center_row - row) >= (center_col - col) {
                    bottom_positions.append((col, row));
                } else {
                    left_positions.append((col, row));
                }
            } else if row == center_row && col > center_col {
                right_positions.append((col, row));
            } else if row == center_row && col < center_col {
                left_positions.append((col, row));
            } else if col == center_col && row > center_row {
                top_positions.append((col, row));
            } else if col == center_col && row < center_row {
                bottom_positions.append((col, row));
            }
            i += 1;
        };
        
        // Select one from each side using different parts of the seed
        if top_positions.len() > 0 {
            let idx = (seed % top_positions.len().into()).try_into().unwrap();
            selected.append(*top_positions[idx]);
        }
        if right_positions.len() > 0 {
            let idx = ((seed / 1000) % right_positions.len().into()).try_into().unwrap();
            selected.append(*right_positions[idx]);
        }
        if bottom_positions.len() > 0 {
            let idx = ((seed / 1000000) % bottom_positions.len().into()).try_into().unwrap();
            selected.append(*bottom_positions[idx]);
        }
        if left_positions.len() > 0 {
            let idx = ((seed / 1000000000) % left_positions.len().into()).try_into().unwrap();
            selected.append(*left_positions[idx]);
        }
        
        selected
    }

    /// Get all positions at distance 7 (alias for compatibility)
    pub fn get_ring_positions(
        center_col: u32,
        center_row: u32,
        exact_distance: u32
    ) -> Array<(u32, u32)> {
        get_distance_positions(center_col, center_row, exact_distance)
    }

    /// Check how many prizes player can get (always 4 at distance 7)
    pub fn count_potential_prizes(
        _player_address: ContractAddress,
        _first_tile_col: u32,
        _first_tile_row: u32,
        _season_id: felt252,
        _max_radius: u32
    ) -> u32 {
        4 // Always exactly 4 prizes at distance 7
    }
}

// Utilities for integration with main game
pub mod game_integration {
    use super::*;

    /// Check prize and return reward (for contract integration)
    pub fn check_and_claim_prize(
        player_address: ContractAddress,
        col: u32,
        row: u32,
        first_tile_col: u32,
        first_tile_row: u32,
        season_id: felt252
    ) -> Option<u128> {
        prize_system::has_prize_at(
            player_address,
            col,
            row,
            first_tile_col,
            first_tile_row,
            season_id
        )
    }

    /// Get prize system information for UI
    pub fn get_prize_info_for_ui(_ring: u32) -> (u32, u32, u32) {
        // Returns: (positions_at_distance, percentage_with_prizes, total_prizes)
        let total_positions_at_7 = 28; // Approximate positions at distance 7
        let prizes_count = 4; // Always 4 prizes
        let percentage = (prizes_count * 100) / total_positions_at_7;
        
        (total_positions_at_7, percentage, prizes_count)
    }

    /// Preliminary validation of parameters
    pub fn validate_prize_check_params(
        col: u32,
        row: u32,
        first_tile_col: u32,
        first_tile_row: u32
    ) -> bool {
        // Check that coordinates are at the correct distance for prizes
        let distance = prize_system::calculate_distance(col, row, first_tile_col, first_tile_row);
        distance == PRIZE_DISTANCE
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use starknet::contract_address_const;

    #[test]
    fn test_distance_calculation() {
        assert(prize_system::calculate_distance(0, 0, 3, 4) == 7, 'Distance should be 7');
        assert(prize_system::calculate_distance(5, 5, 5, 5) == 0, 'Distance should be 0');
        assert(prize_system::calculate_distance(10, 5, 7, 9) == 7, 'Distance should be 7');
    }

    #[test]
    fn test_prize_at_exact_distance() {
        let player = contract_address_const::<0x123>();
        let season_id = 1;
        
        // Test position at distance 7 - should potentially have prize
        let result_at_7 = prize_system::has_prize_at(player, 7, 0, 0, 0, season_id);
        // Test position at distance 6 - should not have prize
        let result_at_6 = prize_system::has_prize_at(player, 6, 0, 0, 0, season_id);
        // Test position at distance 8 - should not have prize
        let result_at_8 = prize_system::has_prize_at(player, 8, 0, 0, 0, season_id);
        
        assert(result_at_6.is_none(), 'Distance 6 should have no prize');
        assert(result_at_8.is_none(), 'Distance 8 should have no prize');
        // Distance 7 may or may not have prize depending on selection, but it's the only valid distance
    }

    #[test]
    fn test_deterministic_prizes() {
        let player = contract_address_const::<0x123>();
        let season_id = 1;
        
        // Same parameters should give same result
        let result1 = prize_system::has_prize_at(player, 10, 3, 3, 3, season_id);
        let result2 = prize_system::has_prize_at(player, 10, 3, 3, 3, season_id);
        assert(result1 == result2, 'Results should be deterministic');
    }

    #[test]
    fn test_selection_seed_generation() {
        let player = contract_address_const::<0x123>();
        let season_id: felt252 = 1;
        
        // Test selection seed function
        let seed1 = prize_system::generate_selection_seed(player, 0, 0, season_id);
        let seed2 = prize_system::generate_selection_seed(player, 0, 0, season_id);
        assert(seed1 == seed2, 'Selection seed should be deterministic');
        
        let seed3 = prize_system::generate_selection_seed(player, 1, 0, season_id);
        assert(seed1 != seed3, 'Different positions should give different seeds');
    }

    #[test]
    fn test_distance_positions() {
        // Test getting positions at distance 7
        let positions = prize_system::get_distance_positions(0, 0, 7);
        assert(positions.len() > 0, 'Should have positions at distance 7');
        
        // Verify all positions are actually at distance 7
        let mut i = 0;
        loop {
            if i >= positions.len() {
                break;
            }
            let (col, row) = *positions[i];
            let distance = prize_system::calculate_distance(col, row, 0, 0);
            assert(distance == 7, 'All positions should be at distance 7');
            i += 1;
        };
    }

    #[test]
    fn test_prize_count() {
        let player = contract_address_const::<0x123>();
        let season_id = 1;
        
        // Should always return 4 prizes
        let count = prize_system::count_potential_prizes(player, 0, 0, season_id, 10);
        assert(count == 4, 'Should always have exactly 4 prizes');
    }

    #[test]
    fn test_prize_amount() {
        let player = contract_address_const::<0x123>();
        let season_id = 1;
        
        // Test that when there is a prize, it returns the correct amount
        let positions_at_7 = prize_system::get_distance_positions(5, 5, 7);
        if positions_at_7.len() > 0 {
            let (test_col, test_row) = *positions_at_7[0];
            let result = prize_system::has_prize_at(player, test_col, test_row, 5, 5, season_id);
            if result.is_some() {
                assert(result.unwrap() == PRIZE_AMOUNT, 'Prize amount should be correct');
            }
        }
    }
}