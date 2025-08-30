use starknet::{ContractAddress};
#[starknet::interface]
pub trait IEvltToken<TState> {
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

    // IEvltTokenProtected
    fn mint(ref self: TState, recipient: ContractAddress, amount: u256);
    fn burn(ref self: TState, from: ContractAddress, amount: u256);
    fn set_transfer_allowed(ref self: TState, allowed_address: ContractAddress);
}

// Exposed to world and admins only
#[starknet::interface]
pub trait IEvltTokenProtected<TState> {
    fn mint(ref self: TState, recipient: ContractAddress, amount: u256);
    fn burn(ref self: TState, from: ContractAddress, amount: u256);
    fn set_minter(ref self: TState, minter_address: ContractAddress);
    fn set_burner(ref self: TState, burner_address: ContractAddress);
    fn set_transfer_allowed(ref self: TState, allowed_address: ContractAddress);
}

#[dojo::contract]
pub mod evlt_token {
    use starknet::{ContractAddress};
    use dojo::world::{WorldStorage};
    use core::num::traits::Zero;

    //-----------------------------------
    // ERC-20 Start
    //
    use openzeppelin_token::erc20::{ERC20Component};
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

    //Internal
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
        Minted: Minted,
        Burned: Burned,
        #[flat]
        SRC5Event: SRC5Component::Event,
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
        pub const TOP_UP_NOT_FOUND: felt252 = 'EVLT: Top-up contract not found';
        pub const ZERO_AMOUNT: felt252 = 'EVLT: Zero amount';
        pub const TRANSFERS_DISABLED: felt252 = 'EVLT: Transfers disabled';
    }

    //*******************************************
    pub fn TOKEN_NAME() -> ByteArray {
        ("Evolute Premium Token")
    }
    pub fn TOKEN_SYMBOL() -> ByteArray {
        ("EVLT")
    }
    pub fn TOKEN_DECIMALS() -> u8 {
        18
    }
    //*******************************************

    // Access Control Roles
    use openzeppelin_access::accesscontrol::DEFAULT_ADMIN_ROLE;
    pub const MINTER_ROLE: felt252 = 'MINTER_ROLE';
    pub const BURNER_ROLE: felt252 = 'BURNER_ROLE';
    pub const TRANSFER_ROLE: felt252 = 'TRANSFER_ROLE';

    fn dojo_init(ref self: ContractState, admin_address: ContractAddress) {
        let mut world = self.world_default();

        // Initialize ERC20
        self.erc20.initializer(TOKEN_NAME(), TOKEN_SYMBOL());

        // Initialize access control with admin
        self.accesscontrol.initializer();
        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, admin_address);

        // Get evlt_topup address from DNS and grant minter role
        let evlt_topup_address = world.find_contract_address(@"evlt_topup");
        assert(!evlt_topup_address.is_zero(), Errors::TOP_UP_NOT_FOUND);
        if !evlt_topup_address.is_zero() {
            self.accesscontrol._grant_role(MINTER_ROLE, evlt_topup_address);
        }

        // Get tournament_token address from DNS and grant burner and transfer roles
        let tournament_token_address = world.find_contract_address(@"tournament_token");
        if !tournament_token_address.is_zero() {
            self.accesscontrol._grant_role(BURNER_ROLE, tournament_token_address);
            self.accesscontrol._grant_role(TRANSFER_ROLE, tournament_token_address);
        }

        // Get budokan tournament address from DNS and grant transfer role
        let budokan_address = world.find_contract_address(@"tournament");
        if !budokan_address.is_zero() {
            self.accesscontrol._grant_role(TRANSFER_ROLE, budokan_address);
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

        fn set_transfer_allowed(ref self: ContractState, allowed_address: ContractAddress) {
            // Only admin can change transfer permissions
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);

            // Grant transfer role to new address
            self.accesscontrol._grant_role(TRANSFER_ROLE, allowed_address);
        }
    }

    impl ERC20HooksImpl of ERC20Component::ERC20HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) {
            println!("[before_update] Starting EVLT token transfer validation");
            println!("[before_update] from: {:?}, recipient: {:?}, amount: {}", from, recipient, amount);

            // Allow minting (from zero address) and burning (to zero address)
            if from.is_zero() {
                println!("[before_update] Minting operation detected (from zero address) - allowing");
                return;
            }
            if recipient.is_zero() {
                println!("[before_update] Burning operation detected (to zero address) - allowing");
                return;
            }

            println!("[before_update] Transfer operation between non-zero addresses detected");

            // Allow transfers initiated by addresses with TRANSFER_ROLE (like budokan tournaments)
            let caller = starknet::get_caller_address();
            println!("[before_update] Caller address: {:?}", caller);
            
            let contract_state = self.get_contract();
            println!("[before_update] Contract state retrieved successfully");

            let has_transfer_role = contract_state.accesscontrol.has_role(TRANSFER_ROLE, caller);
            println!("[before_update] Caller has TRANSFER_ROLE: {}", has_transfer_role);

            if has_transfer_role {
                println!("[before_update] Transfer allowed - caller has TRANSFER_ROLE");
                return;
            }

            println!("[before_update] Transfer BLOCKED - caller does not have TRANSFER_ROLE");
            println!("[before_update] Blocking transfer with TRANSFERS_DISABLED error");
            // Block all other transfers between non-zero addresses
            panic(array![Errors::TRANSFERS_DISABLED]);
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
