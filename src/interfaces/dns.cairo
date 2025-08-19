use starknet::{ContractAddress};
use dojo::world::{WorldStorage, WorldStorageTrait, IWorldDispatcher};
use dojo::meta::interface::{IDeployedResourceDispatcher, IDeployedResourceDispatcherTrait};

pub use evolute_duel::systems::{
    // admin::{IAdminDispatcher, IAdminDispatcherTrait},
    // bank::{IBankDispatcher, IBankDispatcherTrait},
    game::{IGameDispatcher, IGameDispatcherTrait},
    tutorial::{ITutorialDispatcher, ITutorialDispatcherTrait},
    matchmaking::{IMatchmakingDispatcher, IMatchmakingDispatcherTrait},
    // rng::{IRngDispatcher, IRngDispatcherTrait},
    // rng_mock::{IRngMockDispatcher, IRngMockDispatcherTrait},
    tokens::{
        // duel_token::{IDuelTokenDispatcher, IDuelTokenDispatcherTrait},
        // duelist_token::{IDuelistTokenDispatcher, IDuelistTokenDispatcherTrait},
        // pack_token::{IPackTokenDispatcher, IPackTokenDispatcherTrait},
        // fame_coin::{IFameCoinDispatcher, IFameCoinDispatcherTrait},
        // evolute_coin::{IEvoluteCoin, IEvoluteCoinDispatcher, IEvoluteCoinDispatcherTrait},
        // lords_mock::{ILordsMockDispatcher, ILordsMockDispatcherTrait},
        tournament_token::{ITournamentTokenDispatcher, ITournamentTokenDispatcherTrait},
    },
    // rewards_manager::{IRewardsManager, IRewardsManagerDispatcher, IRewardsManagerDispatcherTrait},
};
pub use evolute_duel::interfaces::{
    ierc20::{ierc20, Erc20Dispatcher, Erc20DispatcherTrait},
    vrf::{IVrfProviderDispatcher, IVrfProviderDispatcherTrait, Source},
    ievlt_token::{IEvltTokenDispatcher, IEvltTokenDispatcherTrait},
};
pub use tournaments::components::tournament::{ITournamentDispatcher, ITournamentDispatcherTrait};
// pub use pistols::libs::store::{Store, StoreTrait};
// pub use evolute_duel::models::config::{CONFIG, Config};
// pub use pistols::utils::misc::{ZERO};

pub mod SELECTORS {
    // systems
    // pub const ADMIN: felt252 = selector_from_tag!("pistols-admin");
    // pub const BANK: felt252 = selector_from_tag!("pistols-bank");
    // pub const GAME: felt252 = selector_from_tag!("evolute_duel-game");
    // pub const RNG: felt252 = selector_from_tag!("pistols-rng");
    // pub const RNG_MOCK: felt252 = selector_from_tag!("pistols-rng_mock");
    // tokens
    // pub const DUEL_TOKEN: felt252 = selector_from_tag!("pistols-duel_token");
    // pub const DUELIST_TOKEN: felt252 = selector_from_tag!("pistols-duelist_token");
    // pub const PACK_TOKEN: felt252 = selector_from_tag!("pistols-pack_token");
    // pub const FAME_COIN: felt252 = selector_from_tag!("pistols-fame_coin");
    pub const EVOLUTE_COIN: felt252 = selector_from_tag!("evolute_duel-evolute_coin");
    pub const EVLT_TOKEN: felt252 = selector_from_tag!("evolute_duel-evlt_token");
    pub const REWARDS_MANAGER: felt252 = selector_from_tag!("evolute_duel-rewards_manager");
    pub const TOURNAMENT_TOKEN: felt252 = selector_from_tag!("evolute_duel-tournament_token");
    // // mocks
    // pub const LORDS_MOCK: felt252 = selector_from_tag!("pistols-lords_mock");
    // pub const VR_MOCK: felt252 = selector_from_tag!("pistols-vrf_mock");
    // models
    pub const COIN_CONFIG: felt252 = selector_from_tag!("evolute_duel-CoinConfig");
}

#[generate_trait]
pub impl DnsImpl of DnsTrait {
    #[inline(always)]
    fn find_contract_name(self: @WorldStorage, contract_address: ContractAddress) -> ByteArray {
        (IDeployedResourceDispatcher{contract_address}.dojo_name())
    }
    fn find_contract_address(self: @WorldStorage, contract_name: @ByteArray) -> ContractAddress {
        // let (contract_address, _) = self.dns(contract_name).unwrap(); // will panic if not found
        match self.dns_address(contract_name) {
            Option::Some(contract_address) => {
                (contract_address)
            },
            Option::None => {
                (starknet::contract_address_const::<0x0>()) // return zero address if not found
            },
        }
    }

    // Create a Store from a dispatcher
    // https://github.com/dojoengine/dojo/blob/main/crates/dojo/core/src/contract/components/world_provider.cairo
    // https://github.com/dojoengine/dojo/blob/main/crates/dojo/core/src/world/storage.cairo
    #[inline(always)]
    fn storage(dispatcher: IWorldDispatcher, namespace: @ByteArray) -> WorldStorage {
        (WorldStorageTrait::new(dispatcher, namespace))
    }

    //--------------------------
    // system addresses
    //
    
    #[inline(always)]
    fn game_address(self: @WorldStorage) -> ContractAddress {
        (self.find_contract_address(@"game"))
    }
    
    #[inline(always)]
    fn matchmaking_address(self: @WorldStorage) -> ContractAddress {
        (self.find_contract_address(@"matchmaking"))
    }
   
    // #[inline(always)]
    // fn evolute_coin_address(self: @WorldStorage) -> ContractAddress {
    //     (self.find_contract_address(@"evolute_coin"))
    // }

    // #[inline(always)]
    // fn rewards_manager_address(self: @WorldStorage) -> ContractAddress {
    //     (self.find_contract_address(@"rewards_manager"))
    // }

    #[inline(always)]
    fn tournament_token_address(self: @WorldStorage) -> ContractAddress {
        (self.find_contract_address(@"tournament_token"))
    }

    #[inline(always)]
    fn evlt_token_address(self: @WorldStorage) -> ContractAddress {
        (self.find_contract_address(@"evlt_token"))
    }
    

    //--------------------------
    // address validators
    //
    #[inline(always)]
    fn is_world_contract(self: @WorldStorage, contract_address: ContractAddress) -> bool {
        (contract_address == self.find_contract_address(
            @self.find_contract_name(contract_address)
        ))
    }
    #[inline(always)]
    fn caller_is_world_contract(self: @WorldStorage) -> bool {
        (self.is_world_contract(starknet::get_caller_address()))
    }
    #[inline(always)]
    fn is_game_contract(self: @WorldStorage, contract_address: ContractAddress) -> bool {
        (contract_address == self.game_address())
    }

    //--------------------------
    // dispatchers
    //
    
    #[inline(always)]
    fn matchmaking_dispatcher(self: @WorldStorage) -> IMatchmakingDispatcher {
        (IMatchmakingDispatcher{ contract_address: self.matchmaking_address() })
    }

    #[inline(always)]
    fn evlt_token_dispatcher(self: @WorldStorage) -> IEvltTokenDispatcher {
        (IEvltTokenDispatcher{ contract_address: self.evlt_token_address() })
    }

    // //--------------------------
    // // legacy dispatchers (commented out)
    // //
    // #[inline(always)]
    // fn admin_dispatcher(self: @WorldStorage) -> IAdminDispatcher {
    //     (IAdminDispatcher{ contract_address: self.admin_address() })
    // }
    // #[inline(always)]
    // fn bank_dispatcher(self: @WorldStorage) -> IBankDispatcher {
    //     (IBankDispatcher{ contract_address: self.bank_address() })
    // }
    // #[inline(always)]
    // fn game_dispatcher(self: @WorldStorage) -> IGameDispatcher {
    //     (IGameDispatcher{ contract_address: self.game_address() })
    // }
    // #[inline(always)]
    // fn tutorial_dispatcher(self: @WorldStorage) -> ITutorialDispatcher {
    //     (ITutorialDispatcher{ contract_address: self.tutorial_address() })
    // }
    // #[inline(always)]
    // fn rng_dispatcher(self: @WorldStorage) -> IRngDispatcher {
    //     (IRngDispatcher{ contract_address: self.rng_address() })
    // }
    // #[inline(always)]
    // fn rng_mock_dispatcher(self: @WorldStorage) -> IRngMockDispatcher {
    //     (IRngMockDispatcher{ contract_address: self.rng_mock_address() })
    // }
    // #[inline(always)]
    // fn duel_token_dispatcher(self: @WorldStorage) -> IDuelTokenDispatcher {
    //     (IDuelTokenDispatcher{ contract_address: self.duel_token_address() })
    // }
    // #[inline(always)]
    // fn duelist_token_dispatcher(self: @WorldStorage) -> IDuelistTokenDispatcher {
    //     (IDuelistTokenDispatcher{ contract_address: self.duelist_token_address() })
    // }   
    // #[inline(always)]
    // fn pack_token_dispatcher(self: @WorldStorage) -> IPackTokenDispatcher {
    //     (IPackTokenDispatcher{ contract_address: self.pack_token_address() })
    // }
    // #[inline(always)]
    // fn fame_coin_dispatcher(self: @WorldStorage) -> IFameCoinDispatcher {
    //     (IFameCoinDispatcher{ contract_address: self.fame_coin_address() })
    // }
    // #[inline(always)]
    // fn evolute_coin_dispatcher(self: @WorldStorage) -> IEvoluteCoinDispatcher {
    //     (IEvoluteCoinDispatcher { contract_address: self.evolute_coin_address() })
    // }

    // #[inline(always)]
    // fn rewards_manager_dispatcher(self: @WorldStorage) -> IRewardsManagerDispatcher {
    //     (IRewardsManagerDispatcher { contract_address: self.rewards_manager_address() })
    // }
    // #[inline(always)]
    // fn budokan_dispatcher_from_pass_id(self: @Store, pass_id: u64) -> ITournamentDispatcher {
    //     (ITournamentDispatcher{ contract_address: self.world.read_member(Model::<TokenMetadata>::ptr_from_keys(pass_id), selector!("minted_by")) })
    // }
    // need access to store...
    // #[inline(always)]
    // fn lords_dispatcher(self: @Store) -> Erc20Dispatcher {
    //     (Erc20Dispatcher{ contract_address: self.get_config_lords_address() })
    //     // (ierc20(self.get_config_lords_address()))
    // }
    // #[inline(always)]
    // fn vrf_dispatcher(self: @Store) -> IVrfProviderDispatcher {
    //     (IVrfProviderDispatcher{ contract_address: self.get_config_vrf_address() })
    // }


    //--------------------------
    // test dispatchers
    // (use only in tests)
    //
    // #[inline(always)]
    // fn lords_mock_dispatcher(self: @WorldStorage) -> ILordsMockDispatcher {
    //     (ILordsMockDispatcher{ contract_address: self.lords_mock_address() })
    // }
    // #[inline(always)]
    // fn vrf_mock_dispatcher(self: @WorldStorage) -> IVrfProviderDispatcher {
    //     (IVrfProviderDispatcher{ contract_address: self.vrf_mock_address() })
    // }

}
