use starknet::{ContractAddress};
use dojo::world::IWorldDispatcher;

#[starknet::interface]
pub trait IEvoluteCoin<TState> {
    // IWorldProvider
    fn world_dispatcher(self: @TState) -> IWorldDispatcher;

    // IERC20
    fn total_supply(self: @TState) -> u256;
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    fn approve(ref self: TState, spender: ContractAddress, amount: u256) -> bool;
    // IERC20Metadata
    fn name(self: @TState) -> ByteArray;
    fn symbol(self: @TState) -> ByteArray;
    fn decimals(self: @TState) -> u8;
    // IERC20CamelOnly
    fn totalSupply(self: @TState) -> u256;
    fn balanceOf(self: @TState, account: ContractAddress) -> u256;
    fn transferFrom(ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    
    // IEvoluteTokenProtected
    fn reward_player(ref self: TState, player_address: ContractAddress, amount: u128);
    fn burn(ref self: TState, amount: u128);
}

// Exposed to world
#[starknet::interface]
pub trait IEvoluteCoinProtected<TState> {
    fn reward_player(ref self: TState, player_address: ContractAddress, amount: u128);
    fn burn(ref self: TState, amount: u128);
}

#[dojo::contract]
pub mod evolute_coin {
    use core::num::traits::{Bounded};
    use starknet::{ContractAddress};
    use dojo::world::{WorldStorage};

    //-----------------------------------
    // ERC-20 Start
    //
    use openzeppelin_token::erc20::ERC20Component;
    use openzeppelin_token::erc20::ERC20HooksEmptyImpl;
    use evolute_duel::components::coin_component::{
        CoinComponent,
        // CoinComponent::{Errors as CoinErrors},
    };

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: CoinComponent, storage: coin, event: CoinEvent);

    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
    impl CoinComponentInternalImpl = CoinComponent::CoinComponentInternalImpl<ContractState>;
    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        coin: CoinComponent::Storage,
    }
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        CoinEvent: CoinComponent::Event,
    }
    //
    // ERC-20 End
    //-----------------------------------

    use evolute_duel::interfaces::dns::{DnsTrait};
    // use pistols::utils::math::{MathU128, MathU256};
    // use pistols::types::constants::{FAME};

    mod Errors {
        pub const INVALID_CALLER: felt252   = 'EVOLUTE: Invalid caller';
        pub const NOT_IMPLEMENTED: felt252  = 'EVOLUTE: Not implemented';
    }

    //*******************************************
    fn COIN_NAME() -> ByteArray {("Evolute Coin")}
    fn COIN_SYMBOL() -> ByteArray {("EVOLUTE")}
    //*******************************************

    fn dojo_init(ref self: ContractState) {
        let mut world = self.world_default();
        self.erc20.initializer(
            COIN_NAME(),
            COIN_SYMBOL(),
        );
        self.coin.initialize(
            world.rewards_manager_address(),
            faucet_amount: 0,
        );
    }
    
    #[generate_trait]
    impl WorldDefaultImpl of WorldDefaultTrait {
        #[inline(always)]
        fn world_default(self: @ContractState) -> WorldStorage {
            (self.world(@"evolute_duel"))
        }
    }

    //-----------------------------------
    // Public
    //
    #[abi(embed_v0)]
    impl EvoluteCoinPublicImpl of super::IEvoluteCoinProtected<ContractState> {
        fn reward_player(ref self: ContractState,
            player_address: ContractAddress,
            amount: u128,
        ) {
            // validate caller (duelist token contract)
            let _minter_address: ContractAddress = self.coin.assert_caller_is_minter();

            self.coin.mint(player_address, amount.into());
        }

        fn burn(ref self: ContractState,
            amount: u128,
        ) {
            let mut world = self.world_default();
            assert(world.caller_is_world_contract(), Errors::INVALID_CALLER);
            self.erc20.burn(starknet::get_caller_address(), amount.into());
        }
    }

}
