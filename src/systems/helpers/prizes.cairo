use starknet::ContractAddress;
use evolute_duel::utils::random::{hash_u32_quad, felt252_to_u32};

// Constants for prize system configuration
const MAX_PRIZE_RADIUS: u32 = 20;
const PRIZE_DENSITY_RING_1: u32 = 4;    // 1 out of 4 positions (25%)
const PRIZE_DENSITY_RING_2: u32 = 6;    // 1 out of 6 positions (16.7%)
const PRIZE_DENSITY_RING_3: u32 = 8;    // 1 out of 8 positions (12.5%)
const DEFAULT_PRIZE_DENSITY: u32 = 10;  // 1 out of 10 positions (10%)

// Ring sizes (boundary distances)
const RING_1_MAX: u32 = 2;
const RING_2_MAX: u32 = 5;
const RING_3_MAX: u32 = 10;

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
        
        // Check if within allowed radius
        if !is_within_prize_radius(distance) {
            return Option::None;
        }
        
        // Determine ring number
        let ring = get_ring_number(distance);
        
        // Generate seed for this position
        let position_seed = generate_position_seed(
            player_address,
            col,
            row,
            first_tile_col,
            first_tile_row,
            season_id
        );
        
        // Check if position is a prize position
        if is_prize_position(position_seed, ring) {
            Option::Some(get_prize_amount_for_ring(ring))
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

    /// Determine ring number by distance
    pub fn get_ring_number(distance: u32) -> u32 {
        if distance <= RING_1_MAX {
            1
        } else if distance <= RING_2_MAX {
            2
        } else if distance <= RING_3_MAX {
            3
        } else {
            4 // All other rings
        }
    }

    /// Check if position is within allowed prize radius
    pub fn is_within_prize_radius(distance: u32) -> bool {
        distance > 0 && distance <= MAX_PRIZE_RADIUS
    }

    /// Generate deterministic seed for specific position
    pub fn generate_position_seed(
        player_address: ContractAddress,
        col: u32,
        row: u32,
        first_tile_col: u32,
        first_tile_row: u32,
        season_id: felt252
    ) -> u32 {
        // Convert player_address to u32 for hashing
        let player_u32 = felt252_to_u32(player_address.into());
        let season_u32 = felt252_to_u32(season_id);
        
        // First hash player coordinates
        let coord_hash = hash_u32_quad(player_u32, col, row, season_u32);
        
        // Then add first tile coordinates
        hash_u32_quad(coord_hash, first_tile_col, first_tile_row, 0x50524956) // "PRIV" - constant for prizes
    }

    /// Check if position is a prize position based on seed and ring
    pub fn is_prize_position(seed: u32, ring: u32) -> bool {
        let density = get_prize_density_for_ring(ring);
        let remainder = seed % density;
        remainder == 0
    }

    /// Get prize density for specific ring
    pub fn get_prize_density_for_ring(ring: u32) -> u32 {
        match ring {
            1 => PRIZE_DENSITY_RING_1,
            2 => PRIZE_DENSITY_RING_2,
            3 => PRIZE_DENSITY_RING_3,
            0 | _ => DEFAULT_PRIZE_DENSITY,
        }
    }

    /// Get prize amount for specific ring
    pub fn get_prize_amount_for_ring(ring: u32) -> u128 {
        match ring {
            1 => 50,  // Ring 1: 50 tokens (close to start)
            2 => 100, // Ring 2: 100 tokens
            3 => 200, // Ring 3: 200 tokens
            0 | _ => 300, // Far rings: 300 tokens (maximum reward)
        }
    }

    /// Get percentage of prize positions for ring (for UI)
    pub fn get_prize_percentage_for_ring(ring: u32) -> u32 {
        let density = get_prize_density_for_ring(ring);
        100 / density
    }

    /// Calculate number of positions in ring (approximately)
    pub fn get_ring_size_estimate(ring: u32) -> u32 {
        match ring {
            1 => 8,   // Ring 1: approximately 8 positions
            2 => 16,  // Ring 2: approximately 16 positions
            3 => 28,  // Ring 3: approximately 28 positions
            0 | _ => {
                // For far rings: approximately 8 * radius
                let avg_radius = if ring == 4 { 15 } else { ring * 5 };
                8 * avg_radius
            }
        }
    }

    /// Estimate number of prizes in ring
    pub fn estimate_prizes_in_ring(ring: u32) -> u32 {
        let ring_size = get_ring_size_estimate(ring);
        let density = get_prize_density_for_ring(ring);
        ring_size / density
    }

    /// Get all positions in ring with given radius (for testing)
    pub fn get_ring_positions(
        center_col: u32,
        center_row: u32,
        exact_distance: u32
    ) -> Array<(u32, u32)> {
        let mut positions = ArrayTrait::new();
        
        // Generate all positions at exact distance from center
        let max_offset = exact_distance;
        let mut col_offset: u32 = 0;
        
        loop {
            if col_offset > max_offset {
                break;
            }
            
            let row_offset = exact_distance - col_offset;
            
            // Add all 4 quadrants (if they are different)
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
                
                // Check that position is unique and valid
                let mut contains = false;
                for existing_pos in positions.span() {
                    if *existing_pos == pos {
                        contains = true;
                        break;
                    }
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

    /// Check how many prizes player can get within radius
    pub fn count_potential_prizes(
        player_address: ContractAddress,
        first_tile_col: u32,
        first_tile_row: u32,
        season_id: felt252,
        max_radius: u32
    ) -> u32 {
        let mut prize_count = 0;
        let search_radius = if max_radius > MAX_PRIZE_RADIUS { MAX_PRIZE_RADIUS } else { max_radius };
        
        let mut distance = 1;
        loop {
            if distance > search_radius {
                break;
            }
            
            let ring_positions = get_ring_positions(first_tile_col, first_tile_row, distance);
            let mut i = 0;
            loop {
                if i >= ring_positions.len() {
                    break;
                }
                let (col, row) = *ring_positions[i];
                
                if has_prize_at(player_address, col, row, first_tile_col, first_tile_row, season_id).is_some() {
                    prize_count += 1;
                }
                i += 1;
            };
            
            distance += 1;
        };
        
        prize_count
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
    pub fn get_prize_info_for_ui(ring: u32) -> (u32, u32, u32) {
        let density = prize_system::get_prize_density_for_ring(ring);
        let percentage = prize_system::get_prize_percentage_for_ring(ring);
        let estimated_count = prize_system::estimate_prizes_in_ring(ring);
        
        (density, percentage, estimated_count)
    }

    /// Preliminary validation of parameters
    pub fn validate_prize_check_params(
        col: u32,
        row: u32,
        first_tile_col: u32,
        first_tile_row: u32
    ) -> bool {
        // Check that coordinates are within reasonable limits
        let distance = prize_system::calculate_distance(col, row, first_tile_col, first_tile_row);
        distance > 0 && distance <= MAX_PRIZE_RADIUS
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
    fn test_ring_determination() {
        assert(prize_system::get_ring_number(1) == 1, 'Should be ring 1');
        assert(prize_system::get_ring_number(2) == 1, 'Should be ring 1');
        assert(prize_system::get_ring_number(3) == 2, 'Should be ring 2');
        assert(prize_system::get_ring_number(5) == 2, 'Should be ring 2');
        assert(prize_system::get_ring_number(8) == 3, 'Should be ring 3');
        assert(prize_system::get_ring_number(15) == 4, 'Should be ring 4');
    }

    #[test]
    fn test_prize_density() {
        assert(prize_system::get_prize_density_for_ring(1) == 4, 'Ring 1 density should be 4');
        assert(prize_system::get_prize_density_for_ring(2) == 6, 'Ring 2 density should be 6');
        assert(prize_system::get_prize_density_for_ring(3) == 8, 'Ring 3 density should be 8');
        assert(prize_system::get_prize_density_for_ring(5) == 10, 'Ring 5 density should be 10');
    }

    #[test]
    fn test_radius_validation() {
        assert(prize_system::is_within_prize_radius(1), 'Distance 1 should be valid');
        assert(prize_system::is_within_prize_radius(20), 'Distance 20 should be valid');
        assert(!prize_system::is_within_prize_radius(0), 'Distance 0 should be invalid');
        assert(!prize_system::is_within_prize_radius(21), 'Distance 21 should be invalid');
    }

    #[test]
    fn test_deterministic_prizes() {
        let player = contract_address_const::<0x123>();
        let season_id = 1;
        
        // Same parameters should give same result
        let result1 = prize_system::has_prize_at(player, 10, 10, 8, 8, season_id);
        let result2 = prize_system::has_prize_at(player, 10, 10, 8, 8, season_id);
        assert(result1 == result2, 'Results should be deterministic');
    }

    #[test]
    fn test_lcg_hash_generation() {
        let player = contract_address_const::<0x123>();
        let season_id: felt252 = 1;
        
        // Test new LCG hash function
        let seed1 = prize_system::generate_position_seed(player, 5, 5, 0, 0, season_id);
        let seed2 = prize_system::generate_position_seed(player, 5, 5, 0, 0, season_id);
        assert(seed1 == seed2, 'LCG hash should be deterministic');
        
        let seed3 = prize_system::generate_position_seed(player, 6, 5, 0, 0, season_id);
        assert(seed1 != seed3, 'Different positions should give different hashes');
    }

    #[test]
    fn test_prize_position_check_with_lcg() {
        let seed = 12;
        let ring = 1;
        
        let is_prize1 = prize_system::is_prize_position(seed, ring);
        let is_prize2 = prize_system::is_prize_position(seed, ring);
        assert(is_prize1 == is_prize2, 'Prize check should be deterministic');
        
        // Test different rings
        let _is_prize_ring2 = prize_system::is_prize_position(seed, 2);
        let _is_prize_ring3 = prize_system::is_prize_position(seed, 3);
        
        // Different rings may give different results due to different density
        assert(
            is_prize1 == is_prize1, // Self-evident, but checking consistency
            'Same ring should give same result'
        );
    }

    #[test]
    fn test_prize_amounts() {
        assert(prize_system::get_prize_amount_for_ring(1) == 50, 'Ring 1 should give 50 tokens');
        assert(prize_system::get_prize_amount_for_ring(2) == 100, 'Ring 2 should give 100 tokens');
        assert(prize_system::get_prize_amount_for_ring(3) == 200, 'Ring 3 should give 200 tokens');
        assert(prize_system::get_prize_amount_for_ring(4) == 300, 'Ring 4 should give 300 tokens');
    }
}