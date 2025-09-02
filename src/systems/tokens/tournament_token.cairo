use starknet::{ContractAddress};
use dojo::world::IWorldDispatcher;
use tournaments::components::models::game::{TokenMetadata, GameMetadata};

#[starknet::interface]
pub trait ITournamentToken<TState> {
    // IWorldProvider
    fn world_dispatcher(self: @TState) -> IWorldDispatcher;

    //-----------------------------------
    // IERC721ComboABI start
    //
    // (ISRC5)
    fn supports_interface(self: @TState, interface_id: felt252) -> bool;
    // (IERC721)
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn owner_of(self: @TState, token_id: u256) -> ContractAddress;
    fn safe_transfer_from(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>,
    );
    fn transfer_from(ref self: TState, from: ContractAddress, to: ContractAddress, token_id: u256);
    fn approve(ref self: TState, to: ContractAddress, token_id: u256);
    fn set_approval_for_all(ref self: TState, operator: ContractAddress, approved: bool);
    fn get_approved(self: @TState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(
        self: @TState, owner: ContractAddress, operator: ContractAddress,
    ) -> bool;
    // (IERC721Metadata)
    fn name(self: @TState) -> ByteArray;
    fn symbol(self: @TState) -> ByteArray;
    fn token_uri(self: @TState, token_id: u256) -> ByteArray;
    fn tokenURI(self: @TState, tokenId: u256) -> ByteArray;
    // //-----------------------------------
    // // IERC7572ContractMetadata
    // fn contract_uri(self: @TState) -> ByteArray;
    // fn contractURI(self: @TState) -> ByteArray;
    //-----------------------------------
    // IERC4906MetadataUpdate
    //-----------------------------------
    // // IERC2981RoyaltyInfo
    // fn royalty_info(self: @TState, token_id: u256, sale_price: u256) -> (ContractAddress, u256);
    // fn default_royalty(self: @TState) -> (ContractAddress, felt252, felt252);
    // fn token_royalty(self: @TState, token_id: u256) -> (ContractAddress, u128, u128);
    // IERC721ComboABI end
    //-----------------------------------

    // IGameToken (budokan)
    fn mint(
        ref self: TState,
        player_name: felt252,
        settings_id: u32,
        start: Option<u64>,
        end: Option<u64>,
        to: ContractAddress,
    ) -> u64;
    fn emit_metadata_update(ref self: TState, game_id: u64);
    fn game_metadata(self: @TState) -> GameMetadata;
    fn token_metadata(self: @TState, token_id: u64) -> TokenMetadata;
    fn game_count(self: @TState) -> u64;
    fn namespace(self: @TState) -> ByteArray;
    fn score_model(self: @TState) -> ByteArray;
    fn score_attribute(self: @TState) -> ByteArray;
    fn settings_model(self: @TState) -> ByteArray;


    // ITokenComponentPublic
    fn can_mint(self: @TState, recipient: ContractAddress) -> bool;
    fn update_contract_metadata(ref self: TState);
    fn update_token_metadata(ref self: TState, token_id: u128);
    // fn update_tokens_metadata(ref self: TState, from_token_id: felt252, to_token_id: felt252);

    // ITournamentTokenPublic
    fn can_start_tournament(self: @TState, pass_id: u64) -> bool;
    fn start_tournament(ref self: TState, pass_id: u64) -> u64;
    fn can_enlist_duelist(self: @TState, pass_id: u64) -> bool;
    fn enlist_duelist(ref self: TState, pass_id: u64);
    fn can_join_duel(self: @TState, pass_id: u64) -> bool;
    fn join_duel(ref self: TState, pass_id: u64) -> felt252;
    fn can_end_tournament(self: @TState, pass_id: u64) -> bool;
    fn end_tournament(ref self: TState, pass_id: u64) -> u64;
}

// Exposed to clients
#[starknet::interface]
pub trait ITournamentTokenPublic<TState> {
    // Phase 0 -- Budokan registration

    // Phase 1 -- Enlist Duelist (per player)
    // - can be called by before or after start_tournament()
    fn can_enlist_duelist(self: @TState, pass_id: u64) -> bool;
    fn enlist_duelist(ref self: TState, pass_id: u64);

    // Phase 2 -- Start tournament (any contestant can start)
    // - will shuffle initial bracket
    // - requires VRF!
    fn can_start_tournament(self: @TState, pass_id: u64) -> bool;
    fn start_tournament(ref self: TState, pass_id: u64) -> u64; // returns tournament_id

    // // Phase 3 -- Join tournament (per player)
    fn can_join_duel(self: @TState, pass_id: u64) -> bool;
    fn join_duel(ref self: TState, pass_id: u64) -> felt252; // returns duel_id

    // Phase 4 -- End tournament (any participant can end when time is up)
    fn can_end_tournament(self: @TState, pass_id: u64) -> bool;
    fn end_tournament(ref self: TState, pass_id: u64) -> u64; // returns tournament_id
}

// Exposed to world and admins
#[starknet::interface]
pub trait ITournamentTokenProtected<TState> {
    fn create_settings(ref self: TState);
}

#[dojo::contract]
pub mod tournament_token {
    use core::num::traits::Zero;
    use starknet::{ContractAddress};
    use dojo::world::{WorldStorage, IWorldDispatcherTrait};

    //-----------------------------------
    // ERC-721 Start
    //
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use tournaments::components::game::{game_component};
    use tournaments::components::libs::lifecycle::{LifecycleAssertionsImpl};
    use tournaments::components::interfaces::{IGameDetails, ISettings}; //, IGameToken};

    component!(path: game_component, storage: game, event: GameEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);


    #[abi(embed_v0)]
    impl GameImpl = game_component::GameImpl<ContractState>;
    impl GameInternalImpl = game_component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721CamelOnlyImpl = ERC721Component::ERC721CamelOnlyImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        game: game_component::Storage,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        GameEvent: game_component::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }
    //
    // ERC-721 End
    //-----------------------------------

    // use pistols::models::{
    //     challenge::{Challenge},
    //     duelist::{DuelistTrait},
    //     tournament::{
    //         TournamentPass, TournamentPassValue,
    //         TournamentSettingsValue,
    //         TournamentType, TournamentTypeTrait,
    //         TournamentRules,
    //         Tournament, TournamentValue,
    //         TournamentState,
    //         TournamentRound, TournamentRoundTrait,
    //         TournamentRoundValue,
    //         TournamentBracketTrait,
    //         TournamentResultsTrait,
    //         // TournamentDuelKeys, TournamentDuelKeysTrait,
    //     },
    // };
    // use pistols::types::{
    //     challenge_state::{ChallengeState, ChallengeStateTrait},
    //     constants::{METADATA},
    //     timestamp::{Period, PeriodTrait, TIMESTAMP},
    // };
    use evolute_duel::interfaces::dns::{
        DnsTrait, SELECTORS, ITournamentDispatcher, ITournamentDispatcherTrait,
        IMatchmakingDispatcherTrait, IMatchmakingLibraryDispatcher
        // IDuelProtectedDispatcherTrait,
    };
    use evolute_duel::interfaces::ievlt_token::{IEvltTokenProtectedDispatcher, IEvltTokenProtectedDispatcherTrait};
    // use evolute_duel::systems::rng::{RngWrap, RngWrapTrait};
    use evolute_duel::libs::store::{Store, StoreTrait};
    // use pistols::utils::short_string::{ShortStringTrait};
    // use graffiti::url::{UrlImpl};

    use evolute_duel::models::{
        tournament::{
            TournamentPass, TournamentStateModel,
            TournamentState, PlayerTournamentIndex,
        },
        player::{PlayerTrait},
        game::{GameModeConfig},
    };

    use evolute_duel::utils::{short_string::{ShortStringTrait}};

    use evolute_duel::types::{errors::{tournament::{Errors}}, packing::{GameMode}};

    use tournaments::components::models::{game::{TokenMetadataValue}, tournament::{Registration}};
    use tournaments::components::libs::{lifecycle::{LifecycleTrait}};
    use evolute_duel::libs::rating_system::{RatingSystemTrait};
    use evolute_duel::libs::asserts::{AssertsTrait};

    //*******************************
    // erc721
    fn TOKEN_NAME() -> ByteArray {
        ("Mage Duel Tournament Passes")
    }
    fn TOKEN_SYMBOL() -> ByteArray {
        ("TOURNAMENT")
    }
    //*******************************
    // Budokan
    fn DEFAULT_NS() -> ByteArray {
        "evolute_duel"
    }
    fn SCORE_MODEL() -> ByteArray {
        "TournamentPass"
    }
    fn SCORE_ATTRIBUTE() -> ByteArray {
        "score"
    }
    fn SETTINGS_MODEL() -> ByteArray {
        "TournamentSettings"
    }
    //*******************************

    fn dojo_init(ref self: ContractState, base_uri: felt252) {
        self.erc721.initializer(TOKEN_NAME(), TOKEN_SYMBOL(), base_uri.to_string());
        // // initialize budokan
        self
            .game
            .initializer(
                starknet::get_contract_address(),
                'Mage Duel',
                //TODO: description
                "",
                'Evolute Studio',
                'Evolute Studio',
                'PvP Strategy',
                //TODO: make logo uri
                "",
                DEFAULT_NS(),
                SCORE_MODEL(),
                SCORE_ATTRIBUTE(),
                SETTINGS_MODEL(),
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
    // Budokan hooks
    //
    #[abi(embed_v0)]
    impl SettingsImpl of ISettings<ContractState> {
        fn setting_exists(self: @ContractState, settings_id: u32) -> bool {
            println!("[setting_exists] Starting settings existence check");
            println!("[setting_exists] settings_id = {}", settings_id);

            println!("[setting_exists] Creating Store from world");
            let store: Store = StoreTrait::new(self.world_default());
            println!("[setting_exists] Successfully created Store");

            println!("[setting_exists] Getting tournament settings for ID {}", settings_id);
            let settings: GameModeConfig = store.get_tournament_settings(settings_id);
            println!("[setting_exists] Successfully retrieved tournament settings");

            println!("[setting_exists] Checking tournament type validity");
            println!("[setting_exists] settings.game_mode = {:?}", settings.game_mode);

            let exists = settings.game_mode == GameMode::Tournament.into()
                && settings.board_size != 0;

            println!("[setting_exists] Tournament type is not Undefined: {}", exists);

            println!("[setting_exists] Settings existence check completed, result: {}", exists);
            exists
        }
    }
    #[abi(embed_v0)]
    impl GameDetailsImpl of IGameDetails<ContractState> {
        fn score(self: @ContractState, game_id: u64) -> u32 {
            let mut store: Store = StoreTrait::new(self.world_default());
            let tournament_pass: TournamentPass = store.get_tournament_pass(game_id);
            (tournament_pass.rating)
        }
    }


    //-----------------------------------
    // Public
    //
    #[abi(embed_v0)]
    impl TournamentTokenPublicImpl of super::ITournamentTokenPublic<ContractState> {
        //-----------------------------------
        // Phase 1 -- Enlist Duelist
        //
        fn can_enlist_duelist(self: @ContractState, pass_id: u64) -> bool {
            let store: Store = StoreTrait::new(self.world_default());
            (// owns entry
            self._is_owner_of(starknet::get_caller_address(), pass_id.into())
                &&// not enlisted
                store.get_tournament_pass_value(pass_id).player_address.is_zero())
        }
        fn enlist_duelist(ref self: ContractState, pass_id: u64) {
            println!("[enlist_duelist] Starting enlist_duelist for pass_id: {}", pass_id);
            let mut world = self.world_default();
            let mut store: Store = StoreTrait::new(world);
            println!("[enlist_duelist] Store created successfully");
            
            // validate entry ownership
            let caller: ContractAddress = starknet::get_caller_address();
            println!("[enlist_duelist] Caller address: {:?}", caller);
            
            let is_owner = self._is_owner_of(caller, pass_id.into());
            println!("[enlist_duelist] Ownership check - is_owner: {}", is_owner);
            assert(is_owner == true, Errors::NOT_YOUR_ENTRY);

            // enlist duelist in this tournament
            println!("[enlist_duelist] Getting budokan registration for pass_id: {}", pass_id);
            let registration: Option<Registration> = self
                ._get_budokan_registration(@store, pass_id);
            println!("[enlist_duelist] Registration retrieved: {:?}", registration.is_some());
            
            match registration {
                Option::Some(registration) => {
                    println!("[enlist_duelist] Registration found - tournament_id: {}, entry_number: {}", registration.tournament_id, registration.entry_number);
                    let mut entry: TournamentPass = store.get_tournament_pass(pass_id);
                    println!("[enlist_duelist] Current tournament pass - tournament_id: {}, player_address: {:?}", entry.tournament_id, entry.player_address);
                    
                    assert(entry.player_address.is_zero(), Errors::ALREADY_ENLISTED);
                    println!("[enlist_duelist] Player address is zero - proceeding");
                    
                    assert(registration.entry_number.is_non_zero(), Errors::INVALID_ENTRY_NUMBER);
                    println!("[enlist_duelist] Entry number is valid: {}", registration.entry_number);
                    
                    entry.tournament_id = registration.tournament_id;
                    entry.entry_number = registration.entry_number.try_into().unwrap();
                    entry.player_address = caller;
                    println!("[enlist_duelist] Tournament pass updated - tournament_id: {}, entry_number: {}, player_address: {:?}", entry.tournament_id, entry.entry_number, entry.player_address);

                    // Initialize tournament rating for new participant
                    println!("[enlist_duelist] Initializing tournament rating");
                    RatingSystemTrait::initialize_tournament_rating(ref entry);
                    println!("[enlist_duelist] Tournament rating initialized");

                    store.set_tournament_pass(@entry);
                    println!("[enlist_duelist] Tournament pass saved to store");

                    // Create index for fast player -> pass lookup
                    let player_index = PlayerTournamentIndex {
                        player_address: caller,
                        tournament_id: registration.tournament_id,
                        pass_id: pass_id,
                    };
                    store.set_player_tournament_index(@player_index);
                    println!("[enlist_duelist] Player tournament index created - player: {:?}, tournament_id: {}, pass_id: {}", caller, registration.tournament_id, pass_id);
                    
                    // validate and create DuelistAssignment
                    //TODO: logic of entering tournament for game
                    println!("[enlist_duelist] Calling PlayerTrait::enter_tournament");
                    PlayerTrait::enter_tournament(ref store, caller, pass_id, registration.tournament_id);
                    println!("[enlist_duelist] PlayerTrait::enter_tournament completed successfully");

                    // Reward player with 10 EVLT tokens for enlisting
                    println!("[enlist_duelist] Minting 10 EVLT tokens as enlistment reward");
                    let evlt_token_address = world.evlt_token_address();
                    let evlt_dispatcher = IEvltTokenProtectedDispatcher { contract_address: evlt_token_address };
                    
                    // 10 EVLT tokens with 18 decimals = 10 * 10^18
                    let reward_amount: u256 = 10_u256 * 1000000000000000000_u256; // 10 * 10^18
                    println!("[enlist_duelist] Minting {} EVLT tokens to player {:?}", reward_amount, caller);
                    
                    evlt_dispatcher.mint(caller, reward_amount);
                    println!("[enlist_duelist] Successfully minted {} EVLT tokens to player", reward_amount);
                },
                Option::None => {
                    // should never get here since entry is owned and exists
                    println!("[enlist_duelist] ERROR: Registration not found for pass_id: {}", pass_id);
                    assert(false, Errors::INVALID_ENTRY);
                },
            }
            println!("[enlist_duelist] enlist_duelist completed successfully");
        }

        //-----------------------------------
        // Phase 2 -- Start tournament
        //
        fn can_start_tournament(self: @ContractState, pass_id: u64) -> bool {
            println!("[can_start_tournament] Checking if tournament can be started for pass_id: {}", pass_id);
            
            println!("[can_start_tournament] Getting token owner");
            let token_owner = self.erc721.owner_of(pass_id.into());
            println!("[can_start_tournament] Token owner: {:?}", token_owner);
            
            let caller = starknet::get_caller_address();
            println!("[can_start_tournament] Caller address: {:?}", caller);
            
            if (token_owner != caller) {
                println!("[can_start_tournament] FAIL: Caller is not token owner");
                return false;
            }
            println!("[can_start_tournament] PASS: Caller is token owner");
            
            println!("[can_start_tournament] Creating store");
            let store: Store = StoreTrait::new(self.world_default());
            println!("[can_start_tournament] Store created");
            
            println!("[can_start_tournament] Getting budokan token metadata");
            let token_metadata: TokenMetadataValue = store
                .get_budokan_token_metadata_value(pass_id);
            println!("[can_start_tournament] Token metadata retrieved");
            
            println!("[can_start_tournament] Getting budokan tournament ID");
            let (_, tournament_id): (ITournamentDispatcher, u64) = self
                ._get_budokan_tournament_id(@store, pass_id);
            println!("[can_start_tournament] Tournament ID: {}", tournament_id);
            
            println!("[can_start_tournament] Getting tournament from store");
            let tournament = store.get_tournament(tournament_id);
            println!("[can_start_tournament] Tournament state: {:?}", tournament.state);
            
            // Check ownership
            println!("[can_start_tournament] Checking ownership with _is_owner_of");
            let owns_entry = self._is_owner_of(caller, pass_id.into());
            println!("[can_start_tournament] Owns entry: {}", owns_entry);
            
            // Check lifecycle
            let current_timestamp = starknet::get_block_timestamp();
            println!("[can_start_tournament] Current timestamp: {}", current_timestamp);
            let can_start_lifecycle = token_metadata.lifecycle.can_start(current_timestamp);
            println!("[can_start_tournament] Lifecycle can_start: {}", can_start_lifecycle);
            
            // Check tournament state
            let tournament_not_started = tournament.state == TournamentState::Undefined;
            println!("[can_start_tournament] Tournament not started (is Undefined): {}", tournament_not_started);
            
            let result = owns_entry && can_start_lifecycle && tournament_not_started;
            println!("[can_start_tournament] Final result: {} (owns_entry: {} && can_start_lifecycle: {} && tournament_not_started: {})", 
                result, owns_entry, can_start_lifecycle, tournament_not_started);
            
            result
        }
        fn start_tournament(ref self: ContractState, pass_id: u64) -> u64 {
            println!("[start_tournament] ============= STARTING TOURNAMENT =============");
            println!("[start_tournament] Starting tournament for pass_id: {}", pass_id);
            
            println!("[start_tournament] Asserting token ownership");
            self.assert_token_ownership(pass_id);
            println!("[start_tournament] Token ownership assertion passed");
            
            println!("[start_tournament] Creating Store from world");
            let mut store: Store = StoreTrait::new(self.world_default());
            println!("[start_tournament] Store created successfully");
            
            // validate ownership
            println!("[start_tournament] Getting caller address");
            let caller: ContractAddress = starknet::get_caller_address();
            println!("[start_tournament] Caller address: {:?}", caller);
            
            println!("[start_tournament] Validating ownership with _is_owner_of");
            let is_owner = self._is_owner_of(caller, pass_id.into());
            println!("[start_tournament] Ownership validation result: {}", is_owner);
            assert(is_owner == true, Errors::NOT_YOUR_ENTRY);
            println!("[start_tournament] Ownership validation passed");
            
            // verify lifecycle
            println!("[start_tournament] Getting budokan token metadata for lifecycle verification");
            let token_metadata: TokenMetadataValue = store
                .get_budokan_token_metadata_value(pass_id);
            println!("[start_tournament] Token metadata retrieved successfully");
            
            let current_timestamp = starknet::get_block_timestamp();
            println!("[start_tournament] Current block timestamp: {}", current_timestamp);
            
            let can_start = token_metadata.lifecycle.can_start(current_timestamp);
            println!("[start_tournament] Lifecycle can_start check result: {}", can_start);
            assert(
                can_start,
                Errors::BUDOKAN_NOT_STARTABLE,
            );
            println!("[start_tournament] Lifecycle verification passed");
            
            // verify tournament not started
            println!("[start_tournament] Getting budokan tournament ID");
            let (tournament_dispatcher, tournament_id): (ITournamentDispatcher, u64) = self
                ._get_budokan_tournament_id(@store, pass_id);
            println!("[start_tournament] Tournament dispatcher: {:?}", tournament_dispatcher.contract_address);
            println!("[start_tournament] Retrieved tournament_id: {}", tournament_id);
            
            println!("[start_tournament] Getting tournament state from store");
            let mut tournament: TournamentStateModel = store.get_tournament(tournament_id);
            println!("[start_tournament] Current tournament state: {:?}", tournament.state);
            println!("[start_tournament] Tournament prize_pool: {}", tournament.prize_pool);
            
            assert(tournament.state == TournamentState::Undefined, Errors::ALREADY_STARTED);
            println!("[start_tournament] Tournament state validation passed (was Undefined)");
            
            println!("[start_tournament] Setting tournament state to InProgress");
            tournament.state = TournamentState::InProgress;
            println!("[start_tournament] Tournament state updated to: {:?}", tournament.state);
            
            // store!
            println!("[start_tournament] Saving tournament to store");
            store.set_tournament(@tournament);
            println!("[start_tournament] Tournament saved to store successfully");
            
            // return tournament id
            println!("[start_tournament] Tournament started successfully! Tournament ID: {}", tournament_id);
            println!("[start_tournament] ============= TOURNAMENT STARTED =============");
            (tournament_id)
        }

        //-----------------------------------
        // Phase 3 -- Join Duel
        //
        fn can_join_duel(self: @ContractState, pass_id: u64) -> bool {
            let store: Store = StoreTrait::new(self.world_default());
            let token_metadata = store.get_budokan_token_metadata_value(pass_id);
            let entry = store.get_tournament_pass_value(pass_id);
            let tournament = store.get_tournament_value(entry.tournament_id);

            // Simplified rating-based tournament checks
            (// owns entry
            self._is_owner_of(starknet::get_caller_address(), pass_id.into())
                &&// correct lifecycle
                token_metadata.lifecycle.is_playable(starknet::get_block_timestamp())
                &&// enlisted in tournament
                entry.tournament_id.is_non_zero()
                &&// tournament has started
                tournament.state == TournamentState::InProgress)
        }
        fn join_duel(ref self: ContractState, pass_id: u64) -> felt252 {
            println!("[join_duel] Starting join_duel for pass_id: {}", pass_id);
            
            let mut store: Store = StoreTrait::new(self.world_default());
            println!("[join_duel] Store created successfully");
            
            // validate ownership
            let caller: ContractAddress = starknet::get_caller_address();
            println!("[join_duel] Caller address: {:?}", caller);
            
            let is_owner = self._is_owner_of(caller, pass_id.into());
            println!("[join_duel] Ownership check - is_owner: {}", is_owner);
            assert(is_owner == true, Errors::NOT_YOUR_ENTRY);
            println!("[join_duel] Ownership validation passed");

            // Check tournament lifecycle
            println!("[join_duel] Getting budokan token metadata for lifecycle check");
            let token_metadata = store.get_budokan_token_metadata_value(pass_id);
            let current_timestamp = starknet::get_block_timestamp();
            println!("[join_duel] Current timestamp: {}", current_timestamp);
            
            let is_playable = token_metadata.lifecycle.is_playable(current_timestamp);
            println!("[join_duel] Lifecycle playability check - is_playable: {}", is_playable);
            assert(is_playable, Errors::BUDOKAN_NOT_PLAYABLE);
            println!("[join_duel] Lifecycle validation passed");

            // Get tournament entry
            println!("[join_duel] Getting tournament pass for pass_id: {}", pass_id);
            let entry = store.get_tournament_pass(pass_id);
            println!("[join_duel] Tournament pass retrieved - tournament_id: {}, player_address: {:?}, entry_number: {}, rating: {}", 
                entry.tournament_id, entry.player_address, entry.entry_number, entry.rating);
            
            assert(entry.tournament_id.is_non_zero(), Errors::NOT_ENLISTED);
            println!("[join_duel] Tournament ID validation passed: {}", entry.tournament_id);
            
            assert(entry.player_address.is_non_zero(), Errors::NOT_ENLISTED);
            println!("[join_duel] Player address validation passed: {:?}", entry.player_address);

            // Check tournament state
            println!("[join_duel] Getting tournament state for tournament_id: {}", entry.tournament_id);
            let tournament = store.get_tournament_value(entry.tournament_id);
            println!("[join_duel] Tournament state retrieved - state: {:?}", tournament.state);
            
            assert(tournament.state != TournamentState::Finished, Errors::HAS_ENDED);
            println!("[join_duel] Tournament not finished check passed");
            
            assert(tournament.state == TournamentState::InProgress, Errors::NOT_STARTED);
            println!("[join_duel] Tournament in progress check passed");

            // Check if player can afford tournament entry (WITHOUT charging tokens)
            println!("[join_duel] Getting world storage for token affordability validation");
            let world_storage = self.world_default();
            println!("[join_duel] World storage obtained, checking if player can afford tournament");
            
            let can_afford = AssertsTrait::assert_can_afford_tournament_game(
                caller, entry.tournament_id, world_storage,
            );
            println!("[join_duel] Token affordability check result: {}", can_afford);
            assert(can_afford, Errors::INSUFFICIENT_TOKENS);
            println!("[join_duel] Token affordability validation passed - player can afford tournament but tokens not charged yet");

            // Use matchmaking system to create/join tournaments
            println!("[join_duel] Getting world instance for matchmaking");
            let world = self.world_default();
            println!("[join_duel] Getting matchmaking library dispatcher");
            let matchmaking_dispatcher: IMatchmakingLibraryDispatcher = world.matchmaking_library_dispatcher();
            println!("[join_duel] Matchmaking dispatcher obtained successfully");

            // Call auto_match with Tournament mode and tournament_id
            println!("[join_duel] Calling auto_match with GameMode::Tournament and tournament_id: {}", entry.tournament_id);
            let game_mode_packed = GameMode::Tournament.into();
            println!("[join_duel] GameMode packed value: {}", game_mode_packed);
            
            let result = matchmaking_dispatcher
                .auto_match(game_mode_packed, Option::Some(entry.tournament_id));
            println!("[join_duel] auto_match result: {}", result);

            // Return the result: board_id if match found, 0 if waiting in queue
            if result == 0 {
                println!("[join_duel] Player added to queue, waiting for opponent");
            } else {
                println!("[join_duel] Match found! Board ID: {}", result);
            }
            
            println!("[join_duel] join_duel completed successfully, returning: {}", result);
            (result)
        }

        //-----------------------------------
        // Phase 4 -- End tournament
        //
        fn can_end_tournament(self: @ContractState, pass_id: u64) -> bool {
            let store: Store = StoreTrait::new(self.world_default());
            let entry = store.get_tournament_pass_value(pass_id);

            // Must be enrolled in a tournament
            if entry.tournament_id.is_zero() {
                return false;
            }

            // Must own the entry token
            if !self._is_owner_of(starknet::get_caller_address(), pass_id.into()) {
                return false;
            }

            let tournament = store.get_tournament_value(entry.tournament_id);
            // Tournament must be in progress (not finished yet)
            if tournament.state != TournamentState::InProgress {
                return false;
            }

            // Check if tournament should end based on budokan logic
            // We'll use the lifecycle to determine if tournament period has ended
            let token_metadata = store.get_budokan_token_metadata_value(pass_id);
            let current_time = starknet::get_block_timestamp();

            // Tournament can end if it's no longer playable (time period ended)
            (!token_metadata.lifecycle.is_playable(current_time))
        }

        fn end_tournament(ref self: ContractState, pass_id: u64) -> u64 {
            // Validate ownership and tournament state
            let caller: ContractAddress = starknet::get_caller_address();
            assert(self._is_owner_of(caller, pass_id.into()), Errors::NOT_YOUR_ENTRY);

            let mut store: Store = StoreTrait::new(self.world_default());
            let entry = store.get_tournament_pass(pass_id);
            assert(entry.tournament_id.is_non_zero(), Errors::NOT_ENLISTED);

            // Check if tournament can be ended
            let can_end: bool = self.can_end_tournament(pass_id);
            assert(can_end == true, Errors::TOURNAMENT_NOT_ENDED);

            let mut tournament: TournamentStateModel = store.get_tournament(entry.tournament_id);
            assert(tournament.state == TournamentState::InProgress, Errors::NOT_STARTED);

            // Mark tournament as finished
            tournament.state = TournamentState::Finished;
            store.set_tournament(@tournament);

            // Budokan handles leaderboards and rankings through submit_score()
            // No need to finalize rankings here - participants submit their own scores

            (entry.tournament_id)
        }
    }

    //-----------------------------------
    // Protected
    //
    // #[abi(embed_v0)]
    // impl TournamentTokenProtectedImpl of super::ITournamentTokenProtected<ContractState> {
    // fn create_settings(ref self: ContractState) {
    //     self._assert_caller_is_owner();
    //     self._create_settings();
    // }
    // }

    //------------------------------------
    // Internal calls
    //
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        #[inline(always)]
        fn _assert_caller_is_owner(self: @ContractState) {
            println!("[_assert_caller_is_owner] Asserting caller is contract owner");
            
            println!("[_assert_caller_is_owner] Getting world storage");
            let world = self.world_default();
            println!("[_assert_caller_is_owner] World storage obtained");
            
            let caller = starknet::get_caller_address();
            println!("[_assert_caller_is_owner] Caller address: {:?}", caller);
            
            println!("[_assert_caller_is_owner] Checking if caller is owner of TOURNAMENT_TOKEN");
            let is_owner = world
                .dispatcher
                .is_owner(SELECTORS::TOURNAMENT_TOKEN, caller);
            println!("[_assert_caller_is_owner] Is owner check result: {}", is_owner);
            
            assert(
                is_owner == true,
                Errors::CALLER_NOT_OWNER,
            );
            println!("[_assert_caller_is_owner] Caller ownership assertion passed");
        }

        fn _get_budokan_tournament_id(
            self: @ContractState, store: @Store, pass_id: u64,
        ) -> (ITournamentDispatcher, u64) {
            println!("[_get_budokan_tournament_id] Getting budokan tournament ID for pass_id: {}", pass_id);
            
            println!("[_get_budokan_tournament_id] Getting budokan dispatcher from store");
            let budokan_dispatcher: ITournamentDispatcher = store
                .budokan_dispatcher_from_pass_id(pass_id);
            println!("[_get_budokan_tournament_id] Budokan dispatcher address: {:?}", budokan_dispatcher.contract_address);
            
            println!("[_get_budokan_tournament_id] Checking if dispatcher address is non-zero");
            let tournament_id: u64 = if (budokan_dispatcher.contract_address.is_non_zero()) {
                println!("[_get_budokan_tournament_id] Dispatcher is valid, getting tournament ID from budokan");
                let contract_address = starknet::get_contract_address();
                println!("[_get_budokan_tournament_id] Current contract address: {:?}", contract_address);
                
                let id = budokan_dispatcher
                    .get_tournament_id_for_token_id(contract_address, pass_id);
                println!("[_get_budokan_tournament_id] Retrieved tournament_id from budokan: {}", id);
                id
            } else {
                println!("[_get_budokan_tournament_id] WARNING: Dispatcher address is zero, returning 0");
                0
            }; // invalid entry
            
            println!("[_get_budokan_tournament_id] Final tournament_id: {}", tournament_id);
            (budokan_dispatcher, tournament_id)
        }

        fn _get_budokan_registration(
            self: @ContractState, store: @Store, pass_id: u64,
        ) -> Option<Registration> {
            println!("[_get_budokan_registration] Getting budokan dispatcher for pass_id: {}", pass_id);
            let budokan_dispatcher: ITournamentDispatcher = store
                .budokan_dispatcher_from_pass_id(pass_id);
            println!("[_get_budokan_registration] Budokan dispatcher address: {:?}", budokan_dispatcher.contract_address);
            
            (if (budokan_dispatcher.contract_address.is_non_zero()) {
                println!("[_get_budokan_registration] Dispatcher address is valid, getting registration");
                let registration = budokan_dispatcher.get_registration(starknet::get_contract_address(), pass_id);
                println!("[_get_budokan_registration] Registration retrieved - tournament_id: {}, entry_number: {}", registration.tournament_id, registration.entry_number);
                Option::Some(registration)
            } else {
                println!("[_get_budokan_registration] ERROR: Dispatcher address is zero");
                Option::None
            })
        }

        #[inline(always)]
        fn assert_token_ownership(self: @ContractState, token_id: u64) {
            println!("[assert_token_ownership] Asserting token ownership for token_id: {}", token_id);
            let token_owner = self.erc721.owner_of(token_id.into());
            println!("[assert_token_ownership] Token owner: {:?}", token_owner);
            
            let caller = starknet::get_caller_address();
            println!("[assert_token_ownership] Caller address: {:?}", caller);
            
            let is_owner = token_owner == caller;
            println!("[assert_token_ownership] Is owner check result: {}", is_owner);
            
            assert(is_owner, Errors::NOT_YOUR_ENTRY);
            println!("[assert_token_ownership] Token ownership assertion passed");
        }

        #[inline(always)]
        fn _is_owner_of(self: @ContractState, caller: ContractAddress, token_id: u64) -> bool {
            println!("[_is_owner_of] Checking token ownership for caller: {:?}, token_id: {}", caller, token_id);
            let token_owner: ContractAddress = self.erc721.owner_of(token_id.into());
            let is_owner: bool = token_owner == caller;
            println!("[_is_owner_of] Ownership result: {}", is_owner);
            is_owner
        }
    }
}
