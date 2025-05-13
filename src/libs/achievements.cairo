use core::num::traits::Zero;
use achievement::store::{StoreTrait};
use evolute_duel::types::tasks::index::{Task, TaskTrait};
use dojo::world::{WorldStorage};
use starknet::{ContractAddress, get_block_timestamp};

#[generate_trait]
pub impl AchievementsImpl of AchievementsTrait {
    fn play_game(world: WorldStorage, player_address: ContractAddress) {
        let store = StoreTrait::new(world);
        let player_id: felt252 = player_address.into();
        let time = get_block_timestamp();

        let task_id: felt252 = Task::Seasoned.identifier();
        store.progress(player_id, task_id, count: 1, time: time);
    }

    fn win_game(world: WorldStorage, player_address: ContractAddress) {
        let store = StoreTrait::new(world);
        let player_id: felt252 = player_address.into();
        let time = get_block_timestamp();

        let task_id: felt252 = Task::Winner.identifier();
        store.progress(player_id, task_id, count: 1, time: time);
    }

    fn build_road(world: WorldStorage, player_address: ContractAddress, edges_count: u32) {
        if player_address.is_non_zero() {
            let store = StoreTrait::new(world);
            let player_id: felt252 = player_address.into();
            let time = get_block_timestamp();
            
            if edges_count >= 7   {
                let task_id: felt252 = Task::RoadBuilder.identifier();
                store.progress(player_id, task_id, count: 1, time: time);
            }
            
            let task_id: felt252 = Task::FirstRoad.identifier();
            store.progress(player_id, task_id, count: 1, time: time);
        }
    }

    fn build_city(world: WorldStorage, player_address: ContractAddress, edges_count: u32) {
        if player_address.is_non_zero() {
            let store = StoreTrait::new(world);
            let player_id: felt252 = player_address.into();
            let time = get_block_timestamp();
            if edges_count >= 10  {
                let task_id: felt252 = Task::CityBuilder.identifier();
                store.progress(player_id, task_id, count: 1, time: time);
            }
            
            let task_id: felt252 = Task::FirstCity.identifier();
            store.progress(player_id, task_id, count: 1, time: time);
        }
    }

    fn unlock_bandi(world: WorldStorage, player_address: ContractAddress) {
        let store = StoreTrait::new(world);
        let player_id: felt252 = player_address.into();
        let time = get_block_timestamp();

        let task_id: felt252 = Task::Bandi.identifier();
        store.progress(player_id, task_id, count: 1, time: time);
    }

    fn unlock_golem(world: WorldStorage, player_address: ContractAddress) {
        let store = StoreTrait::new(world);
        let player_id: felt252 = player_address.into();
        let time = get_block_timestamp();

        let task_id: felt252 = Task::Golem.identifier();
        store.progress(player_id, task_id, count: 1, time: time);
    }

    fn create_game(world: WorldStorage, player_address: ContractAddress) {
        let store = StoreTrait::new(world);
        let player_id: felt252 = player_address.into();
        let time = get_block_timestamp();

        let task_id: felt252 = Task::Test.identifier();
        store.progress(player_id, task_id, count: 1, time: time);
    }
}
