use evolute_duel::types::tasks::interface::TaskTrait;

pub impl FirstRoad of TaskTrait {
    #[inline]
    fn identifier() -> felt252 {
        'FIRST_ROAD'
    }

    #[inline]
    fn description(count: u32) -> ByteArray {
        format!("Build a first road")
    }
}
