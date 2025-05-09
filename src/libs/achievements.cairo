use core::num::traits::Zero;
use achievement::store::{Store, StoreTrait};
use evolute_duel::types::tasks::index::{Task, TaskTrait};
use dojo::model::ModelStorage;
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait, WorldStorage};
use starknet::{ContractAddress, get_block_timestamp, get_caller_address};

#[generate_trait]
pub impl AchievementsImpl of AchievementsTrait {
    fn play_game(ref world: WorldStorage, player_address: ContractAddress) {
        let store = StoreTrait::new(world);
        let player_id: felt252 = player_address.into();
        let time = get_block_timestamp();

        let task_id: felt252 = Task::Seasoned.identifier();
        store.progress(player_id, task_id, count: 1, time: time);
    }

    fn win_game(ref world: WorldStorage, player_address: ContractAddress) {
        let store = StoreTrait::new(world);
        let player_id: felt252 = player_address.into();
        let time = get_block_timestamp();

        let task_id: felt252 = Task::Winner.identifier();
        store.progress(player_id, task_id, count: 1, time: time);
    }

    fn build_road(ref world: WorldStorage, player_address: ContractAddress, edges_count: u32) {
        if edges_count >= 7  && player_address.is_non_zero() {
            let store = StoreTrait::new(world);
            let player_id: felt252 = player_address.into();
            let time = get_block_timestamp();
    
            let task_id: felt252 = Task::RoadBuilder.identifier();
            store.progress(player_id, task_id, count: 1, time: time);
        }
    }

    fn build_city(ref world: WorldStorage, player_address: ContractAddress, edges_count: u32) {
        if edges_count >= 10 && player_address.is_non_zero() {
            let store = StoreTrait::new(world);
            let player_id: felt252 = player_address.into();
            let time = get_block_timestamp();
    
            let task_id: felt252 = Task::CityBuilder.identifier();
            store.progress(player_id, task_id, count: 1, time: time);
        }
    }

    fn unlock_bandi(ref world: WorldStorage, player_address: ContractAddress) {
        let store = StoreTrait::new(world);
        let player_id: felt252 = player_address.into();
        let time = get_block_timestamp();

        let task_id: felt252 = Task::Bandi.identifier();
        store.progress(player_id, task_id, count: 1, time: time);
    }

    fn unlock_golem(ref world: WorldStorage, player_address: ContractAddress) {
        let store = StoreTrait::new(world);
        let player_id: felt252 = player_address.into();
        let time = get_block_timestamp();

        let task_id: felt252 = Task::Golem.identifier();
        store.progress(player_id, task_id, count: 1, time: time);
    }

    fn create_game(ref world: WorldStorage, player_address: ContractAddress) {
        let store = StoreTrait::new(world);
        let player_id: felt252 = player_address.into();
        let time = get_block_timestamp();

        let task_id: felt252 = Task::Test.identifier();
        store.progress(player_id, task_id, count: 1, time: time);
    }
}
