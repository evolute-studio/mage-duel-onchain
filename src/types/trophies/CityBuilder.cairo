use evolute_duel::types::trophies::interface::{BushidoTask, Task, TaskTrait, TrophyTrait};

pub impl CityBuilder of TrophyTrait {
    #[inline]
    fn identifier(level: u8) -> felt252 {
        'City_Builder'
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
        30
    }

    #[inline]
    fn group() -> felt252 {
        'Grand Mayour'
    }


    //TODO: Choose a better icon
    #[inline]
    fn icon(level: u8) -> felt252 {
        'fa-landmark'
    }

    #[inline]
    fn title(level: u8) -> felt252 {
        'Grand Mayour'
    }

    //TODO: Choose a better description
    #[inline]
    fn description(level: u8) -> ByteArray {
        "Stone and will create dominion"
    }

    #[inline]
    fn tasks(level: u8) -> Span<BushidoTask> {
        let count: u128 = 1;
        Task::CityBuilder.tasks(count)
    }
}
