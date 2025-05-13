use evolute_duel::types::tasks::interface::TaskTrait;

pub impl Bandi of TaskTrait {
    #[inline]
    fn identifier() -> felt252 {
        'BANDI'
    }

    #[inline]
    fn description(count: u32) -> ByteArray {
        "Unlock Bandi skin"
    }
}
