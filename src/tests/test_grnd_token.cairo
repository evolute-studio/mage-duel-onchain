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
        systems::tokens::grnd_token::{grnd_token, IGrndTokenDispatcher, IGrndTokenDispatcherTrait, IGrndTokenProtectedDispatcher, IGrndTokenProtectedDispatcherTrait},
    };

    const ADMIN_ADDRESS: felt252 = 0x111;
    const GAME_SYSTEM_ADDRESS: felt252 = 0x123;
    const USER_ADDRESS: felt252 = 0x456;
    const UNAUTHORIZED_ADDRESS: felt252 = 0x789;
    const MINT_AMOUNT: u256 = 1000000000000000000000; // 1000 tokens (18 decimals)
    const REWARD_AMOUNT: u128 = 500000000000000000000; // 500 tokens

    fn namespace_def() -> NamespaceDef {
        let ndef = NamespaceDef {
            namespace: "evolute_duel", 
            resources: [
                TestResource::Model(m_CoinConfig::TEST_CLASS_HASH),
                TestResource::Contract(grnd_token::TEST_CLASS_HASH),
            ].span()
        };
        ndef
    }

    fn contract_defs() -> Span<ContractDef> {
        [
            ContractDefTrait::new(@"evolute_duel", @"grnd_token")
                .with_writer_of([dojo::utils::bytearray_hash(@"evolute_duel")].span())
                .with_init_calldata(
                    [ADMIN_ADDRESS].span()
                ),
        ]
            .span()
    }

    fn deploy_grnd_token() -> (IGrndTokenDispatcher, IGrndTokenProtectedDispatcher) {
        // Set admin as the caller during deployment so they become the admin
        let admin_address = contract_address_const::<ADMIN_ADDRESS>();
        testing::set_contract_address(admin_address);
        
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());
        
        let (grnd_token_address, _) = world.dns(@"grnd_token").unwrap();
        
        let grnd_token_dispatcher = IGrndTokenDispatcher { contract_address: grnd_token_address };
        let grnd_token_protected = IGrndTokenProtectedDispatcher { contract_address: grnd_token_address };
        
        (grnd_token_dispatcher, grnd_token_protected)
    }

    #[test]
    fn test_token_metadata() {
        let (grnd_token, _grnd_token_protected) = deploy_grnd_token();
        
        assert(grnd_token.name() == "Grind Token", 'Wrong token name');
        assert(grnd_token.symbol() == "GRND", 'Wrong token symbol');
        assert(grnd_token.decimals() == 18, 'Wrong decimals');
        assert(grnd_token.total_supply() == 0, 'Initial supply should be 0');
    }

    #[test]
    fn test_mint_by_game_system() {
        let (grnd_token, grnd_token_protected) = deploy_grnd_token();
        let admin_address = contract_address_const::<ADMIN_ADDRESS>();
        let game_system_address = contract_address_const::<GAME_SYSTEM_ADDRESS>();
        let user_address = contract_address_const::<USER_ADDRESS>();
        
        // Set caller as admin and grant minter role to game system
        testing::set_contract_address(admin_address);
        grnd_token_protected.set_minter(game_system_address);
        
        // Set caller as game system
        testing::set_contract_address(game_system_address);
        
        // Mint tokens to user
        grnd_token_protected.mint(user_address, MINT_AMOUNT);
        
        assert(grnd_token.balance_of(user_address) == MINT_AMOUNT, 'Wrong balance after mint');
        assert(grnd_token.total_supply() == MINT_AMOUNT, 'Wrong total supply');
    }

    #[test]
    #[should_panic]
    fn test_mint_by_unauthorized_user() {
        let (_grnd_token, grnd_token_protected) = deploy_grnd_token();
        let unauthorized_address = contract_address_const::<UNAUTHORIZED_ADDRESS>();
        let user_address = contract_address_const::<USER_ADDRESS>();
        
        // Set caller as unauthorized user
        testing::set_contract_address(unauthorized_address);
        
        // This should panic
        grnd_token_protected.mint(user_address, MINT_AMOUNT);
    }

    #[test]
    fn test_reward_player() {
        let (grnd_token, grnd_token_protected) = deploy_grnd_token();
        let admin_address = contract_address_const::<ADMIN_ADDRESS>();
        let game_system_address = contract_address_const::<GAME_SYSTEM_ADDRESS>();
        let user_address = contract_address_const::<USER_ADDRESS>();
        
        // Set caller as admin and grant minter role to game system
        testing::set_contract_address(admin_address);
        grnd_token_protected.set_minter(game_system_address);
        
        // Set caller as game system
        testing::set_contract_address(game_system_address);
        
        // Reward player
        grnd_token_protected.reward_player(user_address, REWARD_AMOUNT);
        
        assert(grnd_token.balance_of(user_address) == REWARD_AMOUNT.into(), 'Wrong balance after reward');
        assert(grnd_token.total_supply() == REWARD_AMOUNT.into(), 'Wrong total supply after reward');
    }

    #[test]
    #[should_panic]
    fn test_reward_player_zero_address() {
        let (_grnd_token, grnd_token_protected) = deploy_grnd_token();
        let admin_address = contract_address_const::<ADMIN_ADDRESS>();
        let game_system_address = contract_address_const::<GAME_SYSTEM_ADDRESS>();
        
        // Set caller as admin and grant minter role to game system
        testing::set_contract_address(admin_address);
        grnd_token_protected.set_minter(game_system_address);
        
        testing::set_contract_address(game_system_address);
        
        // This should panic
        grnd_token_protected.reward_player(Zero::zero(), REWARD_AMOUNT);
    }

    #[test]
    #[should_panic]
    fn test_reward_player_zero_amount() {
        let (_grnd_token, grnd_token_protected) = deploy_grnd_token();
        let admin_address = contract_address_const::<ADMIN_ADDRESS>();
        let game_system_address = contract_address_const::<GAME_SYSTEM_ADDRESS>();
        let user_address = contract_address_const::<USER_ADDRESS>();
        
        // Set caller as admin and grant minter role to game system
        testing::set_contract_address(admin_address);
        grnd_token_protected.set_minter(game_system_address);
        
        testing::set_contract_address(game_system_address);
        
        // This should panic
        grnd_token_protected.reward_player(user_address, 0);
    }

    #[test]
    fn test_burn_by_burner() {
        let (grnd_token, grnd_token_protected) = deploy_grnd_token();
        let admin_address = contract_address_const::<ADMIN_ADDRESS>();
        let game_system_address = contract_address_const::<GAME_SYSTEM_ADDRESS>();
        let user_address = contract_address_const::<USER_ADDRESS>();
        
        // Set caller as admin and grant minter role to game system
        testing::set_contract_address(admin_address);
        grnd_token_protected.set_minter(game_system_address);
        grnd_token_protected.set_burner(game_system_address);
        
        // Set caller as game system and mint tokens first
        testing::set_contract_address(game_system_address);
        grnd_token_protected.mint(user_address, MINT_AMOUNT);
        
        let burn_amount = MINT_AMOUNT / 2;
        grnd_token_protected.burn(user_address, burn_amount);
        
        assert(grnd_token.balance_of(user_address) == MINT_AMOUNT - burn_amount, 'Wrong balance after burn');
        assert(grnd_token.total_supply() == MINT_AMOUNT - burn_amount, 'Wrong total supply after burn');
    }

    #[test]
    fn test_burn_own_tokens() {
        let (grnd_token, grnd_token_protected) = deploy_grnd_token();
        let admin_address = contract_address_const::<ADMIN_ADDRESS>();
        let game_system_address = contract_address_const::<GAME_SYSTEM_ADDRESS>();
        let user_address = contract_address_const::<USER_ADDRESS>();
        
        // Set caller as admin and grant minter role to game system
        testing::set_contract_address(admin_address);
        grnd_token_protected.set_minter(game_system_address);
        
        // Mint tokens first
        testing::set_contract_address(game_system_address);
        grnd_token_protected.mint(user_address, MINT_AMOUNT);
        
        // Switch to user and burn their own tokens
        testing::set_contract_address(user_address);
        let burn_amount = MINT_AMOUNT / 2;
        grnd_token_protected.burn(user_address, burn_amount);
        
        assert(grnd_token.balance_of(user_address) == MINT_AMOUNT - burn_amount, 'Wrong balance after self burn');
    }
    
    #[test]
    #[should_panic]
    fn test_transfer_disabled() {
        let (grnd_token, grnd_token_protected) = deploy_grnd_token();
        let admin_address = contract_address_const::<ADMIN_ADDRESS>();
        let game_system_address = contract_address_const::<GAME_SYSTEM_ADDRESS>();
        let user1_address = contract_address_const::<USER_ADDRESS>();
        let user2_address = contract_address_const::<UNAUTHORIZED_ADDRESS>();
        
        // Set caller as admin and grant minter role to game system
        testing::set_contract_address(admin_address);
        grnd_token_protected.set_minter(game_system_address);
        
        // Mint tokens to user1
        testing::set_contract_address(game_system_address);
        grnd_token_protected.mint(user1_address, MINT_AMOUNT);
        
        // Verify tokens were minted
        assert(grnd_token.balance_of(user1_address) == MINT_AMOUNT, 'Wrong balance after minting');
        
        // Attempt transfer from user1 to user2 - this should panic
        testing::set_contract_address(user1_address);
        let transfer_amount = MINT_AMOUNT / 2;
        grnd_token.transfer(user2_address, transfer_amount);
    }

    #[test]
    fn test_approve_works_but_transfer_from_disabled() {
        let (grnd_token, grnd_token_protected) = deploy_grnd_token();
        let admin_address = contract_address_const::<ADMIN_ADDRESS>();
        let game_system_address = contract_address_const::<GAME_SYSTEM_ADDRESS>();
        let owner_address = contract_address_const::<USER_ADDRESS>();
        let spender_address = contract_address_const::<UNAUTHORIZED_ADDRESS>();
        
        // Set caller as admin and grant minter role to game system
        testing::set_contract_address(admin_address);
        grnd_token_protected.set_minter(game_system_address);
        
        // Mint tokens to owner
        testing::set_contract_address(game_system_address);
        grnd_token_protected.mint(owner_address, MINT_AMOUNT);
        
        // Owner approves spender - this should still work
        testing::set_contract_address(owner_address);
        let approve_amount = MINT_AMOUNT / 2;
        let success = grnd_token.approve(spender_address, approve_amount);
        
        assert(success == true, 'Approve should succeed');
        assert(grnd_token.allowance(owner_address, spender_address) == approve_amount, 'Wrong allowance');
    }

    #[test]
    #[should_panic]
    fn test_transfer_from_disabled() {
        let (grnd_token, grnd_token_protected) = deploy_grnd_token();
        let admin_address = contract_address_const::<ADMIN_ADDRESS>();
        let game_system_address = contract_address_const::<GAME_SYSTEM_ADDRESS>();
        let owner_address = contract_address_const::<USER_ADDRESS>();
        let spender_address = contract_address_const::<UNAUTHORIZED_ADDRESS>();
        
        // Set caller as admin and grant minter role to game system
        testing::set_contract_address(admin_address);
        grnd_token_protected.set_minter(game_system_address);
        
        // Mint tokens to owner
        testing::set_contract_address(game_system_address);
        grnd_token_protected.mint(owner_address, MINT_AMOUNT);
        
        // Owner approves spender
        testing::set_contract_address(owner_address);
        let approve_amount = MINT_AMOUNT / 2;
        grnd_token.approve(spender_address, approve_amount);
        
        // Spender attempts transfer_from - this should panic
        testing::set_contract_address(spender_address);
        let transfer_amount = approve_amount / 2;
        grnd_token.transfer_from(owner_address, spender_address, transfer_amount);
    }

    #[test]
    fn test_multiple_rewards_accumulate() {
        let (grnd_token, grnd_token_protected) = deploy_grnd_token();
        let admin_address = contract_address_const::<ADMIN_ADDRESS>();
        let game_system_address = contract_address_const::<GAME_SYSTEM_ADDRESS>();
        let user_address = contract_address_const::<USER_ADDRESS>();
        
        // Set caller as admin and grant minter role to game system
        testing::set_contract_address(admin_address);
        grnd_token_protected.set_minter(game_system_address);
        
        testing::set_contract_address(game_system_address);
        
        // Give multiple rewards
        grnd_token_protected.reward_player(user_address, REWARD_AMOUNT);
        grnd_token_protected.reward_player(user_address, REWARD_AMOUNT);
        grnd_token_protected.reward_player(user_address, REWARD_AMOUNT);
        
        let expected_total = (REWARD_AMOUNT * 3).into();
        assert(grnd_token.balance_of(user_address) == expected_total, 'Rewards should accumulate');
        assert(grnd_token.total_supply() == expected_total, 'Wrong total supply');
    }

    #[test]
    fn test_camel_case_functions() {
        let (grnd_token, _grnd_token_protected) = deploy_grnd_token();
        
        assert(grnd_token.totalSupply() == grnd_token.total_supply(), 'totalSupply mismatch');
        
        let user_address = contract_address_const::<USER_ADDRESS>();
        assert(grnd_token.balanceOf(user_address) == grnd_token.balance_of(user_address), 'balanceOf mismatch');
    }

    #[test]
    #[should_panic]
    fn test_camel_case_transfer_from_disabled() {
        let (grnd_token, grnd_token_protected) = deploy_grnd_token();
        let admin_address = contract_address_const::<ADMIN_ADDRESS>();
        let game_system_address = contract_address_const::<GAME_SYSTEM_ADDRESS>();
        let owner_address = contract_address_const::<USER_ADDRESS>();
        let spender_address = contract_address_const::<UNAUTHORIZED_ADDRESS>();
        
        // Set caller as admin and grant minter role to game system
        testing::set_contract_address(admin_address);
        grnd_token_protected.set_minter(game_system_address);
        
        // Mint tokens to owner
        testing::set_contract_address(game_system_address);
        grnd_token_protected.mint(owner_address, MINT_AMOUNT);
        
        // Owner approves spender
        testing::set_contract_address(owner_address);
        grnd_token.approve(spender_address, MINT_AMOUNT);
        
        // Attempt transferFrom (camel case) - this should panic
        testing::set_contract_address(spender_address);
        grnd_token.transferFrom(owner_address, spender_address, MINT_AMOUNT / 2);
    }
}