use evolute_duel::types::trophies::interface::{BushidoTask, Task, TaskTrait, TrophyTrait};

pub impl Mammoth of TrophyTrait {
    #[inline]
    fn identifier(level: u8) -> felt252 {
        'Mammoth'
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
        70
    }

    #[inline]
    fn group() -> felt252 {
        'Mammoth'
    }


    //TODO: Choose a better icon
    #[inline]
    fn icon(level: u8) -> felt252 {
        'fa-elephant'
    }

    #[inline]
    fn title(level: u8) -> felt252 {
        'Mammoth'
    }

    //TODO: Choose a better description
    #[inline]
    fn description(level: u8) -> ByteArray {
        "He came rampaging to obliterate everything in his path."
    }

    #[inline]
    fn tasks(level: u8) -> Span<BushidoTask> {
        let count: u128 = 1;
        Task::Mammoth.tasks(count)
    }
}
