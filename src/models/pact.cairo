use starknet::ContractAddress;
use evolute_duel::models::challenge::{DuelType};

//
// Pact data represents an ongoing agreement between two players
//
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Pact {
    #[key]
    pub pair: u128, // packed pair of duelist ids
    #[key]
    pub duel_type: DuelType, // type of challenge
    //------
    pub player_a: ContractAddress, // player A
    pub player_b: ContractAddress, // player B  
    pub timestamp: u64, // pact timestamp
}

#[generate_trait]
pub impl PactImpl of PactTrait {
    #[inline(always)]
    fn make_pair(a: u256, b: u256) -> u128 {
        let a_u64: u64 = a.low.try_into().unwrap();
        let b_u64: u64 = b.low.try_into().unwrap();
        if (a_u64 < b_u64) {
            ((a_u64.into() * 0x100000000_u128) + b_u64.into())
        } else {
            ((b_u64.into() * 0x100000000_u128) + a_u64.into())
        }
    }

    #[inline(always)]
    fn exists(self: @Pact) -> bool {
        (*self.pair != 0)
    }

    #[inline(always)]
    fn includes_player(self: @Pact, player_address: ContractAddress) -> bool {
        (*self.player_a == player_address || *self.player_b == player_address)
    }
}
