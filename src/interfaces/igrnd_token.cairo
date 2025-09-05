use starknet::ContractAddress;
use core::num::traits::Zero;

pub use evolute_duel::systems::tokens::grnd_token::{
    IGrndTokenDispatcher as GrndTokenDispatcher,
    IGrndTokenDispatcherTrait as GrndTokenDispatcherTrait,
    IGrndTokenProtectedDispatcher as GrndTokenProtectedDispatcher,
    IGrndTokenProtectedDispatcherTrait as GrndTokenProtectedDispatcherTrait,
};

#[inline(always)]
pub fn igrnd_token(contract_address: ContractAddress) -> GrndTokenDispatcher {
    assert(contract_address.is_non_zero(), 'igrnd_token(): null address');
    (GrndTokenDispatcher { contract_address })
}

#[inline(always)]
pub fn igrnd_token_protected(contract_address: ContractAddress) -> GrndTokenProtectedDispatcher {
    assert(contract_address.is_non_zero(), 'igrnd_token_protected(): null');
    (GrndTokenProtectedDispatcher { contract_address })
}
