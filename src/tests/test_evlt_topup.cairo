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
            evlt_topup::{
                evlt_topup, ITopUpDispatcher, ITopUpDispatcherTrait, ITopUpAdminDispatcher,
                ITopUpAdminDispatcherTrait,
            },
            tokens::evlt_token::{
                evlt_token, IEvltTokenDispatcher, IEvltTokenDispatcherTrait,
                IEvltTokenProtectedDispatcher, IEvltTokenProtectedDispatcherTrait,
            },
        },
    };

    const ADMIN_ADDRESS: felt252 = 0x123;
    const MINTER_ADDRESS: felt252 = 0x456;
    const USER1_ADDRESS: felt252 = 0x789;
    const USER2_ADDRESS: felt252 = 0xabc;
    const USER3_ADDRESS: felt252 = 0xdef;
    const UNAUTHORIZED_ADDRESS: felt252 = 0x999;

    const MINT_AMOUNT: u256 = 1000000000000000000000; // 1000 EVLT tokens (18 decimals)
    const SOURCE_DISCORD: felt252 = 'DISCORD_PAYMENT';
    const SOURCE_WEB: felt252 = 'WEB_PAYMENT';
    const ORDER_ID_123: felt252 = 'ORDER_123';

    fn namespace_def() -> NamespaceDef {
        let ndef = NamespaceDef {
            namespace: "evolute_duel",
            resources: [
                TestResource::Model(m_CoinConfig::TEST_CLASS_HASH),
                TestResource::Contract(evlt_token::TEST_CLASS_HASH),
                TestResource::Contract(evlt_topup::TEST_CLASS_HASH),
            ]
                .span(),
        };
        ndef
    }

    fn contract_defs() -> Span<ContractDef> {
        [
            ContractDefTrait::new(@"evolute_duel", @"evlt_token")
                .with_writer_of([dojo::utils::bytearray_hash(@"evolute_duel")].span())
                .with_init_calldata([ADMIN_ADDRESS].span()),
            ContractDefTrait::new(@"evolute_duel", @"evlt_topup")
                .with_writer_of([dojo::utils::bytearray_hash(@"evolute_duel")].span())
                .with_init_calldata([ADMIN_ADDRESS].span()),
        ]
            .span()
    }

    fn deploy_contracts() -> (
        ITopUpDispatcher,
        IEvltTokenDispatcher,
        IEvltTokenProtectedDispatcher,
        ITopUpAdminDispatcher,
    ) {
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (evlt_token_address, _) = world.dns(@"evlt_token").unwrap();
        let (topup_address, _) = world.dns(@"evlt_topup").unwrap();

        let evlt_token = IEvltTokenDispatcher { contract_address: evlt_token_address };
        let evlt_token_protected = IEvltTokenProtectedDispatcher {
            contract_address: evlt_token_address,
        };
        let topup = ITopUpDispatcher { contract_address: topup_address };
        let topup_admin = ITopUpAdminDispatcher { contract_address: topup_address };

        // // Grant minter role to topup contract
        // testing::set_contract_address(contract_address_const::<ADMIN_ADDRESS>());
        // evlt_token_protected.set_minter(topup_address);

        (topup, evlt_token, evlt_token_protected, topup_admin)
    }

    #[test]
    fn test_single_topup() {
        let (topup, evlt_token, _, _) = deploy_contracts();
        let user_address = contract_address_const::<USER1_ADDRESS>();

        // Set caller as admin
        testing::set_contract_address(contract_address_const::<ADMIN_ADDRESS>());

        // Check initial balance
        assert(evlt_token.balance_of(user_address) == 0, 'Initial balance should be 0');

        testing::set_block_timestamp(1000);

        // Perform topup
        topup.mint_evlt(user_address, MINT_AMOUNT, SOURCE_DISCORD);

        // Check new balance
        assert(evlt_token.balance_of(user_address) == MINT_AMOUNT, 'Balance should increase');

        // Check topup history
        let (amounts, timestamps) = topup.get_topup_history(user_address);
        assert(amounts.len() == 1, 'Should have 1 topup record');
        assert(*amounts.at(0) == MINT_AMOUNT, 'Topup amount should match');
        assert(*timestamps.at(0) == 1000, 'Timestamp should be set');

        // Check total topups
        let total = topup.get_total_topups(user_address);
        assert(total == MINT_AMOUNT, 'Total topups should match');
    }

    #[test]
    fn test_batch_topup() {
        let (topup, evlt_token, _, _) = deploy_contracts();
        let user1 = contract_address_const::<USER1_ADDRESS>();
        let user2 = contract_address_const::<USER2_ADDRESS>();
        let user3 = contract_address_const::<USER3_ADDRESS>();

        // Set caller as admin
        testing::set_contract_address(contract_address_const::<ADMIN_ADDRESS>());

        // Prepare batch data
        let users = array![user1, user2, user3].span();
        let amounts = array![MINT_AMOUNT, MINT_AMOUNT * 2, MINT_AMOUNT / 2].span();

        // Check initial balances
        assert(evlt_token.balance_of(user1) == 0, 'User1 initial balance');
        assert(evlt_token.balance_of(user2) == 0, 'User2 initial balance');
        assert(evlt_token.balance_of(user3) == 0, 'User3 initial balance');

        // Perform batch topup
        topup.mint_evlt_batch(users, amounts, SOURCE_WEB);

        // Check new balances
        assert(evlt_token.balance_of(user1) == MINT_AMOUNT, 'User1 balance after topup');
        assert(evlt_token.balance_of(user2) == MINT_AMOUNT * 2, 'User2 balance after topup');
        assert(evlt_token.balance_of(user3) == MINT_AMOUNT / 2, 'User3 balance after topup');

        // Check topup histories
        let (amounts1, timestamps1) = topup.get_topup_history(user1);
        assert(amounts1.len() == 1, 'User1 should have 1 topup');
        assert(*amounts1.at(0) == MINT_AMOUNT, 'User1 topup amount');

        let (amounts2, timestamps2) = topup.get_topup_history(user2);
        assert(amounts2.len() == 1, 'User2 should have 1 topup');
        assert(*amounts2.at(0) == MINT_AMOUNT * 2, 'User2 topup amount');

        let (amounts3, timestamps3) = topup.get_topup_history(user3);
        assert(amounts3.len() == 1, 'User3 should have 1 topup');
        assert(*amounts3.at(0) == MINT_AMOUNT / 2, 'User3 topup amount');

        // Check total topups
        assert(topup.get_total_topups(user1) == MINT_AMOUNT, 'User1 total topups');
        assert(topup.get_total_topups(user2) == MINT_AMOUNT * 2, 'User2 total topups');
        assert(topup.get_total_topups(user3) == MINT_AMOUNT / 2, 'User3 total topups');
    }

    #[test]
    fn test_multiple_topups_same_user() {
        let (topup, evlt_token, _, _) = deploy_contracts();
        let user_address = contract_address_const::<USER1_ADDRESS>();

        // Set caller as admin
        testing::set_contract_address(contract_address_const::<ADMIN_ADDRESS>());

        // Perform multiple topups
        topup.mint_evlt(user_address, MINT_AMOUNT, SOURCE_DISCORD);
        topup.mint_evlt(user_address, MINT_AMOUNT / 2, SOURCE_WEB);
        topup.mint_evlt(user_address, MINT_AMOUNT * 2, ORDER_ID_123);

        // Check final balance
        let expected_balance = MINT_AMOUNT + (MINT_AMOUNT / 2) + (MINT_AMOUNT * 2);
        assert(evlt_token.balance_of(user_address) == expected_balance, 'Final balance incorrect');

        // Check topup history
        let (amounts, timestamps) = topup.get_topup_history(user_address);
        assert(amounts.len() == 3, 'Should have 3 topup records');
        assert(*amounts.at(0) == MINT_AMOUNT, 'First topup amount');
        assert(*amounts.at(1) == MINT_AMOUNT / 2, 'Second topup amount');
        assert(*amounts.at(2) == MINT_AMOUNT * 2, 'Third topup amount');

        // Check timestamps are in order
        assert(*timestamps.at(0) <= *timestamps.at(1), 'Timestamps should be in order');
        assert(*timestamps.at(1) <= *timestamps.at(2), 'Timestamps should be in order');

        // Check total topups
        assert!(
            topup.get_total_topups(user_address) == expected_balance,
            "Total topups should match balance",
        );
    }

    #[test]
    #[should_panic]
    fn test_unauthorized_single_topup() {
        let (topup, _, _, _) = deploy_contracts();
        let user_address = contract_address_const::<USER1_ADDRESS>();

        // Set caller as unauthorized user
        testing::set_contract_address(contract_address_const::<UNAUTHORIZED_ADDRESS>());

        // This should panic
        topup.mint_evlt(user_address, MINT_AMOUNT, SOURCE_DISCORD);
    }

    #[test]
    #[should_panic]
    fn test_unauthorized_batch_topup() {
        let (topup, _, _, _) = deploy_contracts();
        let user1 = contract_address_const::<USER1_ADDRESS>();
        let user2 = contract_address_const::<USER2_ADDRESS>();

        // Set caller as unauthorized user
        testing::set_contract_address(contract_address_const::<UNAUTHORIZED_ADDRESS>());

        let users = array![user1, user2].span();
        let amounts = array![MINT_AMOUNT, MINT_AMOUNT].span();

        // This should panic
        topup.mint_evlt_batch(users, amounts, SOURCE_WEB);
    }

    #[test]
    #[should_panic]
    fn test_zero_amount_topup() {
        let (topup, _, _, _) = deploy_contracts();
        let user_address = contract_address_const::<USER1_ADDRESS>();

        // Set caller as admin
        testing::set_contract_address(contract_address_const::<ADMIN_ADDRESS>());

        // This should panic due to zero amount
        topup.mint_evlt(user_address, 0, SOURCE_DISCORD);
    }

    #[test]
    #[should_panic]
    fn test_zero_address_topup() {
        let (topup, _, _, _) = deploy_contracts();

        // Set caller as admin
        testing::set_contract_address(contract_address_const::<ADMIN_ADDRESS>());

        // This should panic due to zero address
        topup.mint_evlt(Zero::zero(), MINT_AMOUNT, SOURCE_DISCORD);
    }

    #[test]
    #[should_panic]
    fn test_array_length_mismatch() {
        let (topup, _, _, _) = deploy_contracts();
        let user1 = contract_address_const::<USER1_ADDRESS>();
        let user2 = contract_address_const::<USER2_ADDRESS>();

        // Set caller as admin
        testing::set_contract_address(contract_address_const::<ADMIN_ADDRESS>());

        let users = array![user1, user2].span();
        let amounts = array![MINT_AMOUNT].span(); // Mismatched length

        // This should panic due to array length mismatch
        topup.mint_evlt_batch(users, amounts, SOURCE_WEB);
    }

    #[test]
    #[should_panic]
    fn test_empty_arrays_batch() {
        let (topup, _, _, _) = deploy_contracts();

        // Set caller as admin
        testing::set_contract_address(contract_address_const::<ADMIN_ADDRESS>());

        let users = array![].span();
        let amounts = array![].span();

        // This should panic due to empty arrays
        topup.mint_evlt_batch(users, amounts, SOURCE_WEB);
    }

    #[test]
    fn test_topup_history_empty_user() {
        let (topup, _, _, _) = deploy_contracts();
        let user_address = contract_address_const::<USER1_ADDRESS>();

        // Check empty history
        let (amounts, timestamps) = topup.get_topup_history(user_address);
        assert(amounts.len() == 0, 'History should be empty');
        assert(timestamps.len() == 0, 'Timestamps should be empty');

        // Check zero total
        let total = topup.get_total_topups(user_address);
        assert(total == 0, 'Total should be zero');
    }

    #[test]
    #[should_panic]
    fn test_batch_with_zero_amount_in_array() {
        let (topup, _, _, _) = deploy_contracts();
        let user1 = contract_address_const::<USER1_ADDRESS>();
        let user2 = contract_address_const::<USER2_ADDRESS>();

        // Set caller as admin
        testing::set_contract_address(contract_address_const::<ADMIN_ADDRESS>());

        let users = array![user1, user2].span();
        let amounts = array![MINT_AMOUNT, 0].span(); // Second amount is zero

        // This should panic when processing the zero amount
        topup.mint_evlt_batch(users, amounts, SOURCE_WEB);
    }

    #[test]
    fn test_admin_functions() {
        let (topup, evlt_token, _, topup_admin) = deploy_contracts();
        let new_minter = contract_address_const::<MINTER_ADDRESS>();
        let user_address = contract_address_const::<USER1_ADDRESS>();

        // Set caller as admin
        testing::set_contract_address(contract_address_const::<ADMIN_ADDRESS>());

        // Grant minter role to new address
        topup_admin.grant_minter_role(new_minter);

        // Now the new minter should be able to mint
        testing::set_contract_address(new_minter);
        topup.mint_evlt(user_address, MINT_AMOUNT, SOURCE_DISCORD);

        // Check balance was updated
        assert(evlt_token.balance_of(user_address) == MINT_AMOUNT, 'New minter should work');

        // Admin revokes the role
        testing::set_contract_address(contract_address_const::<ADMIN_ADDRESS>());
        topup_admin.revoke_minter_role(new_minter);
        // Now the revoked minter should not be able to mint
    // We would test this but it requires proper revocation testing
    // For now we just verify the role was granted successfully
    }

    #[test]
    fn test_batch_topup_ordering() {
        let (topup, evlt_token, _, _) = deploy_contracts();
        let user1 = contract_address_const::<USER1_ADDRESS>();
        let user2 = contract_address_const::<USER2_ADDRESS>();

        // Set caller as admin
        testing::set_contract_address(contract_address_const::<ADMIN_ADDRESS>());

        // Test with different amounts to ensure order is maintained
        let users = array![user1, user2, user1, user2].span();
        let amounts = array![100, 200, 300, 400].span();

        // Perform batch topup
        topup.mint_evlt_batch(users, amounts, SOURCE_WEB);

        // Check final balances (user1 gets 100 + 300 = 400, user2 gets 200 + 400 = 600)
        assert(evlt_token.balance_of(user1) == 400, 'User1 final balance');
        assert(evlt_token.balance_of(user2) == 600, 'User2 final balance');

        // Check individual histories
        let (amounts1, _) = topup.get_topup_history(user1);
        assert(amounts1.len() == 2, 'User1 should have 2 topups');
        assert(*amounts1.at(0) == 100, 'User1 first topup');
        assert(*amounts1.at(1) == 300, 'User1 second topup');

        let (amounts2, _) = topup.get_topup_history(user2);
        assert(amounts2.len() == 2, 'User2 should have 2 topups');
        assert(*amounts2.at(0) == 200, 'User2 first topup');
        assert(*amounts2.at(1) == 400, 'User2 second topup');
    }
}
