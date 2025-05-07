use evolute_duel::types::timestamp::{Period};
use starknet::ContractAddress;

//------------------------------------
// Tournament entry (tournament_token)
//
#[derive(Copy, Drop, Introspect, Serde)]
#[dojo::model]
pub struct TournamentPass {
    #[key]
    pub pass_id: u64,               // token id
    //------
    pub tournament_id: u64,         // budokan tournament_id
    pub entry_number: u8,           // entry number in the tournament
    pub player_address: ContractAddress,           // enlisted duelist id
    // progress
    pub current_round_number: u8,   // current round this player is in
    pub score: u32,                 // budokan score (Fame less decimals)
}

//------------------------------------
// Tournament loop
//
#[derive(Copy, Drop, Introspect, Serde)]
#[dojo::model]
pub struct Tournament {
    #[key]
    pub tournament_id: u64,         // budokan id
    //------
    pub state: TournamentState,
    pub round_number: u8,           // current or last round
}

#[derive(Copy, Drop, Serde, PartialEq, Introspect)]
pub enum TournamentState {
    Undefined,   // 0
    InProgress,  // 1
    Finished,    // 2
}


#[derive(Copy, Drop, Introspect, Serde)]
#[dojo::model]
pub struct TournamentRound {
    #[key]
    pub tournament_id: u64,     // budokan id
    #[key]
    pub round_number: u8,
    //------
    pub entry_count: u8,        // participating in this round, maximum of 32
    pub timestamps: Period,     // will never expire after tournament
    // bracket (duelist pairings): 32 bytes, one for each duelist
    // ex: duel between 4 and 7: byte[4-1] = 7, byte[7-1] = 4
    pub bracket: u256,
    // results: 32 nibbles (4-bit), one for each duelist
    // bit 0 (0b0001): 1 = duelist is winning or won / 0 = duelist is losing or lost
    // bit 1 (0b0010): 1 = duelist survived / 0 = duelist dead or not qualified
    // bit 2 (0b0100): 1 = duelist is still playing / 0 = duelist finished playing
    // bit 3 (0b1000): 1 = duelist is participating in this round / 0 = empty slot
    // ps1: never 2 paired duelists are both winning
    // ps2: all winners go to the next round, losers only if finished and survived
    pub results: u128,
}

//------------------------------------
// Links tournament rounds to its Duels
//
// TournamentToChallenge: required for player B to find the duel created by player A
#[derive(Copy, Drop, Introspect, Serde)]
#[dojo::model]
pub struct TournamentToChallenge {
    #[key]
    pub keys: TournamentDuelKeys,
    //-------------------------
    pub duel_id: felt252,
}
// ChallengeToTournament: required to settle results of a duel in the tournament
#[derive(Copy, Drop, Introspect, Serde)]
#[dojo::model]
pub struct ChallengeToTournament {
    #[key]
    pub duel_id: felt252,
    //-------------------------
    pub keys: TournamentDuelKeys,
}

#[derive(Copy, Drop, Serde, IntrospectPacked)]
pub struct TournamentDuelKeys {
    pub tournament_id: u64,
    pub entry_number_a: u8,     // min(entry_number_a, entry_number_b)
    pub entry_number_b: u8,     // max(entry_number_a, entry_number_b)
}