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
        TournamentRegistry { 
            game_mode,
            tournament_id, 
            leagues: 0 
        }
    }

    fn subscribe(
        ref self: TournamentRegistry, 
        ref league: TournamentLeague, 
        ref player_index: PlayerLeagueIndex
    ) -> TournamentSlot {
        let slot = league.subscribe(ref player_index);
        
        // Update bitmap of active leagues
        self._update_league_bitmap(league.league_id, league.size);
        
        slot
    }

    fn unsubscribe(
        ref self: TournamentRegistry,
        ref league: TournamentLeague, 
        ref player_index: PlayerLeagueIndex
    ) {
        league.unsubscribe(ref player_index);
        // Update bitmap
        self._update_league_bitmap(league.league_id, league.size);
    }

    fn search_league(
        ref self: TournamentRegistry,
        ref league: TournamentLeague, 
        ref player_index: PlayerLeagueIndex,
    ) -> Option<u8> {
        PlayerLeagueIndexAssert::assert_subscribed(player_index);
        self.unsubscribe(ref league, ref player_index);
        
        if self.leagues == 0 {
            return Option::None;
        }

        match Bitmap::nearest_significant_bit(self.leagues.into(), league.league_id) {
            Some(bit) => {
                let distance = if bit > league.league_id {
                    bit - league.league_id
                } else {
                    league.league_id - bit
                };
                if distance <= LEAGUE_SEARCH_RADIUS {
                    Some(bit.try_into().unwrap())
                } else {
                    None
                }
            },
            None => None,
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
    fn new(game_mode: u8, tournament_id: u64, league_id: u8) -> TournamentLeague {
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

    fn subscribe(ref self: TournamentLeague, ref player_index: PlayerLeagueIndex) -> TournamentSlot {
        PlayerLeagueIndexAssert::assert_subscribable(player_index);
        let slot_index = self.size;
        self.size += 1;
        player_index.league_id = self.league_id;
        player_index.slot_index = slot_index;

        TournamentSlotTrait::new(
            self.game_mode,
            self.tournament_id,
            self.league_id,
            slot_index,
            player_index.player_address
        )
    }

    fn unsubscribe(ref self: TournamentLeague, ref player_index: PlayerLeagueIndex) {
        LeagueAssert::assert_subscribed(self, player_index);
        self.size -= 1;
        player_index.league_id = 0;
        player_index.slot_index = 0;
    }

    fn search_player(ref self: TournamentLeague, seed: felt252) -> u32 {
        let seed: u256 = seed.into();
        let index = seed % self.size.into();
        index.try_into().unwrap()
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
        TournamentSlot {
            game_mode,
            tournament_id,
            league_id,
            slot_index,
            player_address,
        }
    }

    fn nullify(ref self: TournamentSlot) {
        self.player_address = Zero::zero();
    }

    fn is_empty(self: @TournamentSlot) -> bool {
        (*self.player_address).is_zero()
    }
}

#[generate_trait]
pub impl RegistryAssert of RegistryAssertTrait {
    fn assert_not_empty(self: TournamentRegistry) {
        assert!(self.leagues.into() > 0_u256, "Tournament registry is empty");
    }
}

#[generate_trait]
pub impl LeagueAssert of LeagueAssertTrait {
    fn assert_subscribed(self: TournamentLeague, player_index: PlayerLeagueIndex) {
        assert!(player_index.league_id == self.league_id, "Player is not in a league");
    }
}

#[generate_trait]
pub impl PlayerLeagueIndexAssert of PlayerLeagueIndexAssertTrait {
    #[inline(always)]
    fn assert_subscribable(player_index: PlayerLeagueIndex) {
        assert!(player_index.league_id == 0, "Player is not in a league");
    }

    #[inline(always)]
    fn assert_subscribed(player: PlayerLeagueIndex) {
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
            Into::<GameMode, u8>::into(GameMode::Tournament),
            tournament_id
        ));
        
        // Get player's league
        let mut player_league: TournamentLeague = world.read_model((
            Into::<GameMode, u8>::into(GameMode::Tournament),
            tournament_id,
            player_league_id
        ));

        let mut player_index: PlayerLeagueIndex = world.read_model((
            Into::<GameMode, u8>::into(GameMode::Tournament),
            tournament_id,
            player_address
        ));
        
        // [Step 1] Always subscribe player first (like subscribe())
        player_index.join_time = starknet::get_block_timestamp();
        let slot = registry.subscribe(ref player_league, ref player_index);
        
        // [Step 2] Try to find opponent (like fight())
        let seed = starknet::get_tx_info().unbox().transaction_hash;
        let mut updated_registry = registry;
        let mut updated_player_league = player_league;
        let mut updated_player_index = player_index;
        
        match updated_registry.search_league(ref updated_player_league, ref updated_player_index) {
            Option::Some(opponent_league_id) => {
                // Found opponent league - get random opponent
                let mut opponent_league: TournamentLeague = world.read_model((
                    Into::<GameMode, u8>::into(GameMode::Tournament),
                    tournament_id,
                    opponent_league_id
                ));
                let opponent_slot_id = opponent_league.search_player(seed);
                let opponent_slot: TournamentSlot = world.read_model((
                    Into::<GameMode, u8>::into(GameMode::Tournament),
                    tournament_id,
                    opponent_league_id,
                    opponent_slot_id
                ));
                let opponent_address = opponent_slot.player_address;
                
                // Get opponent index and unsubscribe them
                let mut opponent_index: PlayerLeagueIndex = world.read_model((
                    Into::<GameMode, u8>::into(GameMode::Tournament),
                    tournament_id,
                    opponent_address
                ));
                updated_registry.unsubscribe(ref opponent_league, ref opponent_index);
                
                // Clear opponent slot
                let mut cleared_opponent_slot = opponent_slot;
                cleared_opponent_slot.nullify();
                
                // Clear player slot (we were just subscribed)
                let mut cleared_player_slot = slot;
                cleared_player_slot.nullify();
                
                // Update all models
                world.write_model(@updated_registry);
                world.write_model(@updated_player_league);
                world.write_model(@opponent_league);
                world.write_model(@updated_player_index);
                world.write_model(@opponent_index);
                world.write_model(@cleared_opponent_slot);
                world.write_model(@cleared_player_slot);
                
                Option::Some(opponent_address)
            },
            Option::None => {
                // No opponent found - player stays subscribed, keep slot
                world.write_model(@updated_registry);
                world.write_model(@updated_player_league);
                world.write_model(@updated_player_index);
                world.write_model(@slot);
                
                Option::None
            }
        }
    }

    // Get player's active tournament ID from PlayerAssignment
    fn get_player_active_tournament_id(
        player_address: ContractAddress,
        world: WorldStorage
    ) -> Option<u64> {
        let player_assignment: evolute_duel::models::player::PlayerAssignment = world.read_model(player_address);
        
        if player_assignment.tournament_id != 0 {
            Option::Some(player_assignment.tournament_id)
        } else {
            Option::None
        }
    }

    // Unsubscribe player from tournament matchmaking queue
    fn unsubscribe_tournament_player(
        player_address: ContractAddress,
        tournament_id: u64,
        mut world: WorldStorage
    ) {
        // Get player's current subscription status
        let mut player_index: PlayerLeagueIndex = world.read_model((
            Into::<GameMode, u8>::into(GameMode::Tournament),
            tournament_id,
            player_address
        ));

        // Check if player is actually subscribed
        if player_index.league_id == 0 {
            // Player is not subscribed to any league
            return;
        }

        // Get registry and league
        let mut registry: TournamentRegistry = world.read_model((
            Into::<GameMode, u8>::into(GameMode::Tournament),
            tournament_id
        ));
        
        let mut league: TournamentLeague = world.read_model((
            Into::<GameMode, u8>::into(GameMode::Tournament),
            tournament_id,
            player_index.league_id
        ));

        // Get the slot to clear it
        let mut slot: TournamentSlot = world.read_model((
            Into::<GameMode, u8>::into(GameMode::Tournament),
            tournament_id,
            player_index.league_id,
            player_index.slot_index
        ));

        // Unsubscribe using registry method
        registry.unsubscribe(ref league, ref player_index);

        // Clear the slot
        slot.nullify();

        // Update all models
        world.write_model(@registry);
        world.write_model(@league);
        world.write_model(@player_index);
        world.write_model(@slot);
    }
}