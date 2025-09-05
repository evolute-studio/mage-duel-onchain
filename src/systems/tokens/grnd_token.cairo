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
    fn transfer_from(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256,
    ) -> bool;
    fn approve(ref self: TState, spender: ContractAddress, amount: u256) -> bool;
    // IERC20Metadata
    fn name(self: @TState) -> ByteArray;
    fn symbol(self: @TState) -> ByteArray;
    fn decimals(self: @TState) -> u8;
    // IERC20CamelOnly
    fn totalSupply(self: @TState) -> u256;
    fn balanceOf(self: @TState, account: ContractAddress) -> u256;
    fn transferFrom(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256,
    ) -> bool;

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
    fn set_burner(ref self: TState, burner_address: ContractAddress);
}

#[dojo::contract]
pub mod grnd_token {
    use starknet::{ContractAddress};
    use dojo::world::{WorldStorage};
    use core::num::traits::Zero;

    //-----------------------------------
    // ERC-20 Start
    //
    use openzeppelin_token::erc20::ERC20Component;
    use openzeppelin_access::accesscontrol::AccessControlComponent;
    use openzeppelin_introspection::src5::SRC5Component;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl AccessControlMixinImpl =
        AccessControlComponent::AccessControlMixinImpl<ContractState>;

    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        Minted: Minted,
        Burned: Burned,
        PlayerRewarded: PlayerRewarded,
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
        pub const TRANSFERS_DISABLED: felt252 = 'GRND: Transfers disabled';
    }

    //*******************************************
    fn TOKEN_NAME() -> ByteArray {
        ("Grind Token")
    }
    fn TOKEN_SYMBOL() -> ByteArray {
        ("GRND")
    }
    fn TOKEN_DECIMALS() -> u8 {
        18
    }
    //*******************************************

    // Access Control Roles
    use openzeppelin_access::accesscontrol::DEFAULT_ADMIN_ROLE;
    pub const MINTER_ROLE: felt252 = 'MINTER_ROLE';
    pub const BURNER_ROLE: felt252 = 'BURNER_ROLE';

    fn dojo_init(ref self: ContractState, admin_address: ContractAddress) {
        let mut world = self.world_default();

        // Initialize ERC20
        self.erc20.initializer(TOKEN_NAME(), TOKEN_SYMBOL());

        // Initialize access control with admin
        self.accesscontrol.initializer();
        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, admin_address);

        // Get game system address from DNS and grant minter role
        let game_address = world.find_contract_address(@"game");
        if !game_address.is_zero() {
            self.accesscontrol._grant_role(MINTER_ROLE, game_address);
        }

        // Get rewards_manager address from DNS and grant minter role
        let rewards_manager_address = world.find_contract_address(@"rewards_manager");
        if !rewards_manager_address.is_zero() {
            self.accesscontrol._grant_role(MINTER_ROLE, rewards_manager_address);
        }
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

            // Validate caller has MINTER_ROLE
            self.accesscontrol.assert_only_role(MINTER_ROLE);
            let minter_address = starknet::get_caller_address();

            // Mint tokens
            self.erc20.mint(recipient, amount);

            // Emit custom event
            self.emit(Minted { recipient, amount, minter: minter_address });
        }

        fn burn(ref self: ContractState, from: ContractAddress, amount: u256) {
            assert(!from.is_zero(), Errors::ZERO_ADDRESS);
            assert(amount > 0, Errors::ZERO_AMOUNT);

            // Only admin, burner role, or user burning their own tokens
            let caller = starknet::get_caller_address();
            let is_admin = self.accesscontrol.has_role(DEFAULT_ADMIN_ROLE, caller);
            let is_burner = self.accesscontrol.has_role(BURNER_ROLE, caller);

            assert(is_admin || is_burner || caller == from, Errors::UNAUTHORIZED_BURN);

            // Check balance
            let balance = self.erc20.balance_of(from);
            assert(balance >= amount, Errors::INSUFFICIENT_BALANCE);

            // Burn tokens
            self.erc20.burn(from, amount);

            // Emit custom event
            self.emit(Burned { from, amount, burner: caller });
        }

        fn reward_player(ref self: ContractState, player_address: ContractAddress, amount: u128) {
            assert(!player_address.is_zero(), Errors::ZERO_ADDRESS);
            assert(amount > 0, Errors::ZERO_AMOUNT);

            // Validate caller has MINTER_ROLE
            self.accesscontrol.assert_only_role(MINTER_ROLE);
            let minter_address = starknet::get_caller_address();

            // Mint tokens as reward
            self.erc20.mint(player_address, amount.into());

            // Emit reward event
            self.emit(PlayerRewarded { player: player_address, amount, source: minter_address });
        }

        fn set_minter(ref self: ContractState, minter_address: ContractAddress) {
            // Only admin can change minter
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);

            // Grant minter role to new address
            self.accesscontrol._grant_role(MINTER_ROLE, minter_address);
        }

        fn set_burner(ref self: ContractState, burner_address: ContractAddress) {
            // Only admin can change burner
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);

            // Grant burner role to new address
            self.accesscontrol._grant_role(BURNER_ROLE, burner_address);
        }
    }

    impl ERC20HooksImpl of ERC20Component::ERC20HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
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
            amount: u256,
        ) {
            // No additional logic needed after update
            let _ = (from, recipient, amount);
        }
    }
}
