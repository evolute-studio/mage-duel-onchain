use starknet::ContractAddress;
/// Interface defining actions for player profile management.
#[starknet::interface]
pub trait IPlayerProfileActions<T> {
    /// Retrieves the player's balance.
    fn balance(ref self: T);

    /// Lets admin set the player's data.
    /// - `player_id`: Unique identifier for the player.
    /// - `username`: Player's chosen in-game name.
    /// - `balance`: Current balance of in-game currency or points.
    /// - `games_played`: Total number of games played by the player.
    /// - `active_skin`: The currently equipped skin or avatar.
    /// - `role`: The role of the player (0: Guest, 1: Controller, 2: Bot).
    /// This function is intended for administrative use only.
    /// It allows setting or updating the player's profile information.
    /// It should be used with caution to ensure that player data integrity is maintained.
    /// Admins should ensure that the provided data is valid and consistent with the game's rules.
    fn set_player(
        ref self: T, 
        player_id: ContractAddress, 
        username: felt252,  balance: u32, 
        games_played: felt252, 
        active_skin: u8, 
        role: u8
    );

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

    /// Player becomes a bot
    fn become_bot(ref self: T);

    /// Player becomes a controller
    /// - `player_id`: The ID of the player to be set as a controller.
    fn become_controller(ref self: T);
}

// dojo decorator
#[dojo::contract]
pub mod player_profile_actions {
    use super::{IPlayerProfileActions};
    use starknet::{get_caller_address, ContractAddress};

    use dojo::event::EventStorage;
    use dojo::model::ModelStorage;


    use evolute_duel::{
        events::{
            CurrentPlayerBalance, CurrentPlayerActiveSkin, CurrentPlayerUsername,
            PlayerUsernameChanged, PlayerSkinChanged, PlayerSkinChangeFailed,
        },
        models::{
            player::{Player},
            skins::{Shop},
        }, types::packing::{},
    };
    use evolute_duel::libs::achievements::AchievementsTrait;
    use openzeppelin_access::ownable::OwnableComponent;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // Ownable Mixin
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
 
    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event
    }


    fn dojo_init(ref self: ContractState, creator_address: ContractAddress) {
        let mut world = self.world(@"evolute_duel");
        let id = 0;

        let skin_prices = array![0, 0, 100, 500, 2000];

        let shop = Shop { shop_id: id, skin_prices };
        world.write_model(@shop);

        //println!("Owner: {creator_address:?}");
        self.ownable.initializer(creator_address);
    }

    #[abi(embed_v0)]
    impl PlayerProfileActionsImpl of IPlayerProfileActions<ContractState> {
        fn balance(ref self: ContractState) {
            let mut world = self.world_default();
            let player_id = get_caller_address();
            let player: Player = world.read_model(player_id);
            world.emit_event(@CurrentPlayerBalance { player_id, balance: player.balance });
        }

        fn set_player(
            ref self: ContractState, 
            player_id: ContractAddress, 
            username: felt252,  balance: u32, 
            games_played: felt252, 
            active_skin: u8, 
            role: u8
        ) {
            self.ownable.assert_only_owner();
            let mut world = self.world_default();
            let mut player: Player = world.read_model(player_id);
            player.username = username;
            player.balance = balance;
            player.games_played = games_played;
            player.active_skin = active_skin;
            player.role = role;
            world.write_model(@player);
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

            match skin_id {
                0 | 1 => {}, // Default skin, no achievement => {},
                2 => AchievementsTrait::unlock_bandi(world, player_id), //[Achievements] Bandi skin
                3 => AchievementsTrait::unlock_golem(world, player_id), //[Achievements] Golem skin
                4 => AchievementsTrait::unlock_mammoth(world, player_id), //[Achievements] Mammoth skin
                _ => {},
                
            }

            //[Achievements] Mammoth skin
            if skin_id == 4 {
                AchievementsTrait::unlock_mammoth(world, player_id);
            }
        }

        fn become_bot(ref self: ContractState) {
            let mut world = self.world_default();
            let player_id = get_caller_address();
            let mut player: Player = world.read_model(player_id);
            player.role = 2;
            world.write_model(@player);
        }

        fn become_controller(ref self: ContractState) {
            let mut world = self.world_default();
            let player_id = get_caller_address();
            let mut player: Player = world.read_model(player_id);
            player.role = 1;
            world.write_model(@player);
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"evolute_duel")
        }
    }
}
