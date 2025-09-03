use starknet::ContractAddress;
use core::num::traits::Zero;
use dojo::model::{ModelStorage};
use dojo::world::{WorldStorage};

// Internal imports  
use evolute_duel::{
    constants::bitmap::{LEAGUE_SIZE, DEFAULT_RATING, LEAGUE_COUNT, LEAGUE_MIN_THRESHOLD, DEFAULT_K_FACTOR, LEAGUE_SEARCH_RADIUS},
    systems::helpers::bitmap::{Bitmap},
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
    pub game_mode: u8,         // GameMode::Tournament as u8
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
    pub game_mode: u8,         // GameMode::Tournament as u8
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
    pub game_mode: u8,         // GameMode::Tournament as u8
    #[key]
    pub tournament_id: u64,    // ID турнира
    #[key]
    pub league_id: u8,         // лига игрока
    #[key]
    pub slot_index: u32,       // позиция в очереди лиги
    //------------------------
    pub player_address: ContractAddress,
}

//------------------------------------
// Player League Index (быстрый поиск позиции игрока в лиге)
//
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct PlayerLeagueIndex {
    #[key]
    pub game_mode: u8,         // GameMode::Tournament as u8
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
    fn new(game_mode: u8, tournament_id: u64) -> TournamentRegistry {
        println!("[TournamentRegistryTrait::new] Creating new registry");
        println!("[TournamentRegistryTrait::new] game_mode: {}, tournament_id: {}", game_mode, tournament_id);
        let registry = TournamentRegistry { 
            game_mode,
            tournament_id, 
            leagues: 0 
        };
        println!("[TournamentRegistryTrait::new] Registry created with leagues bitmap: {}", registry.leagues);
        registry
    }

    fn subscribe(
        ref self: TournamentRegistry, 
        ref league: TournamentLeague, 
        ref player_index: PlayerLeagueIndex
    ) -> TournamentSlot {
        println!("[TournamentRegistryTrait::subscribe] Starting subscription");
        println!("[TournamentRegistryTrait::subscribe] tournament_id: {}, league_id: {}", self.tournament_id, league.league_id);
        println!("[TournamentRegistryTrait::subscribe] player_address: {:x}", player_index.player_address);
        println!("[TournamentRegistryTrait::subscribe] current leagues bitmap: {}", self.leagues);
        println!("[TournamentRegistryTrait::subscribe] league size before: {}", league.size);
        
        let slot = league.subscribe(ref player_index);
        println!("[TournamentRegistryTrait::subscribe] slot created at index: {}", slot.slot_index);
        
        // Update bitmap of active leagues
        self._update_league_bitmap(league.league_id, league.size);
        println!("[TournamentRegistryTrait::subscribe] leagues bitmap after update: {}", self.leagues);
        
        slot
    }

    fn unsubscribe(
        ref self: TournamentRegistry,
        ref league: TournamentLeague, 
        ref player_index: PlayerLeagueIndex
    ) {
        println!("[TournamentRegistryTrait::unsubscribe] Starting unsubscription");
        println!("[TournamentRegistryTrait::unsubscribe] tournament_id: {}, league_id: {}", self.tournament_id, league.league_id);
        println!("[TournamentRegistryTrait::unsubscribe] player_address: {:x}", player_index.player_address);
        println!("[TournamentRegistryTrait::unsubscribe] current leagues bitmap: {}", self.leagues);
        println!("[TournamentRegistryTrait::unsubscribe] league size before: {}", league.size);
        
        league.unsubscribe(ref player_index);
        println!("[TournamentRegistryTrait::unsubscribe] league size after: {}", league.size);
        
        // Update bitmap
        self._update_league_bitmap(league.league_id, league.size);
        println!("[TournamentRegistryTrait::unsubscribe] leagues bitmap after update: {}", self.leagues);
    }

    fn search_league(
        ref self: TournamentRegistry,
        ref league: TournamentLeague, 
        ref player_index: PlayerLeagueIndex,
    ) -> Option<u8> {
        println!("[TournamentRegistryTrait::search_league] Starting league search");
        println!("[TournamentRegistryTrait::search_league] tournament_id: {}, player_league_id: {}", self.tournament_id, league.league_id);
        println!("[TournamentRegistryTrait::search_league] player_address: {:x}", player_index.player_address);
        println!("[TournamentRegistryTrait::search_league] current leagues bitmap: {}", self.leagues);
        
        PlayerLeagueIndexAssert::assert_subscribed(player_index);
        self.unsubscribe(ref league, ref player_index);
        
        if self.leagues == 0 {
            println!("[TournamentRegistryTrait::search_league] No leagues available - returning None");
            return Option::None;
        }

        match Bitmap::nearest_significant_bit(self.leagues.into(), league.league_id) {
            Option::Some(bit) => {
                println!("[TournamentRegistryTrait::search_league] Found nearest league at bit: {}", bit);
                let distance = if bit > league.league_id {
                    bit - league.league_id
                } else {
                    league.league_id - bit
                };
                println!("[TournamentRegistryTrait::search_league] Distance from player league: {}, search radius: {}", distance, LEAGUE_SEARCH_RADIUS);
                if distance <= LEAGUE_SEARCH_RADIUS {
                    let result_league = bit.try_into().unwrap();
                    println!("[TournamentRegistryTrait::search_league] League within radius - returning league_id: {}", result_league);
                    Option::Some(result_league)
                } else {
                    println!("[TournamentRegistryTrait::search_league] League outside search radius - returning None");
                    Option::None
                }
            },
            Option::None => {
                println!("[TournamentRegistryTrait::search_league] No nearest league found - returning None");
                Option::None
            },
        }
    }

    fn _update_league_bitmap(ref self: TournamentRegistry, league_id: u8, size: u32) {
        println!("[TournamentRegistryTrait::_update_league_bitmap] Updating bitmap for league");
        println!("[TournamentRegistryTrait::_update_league_bitmap] league_id: {}, size: {}", league_id, size);
        println!("[TournamentRegistryTrait::_update_league_bitmap] current bitmap: {}", self.leagues);
        
        let current_bit = Bitmap::get_bit_at(self.leagues.into(), league_id.into());
        let should_be_active = size > 0;
        
        println!("[TournamentRegistryTrait::_update_league_bitmap] current_bit: {}, should_be_active: {}", current_bit, should_be_active);
        
        if current_bit != should_be_active {
            println!("[TournamentRegistryTrait::_update_league_bitmap] Bit status changed - updating bitmap");
            let new_bitmap = Bitmap::set_bit_at(
                self.leagues.into(), 
                league_id.into(), 
                should_be_active
            );
            self.leagues = new_bitmap.try_into().expect(errors::REGISTRY_INVALID_INDEX);
            println!("[TournamentRegistryTrait::_update_league_bitmap] new bitmap: {}", self.leagues);
        } else {
            println!("[TournamentRegistryTrait::_update_league_bitmap] No bitmap change needed");
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
    fn new(game_mode: u8, tournament_id: u64, league_id: u8) -> TournamentLeague {
        println!("[TournamentLeagueTrait::new] Creating new league");
        println!("[TournamentLeagueTrait::new] game_mode: {}, tournament_id: {}, league_id: {}", game_mode, tournament_id, league_id);
        let league = TournamentLeague { 
            game_mode,
            tournament_id,
            league_id,
            size: 0,
        };
        println!("[TournamentLeagueTrait::new] League created with size: {}", league.size);
        league
    }

    fn compute_id(rating: u32) -> u8 {
        println!("[TournamentLeagueTrait::compute_id] Computing league ID for rating");
        println!("[TournamentLeagueTrait::compute_id] input rating: {}", rating);
        println!("[TournamentLeagueTrait::compute_id] LEAGUE_MIN_THRESHOLD: {}, LEAGUE_SIZE: {}, LEAGUE_COUNT: {}", LEAGUE_MIN_THRESHOLD, LEAGUE_SIZE, LEAGUE_COUNT);
        
        if rating <= LEAGUE_MIN_THRESHOLD {
            println!("[TournamentLeagueTrait::compute_id] Rating below threshold - returning Silver I (1)");
            return 1; // Silver I
        }
        let max_rating = LEAGUE_MIN_THRESHOLD + LEAGUE_SIZE * LEAGUE_COUNT.into();
        println!("[TournamentLeagueTrait::compute_id] max_rating: {}", max_rating);
        
        if rating >= max_rating {
            println!("[TournamentLeagueTrait::compute_id] Rating above maximum - returning Global Elite ({})", LEAGUE_COUNT);
            return LEAGUE_COUNT; // Global Elite
        }
        let id = 1 + (rating - LEAGUE_MIN_THRESHOLD) / LEAGUE_SIZE;
        println!("[TournamentLeagueTrait::compute_id] computed raw id: {}", id);
        
        let final_id = if id > 251 {
            251
        } else if id < 1 {
            1
        } else {
            id.try_into().unwrap()
        };
        println!("[TournamentLeagueTrait::compute_id] final league_id: {}", final_id);
        final_id
    }

    fn subscribe(ref self: TournamentLeague, ref player_index: PlayerLeagueIndex) -> TournamentSlot {
        println!("[TournamentLeagueTrait::subscribe] Starting league subscription");
        println!("[TournamentLeagueTrait::subscribe] league_id: {}, current size: {}", self.league_id, self.size);
        println!("[TournamentLeagueTrait::subscribe] player_address: {:x}", player_index.player_address);
        
        PlayerLeagueIndexAssert::assert_subscribable(player_index);
        let slot_index = self.size;
        println!("[TournamentLeagueTrait::subscribe] assigning slot_index: {}", slot_index);
        
        self.size += 1;
        player_index.league_id = self.league_id;
        player_index.slot_index = slot_index;
        
        println!("[TournamentLeagueTrait::subscribe] league size after increment: {}", self.size);
        println!("[TournamentLeagueTrait::subscribe] player updated - league_id: {}, slot_index: {}", player_index.league_id, player_index.slot_index);

        let slot = TournamentSlotTrait::new(
            self.game_mode,
            self.tournament_id,
            self.league_id,
            slot_index,
            player_index.player_address
        );
        println!("[TournamentLeagueTrait::subscribe] slot created successfully");
        slot
    }

    fn unsubscribe(ref self: TournamentLeague, ref player_index: PlayerLeagueIndex) {
        println!("[TournamentLeagueTrait::unsubscribe] Starting league unsubscription");
        println!("[TournamentLeagueTrait::unsubscribe] league_id: {}, current size: {}", self.league_id, self.size);
        println!("[TournamentLeagueTrait::unsubscribe] player_address: {:x}", player_index.player_address);
        println!("[TournamentLeagueTrait::unsubscribe] player current league_id: {}, slot_index: {}", player_index.league_id, player_index.slot_index);
        
        LeagueAssert::assert_subscribed(*self, player_index);
        self.size -= 1;
        player_index.league_id = 0;
        player_index.slot_index = 0;
        
        println!("[TournamentLeagueTrait::unsubscribe] league size after decrement: {}", self.size);
        println!("[TournamentLeagueTrait::unsubscribe] player cleared - league_id: {}, slot_index: {}", player_index.league_id, player_index.slot_index);
    }

    fn search_player(ref self: TournamentLeague, seed: felt252) -> u32 {
        println!("[TournamentLeagueTrait::search_player] Searching for random player in league");
        println!("[TournamentLeagueTrait::search_player] league_id: {}, league size: {}", self.league_id, self.size);
        println!("[TournamentLeagueTrait::search_player] seed: {}", seed);
        
        let seed: u256 = seed.into();
        let index = seed % self.size.into();
        let final_index = index.try_into().unwrap();
        
        println!("[TournamentLeagueTrait::search_player] computed index: {}", final_index);
        final_index
    }
}

//------------------------------------
// Slot trait implementation
//
#[generate_trait]
pub impl TournamentSlotImpl of TournamentSlotTrait {
    fn new(
        game_mode: u8,
        tournament_id: u64,
        league_id: u8,
        slot_index: u32,
        player_address: ContractAddress
    ) -> TournamentSlot {
        println!("[TournamentSlotTrait::new] Creating new slot");
        println!("[TournamentSlotTrait::new] game_mode: {}, tournament_id: {}", game_mode, tournament_id);
        println!("[TournamentSlotTrait::new] league_id: {}, slot_index: {}", league_id, slot_index);
        println!("[TournamentSlotTrait::new] player_address: {:x}", player_address);
        
        let slot = TournamentSlot {
            game_mode,
            tournament_id,
            league_id,
            slot_index,
            player_address,
        };
        println!("[TournamentSlotTrait::new] Slot created successfully");
        slot
    }

    fn nullify(ref self: TournamentSlot) {
        println!("[TournamentSlotTrait::nullify] Nullifying slot");
        println!("[TournamentSlotTrait::nullify] league_id: {}, slot_index: {}", self.league_id, self.slot_index);
        println!("[TournamentSlotTrait::nullify] old player_address: {:x}", self.player_address);
        
        self.player_address = Zero::zero();
        println!("[TournamentSlotTrait::nullify] new player_address: {:x}", self.player_address);
    }

    fn is_empty(self: @TournamentSlot) -> bool {
        println!("[TournamentSlotTrait::is_empty] Checking if slot is empty");
        println!("[TournamentSlotTrait::is_empty] league_id: {}, slot_index: {}", *self.league_id, *self.slot_index);
        println!("[TournamentSlotTrait::is_empty] player_address: {:x}", *self.player_address);
        
        let is_empty = (*self.player_address).is_zero();
        println!("[TournamentSlotTrait::is_empty] result: {}", is_empty);
        is_empty
    }
}

#[generate_trait]
pub impl RegistryAssert of RegistryAssertTrait {
    fn assert_not_empty(self: TournamentRegistry) {
        println!("[RegistryAssert::assert_not_empty] Checking if registry is not empty");
        println!("[RegistryAssert::assert_not_empty] tournament_id: {}, leagues bitmap: {}", self.tournament_id, self.leagues);
        
        let is_empty = self.leagues.into() == 0_u256;
        println!("[RegistryAssert::assert_not_empty] is_empty: {}", is_empty);
        
        if is_empty {
            println!("[RegistryAssert::assert_not_empty] ERROR: Tournament registry is empty!");
        } else {
            println!("[RegistryAssert::assert_not_empty] Registry not empty - assertion passed");
        }
        
        assert!(self.leagues.into() > 0_u256, "Tournament registry is empty");
    }
}

#[generate_trait]
pub impl LeagueAssert of LeagueAssertTrait {
    fn assert_subscribed(self: TournamentLeague, player_index: PlayerLeagueIndex) {
        println!("[LeagueAssert::assert_subscribed] Checking if player is subscribed to league");
        println!("[LeagueAssert::assert_subscribed] league_id: {}, player league_id: {}", self.league_id, player_index.league_id);
        println!("[LeagueAssert::assert_subscribed] player_address: {:x}", player_index.player_address);
        
        let is_subscribed = player_index.league_id == self.league_id;
        println!("[LeagueAssert::assert_subscribed] is_subscribed: {}", is_subscribed);
        
        if !is_subscribed {
            println!("[LeagueAssert::assert_subscribed] ERROR: Player is not subscribed to this league!");
        } else {
            println!("[LeagueAssert::assert_subscribed] Player correctly subscribed - assertion passed");
        }
        
        assert!(player_index.league_id == self.league_id, "Player is not in a league");
    }
}

#[generate_trait]
pub impl PlayerLeagueIndexAssert of PlayerLeagueIndexAssertTrait {
    #[inline(always)]
    fn assert_subscribable(player_index: PlayerLeagueIndex) {
        println!("[PlayerLeagueIndexAssert::assert_subscribable] Checking if player can be subscribed");
        println!("[PlayerLeagueIndexAssert::assert_subscribable] player_address: {:x}", player_index.player_address);
        println!("[PlayerLeagueIndexAssert::assert_subscribable] current league_id: {}", player_index.league_id);
        
        let is_subscribable = player_index.league_id == 0;
        println!("[PlayerLeagueIndexAssert::assert_subscribable] is_subscribable: {}", is_subscribable);
        
        if !is_subscribable {
            println!("[PlayerLeagueIndexAssert::assert_subscribable] ERROR: Player already in a league!");
        } else {
            println!("[PlayerLeagueIndexAssert::assert_subscribable] Player can be subscribed - assertion passed");
        }
        
        assert!(player_index.league_id == 0, "Player is not in a league");
    }

    #[inline(always)]
    fn assert_subscribed(player: PlayerLeagueIndex) {
        println!("[PlayerLeagueIndexAssert::assert_subscribed] Checking if player is subscribed to any league");
        println!("[PlayerLeagueIndexAssert::assert_subscribed] player_address: {:x}", player.player_address);
        println!("[PlayerLeagueIndexAssert::assert_subscribed] league_id: {}, slot_index: {}", player.league_id, player.slot_index);
        
        let is_subscribed = player.league_id != 0;
        println!("[PlayerLeagueIndexAssert::assert_subscribed] is_subscribed: {}", is_subscribed);
        
        if !is_subscribed {
            println!("[PlayerLeagueIndexAssert::assert_subscribed] ERROR: Player is not subscribed to any league!");
        } else {
            println!("[PlayerLeagueIndexAssert::assert_subscribed] Player is subscribed - assertion passed");
        }
        
        assert!(player.league_id != 0, "Player is not subscribed to a league");
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
        println!("[TournamentELOTrait::get_tournament_player_rating] Getting player tournament rating");
        println!("[TournamentELOTrait::get_tournament_player_rating] player_address: {:x}, tournament_id: {}", player_address, tournament_id);
        
        let index: PlayerTournamentIndex = world.read_model((player_address, tournament_id));
        println!("[TournamentELOTrait::get_tournament_player_rating] player tournament index pass_id: {}", index.pass_id);
        
        if index.pass_id == 0 {
            // Player not in tournament, return default rating
            println!("[TournamentELOTrait::get_tournament_player_rating] Player not in tournament - returning default rating: {}", DEFAULT_RATING);
            return DEFAULT_RATING;
        }
        
        let tournament_pass: TournamentPass = world.read_model(index.pass_id);
        println!("[TournamentELOTrait::get_tournament_player_rating] Found tournament pass - rating: {}", tournament_pass.rating);
        tournament_pass.rating
    }
    
    // Update ratings after tournament match
    fn update_tournament_ratings_after_match(
        winner_address: ContractAddress,
        loser_address: ContractAddress,
        tournament_id: u64,
        mut world: WorldStorage
    ) {
        println!("[TournamentELOTrait::update_tournament_ratings_after_match] Updating tournament ratings");
        println!("[TournamentELOTrait::update_tournament_ratings_after_match] winner_address: {:x}", winner_address);
        println!("[TournamentELOTrait::update_tournament_ratings_after_match] loser_address: {:x}", loser_address);
        println!("[TournamentELOTrait::update_tournament_ratings_after_match] tournament_id: {}", tournament_id);
        
        // Get tournament passes
        let winner_index: PlayerTournamentIndex = world.read_model((winner_address, tournament_id));
        let loser_index: PlayerTournamentIndex = world.read_model((loser_address, tournament_id));
        
        println!("[TournamentELOTrait::update_tournament_ratings_after_match] winner_pass_id: {}, loser_pass_id: {}", winner_index.pass_id, loser_index.pass_id);
        
        if winner_index.pass_id == 0 || loser_index.pass_id == 0 {
            println!("[TournamentELOTrait::update_tournament_ratings_after_match] One of players not in tournament - aborting");
            return; // One of players not in tournament
        }
        
        let mut winner_pass: TournamentPass = world.read_model(winner_index.pass_id);
        let mut loser_pass: TournamentPass = world.read_model(loser_index.pass_id);
        
        println!("[TournamentELOTrait::update_tournament_ratings_after_match] winner rating before: {}, loser rating before: {}", winner_pass.rating, loser_pass.rating);
        println!("[TournamentELOTrait::update_tournament_ratings_after_match] winner stats: wins={}, losses={}, games_played={}", winner_pass.wins, winner_pass.losses, winner_pass.games_played);
        println!("[TournamentELOTrait::update_tournament_ratings_after_match] loser stats: wins={}, losses={}, games_played={}", loser_pass.wins, loser_pass.losses, loser_pass.games_played);
        
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
        
        println!("[TournamentELOTrait::update_tournament_ratings_after_match] ELO calculations:");
        println!("[TournamentELOTrait::update_tournament_ratings_after_match] winner_change: {}, winner_negative: {}", winner_change, winner_negative);
        println!("[TournamentELOTrait::update_tournament_ratings_after_match] loser_change: {}, loser_negative: {}", loser_change, loser_negative);
        
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
        
        println!("[TournamentELOTrait::update_tournament_ratings_after_match] winner rating after: {}, loser rating after: {}", winner_pass.rating, loser_pass.rating);
        println!("[TournamentELOTrait::update_tournament_ratings_after_match] winner stats after: wins={}, losses={}, games_played={}", winner_pass.wins, winner_pass.losses, winner_pass.games_played);
        println!("[TournamentELOTrait::update_tournament_ratings_after_match] loser stats after: wins={}, losses={}, games_played={}", loser_pass.wins, loser_pass.losses, loser_pass.games_played);
        
        // Save updated passes
        world.write_model(@winner_pass);
        world.write_model(@loser_pass);
        println!("[TournamentELOTrait::update_tournament_ratings_after_match] Tournament passes updated successfully");
    }
    
    // Find tournament opponent by ELO with radius check
    fn find_tournament_opponent(
        player_address: ContractAddress,
        tournament_id: u64,
        mut world: WorldStorage
    ) -> Option<ContractAddress> {
        println!("[TournamentELOTrait::find_tournament_opponent] === STARTING TOURNAMENT MATCHMAKING ===");
        println!("[TournamentELOTrait::find_tournament_opponent] player_address: {:x}, tournament_id: {}", player_address, tournament_id);
        
        // Get player's rating and league
        let player_rating = Self::get_tournament_player_rating(player_address, tournament_id, world);
        let player_league_id = TournamentLeagueTrait::compute_id(player_rating);
        
        println!("[TournamentELOTrait::find_tournament_opponent] player_rating: {}, player_league_id: {}", player_rating, player_league_id);
        
        // Get registry
        let mut registry: TournamentRegistry = world.read_model((
            Into::<GameMode, u8>::into(GameMode::Tournament),
            tournament_id
        ));
        println!("[TournamentELOTrait::find_tournament_opponent] registry leagues bitmap: {}", registry.leagues);
        
        // Get player's league
        let mut player_league: TournamentLeague = world.read_model((
            Into::<GameMode, u8>::into(GameMode::Tournament),
            tournament_id,
            player_league_id
        ));
        println!("[TournamentELOTrait::find_tournament_opponent] player league size: {}", player_league.size);

        let mut player_index: PlayerLeagueIndex = world.read_model((
            Into::<GameMode, u8>::into(GameMode::Tournament),
            tournament_id,
            player_address
        ));
        println!("[TournamentELOTrait::find_tournament_opponent] player current league_id: {}, slot_index: {}", player_index.league_id, player_index.slot_index);
        
        // [Step 1] Always subscribe player first (like subscribe())
        println!("[TournamentELOTrait::find_tournament_opponent] === STEP 1: SUBSCRIBING PLAYER ===");
        player_index.join_time = starknet::get_block_timestamp();
        println!("[TournamentELOTrait::find_tournament_opponent] player join_time set to: {}", player_index.join_time);
        
        let slot = registry.subscribe(ref player_league, ref player_index);
        println!("[TournamentELOTrait::find_tournament_opponent] player subscribed to slot_index: {}", slot.slot_index);
        
        // [Step 2] Try to find opponent (like fight())
        println!("[TournamentELOTrait::find_tournament_opponent] === STEP 2: SEARCHING FOR OPPONENT ===");
        let seed = starknet::get_tx_info().unbox().transaction_hash;
        println!("[TournamentELOTrait::find_tournament_opponent] using seed: {}", seed);
        
        let mut updated_registry = registry;
        let mut updated_player_league = player_league;
        let mut updated_player_index = player_index;
        
        match updated_registry.search_league(ref updated_player_league, ref updated_player_index) {
            Option::Some(opponent_league_id) => {
                println!("[TournamentELOTrait::find_tournament_opponent] Found opponent league_id: {}", opponent_league_id);
                // Found opponent league - get random opponent
                let mut opponent_league: TournamentLeague = world.read_model((
                    Into::<GameMode, u8>::into(GameMode::Tournament),
                    tournament_id,
                    opponent_league_id
                ));
                println!("[TournamentELOTrait::find_tournament_opponent] opponent league size: {}", opponent_league.size);
                
                let opponent_slot_id = opponent_league.search_player(seed);
                println!("[TournamentELOTrait::find_tournament_opponent] selected opponent slot_id: {}", opponent_slot_id);
                
                let opponent_slot: TournamentSlot = world.read_model((
                    Into::<GameMode, u8>::into(GameMode::Tournament),
                    tournament_id,
                    opponent_league_id,
                    opponent_slot_id
                ));
                let opponent_address = opponent_slot.player_address;
                println!("[TournamentELOTrait::find_tournament_opponent] opponent_address: {:x}", opponent_address);
                
                // Get opponent index and unsubscribe them
                println!("[TournamentELOTrait::find_tournament_opponent] === UNSUBSCRIBING OPPONENT ===");
                let mut opponent_index: PlayerLeagueIndex = world.read_model((
                    Into::<GameMode, u8>::into(GameMode::Tournament),
                    tournament_id,
                    opponent_address
                ));
                println!("[TournamentELOTrait::find_tournament_opponent] opponent current league_id: {}, slot_index: {}", opponent_index.league_id, opponent_index.slot_index);
                
                updated_registry.unsubscribe(ref opponent_league, ref opponent_index);
                println!("[TournamentELOTrait::find_tournament_opponent] opponent unsubscribed successfully");
                
                // Clear opponent slot
                println!("[TournamentELOTrait::find_tournament_opponent] === CLEARING SLOTS ===");
                let mut cleared_opponent_slot = opponent_slot;
                cleared_opponent_slot.nullify();
                
                // Clear player slot (we were just subscribed)
                let mut cleared_player_slot = slot;
                cleared_player_slot.nullify();
                println!("[TournamentELOTrait::find_tournament_opponent] Both slots cleared");
                
                // Update all models
                println!("[TournamentELOTrait::find_tournament_opponent] === UPDATING WORLD STATE ===");
                world.write_model(@updated_registry);
                world.write_model(@updated_player_league);
                world.write_model(@opponent_league);
                world.write_model(@updated_player_index);
                world.write_model(@opponent_index);
                world.write_model(@cleared_opponent_slot);
                world.write_model(@cleared_player_slot);
                
                println!("[TournamentELOTrait::find_tournament_opponent] === MATCH FOUND - RETURNING OPPONENT ===");
                println!("[TournamentELOTrait::find_tournament_opponent] final opponent_address: {:x}", opponent_address);
                Option::Some(opponent_address)
            },
            Option::None => {
                println!("[TournamentELOTrait::find_tournament_opponent] === NO OPPONENT FOUND ===");
                // No opponent found - player stays subscribed, keep slot
                println!("[TournamentELOTrait::find_tournament_opponent] Player stays in queue - updating world state");
                world.write_model(@updated_registry);
                world.write_model(@updated_player_league);
                world.write_model(@updated_player_index);
                world.write_model(@slot);
                
                println!("[TournamentELOTrait::find_tournament_opponent] === RETURNING NONE ===");
                Option::None
            }
        }
    }

    // Get player's active tournament ID from PlayerAssignment
    fn get_player_active_tournament_id(
        player_address: ContractAddress,
        world: WorldStorage
    ) -> Option<u64> {
        println!("[TournamentELOTrait::get_player_active_tournament_id] Getting active tournament ID");
        println!("[TournamentELOTrait::get_player_active_tournament_id] player_address: {:x}", player_address);
        
        let player_assignment: evolute_duel::models::player::PlayerAssignment = world.read_model(player_address);
        println!("[TournamentELOTrait::get_player_active_tournament_id] player assignment tournament_id: {}", player_assignment.tournament_id);
        
        if player_assignment.tournament_id != 0 {
            println!("[TournamentELOTrait::get_player_active_tournament_id] Active tournament found: {}", player_assignment.tournament_id);
            Option::Some(player_assignment.tournament_id)
        } else {
            println!("[TournamentELOTrait::get_player_active_tournament_id] No active tournament");
            Option::None
        }
    }

    // Unsubscribe player from tournament matchmaking queue
    fn unsubscribe_tournament_player(
        player_address: ContractAddress,
        tournament_id: u64,
        mut world: WorldStorage
    ) {
        println!("[TournamentELOTrait::unsubscribe_tournament_player] === UNSUBSCRIBING TOURNAMENT PLAYER ===");
        println!("[TournamentELOTrait::unsubscribe_tournament_player] player_address: {:x}, tournament_id: {}", player_address, tournament_id);
        
        // Get player's current subscription status
        let mut player_index: PlayerLeagueIndex = world.read_model((
            Into::<GameMode, u8>::into(GameMode::Tournament),
            tournament_id,
            player_address
        ));
        
        println!("[TournamentELOTrait::unsubscribe_tournament_player] current player league_id: {}, slot_index: {}", player_index.league_id, player_index.slot_index);

        // Check if player is actually subscribed
        if player_index.league_id == 0 {
            println!("[TournamentELOTrait::unsubscribe_tournament_player] Player not subscribed to any league - returning");
            // Player is not subscribed to any league
            return;
        }

        println!("[TournamentELOTrait::unsubscribe_tournament_player] Player is subscribed - proceeding with unsubscription");
        
        // Get registry and league
        let mut registry: TournamentRegistry = world.read_model((
            Into::<GameMode, u8>::into(GameMode::Tournament),
            tournament_id
        ));
        println!("[TournamentELOTrait::unsubscribe_tournament_player] registry leagues bitmap: {}", registry.leagues);
        
        let mut league: TournamentLeague = world.read_model((
            Into::<GameMode, u8>::into(GameMode::Tournament),
            tournament_id,
            player_index.league_id
        ));
        println!("[TournamentELOTrait::unsubscribe_tournament_player] league size before: {}", league.size);

        // Get the slot to clear it
        let mut slot: TournamentSlot = world.read_model((
            Into::<GameMode, u8>::into(GameMode::Tournament),
            tournament_id,
            player_index.league_id,
            player_index.slot_index
        ));
        println!("[TournamentELOTrait::unsubscribe_tournament_player] slot player_address: {:x}", slot.player_address);

        // Unsubscribe using registry method
        registry.unsubscribe(ref league, ref player_index);
        println!("[TournamentELOTrait::unsubscribe_tournament_player] Registry unsubscribe completed");

        // Clear the slot
        slot.nullify();
        println!("[TournamentELOTrait::unsubscribe_tournament_player] Slot nullified");

        // Update all models
        world.write_model(@registry);
        world.write_model(@league);
        world.write_model(@player_index);
        world.write_model(@slot);
        
        println!("[TournamentELOTrait::unsubscribe_tournament_player] === UNSUBSCRIPTION COMPLETED ===");
        println!("[TournamentELOTrait::unsubscribe_tournament_player] final league size: {}", league.size);
        println!("[TournamentELOTrait::unsubscribe_tournament_player] final registry bitmap: {}", registry.leagues);
    }
}