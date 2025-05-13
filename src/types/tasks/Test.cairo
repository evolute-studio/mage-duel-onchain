use evolute_duel::types::tasks::interface::TaskTrait;

pub impl Test of TaskTrait {
    #[inline]
    fn identifier() -> felt252 {
        'TEST'
    }

    #[inline]
    fn description(count: u32) -> ByteArray {
        match count {
            0 => "",
            1 => "Create 1 game",
            _ => format!("Create {} games", count),
        }
    }
}
