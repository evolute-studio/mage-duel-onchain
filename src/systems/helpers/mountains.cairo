use starknet::ContractAddress;
use evolute_duel::utils::random::{hash_u32_quad, felt252_to_u32};

// Константы для системы гор
const MOUNTAIN_GENERATION_RADIUS: u32 = 1; // Только непосредственно вокруг приза
const MOUNTAIN_SEED_BASE: u32 = 0x4D4F554E; // "MOUN"
const ENTRANCE_SEED_MAGIC: u32 = 0x454E5452; // "ENTR"

pub mod mountain_system {
    use super::*;

    /// Основная функция: проверить, является ли позиция горой
    pub fn is_mountain_at(
        col: u32,
        row: u32,
        prize_col: u32,
        prize_row: u32,
        season_id: felt252
    ) -> bool {
        // Проверяем, находимся ли мы в квадрате 3x3 вокруг приза
        let col_diff = if col >= prize_col { col - prize_col } else { prize_col - col };
        let row_diff = if row >= prize_row { row - prize_row } else { prize_row - row };
        
        // Если не в квадрате 3x3 или на самом призе - не гора
        if col_diff > 1 || row_diff > 1 || (col_diff == 0 && row_diff == 0) {
            return false;
        }
        
        generate_simple_mountain_pattern(col, row, prize_col, prize_row, season_id)
    }

    /// Вычислить Manhattan distance между двумя точками
    pub fn calculate_manhattan_distance(col1: u32, row1: u32, col2: u32, row2: u32) -> u32 {
        let col_diff = if col1 >= col2 { col1 - col2 } else { col2 - col1 };
        let row_diff = if row1 >= row2 { row1 - row2 } else { row2 - row1 };
        col_diff + row_diff
    }

    /// Простая генерация паттерна гор: все позиции вокруг приза - горы, кроме одного прохода
    fn generate_simple_mountain_pattern(
        col: u32,
        row: u32,
        prize_col: u32,
        prize_row: u32,
        season_id: felt252
    ) -> bool {
        // Генерируем seed для данного приза
        let season_u32 = felt252_to_u32(season_id);
        let area_seed = hash_u32_quad(
            MOUNTAIN_SEED_BASE,
            prize_col,
            prize_row,
            season_u32
        );
        
        // Проверяем, является ли текущая позиция проходом к призу
        // Проход может быть только в одной из 4 клеток, прилегающих к призу ребром
        let is_adjacent_to_prize = (col == prize_col && (row == prize_row + 1 || row == prize_row - 1)) ||
                                  (row == prize_row && (col == prize_col + 1 || col == prize_col - 1));
        
        if is_adjacent_to_prize {
            // Определяем, какая из 4 сторон будет проходом
            let entrance_side = area_seed % 4; // 0=верх, 1=право, 2=низ, 3=лево
            
            let is_entrance = match entrance_side {
                0 => row == prize_row - 1 && col == prize_col, // Верх
                1 => col == prize_col + 1 && row == prize_row, // Право  
                2 => row == prize_row + 1 && col == prize_col, // Низ
                _ => col == prize_col - 1 && row == prize_row, // Лево
            };
            
            return !is_entrance; // Если это вход - не гора, иначе - гора
        }
        
        // Все остальные позиции в квадрате 3x3 (диагонали) - всегда горы
        true
    }


    /// Проверить, можно ли поставить тайл (не гора и в пределах досягаемости)
    pub fn can_place_tile_at(
        col: u32,
        row: u32,
        prize_col: u32,
        prize_row: u32,
        season_id: felt252
    ) -> bool {
        !is_mountain_at(col, row, prize_col, prize_row, season_id)
    }

    /// Получить все доступные позиции вокруг приза (для UI/планирования)
    pub fn get_accessible_positions_around_prize(
        prize_col: u32,
        prize_row: u32,
        season_id: felt252
    ) -> Array<(u32, u32)> {
        let mut positions = ArrayTrait::new();
        
        // Проверяем квадрат 3x3 вокруг приза
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

    /// Подсчитать количество гор вокруг приза (для отладки/статистики)
    pub fn count_mountains_around_prize(
        prize_col: u32,
        prize_row: u32,
        season_id: felt252
    ) -> u32 {
        let mut mountain_count = 0;
        
        // Проверяем квадрат 3x3 вокруг приза (исключая сам приз)
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

// Утилиты для интеграции с основной игрой
pub mod game_integration {
    use super::*;
    use evolute_duel::systems::helpers::prizes::prize_system::{has_prize_at};

    /// O(1) проверка: является ли позиция горой для любого ближайшего приза
    /// Проверяет только 9 позиций в квадрате 3x3 вокруг целевой позиции
    pub fn is_position_mountain_for_nearby_prizes(
        col: u32,
        row: u32,
        player_address: ContractAddress,
        first_tile_col: u32,
        first_tile_row: u32,
        season_id: felt252
    ) -> bool {
        // Проверяем, не является ли сама целевая позиция призом
        if has_prize_at(player_address, col, row, first_tile_col, first_tile_row, season_id).is_some() {
            return false; // Если на позиции приз - там не может быть горы
        }
        
        // Проверяем только квадрат 3x3 вокруг целевой позиции на наличие призов
        // Если рядом есть приз, он может создавать гору в нашей позиции

        let mut is_mountain = false;
        for offset_col in 0..3_u32 {
            if is_mountain { break; }
            for offset_row in 0..3_u32 {
                let potential_prize_col = col - 1 + offset_col;
                let potential_prize_row = row - 1 + offset_row;
                
                // Проверяем: есть ли приз в этой соседней позиции?
                if has_prize_at(
                    player_address,
                    potential_prize_col,
                    potential_prize_row,
                    first_tile_col,
                    first_tile_row,
                    season_id
                ).is_some() {
                    // Есть приз! Проверяем, создает ли он гору в нашей целевой позиции
                    if mountain_system::is_mountain_at(col, row, potential_prize_col, potential_prize_row, season_id) {
                        is_mountain = true;
                        break; // Если нашли гору, выходим из цикла
                    }
                }
            }
        };
        
        is_mountain
    }

    /// Быстрая проверка для известных позиций призов
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
                break; // Если нашли гору, выходим из цикла
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
        
        // Одинаковые параметры должны давать одинаковый результат
        let result1 = mountain_system::is_mountain_at(99, 100, prize_col, prize_row, season_id);
        let result2 = mountain_system::is_mountain_at(99, 100, prize_col, prize_row, season_id);
        assert(result1 == result2, 'Results should be deterministic');
    }

    #[test]
    fn test_prize_position_never_mountain() {
        let season_id: felt252 = 12345;
        let prize_col = 100;
        let prize_row = 100;
        
        // Позиция приза никогда не должна быть горой
        let is_mountain = mountain_system::is_mountain_at(prize_col, prize_row, prize_col, prize_row, season_id);
        assert(!is_mountain, 'Prize position should never be mountain');
    }

    #[test]
    fn test_distance_limit() {
        let season_id: felt252 = 12345;
        let prize_col = 100;
        let prize_row = 100;
        
        // За пределами квадрата 3x3 не должно быть гор (радиус = 1)
        let far_position = mountain_system::is_mountain_at(
            prize_col + 2, // Расстояние 2 от приза
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
        
        // Тестируем, что есть горы в диагональных позициях
        let diagonal_mountain = mountain_system::is_mountain_at(
            prize_col + 1, prize_row + 1, // Диагональ
            prize_col, prize_row, 
            season_id
        );
        assert(diagonal_mountain, 'Diagonal positions should be mountains');
        
        // Тестируем, что одна из сторон свободна (зависит от seed)
        let mut free_sides = 0;
        let sides = array![
            (prize_col, prize_row - 1), // Верх
            (prize_col + 1, prize_row), // Право
            (prize_col, prize_row + 1), // Низ  
            (prize_col - 1, prize_row), // Лево
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