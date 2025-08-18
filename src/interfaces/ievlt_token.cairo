use starknet::ContractAddress;
use core::num::traits::Zero;

pub use evolute_duel::systems::tokens::evlt_token::{
    IEvltTokenDispatcher as EvltTokenDispatcher,
    IEvltTokenDispatcherTrait as EvltTokenDispatcherTrait,
    IEvltTokenProtectedDispatcher as EvltTokenProtectedDispatcher,
    IEvltTokenProtectedDispatcherTrait as EvltTokenProtectedDispatcherTrait,
};

#[inline(always)]
pub fn ievlt_token(contract_address: ContractAddress) -> EvltTokenDispatcher {
    assert(contract_address.is_non_zero(), 'ievlt_token(): null address');
    (EvltTokenDispatcher{contract_address})
}

#[inline(always)]
pub fn ievlt_token_protected(contract_address: ContractAddress) -> EvltTokenProtectedDispatcher {
    assert(contract_address.is_non_zero(), 'ievlt_token_protected(): null');
    (EvltTokenProtectedDispatcher{contract_address})
}