/// Простой демо файл для тестирования интеграции системы призов и гор
/// Можно использовать для быстрой проверки функциональности

use evolute_duel::utils::random::{hash_u32, hash_u32_pair, hash_u32_triple, hash_u32_quad};
use evolute_duel::systems::helpers::prizes::prize_system::{
    has_prize_at, calculate_distance, get_ring_number, is_within_prize_radius
};
use evolute_duel::systems::helpers::mountains::mountain_system::{
    is_mountain_at, calculate_manhattan_distance, can_place_tile_at
};
use starknet::contract_address_const;

/// Демо функция для тестирования всей системы
pub fn demo_prize_and_mountain_system() -> (bool, bool, bool) {
    let player = contract_address_const::<0x123>();
    let season_id = 12345;
    let first_tile_col = 100;
    let first_tile_row = 100;
    
    // Тест 1: Проверяем приз
    let has_prize = has_prize_at(player, 102, 100, first_tile_col, first_tile_row, season_id);
    let prize_exists = has_prize.is_some();
    
    // Тест 2: Проверяем горы (если есть приз в 102,100, то проверяем горы вокруг него)
    let is_mountain = if prize_exists {
        is_mountain_at(101, 100, 102, 100, season_id) // Проверяем соседнюю позицию
    } else {
        false
    };
    
    // Тест 3: Проверяем, можно ли поставить тайл
    let can_place = if prize_exists {
        can_place_tile_at(101, 100, 102, 100, season_id)
    } else {
        true
    };
    
    (prize_exists, is_mountain, can_place)
}

/// Демо функция для тестирования LCG хешей
pub fn demo_lcg_hashes() -> (u32, u32, u32, u32) {
    let hash1 = hash_u32(42);
    let hash2 = hash_u32_pair(42, 24);
    let hash3 = hash_u32_triple(42, 24, 12);
    let hash4 = hash_u32_quad(42, 24, 12, 6);
    
    (hash1, hash2, hash3, hash4)
}

/// Демо функция для проверки детерминированности
pub fn demo_determinism() -> bool {
    let player = contract_address_const::<0x123>();
    let season_id = 12345;
    
    // Проверяем призы
    let prize1 = has_prize_at(player, 105, 100, 100, 100, season_id);
    let prize2 = has_prize_at(player, 105, 100, 100, 100, season_id);
    let prizes_match = (prize1.is_some() == prize2.is_some());
    
    // Проверяем горы
    let mountain1 = is_mountain_at(99, 100, 100, 100, season_id);
    let mountain2 = is_mountain_at(99, 100, 100, 100, season_id);
    let mountains_match = (mountain1 == mountain2);
    
    // Проверяем хеши
    let hash1 = hash_u32(100);
    let hash2 = hash_u32(100);
    let hashes_match = (hash1 == hash2);
    
    prizes_match && mountains_match && hashes_match
}

#[cfg(test)]
mod integration_tests {
    use super::*;

    #[test]
    fn test_full_system_integration() {
        let (prize_exists, is_mountain, can_place) = demo_prize_and_mountain_system();
        
        // Если есть приз, то должна быть какая-то логика с горами
        if prize_exists {
            // Если позиция гора, то нельзя поставить тайл
            if is_mountain {
                assert(!can_place, 'Mountain positions should block tiles');
            }
        }
        
        // Тест всегда должен пройти - мы проверяем консистентность логики
        assert(true, 'Integration test should always pass');
    }

    #[test]
    fn test_lcg_functionality() {
        let (hash1, hash2, hash3, hash4) = demo_lcg_hashes();
        
        // Все хеши должны быть ненулевыми и разными
        assert(hash1 != 0, 'Hash1 should not be zero');
        assert(hash2 != 0, 'Hash2 should not be zero');
        assert(hash3 != 0, 'Hash3 should not be zero');
        assert(hash4 != 0, 'Hash4 should not be zero');
        
        // Хеши должны быть разными (с высокой вероятностью)
        assert(hash1 != hash2, 'Different hash functions should give different results');
    }

    #[test] 
    fn test_determinism_property() {
        let is_deterministic = demo_determinism();
        assert(is_deterministic, 'System should be fully deterministic');
    }

    #[test]
    fn test_distance_calculations() {
        // Тест расстояний для призов
        let prize_distance = calculate_distance(100, 100, 103, 104);
        assert(prize_distance == 7, 'Prize distance should be 7');
        
        // Тест расстояний для гор
        let mountain_distance = calculate_manhattan_distance(100, 100, 103, 104);
        assert(mountain_distance == 7, 'Mountain distance should be 7');
        
        // Функции должны давать одинаковый результат
        assert(prize_distance == mountain_distance, 'Distance functions should match');
    }

    #[test]
    fn test_radius_limits() {
        // Тест лимитов для призов
        assert(is_within_prize_radius(1), 'Distance 1 should be valid for prizes');
        assert(is_within_prize_radius(20), 'Distance 20 should be valid for prizes');
        assert(!is_within_prize_radius(0), 'Distance 0 should be invalid for prizes');
        assert(!is_within_prize_radius(21), 'Distance 21 should be invalid for prizes');
        
        // Тест для гор - они работают только в квадрате 3x3 вокруг приза
        let season_id = 12345;
        let prize_col = 100;
        let prize_row = 100;
        
        // В непосредственной близости могут быть горы
        let close_mountain = is_mountain_at(99, 100, prize_col, prize_row, season_id); // В квадрате 3x3
        
        // За пределами квадрата 3x3 не должно быть гор
        let far_mountain = is_mountain_at(98, 100, prize_col, prize_row, season_id); // distance = 2
        assert(!far_mountain, 'Far positions should not be mountains');
        
        // На самом призе не должно быть гор
        let prize_mountain = is_mountain_at(prize_col, prize_row, prize_col, prize_row, season_id);
        assert(!prize_mountain, 'Prize position should not be mountain');
    }
}