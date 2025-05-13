use evolute_duel::types::tasks::interface::TaskTrait;

pub impl FirstCity of TaskTrait {
    #[inline]
    fn identifier() -> felt252 {
        'FIRST_CITY'
    }

    #[inline]
    fn description(count: u32) -> ByteArray {
        format!("Build a first city")
    }
}
