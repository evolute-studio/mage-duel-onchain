use starknet::ContractAddress;

/// Interface defining core game actions and player interactions.
#[starknet::interface]
pub trait IRewardsManager<T> {
    fn transfer_rewards(ref self: T, player_address: ContractAddress, amount: u128);
}


// dojo decorator
#[dojo::contract]
pub mod rewards_manager {
    use super::IRewardsManager;
    use starknet::ContractAddress;
    use dojo::{
        world::WorldStorage, 
    };
    use evolute_duel::{
        systems::{
            tokens::{
                evolute_coin::{},
            }
        },
        interfaces::{
            dns::{
                DnsTrait,
                IEvoluteCoinDispatcher, IEvoluteCoinDispatcherTrait
            },
        },
    };

    #[storage]
    struct Storage {
    }

    fn dojo_init(self: @ContractState) {
        
    }

    #[abi(embed_v0)]
    impl RewardManagerImpl of IRewardsManager<ContractState> {
        fn transfer_rewards(ref self: ContractState, player_address: ContractAddress, amount: u128) {
            // validate caller (game contract only)
            let mut world = self.world_default();
            assert!(world.caller_is_world_contract(), "[Rewards error] Invalid caller");

            let evolute_coin_dispatcher: IEvoluteCoinDispatcher = world.evolute_coin_dispatcher();

            evolute_coin_dispatcher.reward_player(player_address, amount)
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> WorldStorage {
            self.world(@"evolute_duel")
        }
    }
}