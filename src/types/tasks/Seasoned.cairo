use evolute_duel::types::tasks::interface::TaskTrait;

pub impl Seasoned of TaskTrait {
    #[inline]
    fn identifier() -> felt252 {
        'SEASONED'
    }

    #[inline]
    fn description(count: u128) -> ByteArray {
        format!("Play {} games", count)
    }
}
