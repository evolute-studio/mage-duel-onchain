use starknet::ContractAddress;

//------------------------------------
// Tournament eEVLT Balance - tournament-specific entry tokens
//
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct TournamentBalance {
    #[key]
    pub player_address: ContractAddress,
    #[key]
    pub tournament_id: u64,
    //------
    pub eevlt_balance: u32, // Number of tournament games available for this specific tournament
}

//------------------------------------
// Events for tournament balance operations
//

#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct EevltMinted {
    #[key]
    pub player_address: ContractAddress,
    #[key]
    pub tournament_id: u64,
    pub amount: u32,
}

#[derive(Copy, Drop, Serde, Introspect, Debug)]
#[dojo::event]
pub struct EevltBurned {
    #[key]
    pub player_address: ContractAddress,
    #[key]
    pub tournament_id: u64,
    pub amount: u32,
}

//------------------------------------
// Traits and implementations
//

#[generate_trait]
pub impl TournamentBalanceImpl of TournamentBalanceTrait {
    fn new(player_address: ContractAddress, tournament_id: u64) -> TournamentBalance {
        TournamentBalance { player_address, tournament_id, eevlt_balance: 0 }
    }

    fn add_balance(ref self: TournamentBalance, amount: u32) {
        self.eevlt_balance += amount;
    }

    fn spend_balance(ref self: TournamentBalance, amount: u32) -> bool {
        if self.eevlt_balance >= amount {
            self.eevlt_balance -= amount;
            true
        } else {
            false
        }
    }

    fn can_spend(self: @TournamentBalance, amount: u32) -> bool {
        *self.eevlt_balance >= amount
    }
}
