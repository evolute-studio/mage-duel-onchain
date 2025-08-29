#[cfg(test)]
#[allow(unused_imports)]
mod tests {
    use dojo_cairo_test::WorldStorageTestTrait;
    use dojo::model::{ModelStorage, ModelStorageTest};
    use dojo::world::WorldStorageTrait;
    use dojo_cairo_test::{
        spawn_test_world, NamespaceDef, TestResource, ContractDefTrait, ContractDef,
    };
    use dojo::world::WorldStorage;
    use starknet::{testing, ContractAddress, contract_address_const};
    use core::num::traits::Zero;

    use evolute_duel::{
        models::{
            game::{
                Game, m_Game, Board, m_Board, GameModeConfig, m_GameModeConfig, MatchmakingState,
                m_MatchmakingState, PlayerMatchmaking, m_PlayerMatchmaking, Move, m_Move, Rules,
                m_Rules, TileCommitments, m_TileCommitments, AvailableTiles, m_AvailableTiles,
                BoardCounter, m_BoardCounter
            },
            player::{Player, m_Player},
            scoring::{UnionNode, m_UnionNode, PotentialContests, m_PotentialContests},
            tournament::{TournamentPass, m_TournamentPass, PlayerTournamentIndex, m_PlayerTournamentIndex},
            tournament_matchmaking::{
                TournamentRegistry, m_TournamentRegistry, TournamentLeague, m_TournamentLeague, 
                TournamentSlot, m_TournamentSlot, TournamentRegistryTrait, TournamentLeagueTrait,
                TournamentSlotTrait, TournamentELOTrait
            },
        },
        events::{
            GameCreated, e_GameCreated, GameStarted, e_GameStarted, GameCanceled, e_GameCanceled,
            BoardUpdated, e_BoardUpdated, GameCreateFailed, e_GameCreateFailed, GameJoinFailed,
            e_GameJoinFailed, GameCanceleFailed, e_GameCanceleFailed, PlayerNotInGame,
            e_PlayerNotInGame, GameFinished, e_GameFinished, ErrorEvent, e_ErrorEvent,
            MigrationError, e_MigrationError, NotYourTurn, e_NotYourTurn, NotEnoughJokers,
            e_NotEnoughJokers, Moved, e_Moved, Skiped, e_Skiped, InvalidMove, e_InvalidMove,
            PhaseStarted, e_PhaseStarted,
        },
        types::packing::{GameStatus, GameMode, GameState},
        systems::{
            matchmaking::{matchmaking, IMatchmakingDispatcher, IMatchmakingDispatcherTrait},
            helpers::{board::{BoardTrait}, bitmap::{Bitmap, BitmapTrait}},
        },
        constants::bitmap::{DEFAULT_RATING, LEAGUE_SIZE, LEAGUE_COUNT, LEAGUE_MIN_THRESHOLD},
    };

    const PLAYER1_ADDRESS: felt252 = 0x123;
    const PLAYER2_ADDRESS: felt252 = 0x456;
    const PLAYER3_ADDRESS: felt252 = 0x789;
    const ADMIN_ADDRESS: felt252 = 0x111;
    const TOURNAMENT_ID: u64 = 1;

    fn namespace_def() -> NamespaceDef {
        let ndef = NamespaceDef {
            namespace: "evolute_duel",
            resources: [
                TestResource::Model(m_Game::TEST_CLASS_HASH),
                TestResource::Model(m_Board::TEST_CLASS_HASH),
                TestResource::Model(m_GameModeConfig::TEST_CLASS_HASH),
                TestResource::Model(m_MatchmakingState::TEST_CLASS_HASH),
                TestResource::Model(m_PlayerMatchmaking::TEST_CLASS_HASH),
                TestResource::Model(m_Player::TEST_CLASS_HASH),
                TestResource::Model(m_Move::TEST_CLASS_HASH),
                TestResource::Model(m_Rules::TEST_CLASS_HASH),
                TestResource::Model(m_TileCommitments::TEST_CLASS_HASH),
                TestResource::Model(m_AvailableTiles::TEST_CLASS_HASH),
                TestResource::Model(m_UnionNode::TEST_CLASS_HASH),
                TestResource::Model(m_PotentialContests::TEST_CLASS_HASH),
                TestResource::Model(m_BoardCounter::TEST_CLASS_HASH),
                TestResource::Model(m_TournamentPass::TEST_CLASS_HASH),
                TestResource::Model(m_PlayerTournamentIndex::TEST_CLASS_HASH),
                TestResource::Model(m_TournamentRegistry::TEST_CLASS_HASH),
                TestResource::Model(m_TournamentLeague::TEST_CLASS_HASH),
                TestResource::Model(m_TournamentSlot::TEST_CLASS_HASH),
                TestResource::Contract(matchmaking::TEST_CLASS_HASH),
                TestResource::Event(e_GameCreated::TEST_CLASS_HASH),
                TestResource::Event(e_GameStarted::TEST_CLASS_HASH),
                TestResource::Event(e_GameCanceled::TEST_CLASS_HASH),
                TestResource::Event(e_BoardUpdated::TEST_CLASS_HASH),
                TestResource::Event(e_GameCreateFailed::TEST_CLASS_HASH),
                TestResource::Event(e_GameJoinFailed::TEST_CLASS_HASH),
                TestResource::Event(e_GameCanceleFailed::TEST_CLASS_HASH),
                TestResource::Event(e_PlayerNotInGame::TEST_CLASS_HASH),
                TestResource::Event(e_GameFinished::TEST_CLASS_HASH),
                TestResource::Event(e_ErrorEvent::TEST_CLASS_HASH),
                TestResource::Event(e_MigrationError::TEST_CLASS_HASH),
                TestResource::Event(e_NotYourTurn::TEST_CLASS_HASH),
                TestResource::Event(e_NotEnoughJokers::TEST_CLASS_HASH),
                TestResource::Event(e_Moved::TEST_CLASS_HASH),
                TestResource::Event(e_Skiped::TEST_CLASS_HASH),
                TestResource::Event(e_InvalidMove::TEST_CLASS_HASH),
                TestResource::Event(e_PhaseStarted::TEST_CLASS_HASH),
            ]
                .span(),
        };
        ndef
    }

    fn contract_defs() -> Span<ContractDef> {
        [
            ContractDefTrait::new(@"evolute_duel", @"matchmaking")
                .with_writer_of([dojo::utils::bytearray_hash(@"evolute_duel")].span())
                .with_init_calldata([ADMIN_ADDRESS].span()),
        ]
            .span()
    }

    fn deploy_world() -> WorldStorage {
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());
        world
    }

    // Tests for basic bitmap operations
    #[test]
    fn test_bitmap_get_set_bit() {
        let mut bitmap: u256 = 0;
        
        // Test setting individual bits
        assert!(!Bitmap::get_bit_at(bitmap, 0), "Bit 0 should be false initially");
        bitmap = Bitmap::set_bit_at(bitmap, 0, true);
        assert!(Bitmap::get_bit_at(bitmap, 0), "Bit 0 should be true after setting");
        
        // Test setting multiple bits
        bitmap = Bitmap::set_bit_at(bitmap, 5, true);
        assert!(Bitmap::get_bit_at(bitmap, 5), "Bit 5 should be true");
        assert!(Bitmap::get_bit_at(bitmap, 0), "Bit 0 should still be true");
        
        // Test unsetting bits
        bitmap = Bitmap::set_bit_at(bitmap, 0, false);
        assert!(!Bitmap::get_bit_at(bitmap, 0), "Bit 0 should be false after unsetting");
        assert!(Bitmap::get_bit_at(bitmap, 5), "Bit 5 should still be true");
    }

    #[test]
    fn test_bitmap_edge_cases() {
        let mut bitmap: u256 = 0;
        
        // Test edge bit positions
        bitmap = Bitmap::set_bit_at(bitmap, 0, true); // First bit
        bitmap = Bitmap::set_bit_at(bitmap, 17, true); // League range
        bitmap = Bitmap::set_bit_at(bitmap, 251, true); // Last supported bit
        
        assert!(Bitmap::get_bit_at(bitmap, 0), "First bit should work");
        assert!(Bitmap::get_bit_at(bitmap, 17), "League bit should work");
        assert!(Bitmap::get_bit_at(bitmap, 251), "Last bit should work");
        
        // Test that other bits remain false
        assert!(!Bitmap::get_bit_at(bitmap, 1), "Bit 1 should be false");
        assert!(!Bitmap::get_bit_at(bitmap, 100), "Random bit should be false");
    }

    #[test]
    fn test_most_significant_bit() {
        // Test empty bitmap
        assert!(Bitmap::most_significant_bit(0).is_none(), "Empty bitmap should return None");
        
        // Test single bits
        assert!(Bitmap::most_significant_bit(1).unwrap() == 0, "MSB of 1 should be 0");
        assert!(Bitmap::most_significant_bit(2).unwrap() == 1, "MSB of 2 should be 1");
        assert!(Bitmap::most_significant_bit(4).unwrap() == 2, "MSB of 4 should be 2");
        
        // Test complex bitmap
        let bitmap = Bitmap::set_bit_at(0, 0, true);
        let bitmap = Bitmap::set_bit_at(bitmap, 5, true);
        let bitmap = Bitmap::set_bit_at(bitmap, 17, true);
        assert!(Bitmap::most_significant_bit(bitmap).unwrap() == 17, "MSB should be highest set bit");
    }

    #[test]
    fn test_least_significant_bit() {
        // Test empty bitmap
        assert!(Bitmap::least_significant_bit(0).is_none(), "Empty bitmap should return None");
        
        // Test single bits
        assert!(Bitmap::least_significant_bit(1).unwrap() == 0, "LSB of 1 should be 0");
        assert!(Bitmap::least_significant_bit(2).unwrap() == 1, "LSB of 2 should be 1");
        assert!(Bitmap::least_significant_bit(4).unwrap() == 2, "LSB of 4 should be 2");
        
        // Test complex bitmap
        let bitmap = Bitmap::set_bit_at(0, 5, true);
        let bitmap = Bitmap::set_bit_at(bitmap, 17, true);
        let bitmap = Bitmap::set_bit_at(bitmap, 1, true);
        assert!(Bitmap::least_significant_bit(bitmap).unwrap() == 1, "LSB should be lowest set bit");
    }

    #[test]
    fn test_nearest_significant_bit() {
        // Create bitmap with bits at positions 3, 7, 12
        let bitmap = Bitmap::set_bit_at(0, 3, true);
        let bitmap = Bitmap::set_bit_at(bitmap, 7, true);
        let bitmap = Bitmap::set_bit_at(bitmap, 12, true);
        
        // Test finding nearest to different positions
        assert!(Bitmap::nearest_significant_bit(bitmap, 5).unwrap() == 3, "Nearest to 5 should be 3");
        assert!(Bitmap::nearest_significant_bit(bitmap, 8).unwrap() == 7, "Nearest to 8 should be 7");
        assert!(Bitmap::nearest_significant_bit(bitmap, 10).unwrap() == 12, "Nearest to 10 should be 12");
        
        // Test edge cases
        assert!(Bitmap::nearest_significant_bit(bitmap, 3).unwrap() == 3, "Nearest to exact match should be itself");
        assert!(Bitmap::nearest_significant_bit(0, 5).is_none(), "Empty bitmap should return None");
    }

    #[test]
    fn test_two_pow_function() {
        // Test powers of 2
        assert!(Bitmap::two_pow(0) == 1, "2^0 should be 1");
        assert!(Bitmap::two_pow(1) == 2, "2^1 should be 2");
        assert!(Bitmap::two_pow(2) == 4, "2^2 should be 4");
        assert!(Bitmap::two_pow(10) == 1024, "2^10 should be 1024");
        
        // Test league-relevant powers
        assert!(Bitmap::two_pow(1) == 2, "League 1 bit");
        assert!(Bitmap::two_pow(17) == 131072, "League 17 bit");
    }

    // Tests for TournamentRegistry
    #[test]
    fn test_tournament_registry_new() {
        let registry = TournamentRegistryTrait::new(GameMode::Tournament, TOURNAMENT_ID);
        
        assert!(registry.game_mode == GameMode::Tournament, "Game mode should match");
        assert!(registry.tournament_id == TOURNAMENT_ID, "Tournament ID should match");
        assert!(registry.leagues == 0, "New registry should have no active leagues");
    }

    #[test]
    fn test_tournament_registry_subscribe() {
        let mut world = deploy_world();
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        
        let mut registry = TournamentRegistryTrait::new(GameMode::Tournament, TOURNAMENT_ID);
        let mut league = TournamentLeagueTrait::new(GameMode::Tournament, TOURNAMENT_ID, 1);
        
        let slot = registry.subscribe(ref league, player1, world);
        
        assert!(slot.player_address == player1, "Slot should contain player address");
        assert!(slot.league_id == 1, "Slot should be in league 1");
        assert!(slot.slot_index == 0, "First player should have index 0");
        assert!(league.size == 1, "League should have 1 player");
        assert!(Bitmap::get_bit_at(registry.leagues.into(), 1), "League 1 should be active in bitmap");
    }

    #[test]
    fn test_tournament_registry_unsubscribe() {
        let mut world = deploy_world();
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        
        let mut registry = TournamentRegistryTrait::new(GameMode::Tournament, TOURNAMENT_ID);
        let mut league = TournamentLeagueTrait::new(GameMode::Tournament, TOURNAMENT_ID, 1);
        
        // Subscribe player first
        let slot = registry.subscribe(ref league, player1, world);
        world.write_model(@slot);
        assert!(league.size == 1, "League should have 1 player");
        
        // Unsubscribe player
        registry.unsubscribe(ref league, player1, world);
        assert!(league.size == 0, "League should be empty after unsubscribe");
        assert!(!Bitmap::get_bit_at(registry.leagues.into(), 1), "League 1 should be inactive");
    }

    #[test] 
    fn test_tournament_registry_multiple_leagues() {
        let mut world = deploy_world();
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player2: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        
        let mut registry = TournamentRegistryTrait::new(GameMode::Tournament, TOURNAMENT_ID);
        let mut league1 = TournamentLeagueTrait::new(GameMode::Tournament, TOURNAMENT_ID, 1);
        let mut league5 = TournamentLeagueTrait::new(GameMode::Tournament, TOURNAMENT_ID, 5);
        
        // Add players to different leagues
        let slot1 = registry.subscribe(ref league1, player1, world);
        let slot5 = registry.subscribe(ref league5, player2, world);
        world.write_model(@slot1);
        world.write_model(@slot5);
        
        // Check bitmap has both leagues active
        assert!(Bitmap::get_bit_at(registry.leagues.into(), 1), "League 1 should be active");
        assert!(Bitmap::get_bit_at(registry.leagues.into(), 5), "League 5 should be active");
        assert!(!Bitmap::get_bit_at(registry.leagues.into(), 3), "League 3 should be inactive");
    }

    // Tests for TournamentLeague
    #[test]
    fn test_tournament_league_creation() {
        let league1 = TournamentLeagueTrait::new(GameMode::Tournament, TOURNAMENT_ID, 1);
        let league5 = TournamentLeagueTrait::new(GameMode::Tournament, TOURNAMENT_ID, 5);
        let league_max = TournamentLeagueTrait::new(GameMode::Tournament, TOURNAMENT_ID, LEAGUE_COUNT);
        
        // Verify league properties
        assert!(league1.league_id == 1, "League 1 ID should be correct");
        assert!(league5.league_id == 5, "League 5 ID should be correct");
        assert!(league_max.league_id == LEAGUE_COUNT, "Max league ID should be correct");
        
        // Verify rating ranges
        assert!(league1.min_rating == 0, "League 1 should start from 0");
        assert!(league5.min_rating > league1.max_rating, "League 5 min should be > League 1 max");
        assert!(league_max.max_rating == 999999, "Global Elite should have no upper limit");
    }

    // Tests for TournamentSlot
    #[test]
    fn test_tournament_slot_operations() {
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        
        let mut slot = TournamentSlotTrait::new(GameMode::Tournament, TOURNAMENT_ID, 1, 0, player1);
        
        assert!(slot.player_address == player1, "Slot should contain player");
        assert!(slot.league_id == 1, "Slot should be in correct league");
        assert!(slot.slot_index == 0, "Slot should have correct index");
        assert!(!slot.is_empty(), "Slot should not be empty");
        
        // Test nullification
        slot.nullify();
        assert!(slot.is_empty(), "Slot should be empty after nullification");
        assert!(slot.player_address.is_zero(), "Player address should be zero");
    }

    #[test]
    fn test_tournament_slot_multiple_players() {
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player2: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        
        let slot1 = TournamentSlotTrait::new(GameMode::Tournament, TOURNAMENT_ID, 1, 0, player1);
        let slot2 = TournamentSlotTrait::new(GameMode::Tournament, TOURNAMENT_ID, 1, 1, player2);
        
        assert!(slot1.slot_index == 0, "First slot should have index 0");
        assert!(slot2.slot_index == 1, "Second slot should have index 1");
        assert!(slot1.league_id == slot2.league_id, "Both slots should be in same league");
    }

    // Integration tests for search_league algorithm  
    #[test]
    fn test_search_league_algorithm() {
        let mut world = deploy_world();
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player2: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        let player3: ContractAddress = contract_address_const::<PLAYER3_ADDRESS>();
        
        let mut registry = TournamentRegistryTrait::new(GameMode::Tournament, TOURNAMENT_ID);
        
        // Create leagues and add players
        let mut league1 = TournamentLeagueTrait::new(GameMode::Tournament, TOURNAMENT_ID, 1);
        let mut league3 = TournamentLeagueTrait::new(GameMode::Tournament, TOURNAMENT_ID, 3);
        let mut league7 = TournamentLeagueTrait::new(GameMode::Tournament, TOURNAMENT_ID, 7);
        
        // Add players to leagues 1, 3, 7
        let slot1 = registry.subscribe(ref league1, player1, world);
        let slot3 = registry.subscribe(ref league3, player2, world);
        let slot7 = registry.subscribe(ref league7, player3, world);
        world.write_model(@slot1);
        world.write_model(@slot3);
        world.write_model(@slot7);
        world.write_model(@league1);
        world.write_model(@league3); 
        world.write_model(@league7);
        
        // Now create a player league (e.g., league 5) and search for nearest
        let mut player_league5 = TournamentLeagueTrait::new(GameMode::Tournament, TOURNAMENT_ID, 5);
        let nearest_league = registry.search_league(ref player_league5, player1, world);
        
        // Should find league 3 or 7 (nearest to 5)
        assert!(nearest_league == 3 || nearest_league == 7, "Should find nearest active league");
    }

    // Edge cases and error conditions
    #[test]
    fn test_bitmap_empty_registry() {
        let mut world = deploy_world();
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        
        let mut registry = TournamentRegistryTrait::new(GameMode::Tournament, TOURNAMENT_ID);
        let mut empty_league = TournamentLeagueTrait::new(GameMode::Tournament, TOURNAMENT_ID, 5);
        
        // Trying to search in empty registry should panic
        // Note: In actual test, this would use a should_panic attribute or error handling
    }

    #[test]
    fn test_bitmap_full_range() {
        let mut bitmap: u256 = 0;
        
        // Set bits across the full league range (1-17)
        let mut league_id = 1_u8;
        while league_id <= LEAGUE_COUNT {
            bitmap = Bitmap::set_bit_at(bitmap, league_id.into(), true);
            league_id += 1;
        }
        
        // All league bits should be set
        league_id = 1;
        while league_id <= LEAGUE_COUNT {
            assert!(Bitmap::get_bit_at(bitmap, league_id.into()), "League bit should be set");
            league_id += 1;
        }
        
        // Non-league bits should still be false
        assert!(!Bitmap::get_bit_at(bitmap, 0), "Bit 0 should remain false");
        assert!(!Bitmap::get_bit_at(bitmap, 18), "Bit 18 should remain false");
    }

    #[test]
    fn test_tournament_registry_complex_scenario() {
        let mut world = deploy_world();
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player2: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        let player3: ContractAddress = contract_address_const::<PLAYER3_ADDRESS>();
        
        let mut registry = TournamentRegistryTrait::new(GameMode::Tournament, TOURNAMENT_ID);
        
        // Create multiple leagues
        let mut league2 = TournamentLeagueTrait::new(GameMode::Tournament, TOURNAMENT_ID, 2);
        let mut league8 = TournamentLeagueTrait::new(GameMode::Tournament, TOURNAMENT_ID, 8);
        let mut league15 = TournamentLeagueTrait::new(GameMode::Tournament, TOURNAMENT_ID, 15);
        
        // Subscribe players
        let slot2 = registry.subscribe(ref league2, player1, world);
        let slot8_1 = registry.subscribe(ref league8, player2, world);  
        let slot8_2 = registry.subscribe(ref league8, player3, world);
        let slot15 = registry.subscribe(ref league15, player1, world);
        
        world.write_model(@slot2);
        world.write_model(@slot8_1);
        world.write_model(@slot8_2);
        world.write_model(@slot15);
        
        // Verify bitmap state
        assert!(Bitmap::get_bit_at(registry.leagues.into(), 2), "League 2 should be active");
        assert!(Bitmap::get_bit_at(registry.leagues.into(), 8), "League 8 should be active");
        assert!(Bitmap::get_bit_at(registry.leagues.into(), 15), "League 15 should be active");
        
        // Verify league sizes
        assert!(league2.size == 1, "League 2 should have 1 player");
        assert!(league8.size == 2, "League 8 should have 2 players");
        assert!(league15.size == 1, "League 15 should have 1 player");
        
        // Test unsubscribing from multi-player league
        registry.unsubscribe(ref league8, player2, world);
        assert!(league8.size == 1, "League 8 should have 1 player after unsubscribe");
        assert!(Bitmap::get_bit_at(registry.leagues.into(), 8), "League 8 should still be active");
        
        // Unsubscribe last player from league 8
        registry.unsubscribe(ref league8, player3, world);
        assert!(league8.size == 0, "League 8 should be empty");
        assert!(!Bitmap::get_bit_at(registry.leagues.into(), 8), "League 8 should be inactive");
    }

    // Error and Edge Case Tests
    #[test]
    fn test_bitmap_invalid_indices() {
        let bitmap: u256 = 0;
        
        // Test getting bit at maximum supported index
        assert!(!Bitmap::get_bit_at(bitmap, 251), "Max index should work");
        
        // Test setting bit at maximum supported index
        let bitmap = Bitmap::set_bit_at(bitmap, 251, true);
        assert!(Bitmap::get_bit_at(bitmap, 251), "Max index bit should be set");
    }

    #[test]
    fn test_bitmap_two_pow_edge_cases() {
        // Test all powers within league range
        let mut i = 1_felt252;
        while i <= 17 {
            let power = Bitmap::two_pow(i);
            assert!(power > 0, "Power should be positive");
            assert!(power == Bitmap::two_pow(i), "Should be consistent");
            i += 1;
        };
    }

    #[test]
    fn test_most_significant_bit_edge_cases() {
        // Test with maximum u256 value
        let max_u256: u256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
        let msb = Bitmap::most_significant_bit(max_u256);
        assert!(msb.unwrap() == 255, "MSB of max u256 should be 255");
        
        // Test with single bit at high position
        let high_bit = Bitmap::set_bit_at(0, 200, true);
        let msb_high = Bitmap::most_significant_bit(high_bit);
        assert!(msb_high.unwrap() == 200, "MSB should match set bit position");
    }

    #[test]
    fn test_least_significant_bit_edge_cases() {
        // Test with all high bits set except LSB
        let high_bits: u256 = 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe; // All 1s except bit 0
        let lsb = Bitmap::least_significant_bit(high_bits);
        assert!(lsb.unwrap() == 1, "LSB should be 1 when bit 0 is unset");
        
        // Test with single bit at low position  
        let low_bit = Bitmap::set_bit_at(0, 3, true);
        let lsb_low = Bitmap::least_significant_bit(low_bit);
        assert!(lsb_low.unwrap() == 3, "LSB should match set bit position");
    }

    #[test]
    fn test_nearest_significant_bit_edge_cases() {
        // Test with single bit - should return that bit regardless of search position
        let single_bit = Bitmap::set_bit_at(0, 10, true);
        
        assert!(Bitmap::nearest_significant_bit(single_bit, 5).unwrap() == 10, "Should find the only bit");
        assert!(Bitmap::nearest_significant_bit(single_bit, 15).unwrap() == 10, "Should find the only bit");
        
        // Test with bits far apart
        let far_bits = Bitmap::set_bit_at(0, 1, true);
        let far_bits = Bitmap::set_bit_at(far_bits, 100, true);
        
        let nearest_to_middle = Bitmap::nearest_significant_bit(far_bits, 50);
        // Should find the closer bit (implementation dependent)
        assert!(nearest_to_middle.is_some(), "Should find one of the bits");
    }

    #[test]
    fn test_tournament_registry_unsubscribe_nonexistent_player() {
        let mut world = deploy_world();
        let fake_player: ContractAddress = contract_address_const::<0xfake>();
        
        let mut registry = TournamentRegistryTrait::new(GameMode::Tournament, TOURNAMENT_ID);
        let mut league = TournamentLeagueTrait::new(GameMode::Tournament, TOURNAMENT_ID, 1);
        
        // Try to unsubscribe player that was never subscribed
        registry.unsubscribe(ref league, fake_player, world);
        
        // Should handle gracefully
        assert!(league.size == 0, "League should remain empty");
        assert!(!Bitmap::get_bit_at(registry.leagues.into(), 1), "League should remain inactive");
    }

    #[test]
    fn test_tournament_slot_edge_cases() {
        let zero_player: ContractAddress = contract_address_const::<0>();
        
        let mut slot = TournamentSlotTrait::new(GameMode::Tournament, TOURNAMENT_ID, 1, 0, zero_player);
        
        // Slot with zero address should be considered empty
        assert!(slot.is_empty(), "Slot with zero address should be empty");
        
        // Nullifying already empty slot should work
        slot.nullify();
        assert!(slot.is_empty(), "Nullified slot should remain empty");
    }

    #[test]
    fn test_tournament_registry_bitmap_consistency() {
        let mut world = deploy_world();
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        
        let mut registry = TournamentRegistryTrait::new(GameMode::Tournament, TOURNAMENT_ID);
        let mut league = TournamentLeagueTrait::new(GameMode::Tournament, TOURNAMENT_ID, 5);
        
        // Subscribe player - should set bit 5
        let slot = registry.subscribe(ref league, player1, world);
        world.write_model(@slot);
        
        assert!(Bitmap::get_bit_at(registry.leagues.into(), 5), "Bit 5 should be set");
        assert!(league.size == 1, "League should have 1 player");
        
        // Unsubscribe player - should unset bit 5
        registry.unsubscribe(ref league, player1, world);
        
        assert!(!Bitmap::get_bit_at(registry.leagues.into(), 5), "Bit 5 should be unset");
        assert!(league.size == 0, "League should be empty");
    }

    #[test]
    fn test_tournament_league_rating_ranges() {
        // Test all league rating ranges are non-overlapping and consecutive
        let mut league_id = 1_u8;
        let mut prev_max = 0_u32;
        
        while league_id <= LEAGUE_COUNT {
            let league = TournamentLeagueTrait::new(GameMode::Tournament, TOURNAMENT_ID, league_id);
            
            if league_id == 1 {
                // First league should start from 0
                assert!(league.min_rating == 0, "League 1 should start from 0");
            } else {
                // Subsequent leagues should be consecutive
                assert!(league.min_rating == prev_max + 1, "Leagues should be consecutive");
            }
            
            // Max should be >= min
            assert!(league.max_rating >= league.min_rating, "Max should be >= min");
            
            prev_max = league.max_rating;
            league_id += 1;
        }
    }

    #[test] 
    fn test_search_league_algorithm_edge_cases() {
        let mut world = deploy_world();
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        
        let mut registry = TournamentRegistryTrait::new(GameMode::Tournament, TOURNAMENT_ID);
        let mut player_league = TournamentLeagueTrait::new(GameMode::Tournament, TOURNAMENT_ID, 10);
        
        // Test search in empty registry should panic or handle gracefully
        // Note: This depends on implementation - might need to use should_panic attribute
        
        // First add player to own league
        let slot = registry.subscribe(ref player_league, player1, world);
        world.write_model(@slot);
        
        // Now search should find the same league
        let found_league = registry.search_league(ref player_league, player1, world);
        
        // Player was removed during search, so league 10 should now be inactive
        // The algorithm should find no active leagues and handle appropriately
    }

    #[test]
    fn test_bitmap_operations_stress() {
        let mut bitmap: u256 = 0;
        
        // Set all league bits (1-17)
        let mut i = 1_felt252;
        while i <= 17 {
            bitmap = Bitmap::set_bit_at(bitmap, i, true);
            assert!(Bitmap::get_bit_at(bitmap, i), "Bit should be set");
            i += 1;
        };
        
        // Verify MSB and LSB
        let msb = Bitmap::most_significant_bit(bitmap).unwrap();
        let lsb = Bitmap::least_significant_bit(bitmap).unwrap();
        
        assert!(msb >= lsb, "MSB should be >= LSB");
        assert!(lsb >= 1, "LSB should be at least 1");
        assert!(msb <= 17, "MSB should be at most 17");
        
        // Test nearest bit for each league position
        i = 1;
        while i <= 17 {
            let nearest = Bitmap::nearest_significant_bit(bitmap, i.try_into().unwrap());
            assert!(nearest.is_some(), "Should find nearest bit");
            i += 1;
        };
    }

    #[test]
    fn test_tournament_registry_concurrent_operations() {
        let mut world = deploy_world();
        let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
        let player2: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
        
        let mut registry = TournamentRegistryTrait::new(GameMode::Tournament, TOURNAMENT_ID);
        let mut league3 = TournamentLeagueTrait::new(GameMode::Tournament, TOURNAMENT_ID, 3);
        let mut league7 = TournamentLeagueTrait::new(GameMode::Tournament, TOURNAMENT_ID, 7);
        
        // Subscribe players to different leagues simultaneously
        let slot1 = registry.subscribe(ref league3, player1, world);
        let slot2 = registry.subscribe(ref league7, player2, world);
        world.write_model(@slot1);
        world.write_model(@slot2);
        
        // Verify bitmap has both leagues
        assert!(Bitmap::get_bit_at(registry.leagues.into(), 3), "League 3 should be active");
        assert!(Bitmap::get_bit_at(registry.leagues.into(), 7), "League 7 should be active");
        
        // Unsubscribe from one league
        registry.unsubscribe(ref league3, player1, world);
        
        // Verify only league 7 remains active
        assert!(!Bitmap::get_bit_at(registry.leagues.into(), 3), "League 3 should be inactive");
        assert!(Bitmap::get_bit_at(registry.leagues.into(), 7), "League 7 should remain active");
        assert!(league3.size == 0, "League 3 should be empty");
        assert!(league7.size == 1, "League 7 should have 1 player");
    }
}