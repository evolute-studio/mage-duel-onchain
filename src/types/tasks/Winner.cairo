use evolute_duel::types::tasks::interface::TaskTrait;

pub impl Winner of TaskTrait {
    #[inline]
    fn identifier() -> felt252 {
        'WINNER'
    }

    #[inline]
    fn description(count: u128) -> ByteArray {
        format!("Win {} games", count)
    }
}
