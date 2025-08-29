use starknet::{ContractAddress};
use evolute_duel::types::challenge_state::{ChallengeState, ChallengeStateTrait};
use evolute_duel::types::timestamp::{Period};

//-------------------------
// Challenge lifecycle
//
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Challenge {
    #[key]
    pub duel_id: felt252,
    //-------------------------
    // settings
    pub duel_type: DuelType, // duel type
    // duelists
    pub address_a: ContractAddress,
    pub address_b: ContractAddress, // Challenged wallet
    // progress and results
    pub state: ChallengeState, // current state
    pub winner: u8, // 0:draw, 1:duelist_a, 2:duelist_b
    // timestamps in unix epoch
    pub timestamps: Period,
}

#[derive(Serde, Copy, Drop, PartialEq, Introspect)]
pub enum DuelType {
    Undefined, // 0
    Regular, // 1
    Tournament // 2
    // Practice,       // 3
}

//------------------------------------
// Traits
//

#[generate_trait]
pub impl ChallengeImpl of ChallengeTrait {
    #[inline(always)]
    fn duelist_number(self: @Challenge, player_address: ContractAddress) -> u8 {
        (if (player_address == *self.address_a) {
            (1)
        } else if (player_address == *self.address_b) {
            (2)
        } else {
            (0)
        })
    }
    #[inline(always)]
    fn winner_address(self: @Challenge) -> ContractAddress {
        (if (*self.winner == 1) {
            *self.address_a
        } else if (*self.winner == 2) {
            *self.address_b
        } else {
            starknet::contract_address_const::<0>()
        })
    }
    #[inline(always)]
    fn exists(self: @Challenge) -> bool {
        ((*self.state).exists())
    }
    #[inline(always)]
    fn is_tournament(self: @Challenge) -> bool {
        (*self.duel_type == DuelType::Tournament)
    }
}
// #[generate_trait]
// pub impl RoundImpl of RoundTrait {
//     #[inline(always)]
//     fn make_seed(self: @Round) -> felt252 {
//         (hash_values([(*self).moves_a.salt, (*self).moves_b.salt].span()))
//     }
//     fn set_commit_timeout(ref self: Round, rules: Rules, current_timestamp: u64) {
//         self.moves_a.set_commit_timeout(rules, current_timestamp);
//         self.moves_b.set_commit_timeout(rules, current_timestamp);
//     }
//     fn set_reveal_timeout(ref self: Round, rules: Rules, current_timestamp: u64) {
//         self.moves_a.set_reveal_timeout(rules, current_timestamp);
//         self.moves_b.set_reveal_timeout(rules, current_timestamp);
//     }
// }

// #[generate_trait]
// pub impl MovesImpl of MovesTrait {
//     fn reveal_salt_and_moves(ref self: Moves, salt: felt252, moves: Span<u8>) {
//         self.salt = salt;
//         self.card_1 = moves.value_or_zero(0);
//         self.card_2 = moves.value_or_zero(1);
//         self.card_3 = moves.value_or_zero(2);
//         self.card_4 = moves.value_or_zero(3);
//     }
//     #[inline(always)]
//     fn as_hand(self: @Moves) -> DuelistHand {
//         (DuelistHand {
//             card_fire: (*self.card_1).into(),
//             card_dodge: (*self.card_2).into(),
//             card_tactics: (*self.card_3).into(),
//             card_blades: (*self.card_4).into(),
//         })
//     }
//     #[inline(always)]
//     fn has_comitted(self: @Moves) -> bool {
//         (*self.hashed != 0)
//     }
//     #[inline(always)]
//     fn has_revealed(self: @Moves) -> bool {
//         (*self.salt != 0)
//     }
//     #[inline(always)]
//     fn set_commit_timeout(ref self: Moves, rules: Rules, current_timestamp: u64) {
//         self.timeout = if (!self.has_comitted()) {(current_timestamp +
//         rules.get_reply_timeout())} else {(0)};
//     }
//     #[inline(always)]
//     fn set_reveal_timeout(ref self: Moves, rules: Rules, current_timestamp: u64) {
//         self.timeout = if (!self.has_revealed()) {(current_timestamp +
//         rules.get_reply_timeout())} else {(0)};
//     }
//     #[inline(always)]
//     fn has_timed_out(ref self: Moves, challenge: @Challenge) -> bool {
//         (self.timeout.has_timed_out(challenge))
//     }
// }

// #[generate_trait]
// pub impl DuelistStateImpl of DuelistStateTrait {
//     fn initialize(ref self: DuelistState, hand: DuelistHand) {
//         self = Default::default();
//         self.chances = CONST::INITIAL_CHANCE;
//         self.damage = CONST::INITIAL_DAMAGE;
//         self.health = CONST::FULL_HEALTH;
//         self.honour = hand.card_fire.honour();
//     }
//     #[inline(always)]
//     fn apply_damage(ref self: DuelistState, amount: i8) {
//         self.damage.addi(amount);
//     }
//     #[inline(always)]
//     fn apply_chances(ref self: DuelistState, amount: i8) {
//         self.chances.addi(amount);
//         self.chances.clampi(0, 100);
//     }
// }

// //---------------------------
// // Converters
// //
// impl DuelTypeIntoByteArray of core::traits::Into<DuelType, ByteArray> {
//     fn into(self: DuelType) -> ByteArray {
//         match self {
//             DuelType::Undefined    => "DuelType::Undefined",
//             DuelType::Seasonal     => "DuelType::Seasonal",
//             DuelType::Tournament   => "DuelType::Tournament",
//             DuelType::Tutorial     => "DuelType::Tutorial",
//             DuelType::Practice     => "DuelType::Practice",
//         }
//     }
// }
// // for println! format! (core::fmt::Display<>) assert! (core::fmt::Debug<>)
// pub impl DuelTypeDisplay of core::fmt::Display<DuelType> {
//     fn fmt(self: @DuelType, ref f: core::fmt::Formatter) -> Result<(), core::fmt::Error> {
//         let result: ByteArray = (*self).into();
//         f.buffer.append(@result);
//         Result::Ok(())
//     }
// }
// pub impl DuelTypeDebug of core::fmt::Debug<DuelType> {
//     fn fmt(self: @DuelType, ref f: core::fmt::Formatter) -> Result<(), core::fmt::Error> {
//         let result: ByteArray = (*self).into();
//         f.buffer.append(@result);
//         Result::Ok(())
//     }
// }

