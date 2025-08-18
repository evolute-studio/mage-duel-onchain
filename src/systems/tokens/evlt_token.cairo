use starknet::{ContractAddress};
use dojo::world::IWorldDispatcher;

#[starknet::interface]
pub trait IEvltToken<TState> {
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
    
    // IEvltTokenProtected
    fn mint(ref self: TState, recipient: ContractAddress, amount: u256);
    fn burn(ref self: TState, from: ContractAddress, amount: u256);
}

// Exposed to world and admins only
#[starknet::interface]
pub trait IEvltTokenProtected<TState> {
    fn mint(ref self: TState, recipient: ContractAddress, amount: u256);
    fn burn(ref self: TState, from: ContractAddress, amount: u256);
    fn set_minter(ref self: TState, minter_address: ContractAddress);
}

#[dojo::contract]
pub mod evlt_token {
    use starknet::{ContractAddress};
    use dojo::world::{WorldStorage, IWorldDispatcher, IWorldDispatcherTrait};
    use core::num::traits::Zero;

    //-----------------------------------
    // ERC-20 Start
    //
    use openzeppelin_token::erc20::{
        ERC20Component,
    };
    use openzeppelin_access::accesscontrol::AccessControlComponent;
    use openzeppelin_introspection::src5::SRC5Component;
    use evolute_duel::components::coin_component::{
        CoinComponent,
    };

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: CoinComponent, storage: coin, event: CoinEvent);
    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl AccessControlMixinImpl = AccessControlComponent::AccessControlMixinImpl<ContractState>;

    //Internal
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
    impl CoinComponentInternalImpl = CoinComponent::CoinComponentInternalImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        coin: CoinComponent::Storage,
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        CoinEvent: CoinComponent::Event,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        Minted: Minted,
        Burned: Burned,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    #[derive(Drop, starknet::Event)]
    struct Minted {
        #[key]
        recipient: ContractAddress,
        amount: u256,
        minter: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct Burned {
        #[key]
        from: ContractAddress,
        amount: u256,
        burner: ContractAddress,
    }
    //
    // ERC-20 End
    //-----------------------------------

    use evolute_duel::interfaces::dns::{DnsTrait};

    mod Errors {
        pub const INVALID_CALLER: felt252 = 'EVLT: Invalid caller';
        pub const UNAUTHORIZED_MINT: felt252 = 'EVLT: Unauthorized mint';
        pub const UNAUTHORIZED_BURN: felt252 = 'EVLT: Unauthorized burn';
        pub const INSUFFICIENT_BALANCE: felt252 = 'EVLT: Insufficient balance';
        pub const ZERO_ADDRESS: felt252 = 'EVLT: Zero address';
        pub const ZERO_AMOUNT: felt252 = 'EVLT: Zero amount';
        pub const TRANSFERS_DISABLED: felt252 = 'EVLT: Transfers disabled';
    }

    //*******************************************
    fn TOKEN_NAME() -> ByteArray {("Evolute Premium Token")}
    fn TOKEN_SYMBOL() -> ByteArray {("EVLT")}
    fn TOKEN_DECIMALS() -> u8 { 18 }
    //*******************************************

    // Access Control Roles
    use openzeppelin_access::accesscontrol::DEFAULT_ADMIN_ROLE;
    pub const MINTER_ROLE: felt252 = 'MINTER_ROLE';

    fn dojo_init(ref self: ContractState, admin_address: ContractAddress, minter_address: ContractAddress) {
        let mut world = self.world_default();
        self.erc20.initializer(
            TOKEN_NAME(),
            TOKEN_SYMBOL(),
        );
        self.coin.initialize(
            admin_address,  // Only admin can mint initially
            faucet_amount: 0,  // No faucet for premium token
        );
        // Initialize access control with admin
        self.accesscontrol.initializer();
        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, admin_address);
        self.accesscontrol._grant_role(MINTER_ROLE, minter_address);
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
    impl EvltTokenProtectedImpl of super::IEvltTokenProtected<ContractState> {
        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            assert(!recipient.is_zero(), Errors::ZERO_ADDRESS);
            assert(amount > 0, Errors::ZERO_AMOUNT);
            
            // Validate caller has MINTER_ROLE
            self.accesscontrol.assert_only_role(MINTER_ROLE);
            let minter_address = starknet::get_caller_address();
            
            // Mint tokens
            self.erc20.mint(recipient, amount);
            
            // Emit custom event
            self.emit(Minted {
                recipient,
                amount,
                minter: minter_address,
            });
        }

        fn burn(ref self: ContractState, from: ContractAddress, amount: u256) {
            assert(!from.is_zero(), Errors::ZERO_ADDRESS);
            assert(amount > 0, Errors::ZERO_AMOUNT);
            
            // Only admin can burn or user burning their own tokens
            let caller = starknet::get_caller_address();
            let is_admin = self.accesscontrol.has_role(DEFAULT_ADMIN_ROLE, caller);
            
            assert(is_admin || caller == from, Errors::UNAUTHORIZED_BURN);
            
            // Check balance
            let balance = self.erc20.balance_of(from);
            assert(balance >= amount, Errors::INSUFFICIENT_BALANCE);
            
            // Burn tokens
            self.erc20.burn(from, amount);
            
            // Emit custom event
            self.emit(Burned {
                from,
                amount,
                burner: caller,
            });
        }

        fn set_minter(ref self: ContractState, minter_address: ContractAddress) {
            // Only admin can change minter
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);
            
            // Grant minter role to new address
            self.accesscontrol._grant_role(MINTER_ROLE, minter_address);
        }
    }

    impl ERC20HooksImpl of ERC20Component::ERC20HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            // Allow minting (from zero address) and burning (to zero address)
            // Block all transfers between non-zero addresses
            if !from.is_zero() && !recipient.is_zero() {
                panic(array![Errors::TRANSFERS_DISABLED]);
            }
        }

        fn after_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            // No additional logic needed after update
            let _ = (from, recipient, amount);
        }
    }
}