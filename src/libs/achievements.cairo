use core::num::traits::Zero;
use achievement::store::{StoreTrait};
use evolute_duel::types::tasks::index::{Task, TaskTrait};
use evolute_duel::models::player::{Player, PlayerTrait};
use dojo::world::{WorldStorage};
use dojo::model::{ModelStorage};
use starknet::{ContractAddress, get_block_timestamp};

#[generate_trait]
pub impl AchievementsImpl of AchievementsTrait {
    fn play_game(world: WorldStorage, player_address: ContractAddress) {
        if !Self::can_recieve_achievement(world, player_address) {
            return;
        }
        let store = StoreTrait::new(world);
        let player_id: felt252 = player_address.into();
        let time = get_block_timestamp();

        let task_id: felt252 = Task::Seasoned.identifier();
        store.progress(player_id, task_id, count: 1, time: time);
    }

    fn win_game(world: WorldStorage, player_address: ContractAddress) {
        if !Self::can_recieve_achievement(world, player_address) {
            return;
        }
        let store = StoreTrait::new(world);
        let player_id: felt252 = player_address.into();
        let time = get_block_timestamp();

        let task_id: felt252 = Task::Winner.identifier();
        store.progress(player_id, task_id, count: 1, time: time);
    }

    fn build_road(world: WorldStorage, player_address: ContractAddress, edges_count: u32) {
        if !Self::can_recieve_achievement(world, player_address) {
            return;
        }
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
        if !Self::can_recieve_achievement(world, player_address) {
            return;
        }
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
        if !Self::can_recieve_achievement(world, player_address) {
            return;
        }
        let store = StoreTrait::new(world);
        let player_id: felt252 = player_address.into();
        let time = get_block_timestamp();

        let task_id: felt252 = Task::Bandi.identifier();
        store.progress(player_id, task_id, count: 1, time: time);
    }

    fn unlock_golem(world: WorldStorage, player_address: ContractAddress) {
        if !Self::can_recieve_achievement(world, player_address) {
            return;
        }
        let store = StoreTrait::new(world);
        let player_id: felt252 = player_address.into();
        let time = get_block_timestamp();

        let task_id: felt252 = Task::Golem.identifier();
        store.progress(player_id, task_id, count: 1, time: time);
    }

    fn unlock_mammoth(world: WorldStorage, player_address: ContractAddress) {
        if !Self::can_recieve_achievement(world, player_address) {
            return;
        }
        let store = StoreTrait::new(world);
        let player_id: felt252 = player_address.into();
        let time = get_block_timestamp();

        let task_id: felt252 = Task::Mammoth.identifier();
        store.progress(player_id, task_id, count: 1, time: time);
    }

    fn create_game(world: WorldStorage, player_address: ContractAddress) {
        if !Self::can_recieve_achievement(world, player_address) {
            return;
        }
        let store = StoreTrait::new(world);
        let player_id: felt252 = player_address.into();
        let time = get_block_timestamp();

        let task_id: felt252 = Task::Test.identifier();
        store.progress(player_id, task_id, count: 1, time: time);
    }

    fn can_recieve_achievement(world: WorldStorage, player_address: ContractAddress) -> bool {
        let player: Player = world.read_model(player_address);
        player.is_controller()
    }
}
