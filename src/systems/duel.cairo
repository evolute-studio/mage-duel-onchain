use starknet::{ContractAddress};
use dojo::world::IWorldDispatcher;
use evolute_duel::models::challenge::{DuelType};
use evolute_duel::types::challenge_state::{ChallengeState};

#[starknet::interface]
pub trait IDuel<TState> {
    // IWorldProvider
    fn world_dispatcher(self: @TState) -> IWorldDispatcher;

    // IDuelTokenPublic
    fn get_pact(self: @TState, duel_type: DuelType, address_a: ContractAddress, address_b: ContractAddress) -> felt252;
    fn has_pact(self: @TState, duel_type: DuelType, address_a: ContractAddress, address_b: ContractAddress) -> bool;
    fn create_duel(ref self: TState, duel_type: DuelType, challenged_address: ContractAddress) -> felt252;
    fn reply_duel(ref self: TState, duel_id: felt252, duelist_id: u128, accepted: bool) -> ChallengeState;
}

// Exposed to clients
#[starknet::interface]
pub trait IDuelPublic<TState> {
    // view
    fn get_pact(self: @TState, duel_type: DuelType, address_a: ContractAddress, address_b: ContractAddress) -> felt252;
    fn has_pact(self: @TState, duel_type: DuelType, address_a: ContractAddress, address_b: ContractAddress) -> bool;
    // write
    fn create_duel( //@description: Create a Duel
        ref self: TState,
        challenged_address: ContractAddress,
        tournament_id: u64,
        expire_hours: u64,
    ) -> felt252;
    fn create_duel_from_snapshot( //@description: Create a Duel from a snapshot
        ref self: TState,
        challenged_address: ContractAddress,
        expire_hours: u64,
        snapshot_id: felt252,
    ) -> felt252;
    fn cancel_duel( //@description: Cancel a Duel
        ref self: TState,
    ) -> ChallengeState;
    fn reply_duel( //@description: Reply to a Duel (accept or reject)
        ref self: TState,
        duel_id: felt252,
        accepted: bool,
    ) -> ChallengeState;


}

#[dojo::contract]
pub mod duel {    
    use core::num::traits::Zero;
    use starknet::{ContractAddress};
    use dojo::world::{WorldStorage};

    #[storage]
    struct Storage {
        id_generator: felt252,
    }
    use evolute_duel::models::{
        player::{PlayerTrait, PlayerAssignment},
        challenge::{Challenge, DuelType, ChallengeTrait},
        pact::{PactTrait},
        game::{Board, Snapshot,},
        registration::{Registration},
    };
    use evolute_duel::types::{
        challenge_state::{ChallengeState, ChallengeStateTrait},
        timestamp::{Period, PeriodTrait, TimestampTrait, TIMESTAMP},
    };
    use evolute_duel::libs::store::{Store, StoreTrait};
    use evolute_duel::utils::misc::{ContractAddressIntoU256};

    use evolute_duel::types::errors::duel::{Errors};

    use evolute_duel::systems::helpers::{
        board::{create_board, create_board_from_snapshot},
    };
    use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};


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
        fn get_pact(self: @ContractState, duel_type: DuelType, address_a: ContractAddress, address_b: ContractAddress) -> felt252 {
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
            challenged_address: ContractAddress,
            tournament_id: u64,
            expire_hours: u64,
        ) -> felt252 {
            let mut store: Store = StoreTrait::new(self.world_default());

            // mint to game, so it can transfer to winner
            let duel_id: felt252 = self._next_duel_id();

            // validate duelist ownership
            let address_a: ContractAddress = starknet::get_caller_address();

            // validate challenged
            let address_b: ContractAddress = challenged_address;
            // assert(address_b.is_non_zero(), Errors::INVALID_CHALLENGED); // allow open challenge
            assert(address_b != address_a, Errors::INVALID_CHALLENGED_SELF);

            let duel_type: DuelType = if tournament_id == 0 {
                DuelType::Regular
            } else {
                DuelType::Tournament
            };

            if tournament_id != 0 {
                let registration: Registration = store.get_registration(tournament_id, address_a);
                assert(registration.is_registered, Errors::NOT_REGISTERED); 
            }

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
            store.emit_game_created(
                duel_id.into(),
                address_a.into(),
                address_b.into(),
            );
            (duel_id)
        }

        fn cancel_duel(ref self: ContractState) -> ChallengeState {
            let mut store: Store = StoreTrait::new(self.world_default());
            let address_a: ContractAddress = starknet::get_caller_address();
            let duel_id: felt252 = store.get_player_challenge(address_a).duel_id;
            assert(duel_id != 0, Errors::NO_CALLENGE);

            // validate chalenge
            let mut challenge: Challenge = store.get_challenge(duel_id);
            assert(challenge.exists(), Errors::INVALID_CHALLENGE);
            assert(challenge.state == ChallengeState::Awaiting, Errors::CHALLENGE_NOT_AWAITING);

            // cancel it!
            challenge.state = ChallengeState::Refused;
            challenge.timestamps.end = starknet::get_block_timestamp();
            challenge.unset_pact(ref store);
            store.exit_challenge(address_a);

            // events
            // PlayerTrait::check_in(ref store, Activity::ChallengeCanceled, address_a, duel_id.into());

            // update challenge
            store.set_challenge(@challenge);

            (challenge.state)
        }

        fn create_duel_from_snapshot(
            ref self: ContractState,
            challenged_address: ContractAddress,
            expire_hours: u64,
            snapshot_id: felt252,
        ) -> felt252 {
             let mut store: Store = StoreTrait::new(self.world_default());

            // mint to game, so it can transfer to winner
            let duel_id: felt252 = self._next_duel_id();

            // validate duelist ownership
            let address_a: ContractAddress = starknet::get_caller_address();
            
            // validate challenged
            let address_b: ContractAddress = challenged_address;
            // assert(address_b.is_non_zero(), Errors::INVALID_CHALLENGED); // allow open challenge
            assert(address_b != address_a, Errors::INVALID_CHALLENGED_SELF);

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
                duel_type: DuelType::Regular,
                // duelists
                address_a,
                address_b,
                // progress
                state: ChallengeState::Awaiting,
                winner: 0,
                // timestamps
                timestamps,
            };

            let snapshot: Snapshot = store.get_snapshot(snapshot_id);
            let old_board_id = snapshot.board_id;
            let move_number = snapshot.move_number;

            create_board_from_snapshot(
                ref store, 
                old_board_id, 
                address_a, 
                address_b,
                move_number,
                duel_id,
            );

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
            store.emit_game_created(
                duel_id.into(),
                address_a.into(),
                address_b.into(),
            );
            (duel_id)

        }
        
        fn reply_duel(ref self: ContractState,
            duel_id: felt252,
            accepted: bool,
        ) -> ChallengeState {
            let mut store: Store = StoreTrait::new(self.world_default());
            
            // validate chalenge
            let mut challenge: Challenge = store.get_challenge(duel_id);
            assert(challenge.exists(), Errors::INVALID_CHALLENGE);
            assert(challenge.state == ChallengeState::Awaiting, Errors::CHALLENGE_NOT_AWAITING);

            let address_b: ContractAddress = starknet::get_caller_address();
            let timestamp: u64 = starknet::get_block_timestamp();

            let address_a_assignment: PlayerAssignment = store.get_player_challenge(challenge.address_a);

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
                    if (challenge.duel_type == DuelType::Tournament) {
                        // validate duelist
                        let registration: Registration = store.get_registration(address_a_assignment.tournament_id, address_b);
                        assert(registration.is_registered, Errors::NOT_REGISTERED); 
                    }
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
                    assert(address_b != challenge.address_a, Errors::INVALID_CHALLENGED_SELF);

                    // assert duelist is not in a challenge
                    store.enter_challenge(address_b, duel_id);

                    // // Duelist 2 can commit
                    // store.emit_challenge_action(@challenge, 2, true);

                    // update timestamps
                    challenge.state = ChallengeState::InProgress;
                    challenge.timestamps.start = timestamp;
                    challenge.timestamps.end = 0;

                    let board: Board = store.get_board(duel_id);
                    //creating board
                    if board.initial_edge_state.is_empty() {
                        create_board(
                            ref store, challenge.address_a, address_b, duel_id,
                        );
                    } // When game is created from snapshot
                    else {
                        let mut board: Board = store.get_board(duel_id);
                        let (_, player1_side, joker_number1) = board.player2;
                        board.player2 = (address_b, player1_side, joker_number1);
                        
                        store.set_board_player2(
                            board.id,
                            board.player2
                        );
                    };  

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

    //------------------------------------
    // Internal calls
    //
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _next_duel_id(ref self: ContractState) -> felt252 {
            let mut id_generator: felt252 = self.id_generator.read();
            id_generator += 1;
            let duel_id: felt252 = id_generator;
            self.id_generator.write(id_generator);
            (duel_id)
        }
    }
}
