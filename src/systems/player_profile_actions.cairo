// define the interface
#[starknet::interface]
pub trait IPlayerProfileActions<T> {
    fn balance(ref self: T);
}

// dojo decorator
#[dojo::contract]
pub mod player_profile_actions {
    use dojo::event::EventStorage;
    use super::{IPlayerProfileActions};
    use starknet::{get_caller_address};

    use dojo::model::{ModelStorage};


    use evolute_duel::{events::{CurrentPlayerBalance}, models::{Player, Shop}, packing::{}};

    fn dojo_init(self: @ContractState) {
        let mut world = self.world(@"evolute_duel");
        let id = 0;

        let skin_prices = array![100, 200, 300];

        let shop = Shop { shop_id: id, skin_prices };
        world.write_model(@shop);
    }

    #[abi(embed_v0)]
    impl PlayerProfileActionsImpl of IPlayerProfileActions<ContractState> {
        fn balance(ref self: ContractState) {
            let mut world = self.world_default();
            let player_id = get_caller_address();
            let player: Player = world.read_model(player_id);
            world.emit_event(@CurrentPlayerBalance { player_id, balance: player.balance });
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"evolute_duel")
        }
    }
}
