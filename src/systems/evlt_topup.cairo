use starknet::{ContractAddress};
use dojo::world::IWorldDispatcher;

#[starknet::interface]
pub trait ITopUp<TState> {
    // --- single top-up ---
    fn mint_evlt(ref self: TState, user: ContractAddress, amount: u256, source: felt252);

    // --- batch top-up ---
    fn mint_evlt_batch(ref self: TState, users: Span<ContractAddress>, amounts: Span<u256>, source: felt252);

    // --- views ---
    fn get_topup_history(self: @TState, user: ContractAddress) -> (Span<u256>, Span<u64>);
    fn get_total_topups(self: @TState, user: ContractAddress) -> u256;
}

#[starknet::interface]
pub trait ITopUpAdmin<TState> {
    fn set_evlt_token_address(ref self: TState, token_address: ContractAddress);
    fn grant_minter_role(ref self: TState, account: ContractAddress);
    fn revoke_minter_role(ref self: TState, account: ContractAddress);
}

#[dojo::contract]
pub mod evlt_topup {
    use starknet::{
        ContractAddress, get_caller_address, get_block_timestamp, 
        storage::{StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess, StoragePointerWriteAccess}
    };
    use dojo::world::{WorldStorage, IWorldDispatcherTrait};
    use core::num::traits::Zero;

    use super::{ITopUp, ITopUpAdmin};
    use evolute_duel::systems::tokens::evlt_token::{IEvltTokenProtectedDispatcher, IEvltTokenProtectedDispatcherTrait};

    //-----------------------------------
    // Access Control
    //
    use openzeppelin_access::accesscontrol::AccessControlComponent;
    use openzeppelin_access::accesscontrol::DEFAULT_ADMIN_ROLE;
    use openzeppelin_introspection::src5::SRC5Component;

    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl AccessControlMixinImpl = AccessControlComponent::AccessControlMixinImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;

    //-----------------------------------
    // Storage
    //
    #[storage]
    struct Storage {
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        evlt_token_address: ContractAddress,
        user_topup_history: starknet::storage::Map<(ContractAddress, u32), (u256, u64)>, // (user, index) -> (amount, timestamp)
        user_topup_count: starknet::storage::Map<ContractAddress, u32>, // user -> number of topups
        user_total_topups: starknet::storage::Map<ContractAddress, u256>, // user -> total amount topped up
    }

    //-----------------------------------
    // Events
    //
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        EVLTMinted: EVLTMinted,
        EVLTBatchMinted: EVLTBatchMinted,
    }

    #[derive(Drop, starknet::Event)]
    struct EVLTMinted {
        #[key]
        user: ContractAddress,
        amount: u256,
        source: felt252,
        timestamp: u64,
        admin: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct EVLTBatchMinted {
        users: Span<ContractAddress>,
        amounts: Span<u256>,
        source: felt252,
        timestamp: u64,
        admin: ContractAddress,
        total_amount: u256,
    }

    //-----------------------------------
    // Errors
    //
    mod Errors {
        pub const INVALID_CALLER: felt252 = 'TOPUP: Invalid caller';
        pub const ZERO_AMOUNT: felt252 = 'TOPUP: Zero amount';
        pub const ZERO_ADDRESS: felt252 = 'TOPUP: Zero address';
        pub const ARRAY_LENGTH_MISMATCH: felt252 = 'TOPUP: Array length mismatch';
        pub const EVLT_TOKEN_NOT_SET: felt252 = 'TOPUP: EVLT token not set';
        pub const EMPTY_ARRAYS: felt252 = 'TOPUP: Empty arrays';
    }

    //-----------------------------------
    // Constants
    //
    pub const MINTER_ROLE: felt252 = 'MINTER_ROLE';

    //-----------------------------------
    // Constructor
    //
    fn dojo_init(ref self: ContractState, admin_address: ContractAddress, evlt_token_address: ContractAddress) {
        // Initialize access control
        self.accesscontrol.initializer();
        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, admin_address);
        self.accesscontrol._grant_role(MINTER_ROLE, admin_address);
        
        // Set EVLT token address
        self.evlt_token_address.write(evlt_token_address);
    }

    #[generate_trait]
    impl WorldDefaultImpl of WorldDefaultTrait {
        #[inline(always)]
        fn world_default(self: @ContractState) -> WorldStorage {
            (self.world(@"evolute_duel"))
        }
    }

    //-----------------------------------
    // Internal Functions
    //
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _record_topup(ref self: ContractState, user: ContractAddress, amount: u256, timestamp: u64) {
            let current_count = self.user_topup_count.read(user);
            
            // Store the topup record
            self.user_topup_history.write((user, current_count), (amount, timestamp));
            
            // Update counters
            self.user_topup_count.write(user, current_count + 1);
            
            // Update total topups
            let current_total = self.user_total_topups.read(user);
            self.user_total_topups.write(user, current_total + amount);
        }

        fn _validate_mint_params(self: @ContractState, user: ContractAddress, amount: u256) {
            assert(!user.is_zero(), Errors::ZERO_ADDRESS);
            assert(amount > 0, Errors::ZERO_AMOUNT);
        }

        fn _get_evlt_token(self: @ContractState) -> IEvltTokenProtectedDispatcher {
            let token_address = self.evlt_token_address.read();
            assert(!token_address.is_zero(), Errors::EVLT_TOKEN_NOT_SET);
            IEvltTokenProtectedDispatcher { contract_address: token_address }
        }
    }

    //-----------------------------------
    // External Functions
    //
    #[abi(embed_v0)]
    impl TopUpImpl of super::ITopUp<ContractState> {
        fn mint_evlt(ref self: ContractState, user: ContractAddress, amount: u256, source: felt252) {
            // Only admin/minter can call this
            self.accesscontrol.assert_only_role(MINTER_ROLE);
            
            // Validate parameters
            self._validate_mint_params(user, amount);
            
            let caller = get_caller_address();
            let timestamp = get_block_timestamp();
            
            // Get EVLT token dispatcher and mint
            let evlt_token = self._get_evlt_token();
            evlt_token.mint(user, amount);
            
            // Record the topup
            self._record_topup(user, amount, timestamp);
            
            // Emit event
            self.emit(EVLTMinted {
                user,
                amount,
                source,
                timestamp,
                admin: caller,
            });
        }

        fn mint_evlt_batch(ref self: ContractState, users: Span<ContractAddress>, amounts: Span<u256>, source: felt252) {
            // Only admin/minter can call this
            self.accesscontrol.assert_only_role(MINTER_ROLE);
            
            // Validate arrays
            assert(users.len() > 0, Errors::EMPTY_ARRAYS);
            assert(users.len() == amounts.len(), Errors::ARRAY_LENGTH_MISMATCH);
            
            let caller = get_caller_address();
            let timestamp = get_block_timestamp();
            let evlt_token = self._get_evlt_token();
            
            let mut total_amount: u256 = 0;
            let mut i: u32 = 0;
            
            // Process each user
            loop {
                if i >= users.len() {
                    break;
                }
                
                let user = *users.at(i);
                let amount = *amounts.at(i);
                
                // Validate each mint
                self._validate_mint_params(user, amount);
                
                // Mint tokens
                evlt_token.mint(user, amount);
                
                // Record the topup
                self._record_topup(user, amount, timestamp);
                
                total_amount += amount;
                i += 1;
            };
            
            // Emit batch event
            self.emit(EVLTBatchMinted {
                users,
                amounts,
                source,
                timestamp,
                admin: caller,
                total_amount,
            });
        }

        fn get_topup_history(self: @ContractState, user: ContractAddress) -> (Span<u256>, Span<u64>) {
            let count = self.user_topup_count.read(user);
            
            if count == 0 {
                return (array![].span(), array![].span());
            }
            
            let mut amounts: Array<u256> = array![];
            let mut timestamps: Array<u64> = array![];
            let mut i: u32 = 0;
            
            loop {
                if i >= count {
                    break;
                }
                
                let (amount, timestamp) = self.user_topup_history.read((user, i));
                amounts.append(amount);
                timestamps.append(timestamp);
                i += 1;
            };
            
            (amounts.span(), timestamps.span())
        }

        fn get_total_topups(self: @ContractState, user: ContractAddress) -> u256 {
            self.user_total_topups.read(user)
        }
    }

    //-----------------------------------
    // Admin Functions
    //
    #[abi(embed_v0)]
    impl AdminImpl of super::ITopUpAdmin<ContractState> {
        fn set_evlt_token_address(ref self: ContractState, token_address: ContractAddress) {
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);
            assert(!token_address.is_zero(), Errors::ZERO_ADDRESS);
            self.evlt_token_address.write(token_address);
        }

        fn grant_minter_role(ref self: ContractState, account: ContractAddress) {
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.accesscontrol._grant_role(MINTER_ROLE, account);
        }

        fn revoke_minter_role(ref self: ContractState, account: ContractAddress) {
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);
            self.accesscontrol._revoke_role(MINTER_ROLE, account);
        }
    }
}