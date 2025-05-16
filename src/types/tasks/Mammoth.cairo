use evolute_duel::types::tasks::interface::TaskTrait;

pub impl Mammoth of TaskTrait {
    #[inline]
    fn identifier() -> felt252 {
        'MAMMOTH'
    }

    #[inline]
    fn description(count: u32) -> ByteArray {
        "Unlock MAMMOTH skin"
    }
}
