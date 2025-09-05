use starknet::ContractAddress;

//------------------------------------
// Tournament entry (tournament_token)
//
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct TournamentPass {
    #[key]
    pub pass_id: u64, // token id
    //------
    pub tournament_id: u64, // budokan tournament_id
    pub player_address: ContractAddress, // enlisted duelist id
    pub entry_number: u8, // entry position in tournament
    // tournament rating data
    pub rating: u32, // current tournament rating (ELO-based)
    pub games_played: u32, // games played in tournament
    pub wins: u32, // wins in tournament
    pub losses: u32, // losses in tournament
}

//------------------------------------
// Tournament loop
//
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct TournamentStateModel {
    #[key]
    pub tournament_id: u64, // budokan id
    //------
    pub state: TournamentState,
    pub prize_pool: u256,
}

#[derive(Copy, Drop, Serde, PartialEq, Introspect, DojoStore, Default)]
pub enum TournamentState {
    #[default]
    Undefined, // 0
    InProgress, // 1
    Finished, // 2
}


//------------------------------------
// Simple link between tournament and challenge for rating-based tournaments
//
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct TournamentBoard {
    #[key]
    pub board_id: felt252,
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

//---------------------------
// Converters
//
impl TournamentStateIntoByteArray of core::traits::Into<TournamentState, ByteArray> {
    fn into(self: TournamentState) -> ByteArray {
        match self {
            TournamentState::Undefined => "TournamentState::Undefined",
            TournamentState::InProgress => "TournamentState::InProgress",
            TournamentState::Finished => "TournamentState::Finished",
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

