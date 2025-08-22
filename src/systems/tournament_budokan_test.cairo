use dojo::world::IWorldDispatcher;
use starknet::ContractAddress;
use tournaments::components::models::schedule::{Phase, Schedule};
use tournaments::components::models::tournament::{
    EntryFee, EntryRequirement, GameConfig, Metadata, PrizeType, QualificationProof, TokenType,
    Tournament as TournamentModel, Registration,
};

#[starknet::interface]
pub trait ITournament<TState> {
    fn world_dispatcher(self: @TState) -> IWorldDispatcher;

    fn total_tournaments(self: @TState) -> u64;
    fn tournament(self: @TState, tournament_id: u64) -> TournamentModel;
    fn tournament_entries(self: @TState, tournament_id: u64) -> u64;
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

    fn initializer(
        ref self: TState,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        safe_mode: bool,
        test_mode: bool,
        test_erc20: ContractAddress,
        test_erc721: ContractAddress,
    );
}

#[dojo::contract]
pub mod tournament_budokan_test {
    use tournaments::components::tournament::tournament_component;

    component!(path: tournament_component, storage: tournament, event: TournamentEvent);
    #[abi(embed_v0)]
    impl TournamentComponentImpl =
        tournament_component::TournamentImpl<ContractState>;
    impl TournamentComponentInternalImpl = tournament_component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        tournament: tournament_component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        TournamentEvent: tournament_component::Event,
    }

    fn dojo_init(ref self: ContractState) {
        self.tournament.initialize(false, false);
    }

}