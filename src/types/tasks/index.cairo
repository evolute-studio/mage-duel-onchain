// External imports

use achievement::types::task::{Task as BushidoTask, TaskTrait as BushidoTaskTrait};

// Internal imports

use evolute_duel::types::tasks;

// Types

#[derive(Copy, Drop)]
pub enum Task {
    None,
    Seasoned,
    Winner,
    RoadBuilder,
    CityBuilder,
    Bandi,
    Golem,
    Test,
    FirstCity,
    FirstRoad,
}

// Implementations

#[generate_trait]
pub impl TaskImpl of TaskTrait {
    #[inline]
    fn identifier(self: Task) -> felt252 {
        match self {
            Task::None => 0,
            Task::Seasoned => tasks::Seasoned::Seasoned::identifier(),
            Task::Winner => tasks::Winner::Winner::identifier(),
            Task::RoadBuilder => tasks::RoadBuilder::RoadBuilder::identifier(),
            Task::CityBuilder => tasks::CityBuilder::CityBuilder::identifier(),
            Task::Bandi => tasks::Bandi::Bandi::identifier(),
            Task::Golem => tasks::Golem::Golem::identifier(),
            Task::Test => tasks::Test::Test::identifier(),
            Task::FirstCity => tasks::FirstCity::FirstCity::identifier(),
            Task::FirstRoad => tasks::FirstRoad::FirstRoad::identifier(),
        }
    }

    #[inline]
    fn description(self: Task, count: u32) -> ByteArray {
        match self {
            Task::None => "",
            Task::Seasoned => tasks::Seasoned::Seasoned::description(count),
            Task::Winner => tasks::Winner::Winner::description(count),
            Task::RoadBuilder => tasks::RoadBuilder::RoadBuilder::description(count),
            Task::CityBuilder => tasks::CityBuilder::CityBuilder::description(count),
            Task::Bandi => tasks::Bandi::Bandi::description(count),
            Task::Golem => tasks::Golem::Golem::description(count),
            Task::Test => tasks::Test::Test::description(count),
            Task::FirstCity => tasks::FirstCity::FirstCity::description(count),
            Task::FirstRoad => tasks::FirstRoad::FirstRoad::description(count),
        }
    }

    #[inline]
    fn tasks(self: Task, count: u32) -> Span<BushidoTask> {
        let task_id: felt252 = self.identifier();
        let description: ByteArray = self.description(count);
        array![BushidoTaskTrait::new(task_id, count, description)].span()
    }
}

impl IntoTaskU8 of Into<Task, u8> {
    #[inline]
    fn into(self: Task) -> u8 {
        match self {
            Task::None => 0,
            Task::Seasoned => 1,
            Task::Winner => 2,
            Task::RoadBuilder => 3,
            Task::CityBuilder => 4,
            Task::Bandi => 5,
            Task::Golem => 6,
            Task::Test => 7,
            Task::FirstCity => 8,
            Task::FirstRoad => 9,
        }
    }
}

impl IntoU8Task of Into<u8, Task> {
    #[inline]
    fn into(self: u8) -> Task {
        let card: felt252 = self.into();
        match card {
            0 => Task::None,
            1 => Task::Seasoned,
            2 => Task::Winner,
            3 => Task::RoadBuilder,
            4 => Task::CityBuilder,
            5 => Task::Bandi,
            6 => Task::Golem,
            7 => Task::Test,
            8 => Task::FirstCity,
            9 => Task::FirstRoad,
            _ => Task::None,
        }
    }
}

// impl TaskPrint of PrintTrait<Task> {
//     #[inline]
//     fn print(self: Task) {
//         self.identifier().print();
//     }
// }

