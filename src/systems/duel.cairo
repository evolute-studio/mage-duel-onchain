use starknet::{ContractAddress};
use dojo::world::IWorldDispatcher;
use evolute_duel::models::challenge::{DuelType};
use evolute_duel::models::tournament::{TournamentRules};
use evolute_duel::types::challenge_state::{ChallengeState};

#[starknet::interface]
pub trait IDuel<TState> {
    // IWorldProvider
    fn world_dispatcher(self: @TState) -> IWorldDispatcher;

    // IDuelTokenPublic
    fn get_pact(self: @TState, duel_type: DuelType, address_a: ContractAddress, address_b: ContractAddress) -> u128;
    fn has_pact(self: @TState, duel_type: DuelType, address_a: ContractAddress, address_b: ContractAddress) -> bool;
    fn create_duel(ref self: TState, duel_type: DuelType, duelist_id: u128, challenged_address: ContractAddress, lives_staked: u8, expire_hours: u64, message: ByteArray) -> u128;
    fn reply_duel(ref self: TState, duel_id: u128, duelist_id: u128, accepted: bool) -> ChallengeState;
}

// Exposed to clients
#[starknet::interface]
pub trait IDuelPublic<TState> {
    // view
    fn get_pact(self: @TState, duel_type: DuelType, address_a: ContractAddress, address_b: ContractAddress) -> u128;
    fn has_pact(self: @TState, duel_type: DuelType, address_a: ContractAddress, address_b: ContractAddress) -> bool;
    // write
    fn create_duel( //@description: Create a Duel
        ref self: TState,
        duel_type: DuelType,
        challenged_address: ContractAddress,
        lives_staked: u8,
        expire_hours: u64,
    ) -> u128;
    fn reply_duel( //@description: Reply to a Duel (accept or reject)
        ref self: TState,
        duel_id: u128,
        accepted: bool,
    ) -> ChallengeState;
}

// Exposed to world
#[starknet::interface]
pub trait IDuelProtected<TState> {
    // fn transfer_to_winner(ref self: TState, duel_id: u128);
    fn join_tournament_duel(
        ref self: TState,
        player_address: ContractAddress,
        tournament_id: u64,
        round_number: u8,
        entry_number: u8,
        opponent_entry_number: u8,
        rules: TournamentRules,
        timestamp_end: u64,
    ) -> u128;
}

#[dojo::contract]
pub mod duel {    
    use core::num::traits::Zero;
    use starknet::{ContractAddress};
    use dojo::world::{WorldStorage};

    #[storage]
    struct Storage {
        id_generator: u128,
    }

    use evolute_duel::interfaces::dns::{
        DnsTrait,
        IGameDispatcherTrait,
    };
    use evolute_duel::models::{
        player::{PlayerTrait},
        challenge::{Challenge,ChallengeValue, DuelType, ChallengeTrait},
        pact::{PactTrait},
        tournament::{
            TournamentDuelKeys, TournamentDuelKeysTrait,
            TournamentRules,
            ChallengeToTournament, TournamentToChallenge,
        },
    };
    use evolute_duel::types::{
        challenge_state::{ChallengeState, ChallengeStateTrait},
        timestamp::{Period, PeriodTrait, TimestampTrait, TIMESTAMP},
        constants::{METADATA},
    };
    use evolute_duel::libs::store::{Store, StoreTrait};
    use evolute_duel::utils::short_string::{ShortStringTrait};
    use evolute_duel::utils::misc::{ZERO, ContractAddressIntoU256};
    use evolute_duel::utils::math::{MathTrait};

    use evolute_duel::types::errors::duel::{Errors};

    use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    // use tournaments::components::{
    //     models::lifecycle::{Lifecycle},
    //     libs::lifecycle::{LifecycleTrait},
    // };
    // use graffiti::url::{UrlImpl};

     

    //*******************************
    fn TOKEN_NAME()   -> ByteArray {("Pistols at Dawn Duels")}
    fn TOKEN_SYMBOL() -> ByteArray {("DUEL")}
    //*******************************

    fn dojo_init(
        ref self: ContractState,
    ) {
        self.id_generator.write(1);
    }

    #[generate_trait]
    impl WorldDefaultImpl of WorldDefaultTrait {
        #[inline(always)]
        fn world_default(self: @ContractState) -> WorldStorage {
            (self.world(@"evolute_duel"))
        }
    }


    //-----------------------------------
    // Public
    //
    #[abi(embed_v0)]
    impl DuelPublicImpl of super::IDuelPublic<ContractState> {

        //-----------------------------------
        // View calls
        //
        fn get_pact(self: @ContractState, duel_type: DuelType, address_a: ContractAddress, address_b: ContractAddress) -> u128 {
            let mut store: Store = StoreTrait::new(self.world_default());
            (store.get_pact(duel_type, address_a.into(), address_b.into()).duel_id)
        }
        fn has_pact(self: @ContractState, duel_type: DuelType, address_a: ContractAddress, address_b: ContractAddress) -> bool {
            let mut store: Store = StoreTrait::new(self.world_default());
            (store.get_pact(duel_type, address_a.into(), address_b.into()).duel_id != 0)
        }

        //-----------------------------------
        // Write calls
        //
        fn create_duel(
            ref self: ContractState,
            duel_type: DuelType,
            challenged_address: ContractAddress,
            lives_staked: u8,
            expire_hours: u64,
        ) -> u128 {
            let mut store: Store = StoreTrait::new(self.world_default());

            // mint to game, so it can transfer to winner
            let duel_id: u128 = self._next_duel_id();

            // validate duelist ownership
            let address_a: ContractAddress = starknet::get_caller_address();

            // validate duelist health
// println!("poke A... {}", duelist_id_a);
            // validate challenged
            let address_b: ContractAddress = challenged_address;
            // assert(address_b.is_non_zero(), Errors::INVALID_CHALLENGED); // allow open challenge
            assert(address_b != address_a, Errors::INVALID_CHALLENGED_SELF);

            // validate duel type
            match duel_type {
                DuelType::Regular => {}, // ok!
                DuelType::Undefined | 
                DuelType::Tournament => {
                    // create tutorials with the tutorial contact only
                    assert(false, Errors::INVALID_DUEL_TYPE);
                },
            };

            // assert duelist is not in a challenge
            store.enter_challenge(address_a, duel_id);

            // calc expiration
            let timestamp: u64 = starknet::get_block_timestamp();
            let timestamps = Period {
                start: timestamp,
                end: timestamp + 
                    if (expire_hours == 0) {TIMESTAMP::ONE_DAY}
                    else {TimestampTrait::from_hours(expire_hours)},
            };

            // create challenge
            let challenge = Challenge {
                duel_id,
                duel_type,
                // duelists
                address_a,
                address_b,
                // progress
                state: ChallengeState::Awaiting,
                winner: 0,
                // timestamps
                timestamps,
            };

            // // create Round, ready for player A to commit
            // let mut round = Round {
            //     duel_id: challenge.duel_id,
            //     state: RoundState::Commit,
            //     moves_a: Default::default(),
            //     moves_b: Default::default(),
            //     state_a: Default::default(),
            //     state_b: Default::default(),
            //     final_blow: Default::default(),
            // };

            // save!
            store.set_challenge(@challenge);
            // store.set_round(@round);

            // set the pact + assert it does not exist
            if (address_b.is_non_zero()) {
                challenge.set_pact(ref store);
            }


            //TODO emit events
            // // Duelist 1 is ready to commit
            // store.emit_challenge_action(@challenge, 1, true);
            // // Duelist 2 has to reply
            // store.emit_challenge_reply_action(@challenge, true);

            // events
            // PlayerTrait::check_in(ref store, Activity::ChallengeCreated, address_a, duel_id.into());

            (duel_id)
        }
        
        fn reply_duel(ref self: ContractState,
            duel_id: u128,
            accepted: bool,
        ) -> ChallengeState {
            let mut store: Store = StoreTrait::new(self.world_default());
            
            // validate chalenge
            let mut challenge: Challenge = store.get_challenge(duel_id);
            assert(challenge.exists(), Errors::INVALID_CHALLENGE);
            assert(challenge.state == ChallengeState::Awaiting, Errors::CHALLENGE_NOT_AWAITING);

            let address_b: ContractAddress = starknet::get_caller_address();
            let timestamp: u64 = starknet::get_block_timestamp();

            if (challenge.timestamps.has_expired()) {
                // Expired, close it!
                challenge.state = ChallengeState::Expired;
            } else if (address_b == challenge.address_a) {
                // same duelist, can only withdraw...
                assert(accepted == false, Errors::INVALID_REPLY_SELF);
                challenge.state = ChallengeState::Withdrawn;
            } else {
                // open challenge: anyone can ACCEPT
                if (challenge.address_b.is_zero() && accepted) {
                    challenge.address_b = address_b;
                    // set the pact + assert it does not exist
                    challenge.set_pact(ref store);
                } else {
                    // else, only challenged can reply
                    assert(challenge.address_b == address_b, Errors::NOT_YOUR_CHALLENGE);
                }

                // Challenged is accepting...
                if (accepted) {
                    // validate duelist
                    assert(address_b != challenge.address_b, Errors::INVALID_CHALLENGED_SELF);

                    // assert duelist is not in a challenge
                    store.enter_challenge(address_b, duel_id);

                    // // Duelist 2 can commit
                    // store.emit_challenge_action(@challenge, 2, true);

                    // update timestamps
                    challenge.state = ChallengeState::InProgress;
                    challenge.timestamps.start = timestamp;
                    challenge.timestamps.end = 0;

                    // // set reply timeouts
                    // let mut round: Round = store.get_round(duel_id);
                    // round.set_commit_timeout(store.get_current_season_rules(), timestamp);
                    // store.set_round(@round);
                } else {
                    // Challenged is Refusing
                    challenge.state = ChallengeState::Refused;
                }
            }

            // // replied
            // store.emit_challenge_reply_action(@challenge, false);

            // duel canceled!
            if (challenge.state.is_canceled()) {
                challenge.timestamps.end = timestamp;
                challenge.unset_pact(ref store);
                store.exit_challenge(challenge.address_a);
                // store.emit_clear_challenge_action(@challenge, 1);
                // store.emit_clear_challenge_action(@challenge, 2);
                // Activity::ChallengeCanceled.emit(ref store.world, starknet::get_caller_address(), challenge.duel_id.into());
            } else {
                // PlayerTrait::check_in(ref store, Activity::ChallengeReplied, address_b, duel_id.into());
            }
            
            // update challenge
            store.set_challenge(@challenge);

            (challenge.state)
        }
    }

    
    //-----------------------------------
    // Protected
    //
    #[abi(embed_v0)]
    impl DuelProtectedImpl of super::IDuelProtected<ContractState> {
        // fn transfer_to_winner(ref self: ContractState,
        //     duel_id: u128,
        // ) {
        //     let mut store: Store = StoreTrait::new(self.world_default());
        //     assert(store.world.caller_is_world_contract(), Errors::INVALID_CALLER);

        //     let challenge: ChallengeValue = store.get_challenge_value(duel_id);
        //     let owner: ContractAddress = store.world.game_address();
        //     if (challenge.winner == 1) {
        //         self.transfer_from(owner, challenge.address_a, duel_id.into());
        //     } else if (challenge.winner == 2) {
        //         self.transfer_from(owner, challenge.address_b, duel_id.into());
        //     }
        // }

        fn join_tournament_duel(
            ref self: ContractState,
            player_address: ContractAddress,
            tournament_id: u64,
            round_number: u8,
            entry_number: u8,
            opponent_entry_number: u8,
            rules: TournamentRules,
            timestamp_end: u64,
        ) -> u128 {
            let mut store: Store = StoreTrait::new(self.world_default());
            assert(store.world.caller_is_tournament_contract(), Errors::INVALID_CALLER);

            // check if duel is minted
            let keys: @TournamentDuelKeys = TournamentDuelKeysTrait::new(
                tournament_id,
                round_number,
                entry_number,
                opponent_entry_number,
            );
            let mut duel_id: u128 = store.get_tournament_duel_id(keys);
            let duelist_number: u8 = if (entry_number == *keys.entry_number_a) {1} else {2};
            
            //-----------------------------------
            // NEW DUEL
            //
            if (duel_id.is_zero()) {
                // mint to game, so it can transfer to winner
                duel_id = self._next_duel_id();

                // create challenge
                let timestamp: u64 = starknet::get_block_timestamp();
                let challenge = Challenge {
                    duel_id,
                    duel_type: DuelType::Tournament,
                    // duelists
                    address_a: if (duelist_number == 1) {player_address} else {ZERO()},
                    address_b: if (duelist_number == 2) {player_address} else {ZERO()},
                    // progress
                    state: ChallengeState::Awaiting,
                    winner: 0,
                    // timestamps
                    timestamps: Period {
                        start: timestamp,
                        end: timestamp_end,
                    },
                };
// println!("player_address: {:x}", player_address);
// println!("duelist_id: {}", duelist_id);
// println!("entry_number: {}", entry_number);
// println!("opponent_entry_number: {}", opponent_entry_number);
// println!("duelist_number: {}", duelist_number);
// println!("challenge.address_a: {:x}", challenge.address_a);
// println!("challenge.address_b: {:x}", challenge.address_b);
// println!("challenge.duelist_id_a: {}", challenge.duelist_id_a);
// println!("challenge.duelist_id_b: {}", challenge.duelist_id_b);

                // create Round, ready for player A to commit
                // let mut round = Round {
                //     duel_id: challenge.duel_id,
                //     state: RoundState::Commit,
                //     moves_a: Default::default(),
                //     moves_b: Default::default(),
                //     state_a: Default::default(),
                //     state_b: Default::default(),
                //     final_blow: Default::default(),
                // };
                // round.set_commit_timeout(store.get_current_season_rules(), timestamp);

                // save!
                store.set_challenge(@challenge);
                // store.set_round(@round);

                // tournament links
                store.set_challenge_to_tournament(@ChallengeToTournament {
                    duel_id,
                    keys: *keys,
                });
                store.set_tournament_to_challenge(@TournamentToChallenge {
                    keys: *keys,
                    duel_id,
                });

                if (keys.entry_number_b.is_zero()) {
                    // no opponent! declare winner
                    // collect rewards for this player
                    // TODO: collect rewards
                    // store.world.game_dispatcher().collect_duel(duel_id);
                } else {
                    // assert duelist is not in a challenge
                    store.enter_challenge(player_address, duel_id);
                    // // Duelist 1 is ready to commit
                    // store.emit_challenge_action(@challenge, duelist_number, true);
                    // events
                    // PlayerTrait::check_in(ref store, Activity::ChallengeCreated, player_address, duel_id.into());
                }
            }
            //-----------------------------------
            // EXISTING DUEL
            //
            else {
                let mut challenge: Challenge = store.get_challenge(duel_id);
                assert(challenge.exists(), Errors::INVALID_CHALLENGE);
                assert(challenge.state == ChallengeState::Awaiting, Errors::CHALLENGE_NOT_AWAITING);

                if (duelist_number == 1) {
                    assert(*keys.entry_number_a == entry_number, Errors::NOT_YOUR_CHALLENGE);
                    assert(challenge.address_a.is_zero(), Errors::INVALID_REPLY_SELF);
                    challenge.address_a = player_address;
                } else {
                    assert(*keys.entry_number_b == entry_number, Errors::NOT_YOUR_CHALLENGE);
                    assert(challenge.address_b.is_zero(), Errors::INVALID_REPLY_SELF);
                    challenge.address_b = player_address;
                }

                if (challenge.timestamps.has_expired()) {
                    // Expired, close it!
                    challenge.state = ChallengeState::Expired;
                } else {
                    // game on!
                    challenge.state = ChallengeState::InProgress;
                }

                // save!
                store.set_challenge(@challenge);

                // assert duelist is not in a challenge
                store.enter_challenge(player_address, duel_id);

                // // Duelist 2 can commit
                // store.emit_challenge_action(@challenge, duelist_number, true);

                // events
                // PlayerTrait::check_in(ref store, Activity::ChallengeReplied, player_address, duel_id.into());
            };

            (duel_id)
        }
    }

    //------------------------------------
    // Internal calls
    //
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _next_duel_id(ref self: ContractState) -> u128 {
            let mut id_generator: u128 = self.id_generator.read();
            let duel_id: u128 = id_generator;
            id_generator += 1;
            self.id_generator.write(id_generator);
            (duel_id)
        }
    }
}
