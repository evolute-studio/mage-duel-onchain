use starknet::ContractAddress;
#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct Registration {
    #[key]
    pub tournament_id: u64,
    #[key]
    pub player_address: ContractAddress,
    pub is_registered: bool,
}