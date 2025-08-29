use starknet::ContractAddress;

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct CoinConfig {
    #[key]
    pub coin_address: ContractAddress,
    //------
    pub admin_address: ContractAddress,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct EvltConfig {
    #[key]
    pub config_id: u32, // Always 1 for singleton
    //------
    pub token_address: ContractAddress,
    pub admin_address: ContractAddress,
    pub total_supply_cap: u256, // Maximum tokens that can ever be minted
    pub is_paused: bool, // Emergency pause functionality
    pub staking_enabled: bool, // Future staking feature flag
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
pub struct GrndConfig {
    #[key]
    pub config_id: u32, // Always 1 for singleton
    //------
    pub token_address: ContractAddress,
    pub game_system_address: ContractAddress,
    pub faucet_amount: u128,
    pub faucet_enabled: bool,
    pub reward_multiplier: u32, // Base multiplier for game rewards (100 = 1x, 150 = 1.5x)
    pub daily_reward_cap: u256, // Maximum tokens a player can earn per day
    pub burn_on_upgrade: bool, // Whether upgrades should burn GRND tokens
}
