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
    fn safe_transfer_from(ref self: TState, from: ContractAddress, to: ContractAddress, token_id: u256, data: Span<felt252>);
    fn transfer_from(ref self: TState, from: ContractAddress, to: ContractAddress, token_id: u256);
    fn approve(ref self: TState, to: ContractAddress, token_id: u256);
    fn set_approval_for_all(ref self: TState, operator: ContractAddress, approved: bool);
    fn get_approved(self: @TState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(self: @TState, owner: ContractAddress, operator: ContractAddress) -> bool;
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
    fn mint(ref self: TState,
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
    use dojo::model::{Model, ModelPtr, ModelStorage, ModelValueStorage};


    //-----------------------------------
    // ERC-721 Start
    //
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin_token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait, IERC721Metadata};
    use openzeppelin_token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use tournaments::components::game::{game_component};
    use tournaments::components::libs::lifecycle::{LifecycleAssertionsImpl, LifecycleAssertionsTrait};
    use tournaments::components::models::game::TokenMetadata;
    use tournaments::components::interfaces::{IGameDetails, ISettings};//, IGameToken};
    
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
        DnsTrait, SELECTORS, Source,
        ITournamentDispatcher, ITournamentDispatcherTrait,
        IGameDispatcherTrait, IVrfProviderDispatcherTrait,
        IMatchmakingDispatcher, IMatchmakingDispatcherTrait,
        // IDuelProtectedDispatcherTrait,
    };
    // use evolute_duel::systems::rng::{RngWrap, RngWrapTrait};
    use evolute_duel::libs::store::{Store, StoreTrait};
    // use pistols::utils::short_string::{ShortStringTrait};
    // use graffiti::url::{UrlImpl};

    use evolute_duel::models::{
        tournament::{
            TournamentPass,
            TournamentSettings,
            TournamentType, TournamentTypeTrait,
            TournamentRules,
            Tournament,
            TournamentState,
        
        },
        player::{PlayerTrait},
        challenge::{
            Challenge,
        },
    };

    use evolute_duel::utils::{
        short_string::{ShortStringTrait}
    };

    use evolute_duel::types::{
        errors::{
            tournament::{
                Errors,
            }
        },
        timestamp::{Period, PeriodTrait, TIMESTAMP},
        constants::{METADATA},
        challenge_state::{ChallengeState, ChallengeStateTrait},
        packing::{GameMode},
    };

    use tournaments::components::models::{
        game::{TokenMetadataValue},
        tournament::{Registration},
        lifecycle::{Lifecycle},
    };
    use tournaments::components::libs::{
        lifecycle::{LifecycleTrait},
    };
    use evolute_duel::libs::rating_system::{RatingSystemTrait};

    //*******************************
    // erc721
    fn TOKEN_NAME()   -> ByteArray {("Mage Duel Tournament Passes")}
    fn TOKEN_SYMBOL() -> ByteArray {("TOURNAMENT")}
    //*******************************
    // Budokan
    fn DEFAULT_NS() -> ByteArray {"evolute_duel"}
    fn SCORE_MODEL() -> ByteArray {"TournamentPass"}
    fn SCORE_ATTRIBUTE() -> ByteArray {"score"}
    fn SETTINGS_MODEL() -> ByteArray {"TournamentSettings"}
    //*******************************

    fn dojo_init(
        ref self: ContractState,
        base_uri: felt252,
    ) {
        self.erc721.initializer(
            TOKEN_NAME(),
            TOKEN_SYMBOL(),
            base_uri.to_string(),
        );
        // // initialize budokan
        self.game.initializer(
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
        self._create_settings();
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
            //TODO
            // let store: Store = StoreTrait::new(self.world_default());
            // let settings: TournamentSettingsValue = store.get_tournament_settings_value(settings_id);
            // (settings.tournament_type.exists())
            false
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
            (
                // owns entry
                self._is_owner_of(starknet::get_caller_address(), pass_id.into()) &&
                // not enlisted
                store.get_tournament_pass_value(pass_id).player_address.is_zero()
            )
        }
        fn enlist_duelist(ref self: ContractState, pass_id: u64) {
            let mut store: Store = StoreTrait::new(self.world_default());
            // validate entry ownership
            let caller: ContractAddress = starknet::get_caller_address();
            assert(self._is_owner_of(caller, pass_id.into()) == true, Errors::NOT_YOUR_ENTRY);

            // enlist duelist in this tournament
            let registration: Option<Registration> = self._get_budokan_registration(@store, pass_id);
            match registration {
                Option::Some(registration) => {
                    let mut entry: TournamentPass = store.get_tournament_pass(pass_id);
                    assert(entry.player_address.is_zero(), Errors::ALREADY_ENLISTED);
                    assert(registration.entry_number.is_non_zero(), Errors::INVALID_ENTRY_NUMBER);
                    entry.tournament_id = registration.tournament_id;
                    entry.entry_number = registration.entry_number.try_into().unwrap();
                    entry.player_address = caller;
                    
                    // Initialize tournament rating for new participant
                    RatingSystemTrait::initialize_tournament_rating(ref entry);
                    
                    store.set_tournament_pass(@entry);
                    // validate and create DuelistAssignment
                    //TODO: logic of entering tournament for game
                    PlayerTrait::enter_tournament(ref store, caller, pass_id);
                },
                Option::None => {
                    // should never get here since entry is owned and exists
                    assert(false, Errors::INVALID_ENTRY);
                },
            }
        }

        //-----------------------------------
        // Phase 2 -- Start tournament
        //
        fn can_start_tournament(self: @ContractState, pass_id: u64) -> bool {
            let token_owner = self.erc721.owner_of(pass_id.into());
            if (token_owner != starknet::get_caller_address()) {
                return false;
            }
            let store: Store = StoreTrait::new(self.world_default());
            let token_metadata: TokenMetadataValue = store.get_budokan_token_metadata_value(pass_id);
            let (_, tournament_id): (ITournamentDispatcher, u64) = self._get_budokan_tournament_id(@store, pass_id);
            let tournament = store.get_tournament(tournament_id);
            (
                // owns entry
                self._is_owner_of(starknet::get_caller_address(), pass_id.into()) &&
                // correct lifecycle
                token_metadata.lifecycle.can_start(starknet::get_block_timestamp()) &&
                // tournament not started (don't exist yet)
                tournament.state == TournamentState::Undefined
            )
        }
        fn start_tournament(ref self: ContractState, pass_id: u64) -> u64 {
            self.assert_token_ownership(pass_id);
            let mut store: Store = StoreTrait::new(self.world_default());
            // validate ownership
            let caller: ContractAddress = starknet::get_caller_address();
            assert(self._is_owner_of(caller, pass_id.into()) == true, Errors::NOT_YOUR_ENTRY);
            // verify lifecycle
            let token_metadata: TokenMetadataValue = store.get_budokan_token_metadata_value(pass_id);
            assert(token_metadata.lifecycle.can_start(starknet::get_block_timestamp()), Errors::BUDOKAN_NOT_STARTABLE);
            // verify tournament not started
            let (budokan_dispatcher, tournament_id): (ITournamentDispatcher, u64) = self._get_budokan_tournament_id(@store, pass_id);
            let mut tournament: Tournament = store.get_tournament(tournament_id);
            assert(tournament.state == TournamentState::Undefined, Errors::ALREADY_STARTED);
            tournament.state = TournamentState::InProgress;
            // store!
            store.set_tournament(@tournament);
            // return tournament id
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
            (
                // owns entry
                self._is_owner_of(starknet::get_caller_address(), pass_id.into()) &&
                // correct lifecycle
                token_metadata.lifecycle.is_playable(starknet::get_block_timestamp()) &&
                // enlisted in tournament
                entry.tournament_id.is_non_zero() &&
                // tournament has started
                tournament.state == TournamentState::InProgress
            )
        }
        fn join_duel(ref self: ContractState, pass_id: u64) -> felt252 {
            let mut store: Store = StoreTrait::new(self.world_default());
            // validate ownership
            let caller: ContractAddress = starknet::get_caller_address();
            assert(self._is_owner_of(caller, pass_id.into()) == true, Errors::NOT_YOUR_ENTRY);
            
            // Check tournament lifecycle
            let token_metadata = store.get_budokan_token_metadata_value(pass_id);
            assert(token_metadata.lifecycle.is_playable(starknet::get_block_timestamp()), Errors::BUDOKAN_NOT_PLAYABLE);
            
            // Get tournament entry
            let entry = store.get_tournament_pass(pass_id);
            assert(entry.tournament_id.is_non_zero(), Errors::NOT_ENLISTED);
            assert(entry.player_address.is_non_zero(), Errors::NOT_ENLISTED);
            
            // Check tournament state
            let tournament = store.get_tournament_value(entry.tournament_id);
            assert(tournament.state != TournamentState::Finished, Errors::HAS_ENDED);
            assert(tournament.state == TournamentState::InProgress, Errors::NOT_STARTED);
            
            // Use matchmaking system to create/join tournaments
            let world = self.world_default();
            let matchmaking_dispatcher = world.matchmaking_dispatcher();
            
            // Call auto_match with Tournament mode and tournament_id
            let result = matchmaking_dispatcher.auto_match(
                GameMode::Tournament.into(),
                Option::Some(entry.tournament_id)
            );
            
            // Return the result: board_id if match found, 0 if waiting in queue
            (result)
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
        fn _assert_caller_is_owner(self: @ContractState) {
            let mut world = self.world_default();
            // Simplified: skip owner check for now
            // assert(world.dispatcher.is_owner(SELECTORS::TOURNAMENT_TOKEN, starknet::get_caller_address()) == true, Errors::CALLER_NOT_OWNER);
        }

        fn _create_settings(ref self: ContractState) {
            let mut store: Store = StoreTrait::new(self.world_default());
            store.set_tournament_settings(TournamentType::LastManStanding.tournament_settings());
        }

        // TODO: Simplified tournament - remove complex Budokan integration for now
        fn _get_budokan_tournament_id(self: @ContractState, store: @Store, pass_id: u64) -> (ITournamentDispatcher, u64) {
            // Simplified: return default values
            let dispatcher = ITournamentDispatcher { contract_address: starknet::contract_address_const::<0>() };
            let tournament_id: u64 = pass_id; // Use pass_id as tournament_id for simplicity
            (dispatcher, tournament_id)
        }

        // TODO: Simplified tournament - remove complex Budokan registration for now
        fn _get_budokan_registration(self: @ContractState, store: @Store, pass_id: u64) -> Option<Registration> {
            // Simplified: return None for now
            Option::None
        }

        #[inline(always)]
        fn assert_token_ownership(self: @ContractState, token_id: u64) {
            let token_owner = self.erc721.owner_of(token_id.into());
            assert(
                token_owner == starknet::get_caller_address(),
                Errors::NOT_YOUR_ENTRY
            );
        }

        #[inline(always)]
        fn _is_owner_of(self: @ContractState, caller: ContractAddress, token_id: u64) -> bool {
            let token_owner = self.erc721.owner_of(token_id.into());
            token_owner == caller
        }
    }
}
