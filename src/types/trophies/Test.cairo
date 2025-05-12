use evolute_duel::types::trophies::interface::{BushidoTask, Task, TaskTrait, TrophyTrait};

pub impl Test of TrophyTrait {
    #[inline]
    fn identifier(level: u8) -> felt252 {
        match level {
            0 => 'Creator',
            1 => 'Mega_Creator',
            2 => 'Supr_Mega_Creator',
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
            0 => 1,
            1 => 2,
            2 => 3,
            _ => 0,
        }
    }

    #[inline]
    fn group() -> felt252 {
        'Test'
    }


    //TODO: Choose a better icon
    #[inline]
    fn icon(level: u8) -> felt252 {
        match level {
            0 => 'fa-gamepad',
            1 => 'fa-gamepad-modern',
            2 => 'fa-game-console-handheld-crank',
            _ => '',
            
        }
    }

    #[inline]
    fn title(level: u8) -> felt252 {
        match level {
            0 => 'Creator',
            1 => 'Mega Creator',
            2 => 'Super Mega Creator',
            _ => '',
        }
    }

    //TODO: Choose a better description
    #[inline]
    fn description(level: u8) -> ByteArray {
        match level {
            0 => "Create game",
            1 => "Create more games",
            2 => "Create more more games",
            _ => "",
        }
    }

    #[inline]
    fn tasks(level: u8) -> Span<BushidoTask> {
        let count: u32 = match level {
            0 => 1,
            1 => 5,
            2 => 10,
            _ => 0,
        };
        Task::Test.tasks(count)
    }
}
