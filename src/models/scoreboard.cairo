use starknet::ContractAddress;
#[derive(Copy, Drop, Introspect, Serde)]
#[dojo::model]
pub struct Scoreboard {
    #[key]
    pub tournament_id: u64,
    #[key]
    pub player_address: ContractAddress,
    pub score: u16,
}

#[generate_trait]
pub impl ScoreboardImpl of ScoreboardTrait {
    #[inline(always)]
    fn apply_rewards(ref self: Scoreboard, rewards: u16) {
        self.score += rewards;
    }
}