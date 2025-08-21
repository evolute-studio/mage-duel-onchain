#[cfg(test)]
#[allow(unused_imports)]
mod tests {
    use dojo_cairo_test::WorldStorageTestTrait;
    use dojo::model::{ModelStorage, ModelStorageTest};
    use dojo::world::WorldStorageTrait;
    use dojo_cairo_test::{
        spawn_test_world, NamespaceDef, TestResource, ContractDefTrait, ContractDef,
    };
    use dojo::world::WorldStorage;
    use starknet::{testing, ContractAddress, contract_address_const};
    use core::num::traits::Zero;

    use evolute_duel::{
        models::config::{CoinConfig, m_CoinConfig},
        systems::{
            tokens::evlt_token::{evlt_token, IEvltTokenDispatcher, IEvltTokenDispatcherTrait, IEvltTokenProtectedDispatcher, IEvltTokenProtectedDispatcherTrait},
            evlt_topup::{evlt_topup, ITopUpDispatcher, ITopUpDispatcherTrait, ITopUpAdminDispatcher, ITopUpAdminDispatcherTrait},
        },

    };

    const ADMIN_ADDRESS: felt252 = 0x123;
    const MINTER_ADDRESS: felt252 = 0x124;
    const USER_ADDRESS: felt252 = 0x456;
    const UNAUTHORIZED_ADDRESS: felt252 = 0x789;
    const MINT_AMOUNT: u256 = 1000000000000000000000; // 1000 tokens (18 decimals)

    fn namespace_def() -> NamespaceDef {
        let ndef = NamespaceDef {
            namespace: "evolute_duel", 
            resources: [
                TestResource::Model(m_CoinConfig::TEST_CLASS_HASH),
                TestResource::Contract(evlt_token::TEST_CLASS_HASH),
                TestResource::Contract(evlt_topup::TEST_CLASS_HASH),
            ].span()
        };
        ndef
    }

    fn contract_defs() -> Span<ContractDef> {
        [
            ContractDefTrait::new(@"evolute_duel", @"evlt_topup")
                .with_writer_of([dojo::utils::bytearray_hash(@"evolute_duel")].span())
                .with_init_calldata(
                    [ADMIN_ADDRESS].span()
                ),
            ContractDefTrait::new(@"evolute_duel", @"evlt_token")
                .with_writer_of([dojo::utils::bytearray_hash(@"evolute_duel")].span())
                .with_init_calldata(
                    [ADMIN_ADDRESS].span()
                ),
        ]
            .span()
    }

    fn deploy_evlt_token() -> (IEvltTokenDispatcher, IEvltTokenProtectedDispatcher) {
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());
        
        let (evlt_token_address, _) = world.dns(@"evlt_token").unwrap();
        
        let evlt_token_dispatcher = IEvltTokenDispatcher { contract_address: evlt_token_address };
        let evlt_token_protected = IEvltTokenProtectedDispatcher { contract_address: evlt_token_address };
        
        (evlt_token_dispatcher, evlt_token_protected)
    }

    #[test]
    fn test_token_metadata() {
        let (evlt_token, _evlt_token_protected) = deploy_evlt_token();
        
        assert(evlt_token.name() == "Evolute Premium Token", 'Wrong token name');
        assert(evlt_token.symbol() == "EVLT", 'Wrong token symbol');
        assert(evlt_token.decimals() == 18, 'Wrong decimals');
        assert(evlt_token.total_supply() == 0, 'Initial supply should be 0');
    }

    #[test]
    fn test_mint_by_minter() {
        let (evlt_token, evlt_token_protected) = deploy_evlt_token();
        let admin_address = contract_address_const::<ADMIN_ADDRESS>();
        let minter_address = contract_address_const::<MINTER_ADDRESS>();
        let user_address = contract_address_const::<USER_ADDRESS>();
        
        // Set caller as admin and grant minter role
        testing::set_contract_address(admin_address);
        evlt_token_protected.set_minter(minter_address);
        
        // Set caller as minter
        testing::set_contract_address(minter_address);
        
        // Mint tokens to user
        evlt_token_protected.mint(user_address, MINT_AMOUNT);
        
        assert(evlt_token.balance_of(user_address) == MINT_AMOUNT, 'Wrong balance after mint');
        assert(evlt_token.total_supply() == MINT_AMOUNT, 'Wrong total supply');
    }

    #[test]
    #[should_panic]
    fn test_mint_by_unauthorized_user() {
        let (_evlt_token, evlt_token_protected) = deploy_evlt_token();
        let unauthorized_address = contract_address_const::<UNAUTHORIZED_ADDRESS>();
        let user_address = contract_address_const::<USER_ADDRESS>();
        
        // Set caller as unauthorized user
        testing::set_contract_address(unauthorized_address);
        
        // This should panic
        evlt_token_protected.mint(user_address, MINT_AMOUNT);
    }

    #[test]
    #[should_panic]
    fn test_mint_to_zero_address() {
        let (_evlt_token, evlt_token_protected) = deploy_evlt_token();
        let admin_address = contract_address_const::<ADMIN_ADDRESS>();
        
        testing::set_contract_address(admin_address);
        
        // This should panic
        evlt_token_protected.mint(Zero::zero(), MINT_AMOUNT);
    }

    #[test]
    #[should_panic]
    fn test_mint_zero_amount() {
        let (_evlt_token, evlt_token_protected) = deploy_evlt_token();
        let admin_address = contract_address_const::<ADMIN_ADDRESS>();
        let user_address = contract_address_const::<USER_ADDRESS>();
        
        testing::set_contract_address(admin_address);
        
        // This should panic
        evlt_token_protected.mint(user_address, 0);
    }

    #[test]
    fn test_burn_by_admin() {
        let (evlt_token, evlt_token_protected) = deploy_evlt_token();
        let admin_address = contract_address_const::<ADMIN_ADDRESS>();
        let minter_address = contract_address_const::<MINTER_ADDRESS>();
        let user_address = contract_address_const::<USER_ADDRESS>();
        
        // Set caller as admin and grant minter role
        testing::set_contract_address(admin_address);
        evlt_token_protected.set_minter(minter_address);
        
        // Set caller as minter and mint tokens first
        testing::set_contract_address(minter_address);
        evlt_token_protected.mint(user_address, MINT_AMOUNT);
        
        // Set caller as admin and burn tokens
        testing::set_contract_address(admin_address);
        let burn_amount = MINT_AMOUNT / 2;
        evlt_token_protected.burn(user_address, burn_amount);
        
        assert(evlt_token.balance_of(user_address) == MINT_AMOUNT - burn_amount, 'Wrong balance after burn');
        assert(evlt_token.total_supply() == MINT_AMOUNT - burn_amount, 'Wrong total supply after burn');
    }

    #[test]
    fn test_burn_own_tokens() {
        let (evlt_token, evlt_token_protected) = deploy_evlt_token();
        let admin_address = contract_address_const::<ADMIN_ADDRESS>();
        let minter_address = contract_address_const::<MINTER_ADDRESS>();
        let user_address = contract_address_const::<USER_ADDRESS>();
        
        // Set caller as admin and grant minter role
        testing::set_contract_address(admin_address);
        evlt_token_protected.set_minter(minter_address);
        
        // Mint tokens first
        testing::set_contract_address(minter_address);
        evlt_token_protected.mint(user_address, MINT_AMOUNT);
        
        // Switch to user and burn their own tokens
        testing::set_contract_address(user_address);
        let burn_amount = MINT_AMOUNT / 2;
        evlt_token_protected.burn(user_address, burn_amount);
        
        assert(evlt_token.balance_of(user_address) == MINT_AMOUNT - burn_amount, 'Wrong balance after self burn');
    }

    #[test]
    #[should_panic]
    fn test_burn_others_tokens_unauthorized() {
        let (_evlt_token, evlt_token_protected) = deploy_evlt_token();
        let admin_address = contract_address_const::<ADMIN_ADDRESS>();
        let minter_address = contract_address_const::<MINTER_ADDRESS>();
        let user_address = contract_address_const::<USER_ADDRESS>();
        let unauthorized_address = contract_address_const::<UNAUTHORIZED_ADDRESS>();
        
        // Set caller as admin and grant minter role
        testing::set_contract_address(admin_address);
        evlt_token_protected.set_minter(minter_address);
        
        // Mint tokens first
        testing::set_contract_address(minter_address);
        evlt_token_protected.mint(user_address, MINT_AMOUNT);
        
        // Try to burn someone else's tokens (unauthorized - no admin role)
        testing::set_contract_address(unauthorized_address);
        evlt_token_protected.burn(user_address, MINT_AMOUNT / 2);
    }

    #[test]
    #[should_panic]
    fn test_burn_insufficient_balance() {
        let (_evlt_token, evlt_token_protected) = deploy_evlt_token();
        let admin_address = contract_address_const::<ADMIN_ADDRESS>();
        let user_address = contract_address_const::<USER_ADDRESS>();
        
        testing::set_contract_address(admin_address);
        
        // Try to burn tokens when user has no balance
        evlt_token_protected.burn(user_address, MINT_AMOUNT);
    }

    #[test]
    #[should_panic]
    fn test_transfer_disabled() {
        let (evlt_token, evlt_token_protected) = deploy_evlt_token();
        let admin_address = contract_address_const::<ADMIN_ADDRESS>();
        let minter_address = contract_address_const::<MINTER_ADDRESS>();
        let user1_address = contract_address_const::<USER_ADDRESS>();
        let user2_address = contract_address_const::<UNAUTHORIZED_ADDRESS>();
        
        // Set caller as admin and grant minter role
        testing::set_contract_address(admin_address);
        evlt_token_protected.set_minter(minter_address);
        
        // Mint tokens to user1
        testing::set_contract_address(minter_address);
        evlt_token_protected.mint(user1_address, MINT_AMOUNT);
        
        // Verify tokens were minted
        assert(evlt_token.balance_of(user1_address) == MINT_AMOUNT, 'Wrong balance after minting');

        // Attempt transfer from user1 to user2 - this should panic
        testing::set_contract_address(user1_address);
        let transfer_amount = MINT_AMOUNT / 2;
        evlt_token.transfer(user2_address, transfer_amount);
    }

    #[test]
    fn test_approve_works_but_transfer_from_disabled() {
        let (evlt_token, evlt_token_protected) = deploy_evlt_token();
        let admin_address = contract_address_const::<ADMIN_ADDRESS>();
        let minter_address = contract_address_const::<MINTER_ADDRESS>();
        let owner_address = contract_address_const::<USER_ADDRESS>();
        let spender_address = contract_address_const::<UNAUTHORIZED_ADDRESS>();
        
        // Set caller as admin and grant minter role
        testing::set_contract_address(admin_address);
        evlt_token_protected.set_minter(minter_address);
        
        // Mint tokens to owner
        testing::set_contract_address(minter_address);
        evlt_token_protected.mint(owner_address, MINT_AMOUNT);
        
        // Owner approves spender - this should still work
        testing::set_contract_address(owner_address);
        let approve_amount = MINT_AMOUNT / 2;
        let success = evlt_token.approve(spender_address, approve_amount);
        
        assert(success == true, 'Approve should succeed');
        assert(evlt_token.allowance(owner_address, spender_address) == approve_amount, 'Wrong allowance');
    }

    #[test]
    #[should_panic]
    fn test_transfer_from_disabled() {
        let (evlt_token, evlt_token_protected) = deploy_evlt_token();
        let admin_address = contract_address_const::<ADMIN_ADDRESS>();
        let minter_address = contract_address_const::<MINTER_ADDRESS>();
        let owner_address = contract_address_const::<USER_ADDRESS>();
        let spender_address = contract_address_const::<UNAUTHORIZED_ADDRESS>();
        
        // Set caller as admin and grant minter role
        testing::set_contract_address(admin_address);
        evlt_token_protected.set_minter(minter_address);
        
        // Mint tokens to owner
        testing::set_contract_address(minter_address);
        evlt_token_protected.mint(owner_address, MINT_AMOUNT);
        
        // Owner approves spender
        testing::set_contract_address(owner_address);
        let approve_amount = MINT_AMOUNT / 2;
        evlt_token.approve(spender_address, approve_amount);
        
        // Spender attempts transfer_from - this should panic
        testing::set_contract_address(spender_address);
        let transfer_amount = approve_amount / 2;
        evlt_token.transfer_from(owner_address, spender_address, transfer_amount);
    }

    #[test]
    fn test_camel_case_functions() {
        let (evlt_token, _evlt_token_protected) = deploy_evlt_token();
        
        assert(evlt_token.totalSupply() == evlt_token.total_supply(), 'totalSupply mismatch');
        
        let user_address = contract_address_const::<USER_ADDRESS>();
        assert(evlt_token.balanceOf(user_address) == evlt_token.balance_of(user_address), 'balanceOf mismatch');
    }

    #[test]
    #[should_panic]
    fn test_camel_case_transfer_from_disabled() {
        let (evlt_token, evlt_token_protected) = deploy_evlt_token();
        let admin_address = contract_address_const::<ADMIN_ADDRESS>();
        let minter_address = contract_address_const::<MINTER_ADDRESS>();
        let owner_address = contract_address_const::<USER_ADDRESS>();
        let spender_address = contract_address_const::<UNAUTHORIZED_ADDRESS>();
        
        // Set caller as admin and grant minter role
        testing::set_contract_address(admin_address);
        evlt_token_protected.set_minter(minter_address);
        
        // Mint tokens to owner
        testing::set_contract_address(minter_address);
        evlt_token_protected.mint(owner_address, MINT_AMOUNT);
        
        // Owner approves spender
        testing::set_contract_address(owner_address);
        evlt_token.approve(spender_address, MINT_AMOUNT);
        
        // Attempt transferFrom (camel case) - this should panic
        testing::set_contract_address(spender_address);
        evlt_token.transferFrom(owner_address, spender_address, MINT_AMOUNT / 2);
    }

    #[test]
    fn test_set_minter_by_admin() {
        let (_evlt_token, evlt_token_protected) = deploy_evlt_token();
        let admin_address = contract_address_const::<ADMIN_ADDRESS>();
        let new_minter_address = contract_address_const::<USER_ADDRESS>();
        
        // Set caller as admin
        testing::set_contract_address(admin_address);
        
        // Set new minter
        evlt_token_protected.set_minter(new_minter_address);
        
        // Test that new minter can mint
        testing::set_contract_address(new_minter_address);
        evlt_token_protected.mint(contract_address_const::<UNAUTHORIZED_ADDRESS>(), MINT_AMOUNT);
    }

    #[test]
    #[should_panic]
    fn test_set_minter_by_unauthorized() {
        let (_evlt_token, evlt_token_protected) = deploy_evlt_token();
        let unauthorized_address = contract_address_const::<UNAUTHORIZED_ADDRESS>();
        let new_minter_address = contract_address_const::<USER_ADDRESS>();
        
        // Set caller as unauthorized user (no admin role)
        testing::set_contract_address(unauthorized_address);
        
        // This should panic - missing DEFAULT_ADMIN_ROLE
        evlt_token_protected.set_minter(new_minter_address);
    }

    #[test]
    #[should_panic] 
    fn test_mint_by_admin_without_minter_role() {
        let (_evlt_token, evlt_token_protected) = deploy_evlt_token();
        let admin_address = contract_address_const::<ADMIN_ADDRESS>();
        let user_address = contract_address_const::<USER_ADDRESS>();
        
        // Set caller as admin (has admin role but not minter role by default)
        testing::set_contract_address(admin_address);
        
        // This should panic - admin doesn't have MINTER_ROLE automatically
        evlt_token_protected.mint(user_address, MINT_AMOUNT);
    }
}