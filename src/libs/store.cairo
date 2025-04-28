use core::num::traits::Zero;
use starknet::{ContractAddress};
use dojo::world::{WorldStorage};
use dojo::model::{Model, ModelPtr, ModelStorage, ModelValueStorage};
use dojo::event::{EventStorage};

pub use evolute_duel::models::{
    // config::{
    //     CONFIG,
    //     Config, ConfigValue,
    //     CoinConfig, CoinConfigValue,
    //     TokenConfig, TokenConfigValue,
    // },
    // pool::{
    //     Pool, PoolType,
    //     LordsReleaseBill,
    // },
    player::{
        Player, PlayerValue, Shop, ShopValue
    },
    game::{
        Board, BoardValue, Game, GameValue, 
        Move, MoveValue, Rules, RulesValue,
        Snapshot, SnapshotValue
    },
    scoring::{
        CityNode, CityNodeValue, RoadNode, RoadNodeValue,
        PotentialCityContests, PotentialCityContestsValue, 
        PotentialRoadContests, PotentialRoadContestsValue
    },
    tournament::{
        Tournament, TournamentValue,
        TournamentPass, TournamentPassValue,
        TournamentSettings, TournamentSettingsValue,
        TournamentRound, TournamentRoundValue,
        TournamentType,
        TournamentDuelKeys,
        TournamentRules,
        TournamentState,
    },
};
// pub use pistols::systems::components::{
//     token_bound::{s
//         TokenBoundAddress, TokenBoundAddressValue,
//     },
// };
// use pistols::types::{
//     rules::{RewardValues},
// };
use tournaments::components::models::game::{TokenMetadata, TokenMetadataValue};
use evolute_duel::interfaces::dns::{ITournamentDispatcher};

#[derive(Copy, Drop)]
pub struct Store {
    pub world: WorldStorage,
}

#[generate_trait]
pub impl StoreImpl of StoreTrait {
    #[inline(always)]
    fn new(world: WorldStorage) -> Store {
        (Store { world })
    }

    //----------------------------------
    // Model Getters
    //

    #[inline(always)]
    fn get_player(self: @Store, address: ContractAddress) -> Player {
        (self.world.read_model(address))
    }
    #[inline(always)]
    fn get_payer_value(self: @Store, address: ContractAddress) -> PlayerValue {
        (self.world.read_value(address))
    }

    #[inline(always)]
    fn get_shop(self: @Store, id: felt252) -> Shop {
        (self.world.read_model(id))
    }

    #[inline(always)]
    fn get_shop_value(self: @Store, id: felt252) -> ShopValue {
        (self.world.read_value(id))
    }
    

    #[inline(always)]
    fn get_tournament_pass(self: @Store, pass_id: u64) -> TournamentPass {
        (self.world.read_model(pass_id))
    }
    #[inline(always)]
    fn get_tournament_pass_value(self: @Store, pass_id: u64) -> TournamentPassValue {
        (self.world.read_value(pass_id))
    }

    #[inline(always)]
    fn get_tournament_settings(self: @Store, settings_id: u32) -> TournamentSettings {
        (self.world.read_model(settings_id))
    }
    #[inline(always)]
    fn get_tournament_settings_value(self: @Store, settings_id: u32) -> TournamentSettingsValue {
        (self.world.read_value(settings_id))
    }

    #[inline(always)]
    fn get_tournament(self: @Store, tournament_id: u64) -> Tournament {
        (self.world.read_model(tournament_id))
    }
    #[inline(always)]
    fn get_tournament_value(self: @Store, tournament_id: u64) -> TournamentValue {
        (self.world.read_value(tournament_id))
    }

    #[inline(always)]
    fn get_tournament_round(self: @Store, tournament_id: u64, round_number: u8) -> TournamentRound {
        (self.world.read_model((tournament_id, round_number),))
    }
    #[inline(always)]
    fn get_tournament_round_value(self: @Store, tournament_id: u64, round_number: u8) -> TournamentRoundValue {
        (self.world.read_value((tournament_id, round_number),))
    }

    #[inline(always)]
    fn get_budokan_token_metadata(self: @Store, pass_id: u64) -> TokenMetadata {
        (self.world.read_model(pass_id))
    }
    #[inline(always)]
    fn get_budokan_token_metadata_value(self: @Store, pass_id: u64) -> TokenMetadataValue {
        (self.world.read_value(pass_id))
    }


    //----------------------------------
    // Model Setters
    //

    // #[inline(always)]
    // fn set_player(ref self: Store, model: @Player) {
    //     self.world.write_model(model);
    // }

    // #[inline(always)]
    // fn set_pack(ref self: Store, model: @Pack) {
    //     self.world.write_model(model);
    // }

    // #[inline(always)]
    // fn set_challenge(ref self: Store, model: @Challenge) {
    //     self.world.write_model(model);
    // }

    // #[inline(always)]
    // fn set_round(ref self: Store, model: @Round) {
    //     self.world.write_model(model);
    // }

    // #[inline(always)]
    // fn set_duelist(ref self: Store, model: @Duelist) {
    //     self.world.write_model(model);
    // }

    // #[inline(always)]
    // fn set_duelist_challenge(ref self: Store, model: @DuelistAssignment) {
    //     self.world.write_model(model);
    // }

    // #[inline(always)]
    // fn set_duelist_memorial(ref self: Store, model: @DuelistMemorial) {
    //     self.world.write_model(model);
    // }

    // #[inline(always)]
    // fn set_pact(ref self: Store, model: @Pact) {
    //     self.world.write_model(model);
    // }
    // #[inline(always)]
    // fn delete_pact(ref self: Store, model: @Pact) {
    //     self.world.erase_model(model);
    // }

    // #[inline(always)]
    // fn set_scoreboard(ref self: Store, model: @SeasonScoreboard) {
    //     self.world.write_model(model);
    // }

    // #[inline(always)]
    // fn set_leaderboard(ref self: Store, model: @Leaderboard) {
    //     self.world.write_model(model);
    // }

    // #[inline(always)]
    // fn set_season_config(ref self: Store, model: @SeasonConfig) {
    //     self.world.write_model(model);
    // }

    // #[inline(always)]
    // fn set_coin_config(ref self: Store, model: @CoinConfig) {
    //     self.world.write_model(model);
    // }

    // #[inline(always)]
    // fn set_token_config(ref self: Store, model: @TokenConfig) {
    //     self.world.write_model(model);
    // }

    // #[inline(always)]
    // fn set_config(ref self: Store, model: @Config) {
    //     self.world.write_model(model);
    // }

    // #[inline(always)]
    // fn set_pool(ref self: Store, model: @Pool) {
    //     self.world.write_model(model);
    // }

    // #[inline(always)]
    // fn set_token_bound_address(ref self: Store, model: @TokenBoundAddress) {
    //     self.world.write_model(model);
    // }

    #[inline(always)]
    fn set_tournament_pass(ref self: Store, model: @TournamentPass) {
        self.world.write_model(model);
    }
    
    #[inline(always)]
    fn set_tournament_settings(ref self: Store, model: @TournamentSettings) {
        self.world.write_model(model);
    }

    #[inline(always)]
    fn set_tournament(ref self: Store, model: @Tournament) {
        self.world.write_model(model);
    }

    #[inline(always)]
    fn set_tournament_round(ref self: Store, model: @TournamentRound) {
        self.world.write_model(model);
    }

    // #[inline(always)]
    // fn set_challenge_to_tournament(ref self: Store, model: @ChallengeToTournament) {
    //     self.world.write_model(model);
    // }
    // #[inline(always)]
    // fn set_tournament_to_challenge(ref self: Store, model: @TournamentToChallenge) {
    //     self.world.write_model(model);
    // }

    //----------------------------------
    // Single member setters
    // https://book.dojoengine.org/framework/world/api#read_member-and-read_member_of_models
    // https://book.dojoengine.org/framework/world/api#write_member-and-write_member_of_models
    //

    // #[inline(always)]
    // fn get_current_season_id(self: @Store) -> u32 {
    //     (self.world.read_member(Model::<Config>::ptr_from_keys(CONFIG::CONFIG_KEY), selector!("current_season_id")))
    // }
    // #[inline(always)]
    // fn get_config_lords_address(self: @Store) -> ContractAddress {
    //     (self.world.read_member(Model::<Config>::ptr_from_keys(CONFIG::CONFIG_KEY), selector!("lords_address")))
    // }
    // #[inline(always)]
    // fn get_config_vrf_address(self: @Store) -> ContractAddress {
    //     (self.world.read_member(Model::<Config>::ptr_from_keys(CONFIG::CONFIG_KEY), selector!("vrf_address")))
    // }
    // #[inline(always)]
    // fn get_config_treasury_address(self: @Store) -> ContractAddress {
    //     (self.world.read_member(Model::<Config>::ptr_from_keys(CONFIG::CONFIG_KEY), selector!("treasury_address")))
    // }

    // #[inline(always)]
    // fn get_current_season_rules(self: @Store) -> Rules {
    //     (self.get_season_rules(self.get_current_season_id()))
    // }
    // #[inline(always)]
    // fn get_season_rules(self: @Store, season_id: u32) -> Rules {
    //     (self.world.read_member(Model::<SeasonConfig>::ptr_from_keys(season_id), selector!("rules")))
    // }

    // #[inline(always)]
    // fn get_tournament_settings_rules(self: @Store, settings_id: u32) -> TournamentRules {
    //     let tournament_type: TournamentType = self.world.read_member(Model::<TournamentSettings>::ptr_from_keys(settings_id), selector!("tournament_type"));
    //     (tournament_type.rules())
    // }
    #[inline(always)]
    fn get_tournament_pass_minter_address(self: @Store, pass_id: u64) -> ContractAddress {
        (self.world.read_member(Model::<TokenMetadata>::ptr_from_keys(pass_id), selector!("minted_by")))
    }
    // #[inline(always)]
    // fn get_tournament_duel_id(self: @Store, keys: @TournamentDuelKeys) -> u128 {
    //     (self.world.read_member(Model::<TournamentToChallenge>::ptr_from_keys(*keys), selector!("duel_id")))
    // }
    // #[inline(always)]
    // fn get_duel_tournament_keys(self: @Store, duel_id: u128) -> TournamentDuelKeys {
    //     (self.world.read_member(Model::<ChallengeToTournament>::ptr_from_keys(duel_id), selector!("keys")))
    // }

    // // setters

    // #[inline(always)]
    // fn set_config_is_paused(ref self: Store, is_paused: bool) {
    //     self.world.write_member(Model::<Config>::ptr_from_keys(CONFIG::CONFIG_KEY), selector!("is_paused"), is_paused);
    // }
    // #[inline(always)]
    // fn set_config_season_id(ref self: Store, season_id: u32) {
    //     self.world.write_member(Model::<Config>::ptr_from_keys(CONFIG::CONFIG_KEY), selector!("current_season_id"), season_id);
    // }
    // #[inline(always)]
    // fn set_config_treasury_address(ref self: Store, treasury_address: ContractAddress) {
    //     self.world.write_member(Model::<Config>::ptr_from_keys(CONFIG::CONFIG_KEY), selector!("treasury_address"), treasury_address);
    // }

    // #[inline(always)]
    // fn set_duelist_timestamp_active(ref self: Store, duelist_id: u128, current_timestamp: u64) {
    //     let model_ptr: ModelPtr<Duelist> = Model::<Duelist>::ptr_from_keys(duelist_id);
    //     let mut timestamps: DuelistTimestamps = self.world.read_member(model_ptr, selector!("timestamps"));
    //     timestamps.active = current_timestamp;
    //     self.world.write_member(model_ptr, selector!("timestamps"), timestamps);
    // }


    // //----------------------------------
    // // Emitters
    // //

    // #[inline(always)]
    // fn emit_challenge_reply_action(ref self: Store, challenge: @Challenge, reply_required: bool) {
    //     if ((*challenge.address_b).is_non_zero()) {
    //         // duelist is challenger (just to be unique)
    //         self.emit_call_to_action(*challenge.address_b, *challenge.duelist_id_a,
    //             if (reply_required) {*challenge.duel_id} else {0},
    //             reply_required);
    //     }
    // }
    // #[inline(always)]
    // fn emit_challenge_action(ref self: Store, challenge: @Challenge, duelist_number: u8, call_to_action: bool) {
    //     if (duelist_number == 1) {
    //         self.emit_call_to_action(*challenge.address_a, *challenge.duelist_id_a, *challenge.duel_id, call_to_action);
    //     } else if (duelist_number == 2) {
    //         self.emit_call_to_action(*challenge.address_b, *challenge.duelist_id_b, *challenge.duel_id, call_to_action);
    //     }
    // }
    // #[inline(always)]
    // fn emit_clear_challenge_action(ref self: Store, challenge: @Challenge, duelist_number: u8) {
    //     if (duelist_number == 1) {
    //         self.emit_call_to_action(*challenge.address_a, *challenge.duelist_id_a, 0, false);
    //     } else if (duelist_number == 2) {
    //         self.emit_call_to_action(*challenge.address_b, *challenge.duelist_id_b, 0, false);
    //     }
    // }
    // #[inline(always)]
    // fn emit_call_to_action(ref self: Store, player_address: ContractAddress, duelist_id: u128, duel_id: u128, call_to_action: bool) {
    //     self.world.emit_event(@CallToActionEvent{
    //         player_address,
    //         duelist_id,
    //         duel_id,
    //         call_to_action,
    //         timestamp: if (duel_id.is_non_zero()) {starknet::get_block_timestamp()} else {0},
    //     });
    // }

    // #[inline(always)]
    // fn emit_challenge_rewards(ref self: Store, duel_id: u128, duelist_id: u128, rewards: RewardValues) {
    //     if (duelist_id.is_non_zero()) {
    //         self.world.emit_event(@ChallengeRewardsEvent{
    //             duel_id,
    //             duelist_id,
    //             rewards,
    //         });
    //     }
    // }

    // #[inline(always)]
    // fn emit_lords_release(ref self: Store, season_id: u32, duel_id: u128, bill: @LordsReleaseBill) {
    //     self.world.emit_event(@LordsReleaseEvent {
    //         season_id,
    //         duel_id,
    //         bill: *bill,
    //         timestamp: starknet::get_block_timestamp(),
    //     });
    // }

    //--------------------------
    // dispatchers
    //

    #[inline(always)]
    fn budokan_dispatcher_from_pass_id(self: @Store, pass_id: u64) -> ITournamentDispatcher {
        (ITournamentDispatcher{ contract_address: self.get_tournament_pass_minter_address(pass_id) })
    }

}
