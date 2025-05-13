use evolute_duel::types::trophies::interface::{BushidoTask, Task, TaskTrait, TrophyTrait};

pub impl Winner of TrophyTrait {
    #[inline]
    fn identifier(level: u8) -> felt252 {
        match level {
            0 => 'First_Victory',
            1 => 'Tactician\'s Trail',
            2 => 'Runebound Rival',
            _ => '',
        }
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
        match level {
            0 => 5,
            1 => 20,
            2 => 50,
            _ => 0,
        }
    }

    #[inline]
    fn group() -> felt252 {
        'Winner'
    }


    //TODO: Choose a better icon
    #[inline]
    fn icon(level: u8) -> felt252 {
        match level {
            0 => 'fa-sword',
            1 => 'fa-swords',
            2 => 'fa-wreath-laurel',
            _ => '',
        }
    }

    #[inline]
    fn title(level: u8) -> felt252 {
        match level {
            0 => 'First Victory',
            1 => 'Tactician\'s Trail',
            2 => 'Runebound Rival',
            _ => '',
        }
    }

    //TODO: Choose a better description
    #[inline]
    fn description(level: u8) -> ByteArray {
        match level {
            0 => "Power answers the call of courage",
            1 => "One mind, many victories, no falter",
            2 => "Master of duels, feared and known",
            _ => "",
        }
    }

    #[inline]
    fn tasks(level: u8) -> Span<BushidoTask> {
        let count: u32 = match level {
            0 => 1,
            1 => 5,
            2 => 25,
            _ => 0,
        };
        Task::Winner.tasks(count)
    }
}
