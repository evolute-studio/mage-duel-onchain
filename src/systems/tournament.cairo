use starknet::{ContractAddress};
use dojo::world::IWorldDispatcher;

#[starknet::interface]
pub trait ITournament<TState> {
    // IWorldProvider
    fn world_dispatcher(self: @TState) -> IWorldDispatcher;

    // ITournamentPublic
    fn enter_tournament(
        ref self: TState,
        tournament_id: u64,
        player_address: ContractAddress,
        secret_code: felt252,
    ) -> felt252;
}

// Exposed to clients
#[starknet::interface]
pub trait ITournamentPublic<TState> {
    fn enter_tournament(
        ref self: TState,
        tournament_id: u64,
        secret_code: felt252,
    );
}

#[dojo::contract]
pub mod tournament {    
    use dojo::world::{WorldStorage};

    #[storage]
    struct Storage {
        id_generator: felt252,
    }

    use evolute_duel::models::{
        registration::{Registration, RegistrationTrait},
        player::{PlayerAssignment},
    };
    use evolute_duel::libs::store::{StoreTrait};
    use evolute_duel::utils::misc::{ContractAddressIntoU256};
    use evolute_duel::utils::hash::{hash_values};

    use evolute_duel::types::errors::tournament::{Errors};

    use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};


    const PASSWORD_HASH: felt252 = 0x123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef;


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
    impl TournamentPublicImpl of super::ITournamentPublic<ContractState> {
        fn enter_tournament(
            ref self: ContractState,
            tournament_id: u64,
            secret_code: felt252,
        ) {
            let mut store = StoreTrait::new(self.world_default());
            let player_address = starknet::get_caller_address();
            let mut registration: Registration = store.get_registration(tournament_id, player_address);

            // Check if the player is already registered
            assert(!registration.is_registered(), Errors::ALREADY_REGISTERED);

            // assert(hash_values(array![secret_code].span()) == PASSWORD_HASH, Errors::INVALID_PASSWORD);
            println!("Password hash: {}", hash_values(array![secret_code].span()));
            // Register the player
            registration.register();
            store.set_registration(@registration);

            // Update the player's assignment
            let mut assignment: PlayerAssignment = store.get_player_challenge(player_address);
            assignment.tournament_id = tournament_id;
            store.set_player_challenge(@assignment);
        }
    }

    //------------------------------------
    // Internal calls
    //
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _next_tournament_id(ref self: ContractState) -> felt252 {
            let mut id_generator: felt252 = self.id_generator.read();
            id_generator += 1;
            let duel_id: felt252 = id_generator;
            self.id_generator.write(id_generator);
            (duel_id)
        }
    }
}
