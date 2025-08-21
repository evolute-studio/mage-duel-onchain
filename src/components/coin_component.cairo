use starknet::{ContractAddress};

#[starknet::interface]
pub trait ICoinComponentInternal<TState> {
    fn initialize(ref self: TState, admin_address: ContractAddress);
    fn can_mint(self: @TState, caller: ContractAddress) -> bool;
    fn assert_caller_is_minter(self: @TState) -> ContractAddress;
    fn mint(ref self: TState, recipient: ContractAddress, amount: u256);
    fn grant_minter_role(ref self: TState, minter_address: ContractAddress);
    fn revoke_minter_role(ref self: TState, minter_address: ContractAddress);
}

#[starknet::component]
pub mod CoinComponent {
    use core::num::traits::Zero;
    use starknet::{ContractAddress};
    use dojo::contract::components::world_provider::{IWorldProvider};
    use dojo::model::ModelStorage;
    
    use openzeppelin_token::erc20::{
        ERC20Component,
        ERC20Component::{InternalImpl as ERC20InternalImpl},
    };

    use evolute_duel::interfaces::dns::{DnsTrait};
    use evolute_duel::models::config::{CoinConfig};

    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub enum Event {}

    pub mod Errors {
        pub const CALLER_IS_NOT_MINTER: felt252 = 'COIN: caller is not minter';
        pub const ZERO_ADDRESS: felt252 = 'COIN: Zero address';
    }


    //-----------------------------------------
    // Internal
    //
    #[embeddable_as(CoinComponentInternalImpl)]
    pub impl CoinComponentInternal<
        TContractState,
        +HasComponent<TContractState>,
        +IWorldProvider<TContractState>,
        +ERC20Component::ERC20HooksTrait<TContractState>,
        impl ERC20: ERC20Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of super::ICoinComponentInternal<ComponentState<TContractState>> {
        fn initialize(ref self: ComponentState<TContractState>, admin_address: ContractAddress) {
            assert(!admin_address.is_zero(), Errors::ZERO_ADDRESS);
            
            // Save coin config with admin address
            let mut world = DnsTrait::storage(self.get_contract().world_dispatcher(), @"evolute_duel");
            let coin_config: CoinConfig = CoinConfig {
                coin_address: starknet::get_contract_address(),
                admin_address,
            };
            world.write_model(@coin_config);
        }

        fn can_mint(self: @ComponentState<TContractState>, caller: ContractAddress) -> bool {
            // This will be overridden by token contracts to check their AccessControl
            let _ = (self, caller);
            true  // Default implementation - token contracts should override this
        }

        fn assert_caller_is_minter(self: @ComponentState<TContractState>) -> ContractAddress {
            let caller: ContractAddress = starknet::get_caller_address();
            // Token contracts should override can_mint to provide proper role checking
            assert(self.can_mint(caller), Errors::CALLER_IS_NOT_MINTER);
            caller
        }

        fn mint(ref self: ComponentState<TContractState>, recipient: ContractAddress, amount: u256) {
            self.assert_caller_is_minter();
            let mut erc20 = get_dep_component_mut!(ref self, ERC20);
            erc20.mint(recipient, amount);
        }

        fn grant_minter_role(ref self: ComponentState<TContractState>, minter_address: ContractAddress) {
            // This will be implemented by the tokens themselves using their AccessControl
            let _ = (self, minter_address);
        }

        fn revoke_minter_role(ref self: ComponentState<TContractState>, minter_address: ContractAddress) {
            // This will be implemented by the tokens themselves using their AccessControl
            let _ = (self, minter_address);
        }
    }

}
