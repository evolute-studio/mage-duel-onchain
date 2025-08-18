use starknet::{ContractAddress};
use dojo::world::IWorldDispatcher;

#[starknet::interface]
pub trait IGrndToken<TState> {
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
    
    // IGrndTokenProtected
    fn mint(ref self: TState, recipient: ContractAddress, amount: u256);
    fn burn(ref self: TState, from: ContractAddress, amount: u256);
    fn reward_player(ref self: TState, player_address: ContractAddress, amount: u128);
}

// Exposed to game systems
#[starknet::interface]
pub trait IGrndTokenProtected<TState> {
    fn mint(ref self: TState, recipient: ContractAddress, amount: u256);
    fn burn(ref self: TState, from: ContractAddress, amount: u256);
    fn reward_player(ref self: TState, player_address: ContractAddress, amount: u128);
    fn set_minter(ref self: TState, minter_address: ContractAddress);
    fn set_faucet_amount(ref self: TState, faucet_amount: u128);
    fn faucet(ref self: TState, recipient: ContractAddress);
}

#[dojo::contract]
pub mod grnd_token {
    use starknet::{ContractAddress};
    use dojo::world::{WorldStorage, IWorldDispatcherTrait};
    use dojo::model::{ModelStorage};
    use core::num::traits::Zero;

    //-----------------------------------
    // ERC-20 Start
    //
    use openzeppelin_token::erc20::ERC20Component;
    use evolute_duel::components::coin_component::{
        CoinComponent,
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
        Minted: Minted,
        Burned: Burned,
        PlayerRewarded: PlayerRewarded,
        FaucetUsed: FaucetUsed,
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

    #[derive(Drop, starknet::Event)]
    struct PlayerRewarded {
        #[key]
        player: ContractAddress,
        amount: u128,
        source: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct FaucetUsed {
        #[key]
        recipient: ContractAddress,
        amount: u128,
    }
    //
    // ERC-20 End
    //-----------------------------------

    use evolute_duel::interfaces::dns::{DnsTrait};

    mod Errors {
        pub const INVALID_CALLER: felt252 = 'GRND: Invalid caller';
        pub const UNAUTHORIZED_MINT: felt252 = 'GRND: Unauthorized mint';
        pub const UNAUTHORIZED_BURN: felt252 = 'GRND: Unauthorized burn';
        pub const INSUFFICIENT_BALANCE: felt252 = 'GRND: Insufficient balance';
        pub const ZERO_ADDRESS: felt252 = 'GRND: Zero address';
        pub const ZERO_AMOUNT: felt252 = 'GRND: Zero amount';
        pub const FAUCET_DISABLED: felt252 = 'GRND: Faucet disabled';
        pub const TRANSFERS_DISABLED: felt252 = 'GRND: Transfers disabled';
    }

    //*******************************************
    fn TOKEN_NAME() -> ByteArray {("Grind Token")}
    fn TOKEN_SYMBOL() -> ByteArray {("GRND")}
    fn TOKEN_DECIMALS() -> u8 { 18 }
    const DEFAULT_FAUCET_AMOUNT: u128 = 100000000000000000000; // 100 GRND tokens (18 decimals)
    //*******************************************

    fn dojo_init(ref self: ContractState, game_system_address: ContractAddress) {
        let mut world = self.world_default();
        self.erc20.initializer(
            TOKEN_NAME(),
            TOKEN_SYMBOL(),
        );
        self.coin.initialize(
            game_system_address,  // Game systems can mint
            faucet_amount: DEFAULT_FAUCET_AMOUNT,  // Allow faucet for grindable token
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
    // Protected functions
    //
    #[abi(embed_v0)]
    impl GrndTokenProtectedImpl of super::IGrndTokenProtected<ContractState> {
        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            assert(!recipient.is_zero(), Errors::ZERO_ADDRESS);
            assert(amount > 0, Errors::ZERO_AMOUNT);
            
            // Validate caller is authorized minter (game systems or admin)
            let minter_address: ContractAddress = self.coin.assert_caller_is_minter();
            
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
            
            // Game systems can burn, or user burning their own tokens
            let caller = starknet::get_caller_address();
            let mut world = self.world_default();
            let is_game_system = world.dispatcher.is_owner(selector_from_tag!("evolute_duel-grnd_token"), caller);
            
            assert(is_game_system || caller == from, Errors::UNAUTHORIZED_BURN);
            
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

        fn reward_player(ref self: ContractState, player_address: ContractAddress, amount: u128) {
            assert(!player_address.is_zero(), Errors::ZERO_ADDRESS);
            assert(amount > 0, Errors::ZERO_AMOUNT);
            
            // Validate caller is authorized minter
            let minter_address: ContractAddress = self.coin.assert_caller_is_minter();
            
            // Mint tokens as reward
            self.erc20.mint(player_address, amount.into());
            
            // Emit reward event
            self.emit(PlayerRewarded {
                player: player_address,
                amount,
                source: minter_address,
            });
        }

        fn set_minter(ref self: ContractState, minter_address: ContractAddress) {
            // Only world admin can change minter
            let mut world = self.world_default();
            assert(world.caller_is_world_contract(), Errors::INVALID_CALLER);
            
            // Update minter in coin config while preserving faucet amount
            let coin_config = evolute_duel::models::config::CoinConfig {
                coin_address: starknet::get_contract_address(),
                minter_address,
                faucet_amount: DEFAULT_FAUCET_AMOUNT,
            };
            world.write_model(@coin_config);
        }

        fn set_faucet_amount(ref self: ContractState, faucet_amount: u128) {
            // Only admin can change faucet amount
            let mut world = self.world_default();
            assert(world.caller_is_world_contract(), Errors::INVALID_CALLER);
            
            // Update faucet amount
            self.coin.initialize(starknet::get_caller_address(), faucet_amount);
        }

        fn faucet(ref self: ContractState, recipient: ContractAddress) {
            assert(!recipient.is_zero(), Errors::ZERO_ADDRESS);
            
            // Use faucet from coin component
            self.coin.faucet(recipient);
            
            // Emit faucet event
            self.emit(FaucetUsed {
                recipient,
                amount: DEFAULT_FAUCET_AMOUNT,
            });
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