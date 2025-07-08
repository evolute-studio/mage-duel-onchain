use evolute_duel::types::trophies::interface::{BushidoTask, Task, TaskTrait, TrophyTrait};

pub impl Seasoned of TrophyTrait {
    #[inline]
    fn identifier(level: u8) -> felt252 {
        match level {
            0 => 'Apprentice_Mage',
            1 => 'Journeyman_Mage',
            2 => 'Seasoned_Mage',
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
            1 => 10,
            2 => 20,
            _ => 0,
        }
    }

    #[inline]
    fn group() -> felt252 {
        'Seasoned'
    }


    //TODO: Choose a better icon
    #[inline]
    fn icon(level: u8) -> felt252 {
        match level {
            0 => 'fa-chess-pawn-piece',
            1 => 'fa-chess-bishop-piece',
            2 => 'fa-chess-queen-piece',
            _ => '',
            
        }
    }

    #[inline]
    fn title(level: u8) -> felt252 {
        match level {
            0 => 'Apprentice Mage',
            1 => 'Journeyman Mage',
            2 => 'Seasoned Mage',
            _ => '',
        }
    }

    //TODO: Choose a better description
    #[inline]
    fn description(level: u8) -> ByteArray {
        match level {
            0 => "Chosen to shape worlds anew",
            1 => "Harnessing Evolute, forging balanced realms",
            2 => "Master of realms, guided by Evolute",
            _ => "",
        }
    }

    #[inline]
    fn tasks(level: u8) -> Span<BushidoTask> {
        let count: u128 = match level {
            0 => 5,
            1 => 15,
            2 => 50,
            _ => 0,
        };
        Task::Seasoned.tasks(count)
    }
}
