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
        Player, PlayerValue,
        PlayerAssignment, PlayerAssignmentValue,
    },
    skins::{
        Shop, ShopValue,
    },
    game::{
        Board, BoardValue, Game, GameValue, 
        Move, MoveValue, Rules, RulesValue,
        // Snapshot, SnapshotValue
    },
    tournament::{
        Tournament, TournamentValue,
        TournamentPass, TournamentPassValue,
        TournamentSettings, TournamentSettingsValue,
        TournamentChallenge,
        TournamentType,
        TournamentRules,
        TournamentState,
        TournamentTypeTrait
    },
    // config::{
    //     CONFIG,
    //     Config, ConfigValue,
    //     TokenConfig, TokenConfigValue,
    // },
    // challenge::{
    //     Challenge, ChallengeValue, DuelType,
    // },
    pact::{
        Pact, PactTrait, PactValue,
    },
    scoreboard::{Scoreboard},
    registration::{Registration}
};
pub use evolute_duel::events::{
    GameStarted, GameCanceled, GameFinished, GameCreated,
    // GameCreateFailed, GameIsAlreadyFinished, GameJoinFailed, BoardCreatedFromSnapshot,
    // BoardCreated, 
    BoardUpdated, CityContestWon, RoadContestWon,
    CityContestDraw, RoadContestDraw, SnapshotCreated, SnapshotCreateFailed
};
pub use evolute_duel::types::packing::{
    PlayerSide, GameState, GameStatus, GameMode,
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
    fn new(world: WorldStorage) -> Store {
        (Store { world })
    }

    //----------------------------------
    // Model Getters
    //

    fn get_player(self: @Store, address: ContractAddress) -> Player {
        (self.world.read_model(address))
    }
    fn get_player_value(self: @Store, address: ContractAddress) -> PlayerValue {
        (self.world.read_value(address))
    }

    fn get_shop(self: @Store, id: felt252) -> Shop {
        (self.world.read_model(id))
    }

    fn get_shop_value(self: @Store, id: felt252) -> ShopValue {
        (self.world.read_value(id))
    }
    

    fn get_tournament_pass(self: @Store, pass_id: u64) -> TournamentPass {
        (self.world.read_model(pass_id))
    }
    fn get_tournament_pass_value(self: @Store, pass_id: u64) -> TournamentPassValue {
        (self.world.read_value(pass_id))
    }

    fn get_tournament_settings(self: @Store, settings_id: u32) -> TournamentSettings {
        (self.world.read_model(settings_id))
    }
    fn get_tournament_settings_value(self: @Store, settings_id: u32) -> TournamentSettingsValue {
        (self.world.read_value(settings_id))
    }

    fn get_tournament(self: @Store, tournament_id: u64) -> Tournament {
        (self.world.read_model(tournament_id))
    }
    fn get_tournament_value(self: @Store, tournament_id: u64) -> TournamentValue {
        (self.world.read_value(tournament_id))
    }


    fn get_budokan_token_metadata(self: @Store, pass_id: u64) -> TokenMetadata {
        (self.world.read_model(pass_id))
    }
    fn get_budokan_token_metadata_value(self: @Store, pass_id: u64) -> TokenMetadataValue {
        (self.world.read_value(pass_id))
    }

    fn get_player_challenge(self: @Store, player_address: ContractAddress) -> PlayerAssignment {
        (self.world.read_model(player_address))
    }
    fn get_player_challenge_value(self: @Store, player_address: ContractAddress) -> PlayerAssignmentValue {
        (self.world.read_value(player_address))
    }

    // #[inline(always)]
    // fn get_challenge(self: @Store, duel_id: felt252) -> Challenge {
    //     (self.world.read_model(duel_id))
    // }


    fn get_board(self: @Store, duel_id: felt252) -> Board {
        (self.world.read_model(duel_id))
    }
    // #[inline(always)]
    // fn get_round(self: @Store, duel_id: felt252) -> Round {
    //     (self.world.read_model(duel_id))
    // }
    // #[inline(always)]
    // fn get_round_value(self: @Store, duel_id: felt252) -> RoundValue {
    //     (self.world.read_value(duel_id))
    // }

    // #[inline(always)]
    // fn get_pact(self: @Store, duel_type: DuelType, a: u256, b: u256) -> Pact {
    //     let pair: u128 = PactTrait::make_pair(a, b);
    //     (self.world.read_model((duel_type, pair),))
    // }

    fn get_rules(self: @Store) -> Rules {
        (self.world.read_model(0))
    }

    fn get_move(self: @Store, move_id: felt252) -> Move {
        (self.world.read_model(move_id))
    }

    // #[inline(always)]
    // fn get_city_node(self: @Store, board_id: felt252, position: u8) -> CityNode {
    //     (self.world.read_model((board_id, position)))
    // }
    // #[inline(always)]
    // fn get_road_node(self: @Store, board_id: felt252, position: u8) -> RoadNode {
    //     (self.world.read_model((board_id, position)))
    // }
    // #[inline(always)]
    // fn get_potential_city_contests(self: @Store, board_id: felt252) -> PotentialCityContests {
    //     (self.world.read_model(board_id))
    // }
    // #[inline(always)]
    // fn get_potential_road_contests(self: @Store, board_id: felt252) -> PotentialRoadContests {
    //     (self.world.read_model(board_id))
    // }

    // #[inline(always)]
    // fn get_snapshot(self: @Store, duel_id: felt252) -> Snapshot {
    //     (self.world.read_model(duel_id))
    // }
    
    fn get_scoreboard(self: @Store, tournament_id: u64, player_address: ContractAddress) -> Scoreboard {
        (self.world.read_model((tournament_id, player_address)))
    }

    fn get_registration(self: @Store, tournament_id: u64, player_address: ContractAddress) -> Registration {
        (self.world.read_model((tournament_id, player_address)))
    }
    
    //----------------------------------
    // Model Setters
    //

    fn set_rules(ref self: Store, model: @Rules) {
        self.world.write_model(model);
    }

    fn set_player(ref self: Store, model: @Player) {
        self.world.write_model(model);
    }

    // #[inline(always)]
    // fn set_pack(ref self: Store, model: @Pack) {
    //     self.world.write_model(model);
    // }

    // #[inline(always)]
    // fn set_challenge(ref self: Store, model: @Challenge) {
    //     self.world.write_model(model);
    // }

    fn set_board(ref self: Store, model: @Board) {
        self.world.write_model(model);
    }

    // #[inline(always)]
    // fn set_round(ref self: Store, model: @Round) {
    //     self.world.write_model(model);
    // }

    // #[inline(always)]
    // fn set_duelist(ref self: Store, model: @Duelist) {
    //     self.world.write_model(model);
    // }

    fn set_player_challenge(ref self: Store, model: @PlayerAssignment) {
        self.world.write_model(model);
    }

    // #[inline(always)]
    // fn set_duelist_memorial(ref self: Store, model: @DuelistMemorial) {
    //     self.world.write_model(model);
    // }

    fn set_pact(ref self: Store, model: @Pact) {
        self.world.write_model(model);
    }
    fn delete_pact(ref self: Store, model: @Pact) {
        self.world.erase_model(model);
    }

    // #[inline(always)]
    // fn set_city_node(ref self: Store, model: @CityNode) {
    //     self.world.write_model(model);
    // }
    // #[inline(always)]
    // fn set_road_node(ref self: Store, model: @RoadNode) {
    //     self.world.write_model(model);
    // }
    // #[inline(always)]  
    // fn set_potential_city_contests(ref self: Store, model: @PotentialCityContests) {
    //     self.world.write_model(model);
    // }
    // #[inline(always)]
    // fn set_potential_road_contests(ref self: Store, model: @PotentialRoadContests) {
    //     self.world.write_model(model);
    // }
    // #[inline(always)]
    // fn set_snapshot(ref self: Store, model: @Snapshot) {
    //     self.world.write_model(model);
    // }

    fn set_scoreboard(ref self: Store, model: @Scoreboard) {
        self.world.write_model(model);
    }

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

    fn set_tournament_pass(ref self: Store, model: @TournamentPass) {
        self.world.write_model(model);
    }
    
    fn set_tournament_settings(ref self: Store, model: @TournamentSettings) {
        self.world.write_model(model);
    }

    fn set_tournament(ref self: Store, model: @Tournament) {
        self.world.write_model(model);
    }

    fn set_tournament_challenge(ref self: Store, model: @TournamentChallenge) {
        self.world.write_model(model);
    }
    fn set_move(ref self: Store, model: @Move) {
        self.world.write_model(model);
    }


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

    fn get_tournament_settings_rules(self: @Store, settings_id: u32) -> TournamentRules {
        let tournament_type: TournamentType = self.world.read_member(Model::<TournamentSettings>::ptr_from_keys(settings_id), selector!("tournament_type"));
        (tournament_type.rules())
    }
    fn get_tournament_pass_minter_address(self: @Store, pass_id: u64) -> ContractAddress {
        (self.world.read_member(Model::<TokenMetadata>::ptr_from_keys(pass_id), selector!("minted_by")))
    }
    fn get_tournament_challenge(self: @Store, challenge_id: felt252) -> TournamentChallenge {
        (self.world.read_model(challenge_id))
    }

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

    fn set_board_initial_state(ref self: Store, duel_id: felt252, initial_state: Array<u8>) {
        self.world.write_member(Model::<Board>::ptr_from_keys(duel_id), selector!("initial_edge_state"), initial_state);
    }
    
    fn set_board_available_tiles_in_deck (ref self: Store, duel_id: felt252, available_tiles_in_deck: Array<u8>) {
        self.world.write_member(Model::<Board>::ptr_from_keys(duel_id), selector!("available_tiles_in_deck"), available_tiles_in_deck);
    }
    fn set_board_top_tile(ref self: Store, duel_id: felt252, top_tile: Option<u8>) {
        self.world.write_member(Model::<Board>::ptr_from_keys(duel_id), selector!("top_tile"), top_tile);
    }

    fn set_board_state(ref self: Store, duel_id: felt252, state: Array<(u8, u8, u8)>) {
        self.world.write_member(Model::<Board>::ptr_from_keys(duel_id), selector!("state"), state);
    }
    fn set_board_player1(ref self: Store, duel_id: felt252, player1: (ContractAddress, PlayerSide, u8)) {
        self.world.write_member(Model::<Board>::ptr_from_keys(duel_id), selector!("player1"), player1);
    }
    fn set_board_player2(ref self: Store, duel_id: felt252, player2: (ContractAddress, PlayerSide, u8)) {
        self.world.write_member(Model::<Board>::ptr_from_keys(duel_id), selector!("player2"), player2);
    }
    fn set_board_blue_score(ref self: Store, duel_id: felt252, blue_score: (u16, u16)) {
        self.world.write_member(Model::<Board>::ptr_from_keys(duel_id), selector!("blue_score"), blue_score);
    }
    fn set_board_red_score(ref self: Store, duel_id: felt252, red_score: (u16, u16)) {
        self.world.write_member(Model::<Board>::ptr_from_keys(duel_id), selector!("red_score"), red_score);
    }
    fn set_board_last_move_id(ref self: Store, duel_id: felt252, last_move_id: Option<felt252>) {
        self.world.write_member(Model::<Board>::ptr_from_keys(duel_id), selector!("last_move_id"), last_move_id);
    }
    fn set_board_game_state(ref self: Store, duel_id: felt252, game_state: GameState) {
        self.world.write_member(Model::<Board>::ptr_from_keys(duel_id), selector!("game_state"), game_state);
    }
    fn set_board_last_move(ref self: Store, duel_id: felt252, last_move: Option<felt252>) {
        self.world.write_member(Model::<Board>::ptr_from_keys(duel_id), selector!("last_move"), last_move);
    }

    // //----------------------------------
    // // Emitters
    // //

    fn emit_game_created(ref self: Store, host_player: ContractAddress, status: GameStatus) {
        self.world.emit_event(@GameCreated {
            host_player,
            status,
        });
    }

    // #[inline(always)]
    // fn emit_board_created(ref self: Store, board: Board) {
    //     self.world.emit_event(@BoardCreated {
    //         board_id: board.id,
    //         initial_edge_state: board.initial_edge_state,
    //         top_tile: board.top_tile,
    //         state: board.state,
    //         player1: board.player1,
    //         player2: board.player2,
    //         blue_score: board.blue_score,
    //         red_score: board.red_score,
    //         last_move_id: board.last_move_id,
    //         game_state: board.game_state,
    //     });
    // }

    // #[inline(always)]
    // fn emit_board_created_from_snapshot(ref self: Store, board: Board, old_board_id: felt252, move_number: u8) {
    //     self.world.emit_event(@BoardCreatedFromSnapshot {
    //         board_id: board.id,
    //         old_board_id,
    //         move_number,
    //         initial_edge_state: board.initial_edge_state,
    //         available_tiles_in_deck: board.available_tiles_in_deck,
    //         top_tile: board.top_tile,
    //         state: board.state,
    //         player1: board.player1,
    //         player2: board.player2,
    //         blue_score: board.blue_score,
    //         red_score: board.red_score,
    //         last_move_id: board.last_move_id,
    //         game_state: board.game_state,
    //     });
    // }

    fn emit_board_updated(ref self: Store, board: Board) {
        self.world.emit_event(@BoardUpdated {
            board_id: board.id,
            top_tile: board.top_tile,
            player1: board.player1,
            player2: board.player2,
            blue_score: board.blue_score,
            red_score: board.red_score,
            last_move_id: board.last_move_id,
            moves_done: 0, // TODO: track actual moves done
            game_state: board.game_state,
        });
    }

    fn emit_city_contest_won(ref self: Store, event: @CityContestWon) {
        self.world.emit_event(event);
    }

    fn emit_road_contest_won(ref self: Store, event: @RoadContestWon) {
        self.world.emit_event(event);
    }
    fn emit_city_contest_draw(ref self: Store, event: @CityContestDraw) {
        self.world.emit_event(event);
    }
    fn emit_road_contest_draw(ref self: Store, event: @RoadContestDraw) {
        self.world.emit_event(event);
    }

    // fn emit_snapshot_created(ref self: Store, snapshot: @Snapshot) {
    //     self.world.emit_event(@SnapshotCreated {
    //         snapshot_id: snapshot.snapshot_id,
    //         player: snapshot.player,
    //         board_id: snapshot.board_id,
    //         move_number: snapshot.move_number,
    //     });
    // }
    fn emit_snapshot_create_failed(ref self: Store, player: ContractAddress, board_id: felt252, board_game_state: GameState, move_number: u8) {
        self.world.emit_event(@SnapshotCreateFailed {
            player,
            board_id,
            board_game_state,
            move_number,
        });
    }

    fn emit_event<T, +dojo::event::storage::EventStorage::<dojo::world::storage::WorldStorage, T>> (ref self: Store, event: @T) {
        self.world.emit_event(event);
    }



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
}
