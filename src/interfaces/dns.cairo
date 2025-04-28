use starknet::{ContractAddress};
use core::num::traits::Zero;
use dojo::world::{WorldStorage, WorldStorageTrait, IWorldDispatcher};
use dojo::model::{Model, ModelPtr, ModelStorage, ModelValueStorage};
use dojo::meta::interface::{IDeployedResourceDispatcher, IDeployedResourceDispatcherTrait};

pub use evolute_duel::utils::misc::{ZERO};
pub use evolute_duel::systems::{
    game::{IGameDispatcher, IGameDispatcherTrait},
    tokens::{
        tournament_token::{ITournamentToken, ITournamentTokenDispatcher}
    }
};
pub use tournaments::components::tournament::{ITournamentDispatcher, ITournamentDispatcherTrait};
use tournaments::components::models::game::{TokenMetadata, TokenMetadataValue};

pub mod SELECTORS {
    // systems
    pub const GAME: felt252 = selector_from_tag!("evolute_duel-game");
    // tokens
    pub const TOURNAMENT_TOKEN: felt252 = selector_from_tag!("evolute_duel-tournament_token");
    // models
    // pub const CONFIG: felt252 = selector_from_tag!("pistols-Config");
    // pub const SEASON_CONFIG: felt252 = selector_from_tag!("pistols-SeasonConfig");
    // pub const TOKEN_CONFIG: felt252 = selector_from_tag!("pistols-TokenConfig");
    // pub const COIN_CONFIG: felt252 = selector_from_tag!("pistols-CoinConfig");
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
                (ZERO())
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
    fn tournament_token_address(self: @WorldStorage) -> ContractAddress {
        (self.find_contract_address(@"tournament_token"))
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
    fn caller_is_tournament_contract(self: @WorldStorage) -> bool {
        (starknet::get_caller_address() == self.tournament_token_address())
    }

    //--------------------------
    // dispatchers
    //
    #[inline(always)]
    fn game_dispatcher(self: @WorldStorage) -> IGameDispatcher {
        (IGameDispatcher{ contract_address: self.game_address() })
    }
    #[inline(always)]
    fn tournament_token_dispatcher(self: @WorldStorage) -> ITournamentTokenDispatcher {
        (ITournamentTokenDispatcher{ contract_address: self.tournament_token_address() })
    }

    #[inline(always)]
    fn budokan_dispatcher_from_pass_id(self: @WorldStorage, pass_id: u64) -> ITournamentDispatcher {
        let tournament_pass_minter_address: ContractAddress = self.read_member(Model::<TokenMetadata>::ptr_from_keys(pass_id), selector!("minted_by"));
        (ITournamentDispatcher{ contract_address: tournament_pass_minter_address })
    }
}