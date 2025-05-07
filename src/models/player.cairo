use starknet::{ContractAddress};

/// Represents a player profile, tracking in-game identity and statistics.
///
/// - `player_id`: Unique identifier for the player.
/// - `username`: Player's chosen in-game name.
/// - `balance`: Current balance of in-game currency or points.
/// - `games_played`: Total number of games played by the player.
/// - `active_skin`: The currently equipped skin or avatar.
#[derive(Drop, Serde, Introspect, Debug)]
#[dojo::model]
pub struct Player {
    #[key]
    pub player_id: ContractAddress,
    pub username: felt252,
    pub balance: u16,
    pub games_played: felt252,
    pub active_skin: u8,
    pub is_bot: bool,
}

#[derive(Copy, Drop, Serde, Introspect)]
#[dojo::model]
pub struct PlayerAssignment {
    #[key]
    pub player_address: ContractAddress,
    //-----------------------
    pub duel_id: felt252,      // current Challenge a Duelist is in
    pub tournament_id: u64,       // current Tournament a Duelist is in
}

use core::num::traits::Zero;
use evolute_duel::libs::store::{
    Store, StoreImpl
};
use evolute_duel::types::errors::{
    duel::{
        Errors as DuelErrors
    },
    tournament::{
        Errors as TournamentErrors
    }
};


#[generate_trait]
pub impl PlayerImpl of PlayerTrait {
    fn enter_challenge(ref self: Store, player_address: ContractAddress, duel_id: felt252) {
        let mut assignment: PlayerAssignment = self.get_player_challenge(player_address);
        assert(assignment.duel_id == 0, DuelErrors::DUELIST_IN_CHALLENGE);
        assignment.duel_id = duel_id;
        self.set_player_challenge(@assignment);
    }
    fn exit_challenge(ref self: Store, player_address: ContractAddress) {
        if (player_address.is_non_zero()) {
            let mut assignment: PlayerAssignment = self.get_player_challenge(player_address);
            assignment.duel_id = 0;
            self.set_player_challenge(@assignment);
        }
    }
    // fn enter_tournament(ref self: Store, player_address: ContractAddress, pass_id: u64) {
    //     let mut assignment: PlayerAssignment = self.get_player_challenge(player_address);
    //     assert(assignment.duel_id.is_zero(), TournamentErrors::DUELIST_IN_CHALLENGE);
    //     assert(assignment.pass_id.is_zero(), TournamentErrors::DUELIST_IN_TOURNAMENT);
    //     assignment.pass_id = pass_id;
    //     self.set_player_challenge(@assignment);
    // }
    // fn exit_tournament(ref self: Store, player_address: ContractAddress) {
    //     let mut assignment: PlayerAssignment = self.get_player_challenge(player_address);
    //     assignment.pass_id = 0;
    //     self.set_player_challenge(@assignment);
    // }
}