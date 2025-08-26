// #[cfg(test)]
// mod tests {
//     use core::option::Option;
//     use starknet::{ContractAddress, get_block_timestamp, testing, contract_address_const};
//     use dojo::world::WorldStorage;
//     use dojo_cairo_test::{
//         spawn_test_world, NamespaceDef, TestResource, ContractDefTrait, ContractDef,
//         WorldStorageTestTrait,
//     };

//     // Budokan models
//     use tournaments::components::models::tournament::{
//         Tournament as BudokanTournament, m_Tournament as m_BudokanTournament, Registration,
//         m_Registration, Metadata, GameConfig, EntryFee, PrizeType,
//     };
//     use tournaments::components::models::game::{
//         m_TokenMetadata, m_GameMetadata, m_GameCounter, m_SettingsDetails, m_Score,
//     };
//     use tournaments::components::models::schedule::{Schedule, Period};

//     // Tournament budokan test contract
//     use evolute_duel::systems::tournament_budokan_test::{
//         tournament_budokan_test, ITournament, ITournamentDispatcher, ITournamentDispatcherTrait,
//     };

//     // Test mocks
//     use tournaments::components::tests::mocks::{erc20_mock::erc20_mock, erc721_mock::erc721_mock};
//     use tournaments::components::tests::interfaces::{
//         IERC20MockDispatcher, IERC20MockDispatcherTrait, IERC721MockDispatcher,
//         IERC721MockDispatcherTrait,
//     };

//     // Constants for testing
//     const ADMIN_ADDRESS: felt252 = 0x111;
//     const PLAYER1_ADDRESS: felt252 = 0x123;
//     const PLAYER2_ADDRESS: felt252 = 0x456;
//     const PLAYER3_ADDRESS: felt252 = 0x789;
//     const STARTING_BALANCE: u256 = 1000;
//     const TOURNAMENT_NAME: felt252 = 'Test Tournament';
//     fn TOURNAMENT_DESCRIPTION() -> ByteArray {
//         "Integration tournament test"
//     }

//     #[derive(Drop)]
//     struct TestContracts {
//         world: WorldStorage,
//         tournament: ITournamentDispatcher,
//         erc20: IERC20MockDispatcher,
//         erc721: IERC721MockDispatcher,
//     }

//     fn namespace_def() -> NamespaceDef {
//         NamespaceDef {
//             namespace: "evolute_duel",
//             resources: [
//                 // Budokan tournament models
//                 TestResource::Model(m_BudokanTournament::TEST_CLASS_HASH.try_into().unwrap()),
//                 TestResource::Model(m_Registration::TEST_CLASS_HASH.try_into().unwrap()),
//                 TestResource::Model(m_TokenMetadata::TEST_CLASS_HASH.try_into().unwrap()),
//                 TestResource::Model(m_GameMetadata::TEST_CLASS_HASH.try_into().unwrap()),
//                 TestResource::Model(m_GameCounter::TEST_CLASS_HASH.try_into().unwrap()),
//                 TestResource::Model(m_SettingsDetails::TEST_CLASS_HASH.try_into().unwrap()),
//                 TestResource::Model(m_Score::TEST_CLASS_HASH.try_into().unwrap()),
//                 // Contracts
//                 TestResource::Contract(tournament_budokan_test::TEST_CLASS_HASH),
//                 TestResource::Contract(erc20_mock::TEST_CLASS_HASH),
//                 TestResource::Contract(erc721_mock::TEST_CLASS_HASH),
//             ]
//                 .span(),
//         }
//     }

//     fn contract_defs() -> Span<ContractDef> {
//         [
//             ContractDefTrait::new(@"evolute_duel", @"tournament_budokan_test")
//                 .with_writer_of([dojo::utils::bytearray_hash(@"evolute_duel")].span()),
//             ContractDefTrait::new(@"evolute_duel", @"erc20_mock")
//                 .with_writer_of([dojo::utils::bytearray_hash(@"evolute_duel")].span()),
//             ContractDefTrait::new(@"evolute_duel", @"erc721_mock")
//                 .with_writer_of([dojo::utils::bytearray_hash(@"evolute_duel")].span()),
//         ]
//             .span()
//     }

//     fn setup() -> TestContracts {
//         testing::set_block_number(1);
//         testing::set_block_timestamp(1);

//         let mut world = spawn_test_world([namespace_def()].span());
//         world.sync_perms_and_inits(contract_defs());

//         let tournament_address = world.dispatcher.contract_address;
//         let erc20_address = world.dispatcher.contract_address;
//         let erc721_address = world.dispatcher.contract_address;

//         let tournament = ITournamentDispatcher { contract_address: tournament_address };
//         let erc20 = IERC20MockDispatcher { contract_address: erc20_address };
//         let erc721 = IERC721MockDispatcher { contract_address: erc721_address };

//         // Initialize contracts
//         tournament
//             .initializer(
//                 "BUDOKAN",
//                 "BDK",
//                 "https://api.budokan.io/",
//                 false,
//                 true,
//                 erc20_address,
//                 erc721_address,
//             );

//         // Mint tokens for testing
//         let admin: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
//         testing::set_contract_address(admin);
//         erc20.mint(admin, STARTING_BALANCE);
//         erc721.mint(admin, 1);

//         TestContracts { world, tournament, erc20, erc721 }
//     }

//     fn create_test_metadata() -> Metadata {
//         Metadata { name: TOURNAMENT_NAME, description: TOURNAMENT_DESCRIPTION() }
//     }

//     fn create_test_schedule() -> Schedule {
//         let current_time = get_block_timestamp();
//         Schedule {
//             registration: Option::Some(
//                 Period { start: current_time, end: current_time + 3600 // 1 hour registration
//                 },
//             ),
//             game: Period { start: current_time, end: current_time + 7200 // 2 hours game period
//             },
//             submission_duration: 300 // 5 minutes for score submission
//         }
//     }

//     fn create_test_game_config(game_address: ContractAddress) -> GameConfig {
//         GameConfig { address: game_address, settings_id: 1, prize_spots: 3 }
//     }

//     // Basic functionality tests
//     #[test]
//     fn test_initializer() {
//         let contracts = setup();

//         // Check that tournament contract was initialized
//         let total_tournaments = contracts.tournament.total_tournaments();
//         assert!(total_tournaments == 0, "Initial tournament count should be 0");
//     }

//     #[test]
//     fn test_create_tournament_basic() {
//         let contracts = setup();
//         let admin: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();

//         testing::set_contract_address(admin);

//         let tournament = contracts
//             .tournament
//             .create_tournament(
//                 admin,
//                 create_test_metadata(),
//                 create_test_schedule(),
//                 create_test_game_config(contracts.tournament.contract_address),
//                 Option::None, // No entry fee
//                 Option::None // No entry requirement
//             );

//         // Verify tournament was created
//         assert!(tournament.id == 1, "First tournament should have ID 1");
//         assert!(tournament.created_by == admin, "Creator should be admin");

//         // Check total tournaments increased
//         let total_tournaments = contracts.tournament.total_tournaments();
//         assert!(total_tournaments == 1, "Total tournaments should be 1");
//     }

//     #[test]
//     fn test_create_tournament_with_entry_fee() {
//         let contracts = setup();
//         let admin: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();

//         testing::set_contract_address(admin);

//         let entry_fee = EntryFee {
//             token_address: contracts.erc20.contract_address,
//             amount: 100,
//             distribution: [50, 30, 20].span(),
//             tournament_creator_share: Option::Some(10),
//             game_creator_share: Option::Some(5),
//         };

//         let tournament = contracts
//             .tournament
//             .create_tournament(
//                 admin,
//                 create_test_metadata(),
//                 create_test_schedule(),
//                 create_test_game_config(contracts.tournament.contract_address),
//                 Option::Some(entry_fee),
//                 Option::None,
//             );

//         assert!(tournament.id == 1, "Tournament should be created");

//         // Verify tournament details
//         let saved_tournament = contracts.tournament.tournament(1);
//         assert!(saved_tournament.id == 1, "Tournament ID should match");
//     }

//     #[test]
//     fn test_enter_tournament_basic() {
//         let contracts = setup();
//         let admin: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
//         let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();

//         testing::set_contract_address(admin);

//         // Create tournament
//         let tournament = contracts
//             .tournament
//             .create_tournament(
//                 admin,
//                 create_test_metadata(),
//                 create_test_schedule(),
//                 create_test_game_config(contracts.tournament.contract_address),
//                 Option::None,
//                 Option::None,
//             );

//         // Enter tournament as player1
//         testing::set_contract_address(player1);
//         let (token_id, entry_number) = contracts
//             .tournament
//             .enter_tournament(tournament.id, 'player1', player1, Option::None);

//         assert!(token_id > 0, "Token ID should be generated");
//         assert!(entry_number == 1, "First entry should have number 1");

//         // Check tournament entries count
//         let entries = contracts.tournament.tournament_entries(tournament.id);
//         assert!(entries == 1, "Tournament should have 1 entry");
//     }

//     #[test]
//     fn test_enter_tournament_with_entry_fee() {
//         let contracts = setup();
//         let admin: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
//         let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();

//         // Give player1 some tokens
//         testing::set_contract_address(admin);
//         contracts.erc20.mint(player1, 500);

//         let entry_fee = EntryFee {
//             token_address: contracts.erc20.contract_address,
//             amount: 100,
//             distribution: [50, 30, 20].span(),
//             tournament_creator_share: Option::None,
//             game_creator_share: Option::None,
//         };

//         let tournament = contracts
//             .tournament
//             .create_tournament(
//                 admin,
//                 create_test_metadata(),
//                 create_test_schedule(),
//                 create_test_game_config(contracts.tournament.contract_address),
//                 Option::Some(entry_fee),
//                 Option::None,
//             );

//         // Check player's balance before entry
//         let balance_before = contracts.erc20.balance_of(player1);
//         assert!(balance_before == 500, "Player should have 500 tokens before entry");

//         // Enter tournament as player1
//         testing::set_contract_address(player1);
//         let (_token_id, entry_number) = contracts
//             .tournament
//             .enter_tournament(tournament.id, 'player1', player1, Option::None);

//         // Check balance after entry (should be reduced by entry fee)
//         let balance_after = contracts.erc20.balance_of(player1);
//         assert!(balance_after == 400, "Player should have 400 tokens after paying entry fee");

//         assert!(entry_number == 1, "First entry should have number 1");
//     }

//     #[test]
//     fn test_multiple_players_enter_tournament() {
//         let contracts = setup();
//         let admin: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
//         let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();
//         let player2: ContractAddress = contract_address_const::<PLAYER2_ADDRESS>();
//         let player3: ContractAddress = contract_address_const::<PLAYER3_ADDRESS>();

//         testing::set_contract_address(admin);

//         let tournament = contracts
//             .tournament
//             .create_tournament(
//                 admin,
//                 create_test_metadata(),
//                 create_test_schedule(),
//                 create_test_game_config(contracts.tournament.contract_address),
//                 Option::None,
//                 Option::None,
//             );

//         // Enter as player1
//         testing::set_contract_address(player1);
//         let (_, entry1) = contracts
//             .tournament
//             .enter_tournament(tournament.id, 'player1', player1, Option::None);

//         // Enter as player2
//         testing::set_contract_address(player2);
//         let (_, entry2) = contracts
//             .tournament
//             .enter_tournament(tournament.id, 'player2', player2, Option::None);

//         // Enter as player3
//         testing::set_contract_address(player3);
//         let (_, entry3) = contracts
//             .tournament
//             .enter_tournament(tournament.id, 'player3', player3, Option::None);

//         assert!(entry1 == 1, "First entry should be 1");
//         assert!(entry2 == 2, "Second entry should be 2");
//         assert!(entry3 == 3, "Third entry should be 3");

//         let total_entries = contracts.tournament.tournament_entries(tournament.id);
//         assert!(total_entries == 3, "Tournament should have 3 entries");
//     }

//     #[test]
//     fn test_submit_score() {
//         let contracts = setup();
//         let admin: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
//         let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();

//         testing::set_contract_address(admin);

//         let tournament = contracts
//             .tournament
//             .create_tournament(
//                 admin,
//                 create_test_metadata(),
//                 create_test_schedule(),
//                 create_test_game_config(contracts.tournament.contract_address),
//                 Option::None,
//                 Option::None,
//             );

//         testing::set_contract_address(player1);
//         let (token_id, _) = contracts
//             .tournament
//             .enter_tournament(tournament.id, 'player1', player1, Option::None);

//         // Submit score
//         contracts.tournament.submit_score(tournament.id, token_id, 1);

//         // Check leaderboard was updated
//         let leaderboard = contracts.tournament.get_leaderboard(tournament.id);
//         assert!(leaderboard.len() > 0, "Leaderboard should not be empty");
//     }

//     #[test]
//     fn test_current_phase() {
//         let contracts = setup();
//         let admin: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();

//         testing::set_contract_address(admin);

//         let tournament = contracts
//             .tournament
//             .create_tournament(
//                 admin,
//                 create_test_metadata(),
//                 create_test_schedule(),
//                 create_test_game_config(contracts.tournament.contract_address),
//                 Option::None,
//                 Option::None,
//             );

//         let _phase = contracts.tournament.current_phase(tournament.id);
//         // Phase should be Registration since we're at the start time
//     // The exact phase depends on the current timestamp vs schedule
//     }

//     #[test]
//     fn test_get_registration() {
//         let contracts = setup();
//         let admin: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
//         let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();

//         testing::set_contract_address(admin);

//         let tournament = contracts
//             .tournament
//             .create_tournament(
//                 admin,
//                 create_test_metadata(),
//                 create_test_schedule(),
//                 create_test_game_config(contracts.tournament.contract_address),
//                 Option::None,
//                 Option::None,
//             );

//         testing::set_contract_address(player1);
//         let (token_id, _) = contracts
//             .tournament
//             .enter_tournament(tournament.id, 'player1', player1, Option::None);

//         // Get registration
//         let registration = contracts
//             .tournament
//             .get_registration(contracts.tournament.contract_address, token_id);
//         assert!(
//             registration.tournament_id == tournament.id, "Registration should match tournament",
//         );
//         // assert!(registration.player == player1, "Registration should match player");
//     }

//     #[test]
//     fn test_tournament_id_for_token() {
//         let contracts = setup();
//         let admin: ContractAddress = contract_address_const::<ADMIN_ADDRESS>();
//         let player1: ContractAddress = contract_address_const::<PLAYER1_ADDRESS>();

//         testing::set_contract_address(admin);

//         let tournament = contracts
//             .tournament
//             .create_tournament(
//                 admin,
//                 create_test_metadata(),
//                 create_test_schedule(),
//                 create_test_game_config(contracts.tournament.contract_address),
//                 Option::None,
//                 Option::None,
//             );

//         testing::set_contract_address(player1);
//         let (token_id, _) = contracts
//             .tournament
//             .enter_tournament(tournament.id, 'player1', player1, Option::None);

//         // Get tournament ID for token
//         let retrieved_tournament_id = contracts
//             .tournament
//             .get_tournament_id_for_token_id(contracts.tournament.contract_address, token_id);
//         assert!(retrieved_tournament_id == tournament.id, "Tournament ID should match");
//     }
// }
