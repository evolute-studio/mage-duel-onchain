use starknet::ContractAddress;
use core::num::traits::Zero;

pub use evolute_duel::systems::tokens::evlt_token::{
    IEvltTokenDispatcher, IEvltTokenDispatcherTrait, IEvltTokenProtectedDispatcher,
    IEvltTokenProtectedDispatcherTrait,
};

#[inline(always)]
pub fn ievlt_token(contract_address: ContractAddress) -> IEvltTokenDispatcher {
    assert(contract_address.is_non_zero(), 'ievlt_token(): null address');
    (IEvltTokenDispatcher { contract_address })
}

#[inline(always)]
pub fn ievlt_token_protected(contract_address: ContractAddress) -> IEvltTokenProtectedDispatcher {
    assert(contract_address.is_non_zero(), 'ievlt_token_protected(): null');
    (IEvltTokenProtectedDispatcher { contract_address })
}
