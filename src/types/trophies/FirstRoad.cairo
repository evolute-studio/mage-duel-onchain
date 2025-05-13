use evolute_duel::types::trophies::interface::{BushidoTask, Task, TaskTrait, TrophyTrait};

pub impl FirstRoad of TrophyTrait {
    #[inline]
    fn identifier(level: u8) -> felt252 {
        'First_Road'
    }

    #[inline]
    fn hidden(level: u8) -> bool {
        false
    }

    #[inline]
    fn index(level: u8) -> u8 {
        level
    }

    #[inline]
    fn points(level: u8) -> u16 {
        10
    }

    #[inline]
    fn group() -> felt252 {
        'First Road'
    }


    //TODO: Choose a better icon
    #[inline]
    fn icon(level: u8) -> felt252 {
        'fa-road'
    }

    #[inline]
    fn title(level: u8) -> felt252 {
        'First Road'
    }

    //TODO: Choose a better description
    #[inline]
    fn description(level: u8) -> ByteArray {
        "Build a first road"
    }

    #[inline]
    fn tasks(level: u8) -> Span<BushidoTask> {
        let count: u32 = 1;
        Task::FirstRoad.tasks(count)
    }
}
