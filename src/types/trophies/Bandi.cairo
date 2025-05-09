use evolute_duel::types::trophies::interface::{BushidoTask, Task, TaskTrait, TrophyTrait};

pub impl Bandi of TrophyTrait {
    #[inline]
    fn identifier(level: u8) -> felt252 {
        'Bandi'
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
        'Bandi'
    }


    //TODO: Choose a better icon
    #[inline]
    fn icon(level: u8) -> felt252 {
        'fa-shield-cat'
    }

    #[inline]
    fn title(level: u8) -> felt252 {
        'Bandi'
    }

    //TODO: Choose a better description
    #[inline]
    fn description(level: u8) -> ByteArray {
        "The guardian awakens to your call"
    }

    #[inline]
    fn tasks(level: u8) -> Span<BushidoTask> {
        let count: u32 = 1;
        Task::Bandi.tasks(count)
    }
}
