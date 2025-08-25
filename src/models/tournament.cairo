use evolute_duel::types::timestamp::{Period};
use starknet::ContractAddress;

//------------------------------------
// Tournament entry (tournament_token)
//
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct TournamentPass {
    #[key]
    pub pass_id: u64,               // token id
    //------
    pub tournament_id: u64,         // budokan tournament_id
    pub player_address: ContractAddress,           // enlisted duelist id
    pub entry_number: u8,           // entry position in tournament
    // tournament rating data
    pub rating: u32,                // current tournament rating (ELO-based)
    pub games_played: u32,          // games played in tournament
    pub wins: u32,                  // wins in tournament
    pub losses: u32,                // losses in tournament
}

//------------------------------------
// Tournament loop
//
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct TournamentStateModel {
    #[key]
    pub tournament_id: u64,         // budokan id
    //------
    pub state: TournamentState,
}

#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
pub enum TournamentState {
    Undefined,   // 0
    InProgress,  // 1
    Finished,    // 2
}


//------------------------------------
// Simple link between tournament and challenge for rating-based tournaments
//
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct TournamentChallenge {
    #[key]
    pub challenge_id: felt252,
    //-------------------------
    pub tournament_id: u64,
}

//------------------------------------
// Player to Tournament Pass index  
// Allows quick lookup of player's passes in tournaments
//
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct PlayerTournamentIndex {
    #[key]
    pub player_address: ContractAddress,
    #[key] 
    pub tournament_id: u64,
    //-------------------------
    pub pass_id: u64,
}



//------------------------------------
// Tournament settings/rules
// selected in Budokan
//
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct TournamentSettings {
    #[key]
    pub settings_id: u32,
    //------
    pub tournament_type: TournamentType,
    // pub description: ByteArray,
}

#[derive(Serde, Copy, Drop, PartialEq, Introspect)]
pub enum TournamentType {
    Undefined,          // 0
    LastManStanding,    // 2
    BestOfThree,        // 1
}

#[derive(Copy, Drop, Serde, Default)]
pub struct TournamentRules {
    pub settings_id: u32,       // Budokan settings id
    pub description: felt252,   // @generateContants:shortstring
    pub min_lives: u8,          // min lives required to enlist Duelist  
    pub max_lives: u8,          // max lives allowed to enlist Duelist
    pub lives_staked: u8,       // lives staked by each duel in the tournament
}

// to be exported to typescript by generateConstants
// IMPORTANT: names must be in sync with enum TournamentType
pub mod TOURNAMENT_RULES {
    use super::{TournamentRules};
    pub const Undefined: TournamentRules = TournamentRules {
        settings_id: 0,
        description: 'Undefined',
        min_lives: 0,
        max_lives: 0,
        lives_staked: 0,
    };
    pub const LastManStanding: TournamentRules = TournamentRules {
        settings_id: 1,
        description: 'Last Man Standing',
        min_lives: 3,       // anyone can join
        max_lives: 3,       // death guaranteed on loss
        lives_staked: 3,    // sudden death
    };
    pub const BestOfThree: TournamentRules = TournamentRules {
        settings_id: 2,
        description: 'Best of Three',
        min_lives: 3,
        max_lives: 3,
        lives_staked: 1,
    };
}



//---------------------------
// Traits
//

#[generate_trait]
pub impl TournamentTypeImpl of TournamentTypeTrait {
    fn rules(self: @TournamentType) -> TournamentRules {
        match self {
            TournamentType::Undefined           => TOURNAMENT_RULES::Undefined,
            TournamentType::LastManStanding     => TOURNAMENT_RULES::LastManStanding,
            TournamentType::BestOfThree         => TOURNAMENT_RULES::BestOfThree,
        }
    }
    fn exists(self: @TournamentType) -> bool {
        (*self != TournamentType::Undefined)
    }
    fn tournament_settings(self: @TournamentType) -> @TournamentSettings {
        @TournamentSettings {
            settings_id: self.rules().settings_id,
            tournament_type: *self,
            // description: self.rules().description.to_string(),
        }
    }
}






//---------------------------
// Converters
//
impl TournamentStateIntoByteArray of core::traits::Into<TournamentState, ByteArray> {
    fn into(self: TournamentState) -> ByteArray {
        match self {
            TournamentState::Undefined      => "TournamentState::Undefined",
            TournamentState::InProgress     => "TournamentState::InProgress",
            TournamentState::Finished       => "TournamentState::Finished",
        }
    }
}
pub impl TournamentStateDebug of core::fmt::Debug<TournamentState> {
    fn fmt(self: @TournamentState, ref f: core::fmt::Formatter) -> Result<(), core::fmt::Error> {
        let result: ByteArray = (*self).into();
        f.buffer.append(@result);
        Result::Ok(())
    }
}
impl TournamentTypeIntoByteArray of core::traits::Into<TournamentType, ByteArray> {
    fn into(self: TournamentType) -> ByteArray {
        match self {
            TournamentType::Undefined       => "TournamentType::Undefined",
            TournamentType::LastManStanding => "TournamentType::LastManStanding",
            TournamentType::BestOfThree     => "TournamentType::BestOfThree",
        }
    }
}
pub impl TournamentTypeDebug of core::fmt::Debug<TournamentType> {
    fn fmt(self: @TournamentType, ref f: core::fmt::Formatter) -> Result<(), core::fmt::Error> {
        let result: ByteArray = (*self).into();
        f.buffer.append(@result);
        Result::Ok(())
    }
}
