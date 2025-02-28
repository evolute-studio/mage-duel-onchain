/// Interface defining actions for player profile management.
#[starknet::interface]
pub trait IPlayerProfileActions<T> {
    /// Retrieves the player's balance.
    fn balance(ref self: T);

    /// Retrieves the player's username.
    fn username(ref self: T);

    /// Retrieves the player's active skin.
    fn active_skin(ref self: T);

    /// Changes the player's username.
    /// - `new_username`: The new username to be set.
    fn change_username(ref self: T, new_username: felt252);

    /// Changes the player's active skin.
    /// - `skin_id`: The ID of the new skin to be applied.
    fn change_skin(ref self: T, skin_id: u8);
}


// dojo decorator
#[dojo::contract]
pub mod player_profile_actions {
    use dojo::event::EventStorage;
    use super::{IPlayerProfileActions};
    use starknet::{get_caller_address};

    use dojo::model::{ModelStorage};


    use evolute_duel::{
        events::{
            CurrentPlayerBalance, CurrentPlayerActiveSkin, CurrentPlayerUsername,
            PlayerUsernameChanged, PlayerSkinChanged, PlayerSkinChangeFailed,
        },
        models::{Player, Shop}, packing::{},
    };

    fn dojo_init(self: @ContractState) {
        let mut world = self.world(@"evolute_duel");
        let id = 0;

        let skin_prices = array![0, 0, 100, 500];

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

        fn username(ref self: ContractState) {
            let mut world = self.world_default();
            let player_id = get_caller_address();
            let player: Player = world.read_model(player_id);
            world.emit_event(@CurrentPlayerUsername { player_id, username: player.username });
        }

        fn change_username(ref self: ContractState, new_username: felt252) {
            let mut world = self.world_default();
            let player_id = get_caller_address();
            let mut player: Player = world.read_model(player_id);
            player.username = new_username;
            world.write_model(@player);

            world.emit_event(@PlayerUsernameChanged { player_id, new_username });
        }

        fn active_skin(ref self: ContractState) {
            let mut world = self.world_default();
            let player_id = get_caller_address();
            let player: Player = world.read_model(player_id);
            world
                .emit_event(
                    @CurrentPlayerActiveSkin { player_id, active_skin: player.active_skin },
                );
        }

        fn change_skin(ref self: ContractState, skin_id: u8) {
            let mut world = self.world_default();
            let player_id = get_caller_address();
            let mut player: Player = world.read_model(player_id);
            let shop: Shop = world.read_model(0);
            if skin_id.into() >= shop.skin_prices.len() {
                return;
            }
            let skin_price = *shop.skin_prices.at(skin_id.into());

            if player.balance < skin_price {
                world
                    .emit_event(
                        @PlayerSkinChangeFailed {
                            player_id, new_skin: skin_id, skin_price, balance: player.balance,
                        },
                    );
                return;
            }

            player.active_skin = skin_id;
            world.write_model(@player);

            world.emit_event(@PlayerSkinChanged { player_id, new_skin: skin_id });
            world
                .emit_event(
                    @CurrentPlayerActiveSkin { player_id, active_skin: player.active_skin },
                );
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"evolute_duel")
        }
    }
}
