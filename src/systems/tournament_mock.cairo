use dojo::world::IWorldDispatcher;
use starknet::ContractAddress;
use tournaments::components::models::schedule::{Phase, Schedule};
use tournaments::components::models::tournament::{
    EntryFee, EntryRequirement, GameConfig, Metadata, PrizeType, QualificationProof, TokenType,
    Tournament as TournamentModel, Registration,
};

#[starknet::interface]
pub trait ITournamentMock<TState> {
    fn world_dispatcher(self: @TState) -> IWorldDispatcher;

    fn total_tournaments(self: @TState) -> u64;
    fn tournament(self: @TState, tournament_id: u64) -> TournamentModel;
    fn tournament_entries(self: @TState, tournament_id: u64) -> u32;
    fn get_leaderboard(self: @TState, tournament_id: u64) -> Array<u64>;
    fn current_phase(self: @TState, tournament_id: u64) -> Phase;
    fn top_scores(self: @TState, tournament_id: u64) -> Array<u64>;
    fn is_token_registered(self: @TState, token: ContractAddress) -> bool;
    fn get_registration(self: @TState, game_address: ContractAddress, token_id: u64) -> Registration;
    fn get_tournament_id_for_token_id(self: @TState, game_address: ContractAddress, token_id: u64) -> u64;
    
    fn create_tournament(
        ref self: TState,
        creator_rewards_address: ContractAddress,
        metadata: Metadata,
        schedule: Schedule,
        game_config: GameConfig,
        entry_fee: Option<EntryFee>,
        entry_requirement: Option<EntryRequirement>,
    ) -> TournamentModel;
    fn enter_tournament(
        ref self: TState,
        tournament_id: u64,
        player_name: felt252,
        player_address: ContractAddress,
        qualification: Option<QualificationProof>,
    ) -> (u64, u32);
    fn submit_score(ref self: TState, tournament_id: u64, token_id: u64, position: u8);
    fn claim_prize(ref self: TState, tournament_id: u64, prize_type: PrizeType);
    fn add_prize(
        ref self: TState,
        tournament_id: u64,
        token_address: ContractAddress,
        token_type: TokenType,
        position: u8,
    );
}

#[dojo::contract]
pub mod tournament_mock {
    use super::ITournamentMock;
    use dojo::world::{IWorldDispatcher, WorldStorage, WorldStorageTrait};
    use starknet::{ContractAddress, get_block_timestamp};
    use dojo::model::{ModelStorage, ModelValueStorage};
    use tournaments::components::models::schedule::{Phase, Schedule, Period};
    use tournaments::components::models::tournament::{
        EntryFee, EntryRequirement, GameConfig, Metadata, PrizeType, QualificationProof, TokenType,
        Tournament as TournamentModel, Registration,
    };

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl TournamentMockImpl of ITournamentMock<ContractState> {
        fn world_dispatcher(self: @ContractState) -> IWorldDispatcher {
            self.world_dispatcher()
        }

        fn total_tournaments(self: @ContractState) -> u64 {
            1 // Static mock value
        }

        fn tournament(self: @ContractState, tournament_id: u64) -> TournamentModel {
            // Mock implementation - return a basic tournament
            TournamentModel {
                id: tournament_id,
                created_at: get_block_timestamp(),
                created_by: starknet::contract_address_const::<0x111>(),
                creator_token_id: 1,
                metadata: Metadata {
                    name: 'Mock Tournament',
                    description: "Mock tournament for testing"
                },
                schedule: Schedule {
                    registration: Option::None,
                    game: Period {
                        start: get_block_timestamp(),
                        end: get_block_timestamp() + 3600,
                    },
                    submission_duration: 300,
                },
                game_config: GameConfig {
                    address: starknet::contract_address_const::<0x123>(),
                    settings_id: 1,
                    prize_spots: 3,
                },
                entry_fee: Option::None,
                entry_requirement: Option::None,
            }
        }

        fn tournament_entries(self: @ContractState, tournament_id: u64) -> u32 {
            1 // Mock - always return 1 entry
        }

        fn get_leaderboard(self: @ContractState, tournament_id: u64) -> Array<u64> {
            array![]
        }

        fn current_phase(self: @ContractState, tournament_id: u64) -> Phase {
            Phase::Registration
        }

        fn top_scores(self: @ContractState, tournament_id: u64) -> Array<u64> {
            array![]
        }

        fn is_token_registered(self: @ContractState, token: ContractAddress) -> bool {
            true
        }

        fn get_registration(self: @ContractState, game_address: ContractAddress, token_id: u64) -> Registration {
            Registration {
                game_address,
                game_token_id: token_id,
                tournament_id: 1,
                entry_number: 1,
                has_submitted: false,
            }
        }

        fn get_tournament_id_for_token_id(self: @ContractState, game_address: ContractAddress, token_id: u64) -> u64 {
            1
        }

        fn create_tournament(
            ref self: ContractState,
            creator_rewards_address: ContractAddress,
            metadata: Metadata,
            schedule: Schedule,
            game_config: GameConfig,
            entry_fee: Option<EntryFee>,
            entry_requirement: Option<EntryRequirement>,
        ) -> TournamentModel {
            // Static tournament ID for mock
            let tournament_id = 1;

            TournamentModel {
                id: tournament_id,
                created_at: get_block_timestamp(),
                created_by: creator_rewards_address,
                creator_token_id: 1,
                metadata,
                schedule,
                game_config,
                entry_fee,
                entry_requirement,
            }
        }

        fn enter_tournament(
            ref self: ContractState,
            tournament_id: u64,
            player_name: felt252,
            player_address: ContractAddress,
            qualification: Option<QualificationProof>,
        ) -> (u64, u32) {
            // Mock implementation - return token_id = 1, entry_number = 1
            (1, 1)
        }

        fn submit_score(ref self: ContractState, tournament_id: u64, token_id: u64, position: u8) {
            // Mock implementation - do nothing
        }

        fn claim_prize(ref self: ContractState, tournament_id: u64, prize_type: PrizeType) {
            // Mock implementation - do nothing
        }

        fn add_prize(
            ref self: ContractState,
            tournament_id: u64,
            token_address: ContractAddress,
            token_type: TokenType,
            position: u8,
        ) {
            // Mock implementation - do nothing
        }
    }
}