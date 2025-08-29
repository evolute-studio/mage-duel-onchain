use starknet::ContractAddress;
use core::num::traits::Zero;
use dojo::model::{ModelStorage};
use dojo::world::{WorldStorage};

// Internal imports  
use evolute_duel::{
    constants::bitmap::{LEAGUE_SIZE, DEFAULT_RATING, LEAGUE_COUNT, LEAGUE_MIN_THRESHOLD, DEFAULT_K_FACTOR, LEAGUE_SEARCH_RADIUS},
    systems::helpers::bitmap::{Bitmap, BitmapTrait},
    models::tournament::{TournamentPass, PlayerTournamentIndex},
    types::packing::GameMode,
};

// External imports
use origami_rating::elo::EloTrait;

// Errors
mod errors {
    pub const REGISTRY_INVALID_INDEX: felt252 = 'Registry: invalid bitmap index';
    pub const REGISTRY_IS_EMPTY: felt252 = 'Registry: is empty';
    pub const REGISTRY_LEAGUE_NOT_FOUND: felt252 = 'Registry: league not found';
    pub const SLOT_DOES_NOT_EXIST: felt252 = 'Slot: does not exist';
    pub const SLOT_ALREADY_EXISTS: felt252 = 'Slot: already exists';
    pub const LEAGUE_INVALID_ID: felt252 = 'League: invalid id';
}

//------------------------------------
// Tournament Registry (bitmap-based league tracking)
//
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct TournamentRegistry {
    #[key]
    pub game_mode: GameMode,         // GameMode::Tournament
    #[key] 
    pub tournament_id: u64,    // ID турнира
    //------------------------
    pub leagues: felt252,      // BITMAP! Активные лиги (биты 1-17)
}

//------------------------------------
// Tournament League (информация о лигах)
//
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct TournamentLeague {
    #[key]
    pub game_mode: GameMode,         // GameMode::Tournament
    #[key] 
    pub tournament_id: u64,    // ID турнира
    #[key]
    pub league_id: u8,         // 1-17 (Silver I -> Global Elite)
    //------------------------
    pub size: u32,             // количество игроков в лиге
}

//------------------------------------
// Tournament Slot (игроки в очереди)
//
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct TournamentSlot {
    #[key]
    pub game_mode: GameMode,         // GameMode::Tournament
    #[key]
    pub tournament_id: u64,    // ID турнира
    #[key]
    pub league_id: u8,         // лига игрока
    #[key]
    pub slot_index: u32,       // позиция в очереди лиги
    //------------------------
    pub player_address: ContractAddress,
    pub join_time: u64,        // timestamp присоединения
}

//------------------------------------
// Player League Index (быстрый поиск позиции игрока в лиге)
//
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct PlayerLeagueIndex {
    #[key]
    pub game_mode: GameMode,         // GameMode::Tournament
    #[key]
    pub tournament_id: u64,    // ID турнира
    #[key]
    pub player_address: ContractAddress, // адрес игрока
    //------------------------
    pub league_id: u8,         // лига игрока (0 если не в очереди)
    pub slot_index: u32,       // позиция в очереди лиги (0 если не в очереди)
    pub join_time: u64,        // timestamp присоединения
}

//------------------------------------
// Registry trait implementation
//
#[generate_trait]
pub impl TournamentRegistryImpl of TournamentRegistryTrait {
    fn new(game_mode: GameMode, tournament_id: u64) -> TournamentRegistry {
        TournamentRegistry { 
            game_mode,
            tournament_id, 
            leagues: 0 
        }
    }

    fn subscribe(
        ref self: TournamentRegistry, 
        ref league: TournamentLeague, 
        player_address: ContractAddress,
        mut world: WorldStorage
    ) -> TournamentSlot {
        // Create slot for player
        let slot_index = league.size;
        let join_time = starknet::get_block_timestamp();
        let slot = TournamentSlot {
            game_mode: self.game_mode,
            tournament_id: self.tournament_id,
            league_id: league.league_id,
            slot_index,
            player_address,
            join_time,
        };
        
        // Create/Update index entry for fast lookup  
        let player_index = PlayerLeagueIndex {
            game_mode: self.game_mode,
            tournament_id: self.tournament_id,
            player_address,
            league_id: league.league_id,
            slot_index,
            join_time,
        };
        world.write_model(@player_index);
        
        // Update league size
        league.size += 1;
        
        // Update bitmap of active leagues
        self._update_league_bitmap(league.league_id, league.size);
        
        slot
    }

    fn unsubscribe(
        ref self: TournamentRegistry,
        ref league: TournamentLeague, 
        player_address: ContractAddress,
        mut world: WorldStorage
    ) {
        // Get player's current position using index
        let player_index: PlayerLeagueIndex = world.read_model((
            self.game_mode,
            self.tournament_id,
            player_address
        ));
        
        // Check if player is actually in this league
        if player_index.league_id == league.league_id && player_index.league_id != 0 {
            // Handle slot compaction (move last player to removed player's position)
            let last_slot_index = league.size - 1;
            if player_index.slot_index != last_slot_index {
                // Get the last slot
                let last_slot: TournamentSlot = world.read_model((
                    self.game_mode,
                    self.tournament_id,
                    league.league_id,
                    last_slot_index
                ));
                
                // Move last player to the removed player's position
                let mut moved_slot = TournamentSlot {
                    game_mode: self.game_mode,
                    tournament_id: self.tournament_id,
                    league_id: league.league_id,
                    slot_index: player_index.slot_index,
                    player_address: last_slot.player_address,
                    join_time: last_slot.join_time,
                };
                world.write_model(@moved_slot);
                
                // Update moved player's index
                let mut moved_player_index = PlayerLeagueIndex {
                    game_mode: self.game_mode,
                    tournament_id: self.tournament_id,
                    player_address: last_slot.player_address,
                    league_id: league.league_id,
                    slot_index: player_index.slot_index,
                    join_time: last_slot.join_time,
                };
                world.write_model(@moved_player_index);
            }
            
            // Remove the last slot (now empty after moving)
            let mut empty_slot: TournamentSlot = world.read_model((
                self.game_mode,
                self.tournament_id,
                league.league_id,
                last_slot_index
            ));
            empty_slot.player_address = starknet::contract_address_const::<0>();
            world.write_model(@empty_slot);
            
            // Clear player's index
            let empty_index = PlayerLeagueIndex {
                game_mode: self.game_mode,
                tournament_id: self.tournament_id,
                player_address,
                league_id: 0,
                slot_index: 0,
                join_time: 0,
            };
            world.write_model(@empty_index);
            
            // Update league size
            league.size -= 1;
            
            // Update bitmap
            self._update_league_bitmap(league.league_id, league.size);
        }
    }

    fn search_league(
        ref self: TournamentRegistry,
        ref player_league: TournamentLeague, 
        player_address: ContractAddress,
        world: WorldStorage
    ) -> Option<u8> {
        // Remove player from his current league
        self.unsubscribe(ref player_league, player_address, world);
        
        // Check that registry is not empty
        let leagues_u256: u256 = self.leagues.into();
        if leagues_u256 == 0 {
            return Option::None;
        }
        
        // КЛЮЧЕВОЙ АЛГОРИТМ: найти ближайшую активную лигу
        match Bitmap::nearest_significant_bit(self.leagues.into(), player_league.league_id) {
            Option::Some(found_league_id) => {
                // Проверяем принадлежность радиусу поиска
                let player_league_id = player_league.league_id;
                let league_diff = if found_league_id >= player_league_id {
                    found_league_id - player_league_id
                } else {
                    player_league_id - found_league_id
                };
                
                if league_diff <= LEAGUE_SEARCH_RADIUS {
                    Option::Some(found_league_id)
                } else {
                    Option::None
                }
            },
            Option::None => Option::None
        }
    }

    fn _update_league_bitmap(ref self: TournamentRegistry, league_id: u8, size: u32) {
        let current_bit = Bitmap::get_bit_at(self.leagues.into(), league_id.into());
        let should_be_active = size > 0;
        
        if current_bit != should_be_active {
            let new_bitmap = Bitmap::set_bit_at(
                self.leagues.into(), 
                league_id.into(), 
                should_be_active
            );
            self.leagues = new_bitmap.try_into().expect(errors::REGISTRY_INVALID_INDEX);
        }
    }

    fn _find_player_slot(
        self: @TournamentRegistry,
        league_id: u8,
        player_address: ContractAddress,
        world: WorldStorage
    ) -> Option<u32> {
        // Use PlayerLeagueIndex for O(1) lookup instead of linear search
        let player_index: PlayerLeagueIndex = world.read_model((
            *self.game_mode,
            *self.tournament_id,
            player_address
        ));
        
        // Check if player is in the specified league
        if player_index.league_id == league_id && player_index.league_id != 0 {
            Option::Some(player_index.slot_index)
        } else {
            Option::None
        }
    }
}

//------------------------------------
// League trait implementation
//
#[generate_trait]
pub impl TournamentLeagueImpl of TournamentLeagueTrait {
    fn new(game_mode: GameMode, tournament_id: u64, league_id: u8) -> TournamentLeague {
        TournamentLeague { 
            game_mode,
            tournament_id,
            league_id,
            size: 0,
        }
    }

    fn compute_id(rating: u32) -> u8 {
        if rating <= LEAGUE_MIN_THRESHOLD {
            return 1; // Silver I
        }
        let max_rating = LEAGUE_MIN_THRESHOLD + LEAGUE_SIZE * LEAGUE_COUNT.into();
        if rating >= max_rating {
            return LEAGUE_COUNT; // Global Elite
        }
        let id = 1 + (rating - LEAGUE_MIN_THRESHOLD) / LEAGUE_SIZE;
        if id > 251 {
            251
        } else if id < 1 {
            1
        } else {
            id.try_into().unwrap()
        }
    }
}

//------------------------------------
// Slot trait implementation
//
#[generate_trait]
pub impl TournamentSlotImpl of TournamentSlotTrait {
    fn new(
        game_mode: GameMode,
        tournament_id: u64,
        league_id: u8,
        slot_index: u32,
        player_address: ContractAddress
    ) -> TournamentSlot {
        TournamentSlot {
            game_mode,
            tournament_id,
            league_id,
            slot_index,
            player_address,
            join_time: starknet::get_block_timestamp(),
        }
    }

    fn nullify(ref self: TournamentSlot) {
        self.player_address = starknet::contract_address_const::<0>();
    }

    fn is_empty(self: @TournamentSlot) -> bool {
        (*self.player_address).is_zero()
    }
}

//------------------------------------
// ELO system for tournaments
//
#[generate_trait]
pub impl TournamentELOImpl of TournamentELOTrait {
    // Get player's tournament rating from TournamentPass
    fn get_tournament_player_rating(
        player_address: ContractAddress,
        tournament_id: u64,
        world: WorldStorage
    ) -> u32 {
        let index: PlayerTournamentIndex = world.read_model((player_address, tournament_id));
        if index.pass_id == 0 {
            // Player not in tournament, return default rating
            return DEFAULT_RATING;
        }
        
        let tournament_pass: TournamentPass = world.read_model(index.pass_id);
        tournament_pass.rating
    }
    
    // Update ratings after tournament match
    fn update_tournament_ratings_after_match(
        winner_address: ContractAddress,
        loser_address: ContractAddress,
        tournament_id: u64,
        mut world: WorldStorage
    ) {
        // Get tournament passes
        let winner_index: PlayerTournamentIndex = world.read_model((winner_address, tournament_id));
        let loser_index: PlayerTournamentIndex = world.read_model((loser_address, tournament_id));
        
        if winner_index.pass_id == 0 || loser_index.pass_id == 0 {
            return; // One of players not in tournament
        }
        
        let mut winner_pass: TournamentPass = world.read_model(winner_index.pass_id);
        let mut loser_pass: TournamentPass = world.read_model(loser_index.pass_id);
        
        // Calculate ELO changes using Origami library
        let (winner_change, winner_negative) = EloTrait::rating_change(
            winner_pass.rating, 
            loser_pass.rating, 
            100_u32, // Winner gets 100 points
            DEFAULT_K_FACTOR
        );
        
        let (loser_change, loser_negative) = EloTrait::rating_change(
            loser_pass.rating, 
            winner_pass.rating, 
            0_u32, // Loser gets 0 points
            DEFAULT_K_FACTOR
        );
        
        // Update winner
        if winner_negative {
            winner_pass.rating -= winner_change;
        } else {
            winner_pass.rating += winner_change;
        }
        winner_pass.wins += 1;
        winner_pass.games_played += 1;
        
        // Update loser
        if loser_negative {
            loser_pass.rating -= loser_change;
        } else {
            loser_pass.rating += loser_change;
        }
        loser_pass.losses += 1;
        loser_pass.games_played += 1;
        
        // Save updated passes
        world.write_model(@winner_pass);
        world.write_model(@loser_pass);
    }
    
    // Find tournament opponent by ELO with radius check
    fn find_tournament_opponent(
        player_address: ContractAddress,
        tournament_id: u64,
        mut world: WorldStorage
    ) -> Option<ContractAddress> {
        // Get player's rating and league
        let player_rating = Self::get_tournament_player_rating(player_address, tournament_id, world);
        let player_league_id = TournamentLeagueTrait::compute_id(player_rating);
        
        // Get registry
        let mut registry: TournamentRegistry = world.read_model((
            GameMode::Tournament, 
            tournament_id
        ));
        
        // Get player's league
        let mut player_league: TournamentLeague = world.read_model((
            GameMode::Tournament,
            tournament_id,
            player_league_id
        ));
        
        // Search for opponent using registry algorithm with radius check
        match registry.search_league(ref player_league, player_address, world) {
            Option::Some(opponent_league_id) => {
                // Update models after search_league modified them
                world.write_model(@registry);
                world.write_model(@player_league);
                
                // Find random player in the found league
                let opponent_league: TournamentLeague = world.read_model((
                    GameMode::Tournament,
                    tournament_id,
                    opponent_league_id
                ));
                
                Self::_find_random_player_in_league(
                    tournament_id, opponent_league_id, opponent_league.size, world
                )
            },
            Option::None => {
                // No suitable league found within radius, add player to their own league
                let slot = registry.subscribe(ref player_league, player_address, world);
                world.write_model(@registry);
                world.write_model(@player_league); 
                world.write_model(@slot);
                Option::None
            }
        }
    }
    
    // Helper: Find random player in league
    fn _find_random_player_in_league(
        tournament_id: u64,
        league_id: u8,
        league_size: u32,
        world: WorldStorage
    ) -> Option<ContractAddress> {
        if league_size == 0 {
            return Option::None;
        }
        
        // Simple pseudo-random: use current timestamp + league_id as seed
        let timestamp = starknet::get_block_timestamp();
        let random_index = (timestamp + league_id.into()) % league_size.into();
        
        // Try to find non-empty slot starting from random index
        let mut attempts = 0;
        let mut current_index: u32 = (random_index % league_size.into()).try_into().unwrap();

        loop {
            if attempts >= league_size {
                break Option::None;
            }
            
            let slot: TournamentSlot = world.read_model((
                GameMode::Tournament,
                tournament_id,
                league_id,
                current_index
            ));
            
            if !slot.is_empty() {
                break Option::Some(slot.player_address);
            }
            
            current_index = (current_index + 1) % league_size.into();
            attempts += 1;
        }
    }
}