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

    // Tournament models
    use evolute_duel::models::{
        tournament::{
            TournamentPass, m_TournamentPass, TournamentStateModel, m_TournamentStateModel,
            TournamentSettings, m_TournamentSettings, PlayerTournamentIndex,
            m_PlayerTournamentIndex, TournamentState, TournamentType,
        },
        tournament_balance::{TournamentBalance, m_TournamentBalance}, player::{Player, m_Player},
    };

    // Tournament systems
    use evolute_duel::systems::{
        tournament_budokan_test::{
            tournament_budokan_test, ITournament, ITournamentDispatcher, ITournamentDispatcherTrait,
        },
        tokens::tournament_token::{
            tournament_token, ITournamentTokenDispatcher, ITournamentTokenDispatcherTrait,
        },
        tokens::evlt_token::{
            evlt_token, IEvltTokenDispatcher, IEvltTokenDispatcherTrait,
            IEvltTokenProtectedDispatcher, IEvltTokenProtectedDispatcherTrait,
        },
    };

    // Budokan models
    use tournaments::components::models::{
        tournament::{
            Tournament, m_Tournament, Registration, m_Registration, TokenType, Metadata, GameConfig,
            EntryFee, EntryRequirement, m_Leaderboard, m_PlatformMetrics, m_TournamentTokenMetrics,
            m_PrizeMetrics, m_EntryCount, m_Prize, m_Token, m_TournamentConfig, m_PrizeClaim,
            m_QualificationEntries,
        },
        game::{
            TokenMetadata, m_TokenMetadata, GameMetadata, m_GameMetadata, GameCounter,
            m_GameCounter, m_Score, m_Settings, m_SettingsDetails, m_SettingsCounter,
        },
        schedule::{Schedule, Period},
    };

    // Test constants
    const ADMIN_ADDRESS: felt252 = 0x111;
    const PLAYER1_ADDRESS: felt252 = 0x123;
    const PLAYER2_ADDRESS: felt252 = 0x456;

    fn namespace_def() -> NamespaceDef {
        let ndef = NamespaceDef {
            namespace: "evolute_duel",
            resources: [
                // Tournament models
                TestResource::Model(m_TournamentPass::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_TournamentStateModel::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_TournamentSettings::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_PlayerTournamentIndex::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_TournamentBalance::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_Player::TEST_CLASS_HASH.try_into().unwrap()),
                //Budokan models
                TestResource::Model(m_Tournament::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_Registration::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_TokenMetadata::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_GameMetadata::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_GameCounter::TEST_CLASS_HASH.try_into().unwrap()),
                // Additional tournament models
                TestResource::Model(m_Score::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_Settings::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_SettingsDetails::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_SettingsCounter::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_Leaderboard::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_PlatformMetrics::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_TournamentTokenMetrics::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_PrizeMetrics::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_EntryCount::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_Prize::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_Token::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_TournamentConfig::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_PrizeClaim::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_QualificationEntries::TEST_CLASS_HASH.try_into().unwrap()),
                // Contracts
                TestResource::Contract(tournament_budokan_test::TEST_CLASS_HASH),
                TestResource::Contract(tournament_token::TEST_CLASS_HASH),
                TestResource::Contract(evlt_token::TEST_CLASS_HASH),
            ]
                .span(),
        };
        ndef
    }

    fn contract_defs() -> Span<ContractDef> {
        [
            ContractDefTrait::new(@"evolute_duel", @"tournament_budokan_test")
                .with_writer_of([dojo::utils::bytearray_hash(@"evolute_duel")].span()),
            // ContractDefTrait::new(@"evolute_duel", @"tournament_token")
        //     .with_writer_of([dojo::utils::bytearray_hash(@"evolute_duel")].span())
        //     .with_init_calldata([0].span()), // base_uri as felt252
        // ContractDefTrait::new(@"evolute_duel", @"evlt_token")
        //     .with_writer_of([dojo::utils::bytearray_hash(@"evolute_duel")].span())
        //     .with_init_calldata([ADMIN_ADDRESS].span()),
        ]
            .span()
    }

    fn deploy_tournament_system() -> (ITournamentDispatcher, WorldStorage) {
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());

        let (budokan_address, _) = world.dns(@"tournament_budokan_test").unwrap();
        // let (tournament_token_address, _) = world.dns(@"tournament_token").unwrap();
        // let (evlt_token_address, _) = world.dns(@"evlt_token").unwrap();

        let budokan_dispatcher = ITournamentDispatcher { contract_address: budokan_address };
        // let tournament_token_dispatcher = ITournamentTokenDispatcher { contract_address:
        // tournament_token_address };
        // let evlt_token_dispatcher = IEvltTokenDispatcher { contract_address: evlt_token_address
        // };
        // let evlt_token_protected = IEvltTokenProtectedDispatcher { contract_address:
        // evlt_token_address };

        (budokan_dispatcher, world)
    }

    #[test]
    fn test_deploy_tournament_system() {
        let (budokan_dispatcher, mut world) = deploy_tournament_system();
        println!("Deployed tournament system");
    }
    // #[test]
// fn test_create_tournament_with_evlt_entry_fee() {
//     let (budokan_dispatcher, tournament_token_dispatcher, evlt_token_dispatcher,
//     evlt_protected, mut world) = deploy_tournament_system();
//     let admin_address: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
//     let player1_address: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
//     let tournament_token_address = tournament_token_dispatcher.contract_address;
//     let evlt_token_address = evlt_token_dispatcher.contract_address;
//     let budokan_address = budokan_dispatcher.contract_address;

    //     // Setup admin as contract caller
//     testing::set_contract_address(admin_address);

    //     // Mint EVLT tokens to player1
//     evlt_protected.mint(player1_address, 1000); // Give player 1000 EVLT

    //     // Allow budokan tournament to transfer EVLT tokens
//     evlt_protected.set_transfer_allowed(budokan_address);

    //     // Create tournament metadata
//     let metadata = Metadata {
//         name: 'EVLT Tournament',
//         description: "Tournament with EVLT token entry fee",
//     };

    //     // Create tournament schedule
//     let current_time = starknet::get_block_timestamp();
//     let schedule = Schedule {
//         registration: Option::Some(Period {
//             start: current_time,
//             end: current_time + 3600, // 1 hour registration
//         }),
//         game: Period {
//             start: current_time,
//             end: current_time + 7200, // 2 hours game period
//         },
//         submission_duration: 300, // 5 minutes for score submission
//     };

    //     // Create game configuration
//     let game_config = GameConfig {
//         address: tournament_token_address,
//         settings_id: 1,
//         prize_spots: 3,
//     };

    //     // Entry fee configuration with EVLT tokens
//     let entry_fee = EntryFee {
//         token_address: evlt_token_address,
//         amount: 100, // 100 EVLT entry fee
//         distribution: [50, 30, 20].span(), // 1st: 50%, 2nd: 30%, 3rd: 20%
//         tournament_creator_share: Option::None,
//         game_creator_share: Option::None,
//     };

    //     // Create tournament with EVLT entry fee
//     let tournament = budokan_dispatcher.create_tournament(
//         admin_address,
//         metadata,
//         schedule,
//         game_config,
//         Option::Some(entry_fee),
//         Option::None  // No entry requirement
//     );

    //     // Verify tournament was created successfully
//     assert!(tournament.id > 0, "Tournament should have valid ID");
//     assert!(tournament.created_by == admin_address, "Creator should match admin address");

    //     // Check that tournament exists in the system
//     let fetched_tournament = budokan_dispatcher.tournament(tournament.id);
//     assert!(fetched_tournament.id == tournament.id, "Tournament ID should match");
//     assert!(fetched_tournament.metadata.name == 'EVLT Tournament', "Tournament name should
//     match");

    //     // Verify initial state
//     let total_entries = budokan_dispatcher.tournament_entries(tournament.id);
//     assert!(total_entries == 0, "Tournament should start with 0 entries");

    //     // Test player entry with EVLT payment
//     testing::set_contract_address(player1_address);

    //     // Check player's balance before entry
//     let balance_before = evlt_token_dispatcher.balance_of(player1_address);
//     assert!(balance_before == 1000, "Player should have 1000 EVLT before entry");

    //     // Player enters tournament (should pay entry fee)
//     let (token_id, entry_number) = budokan_dispatcher.enter_tournament(
//         tournament.id,
//         'player1',
//         player1_address,
//         Option::None
//     );

    //     // Verify entry was successful
//     assert!(token_id > 0, "Token ID should be valid");
//     assert!(entry_number == 1, "First entry should have number 1");

    //     // Check that entry fee was deducted
//     let balance_after = evlt_token_dispatcher.balance_of(player1_address);
//     assert!(balance_after == 900, "Player should have 900 EVLT after paying entry fee");

    //     // Check tournament entries increased
//     let total_entries_after = budokan_dispatcher.tournament_entries(tournament.id);
//     assert!(total_entries_after == 1, "Tournament should have 1 entry after registration");
// }
}
