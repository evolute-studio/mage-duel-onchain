use starknet::ContractAddress;
use core::hash::{HashStateTrait};
use core::poseidon::PoseidonTrait;

// Константы для настройки системы призов
const MAX_PRIZE_RADIUS: u32 = 20;
const PRIZE_DENSITY_RING_1: u32 = 4; // 1 из 4 позиций (25%)
const PRIZE_DENSITY_RING_2: u32 = 6; // 1 из 6 позиций (16.7%)
const PRIZE_DENSITY_RING_3: u32 = 8; // 1 из 8 позиций (12.5%)
const DEFAULT_PRIZE_DENSITY: u32 = 10; // 1 из 10 позиций (10%)

// Размеры колец (граничные расстояния)
const RING_1_MAX: u32 = 2;
const RING_2_MAX: u32 = 5;
const RING_3_MAX: u32 = 10;

pub mod prize_system {
    use super::*;

    /// Основная функция: получить размер приза в данной
    /// позиции
    pub fn has_prize_at(
        player_address: ContractAddress,
        col: u32,
        row: u32,
        first_tile_col: u32,
        first_tile_row: u32,
        season_id: felt252,
    ) -> Option<u128> {
        // Вычисляем расстояние от первого тайла
        let distance = calculate_distance(col, row, first_tile_col, first_tile_row);

        // Проверяем, в допустимом ли радиусе
        if !is_within_prize_radius(distance) {
            return Option::None;
        }

        // Определяем номер кольца
        let ring = get_ring_number(distance);

        // Генерируем seed для этой позиции
        let position_seed = generate_position_seed(
            player_address, col, row, first_tile_col, first_tile_row, season_id,
        );

        // Проверяем, является ли позиция призовой
        if is_prize_position(position_seed, ring) {
            Option::Some(get_prize_amount_for_ring(ring))
        } else {
            Option::None
        }
    }

    /// Вычислить Manhattan distance между двумя точками
    pub fn calculate_distance(col1: u32, row1: u32, col2: u32, row2: u32) -> u32 {
        let col_diff = if col1 >= col2 {
            col1 - col2
        } else {
            col2 - col1
        };
        let row_diff = if row1 >= row2 {
            row1 - row2
        } else {
            row2 - row1
        };
        col_diff + row_diff
    }

    /// Определить номер кольца по расстоянию
    pub fn get_ring_number(distance: u32) -> u32 {
        if distance <= RING_1_MAX {
            1
        } else if distance <= RING_2_MAX {
            2
        } else if distance <= RING_3_MAX {
            3
        } else {
            4 // Все остальные кольца
        }
    }

    /// Проверить, находится ли позиция в допустимом
    /// радиусе призов
    pub fn is_within_prize_radius(distance: u32) -> bool {
        distance > 0 && distance <= MAX_PRIZE_RADIUS
    }

    /// Генерировать детерминированный seed для конкретной
    /// позиции
    pub fn generate_position_seed(
        player_address: ContractAddress,
        col: u32,
        row: u32,
        first_tile_col: u32,
        first_tile_row: u32,
        season_id: felt252,
    ) -> felt252 {
        let mut state = PoseidonTrait::new();

        // Добавляем все параметры в хеш
        state = state.update(player_address.into());
        state = state.update(col.into());
        state = state.update(row.into());
        state = state.update(first_tile_col.into());
        state = state.update(first_tile_row.into());
        state = state.update(season_id);

        state.finalize()
    }

    /// Проверить, является ли позиция призовой на основе
    /// seed и кольца
    pub fn is_prize_position(seed: felt252, ring: u32) -> bool {
        let density = get_prize_density_for_ring(ring);
        let seed_u256: u256 = seed.into();
        let remainder = seed_u256 % density.into();
        remainder == 0
    }

    /// Получить плотность призов для конкретного кольца
    pub fn get_prize_density_for_ring(ring: u32) -> u32 {
        match ring {
            1 => PRIZE_DENSITY_RING_1,
            2 => PRIZE_DENSITY_RING_2,
            3 => PRIZE_DENSITY_RING_3,
            0 | _ => DEFAULT_PRIZE_DENSITY,
        }
    }

    /// Получить размер приза для конкретного кольца
    pub fn get_prize_amount_for_ring(ring: u32) -> u128 {
        match ring {
            1 => 50, // Кольцо 1: 50 токенов (близко к старту)
            2 => 100, // Кольцо 2: 100 токенов
            3 => 200, // Кольцо 3: 200 токенов
            0 |
            _ => 300 // Дальние кольца: 300 токенов (максимальная награда)
        }
    }

    /// Получить процент призовых позиций для кольца (для
    /// UI)
    pub fn get_prize_percentage_for_ring(ring: u32) -> u32 {
        let density = get_prize_density_for_ring(ring);
        100 / density
    }

    /// Вычислить количество позиций в кольце
    /// (приблизительно)
    pub fn get_ring_size_estimate(ring: u32) -> u32 {
        match ring {
            1 => 8, // Кольцо 1: примерно 8 позиций
            2 => 16, // Кольцо 2: примерно 16 позиций
            3 => 28, // Кольцо 3: примерно 28 позиций
            0 | _ => {
                // Для дальних колец: приблизительно 8 * радиус
                let avg_radius = if ring == 4 {
                    15
                } else {
                    ring * 5
                };
                8 * avg_radius
            },
        }
    }

    /// Оценить количество призов в кольце
    pub fn estimate_prizes_in_ring(ring: u32) -> u32 {
        let ring_size = get_ring_size_estimate(ring);
        let density = get_prize_density_for_ring(ring);
        ring_size / density
    }

    /// Получить все позиции в кольце с данным радиусом
    /// (для тестирования)
    pub fn get_ring_positions(
        center_col: u32, center_row: u32, exact_distance: u32,
    ) -> Array<(u32, u32)> {
        let mut positions = ArrayTrait::new();

        // Генерируем все позиции на точном расстоянии от
        // центра
        let max_offset = exact_distance;
        let mut col_offset: u32 = 0;

        loop {
            if col_offset > max_offset {
                break;
            }

            let row_offset = exact_distance - col_offset;

            // Добавляем все 4 квадранта (если они разные)
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

                // Проверяем, что позиция уникальна и валидна
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

    /// Проверить, сколько призов игрок может получить в
    /// радиусе
    pub fn count_potential_prizes(
        player_address: ContractAddress,
        first_tile_col: u32,
        first_tile_row: u32,
        season_id: felt252,
        max_radius: u32,
    ) -> u32 {
        let mut prize_count = 0;
        let search_radius = if max_radius > MAX_PRIZE_RADIUS {
            MAX_PRIZE_RADIUS
        } else {
            max_radius
        };

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

                if has_prize_at(player_address, col, row, first_tile_col, first_tile_row, season_id)
                    .is_some() {
                    prize_count += 1;
                }
                i += 1;
            };

            distance += 1;
        };

        prize_count
    }
}

// Утилиты для интеграции с основной игрой
pub mod game_integration {
    use super::*;

    /// Проверить приз и вернуть награду (для интеграции с
    /// контрактом)
    pub fn check_and_claim_prize(
        player_address: ContractAddress,
        col: u32,
        row: u32,
        first_tile_col: u32,
        first_tile_row: u32,
        season_id: felt252,
    ) -> Option<u128> {
        prize_system::has_prize_at(
            player_address, col, row, first_tile_col, first_tile_row, season_id,
        )
    }

    /// Получить информацию о призовой системе для UI
    pub fn get_prize_info_for_ui(ring: u32) -> (u32, u32, u32) {
        let density = prize_system::get_prize_density_for_ring(ring);
        let percentage = prize_system::get_prize_percentage_for_ring(ring);
        let estimated_count = prize_system::estimate_prizes_in_ring(ring);

        (density, percentage, estimated_count)
    }

    /// Предварительная проверка валидности параметров
    pub fn validate_prize_check_params(
        col: u32, row: u32, first_tile_col: u32, first_tile_row: u32,
    ) -> bool {
        // Проверяем, что координаты в разумных пределах
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

        // Одинаковые параметры должны давать одинаковый
        // результат
        let result1 = prize_system::has_prize_at(player, 10, 10, 8, 8, season_id);
        let result2 = prize_system::has_prize_at(player, 10, 10, 8, 8, season_id);
        assert(result1 == result2, 'Results should be deterministic');
    }

    #[test]
    fn test_prize_amounts() {
        assert(prize_system::get_prize_amount_for_ring(1) == 50, 'Ring 1 should give 50 tokens');
        assert(prize_system::get_prize_amount_for_ring(2) == 100, 'Ring 2 should give 100 tokens');
        assert(prize_system::get_prize_amount_for_ring(3) == 200, 'Ring 3 should give 200 tokens');
        assert(prize_system::get_prize_amount_for_ring(4) == 300, 'Ring 4 should give 300 tokens');
    }
}
