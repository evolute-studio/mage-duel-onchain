use starknet::ContractAddress;
use evolute_duel::utils::random::{hash_u32_quad, felt252_to_u32};


const MOUNTAIN_GENERATION_RADIUS: u32 = 1; 
const MOUNTAIN_SEED_BASE: u32 = 0x4D4F554E; // "MOUN"
const ENTRANCE_SEED_MAGIC: u32 = 0x454E5452; // "ENTR"

pub mod mountain_system {
    use super::*;

    pub fn is_mountain_at(
        col: u32,
        row: u32,
        prize_col: u32,
        prize_row: u32,
        season_id: felt252
    ) -> bool {
        let col_diff = if col >= prize_col { col - prize_col } else { prize_col - col };
        let row_diff = if row >= prize_row { row - prize_row } else { prize_row - row };
        
        if col_diff > 1 || row_diff > 1 || (col_diff == 0 && row_diff == 0) {
            return false;
        }
        
        generate_simple_mountain_pattern(col, row, prize_col, prize_row, season_id)
    }

    pub fn calculate_manhattan_distance(col1: u32, row1: u32, col2: u32, row2: u32) -> u32 {
        let col_diff = if col1 >= col2 { col1 - col2 } else { col2 - col1 };
        let row_diff = if row1 >= row2 { row1 - row2 } else { row2 - row1 };
        col_diff + row_diff
    }

    fn generate_simple_mountain_pattern(
        col: u32,
        row: u32,
        prize_col: u32,
        prize_row: u32,
        season_id: felt252
    ) -> bool {
        let season_u32 = felt252_to_u32(season_id);
        let area_seed = hash_u32_quad(
            MOUNTAIN_SEED_BASE,
            prize_col,
            prize_row,
            season_u32
        );
        
  
        let is_adjacent_to_prize = (col == prize_col && (row == prize_row + 1 || row == prize_row - 1)) ||
                                  (row == prize_row && (col == prize_col + 1 || col == prize_col - 1));
        
        if is_adjacent_to_prize {
            let entrance_side = area_seed % 4; // 0=up, 1=right, 2=down, 3=left
            
            let is_entrance = match entrance_side {
                0 => row == prize_row - 1 && col == prize_col, // Up
                1 => col == prize_col + 1 && row == prize_row, // Right
                2 => row == prize_row + 1 && col == prize_col, // Down
                _ => col == prize_col - 1 && row == prize_row, // Left
            };
            
            return !is_entrance; 
        }
        
        true
    }


    pub fn can_place_tile_at(
        col: u32,
        row: u32,
        prize_col: u32,
        prize_row: u32,
        season_id: felt252
    ) -> bool {
        !is_mountain_at(col, row, prize_col, prize_row, season_id)
    }

    pub fn get_accessible_positions_around_prize(
        prize_col: u32,
        prize_row: u32,
        season_id: felt252
    ) -> Array<(u32, u32)> {
        let mut positions = ArrayTrait::new();
        
        for offset_col in 0..3_u32 {
            for offset_row in 0..3_u32 {
                let col = prize_col - 1 + offset_col;
                let row = prize_row - 1 + offset_row;
                
                if can_place_tile_at(col, row, prize_col, prize_row, season_id) {
                    positions.append((col, row));
                }
            }
        };
        
        positions
    }

    pub fn count_mountains_around_prize(
        prize_col: u32,
        prize_row: u32,
        season_id: felt252
    ) -> u32 {
        let mut mountain_count = 0;
        
        for offset_col in 0..3_u32 {
            for offset_row in 0..3_u32 {
                let col = prize_col - 1 + offset_col;
                let row = prize_row - 1 + offset_row;
                
                if is_mountain_at(col, row, prize_col, prize_row, season_id) {
                    mountain_count += 1;
                }
            }
        };
        
        mountain_count
    }
}

pub mod game_integration {
    use super::*;
    use evolute_duel::systems::helpers::prizes::prize_system::{has_prize_at};


    pub fn is_position_mountain_for_nearby_prizes(
        col: u32,
        row: u32,
        player_address: ContractAddress,
        first_tile_col: u32,
        first_tile_row: u32,
        season_id: felt252
    ) -> bool {
        if has_prize_at(player_address, col, row, first_tile_col, first_tile_row, season_id).is_some() {
            return false; 
        }
        
        
        let mut is_mountain = false;
        for offset_col in 0..3_u32 {
            if is_mountain { break; }
            for offset_row in 0..3_u32 {
                let potential_prize_col = col - 1 + offset_col;
                let potential_prize_row = row - 1 + offset_row;
                
                if has_prize_at(
                    player_address,
                    potential_prize_col,
                    potential_prize_row,
                    first_tile_col,
                    first_tile_row,
                    season_id
                ).is_some() {
                    if mountain_system::is_mountain_at(col, row, potential_prize_col, potential_prize_row, season_id) {
                        is_mountain = true;
                        break; 
                    }
                }
            }
        };
        
        is_mountain
    }

    pub fn is_position_blocked_by_mountains(
        col: u32,
        row: u32,
        known_prize_positions: Span<(u32, u32)>,
        season_id: felt252
    ) -> bool {
        let mut result = false;
        for prize_pos in known_prize_positions {
            let (prize_col, prize_row) = *prize_pos;
            if mountain_system::is_mountain_at(col, row, prize_col, prize_row, season_id) {
                result = true;
                break; 
            }
        };
        result
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_distance_calculation() {
        assert(
            mountain_system::calculate_manhattan_distance(0, 0, 3, 4) == 7,
            'Distance should be 7'
        );
        assert(
            mountain_system::calculate_manhattan_distance(5, 5, 5, 5) == 0,
            'Distance should be 0'
        );
    }

    #[test]
    fn test_mountain_generation_deterministic() {
        let season_id: felt252 = 12345;
        let prize_col = 100;
        let prize_row = 100;
        
        // Same parameters should give same result
        let result1 = mountain_system::is_mountain_at(99, 100, prize_col, prize_row, season_id);
        let result2 = mountain_system::is_mountain_at(99, 100, prize_col, prize_row, season_id);
        assert(result1 == result2, 'Results should be deterministic');
    }

    #[test]
    fn test_prize_position_never_mountain() {
        let season_id: felt252 = 12345;
        let prize_col = 100;
        let prize_row = 100;
        
        // Prize position should never be a mountain
        let is_mountain = mountain_system::is_mountain_at(prize_col, prize_row, prize_col, prize_row, season_id);
        assert(!is_mountain, 'Prize position should never be mountain');
    }

    #[test]
    fn test_distance_limit() {
        let season_id: felt252 = 12345;
        let prize_col = 100;
        let prize_row = 100;
        
        // Beyond 3x3 square there should be no mountains (radius = 1)
        let far_position = mountain_system::is_mountain_at(
            prize_col + 2, // Distance 2 from prize
            prize_row,
            prize_col,
            prize_row,
            season_id
        );
        assert(!far_position, 'Far positions should not be mountains');
    }

    #[test]
    fn test_simple_mountain_pattern() {
        let season_id: felt252 = 12345;
        let prize_col = 100;
        let prize_row = 100;
        
        // Test that there are mountains in diagonal positions
        let diagonal_mountain = mountain_system::is_mountain_at(
            prize_col + 1, prize_row + 1, // Diagonal
            prize_col, prize_row, 
            season_id
        );
        assert(diagonal_mountain, 'Diagonal positions should be mountains');
        
        // Test that one side is free (depends on seed)
        let mut free_sides = 0;
        let sides = array![
            (prize_col, prize_row - 1), // Top
            (prize_col + 1, prize_row), // Right
            (prize_col, prize_row + 1), // Bottom  
            (prize_col - 1, prize_row), // Left
        ];
        
        for side_pos in sides.span() {
            let (col, row) = *side_pos;
            if !mountain_system::is_mountain_at(col, row, prize_col, prize_row, season_id) {
                free_sides += 1;
            }
        };
        
        assert(free_sides == 1, 'Should be exactly one free side');
    }
}