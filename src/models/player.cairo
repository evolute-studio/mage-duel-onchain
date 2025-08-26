use starknet::ContractAddress;
use core::num::traits::Zero;
// --------------------------------------
// Player Profile Models
// --------------------------------------

/// Represents a player profile, tracking in-game identity and statistics.
///
/// - `player_id`: Unique identifier for the player.
/// - `username`: Player's chosen in-game name.
/// - `balance`: Current balance of in-game currency or points.
/// - `games_played`: Total number of games played by the player.
/// - `active_skin`: The currently equipped skin or avatar.
#[derive(Drop, Serde, Copy, Introspect, Debug)]
#[dojo::model]
pub struct Player {
    #[key]
    pub player_id: ContractAddress,
    pub username: felt252,
    pub balance: u32,
    pub games_played: felt252,
    pub active_skin: u8,
    pub role: u8, // 0: Guest, 1: Controller, 2: Bot
    pub tutorial_completed: bool,
    pub migration_target: ContractAddress,
    pub migration_initiated_at: u64,
    pub migration_used: bool, // Prevents repeated migrations
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct PlayerAssignment {
    #[key]
    pub player_address: ContractAddress,
    //-----------------------
    pub duel_id: felt252, // current Duel a Player is in
    pub pass_id: u64, // current Tournament a Player is in
}

use evolute_duel::libs::store::{Store, StoreTrait};

#[generate_trait]
pub impl PlayerImpl of PlayerTrait {
    fn is_bot(self: @Player) -> bool {
        *self.role == 2
    }

    fn is_controller(self: @Player) -> bool {
        *self.role == 1
    }

    fn is_guest(self: @Player) -> bool {
        *self.role == 0
    }

    fn can_migrate(self: @Player) -> bool {
        *self.role == 0
            && *self.tutorial_completed
            && (*self.migration_target).is_zero()
            && !*self.migration_used
    }

    fn has_pending_migration(self: @Player) -> bool {
        !(*self.migration_target).is_zero()
    }

    // Tournament methods
    fn can_join_tournament(self: @Player) -> bool {
        // Players can join tournaments if they are not guests or have completed tutorial
        *self.role != 0 || *self.tutorial_completed
    }

    // Tournament integration - placeholder for now
    // Implementation will be completed when Store is fixed
    fn prepare_for_tournament(self: @Player) -> bool {
        self.can_join_tournament()
    }

    // Enter tournament method - static method for tournament entry
    fn enter_tournament(ref store: Store, player_address: starknet::ContractAddress, pass_id: u64) {
        // Create player assignment for this tournament pass
        let player_assignment = PlayerAssignment {
            player_address: player_address,
            pass_id: pass_id,
            duel_id: 0 // Will be set when matched in tournament
        };

        // Save player assignment
        store.set_player_challenge(@player_assignment);
    }
}

