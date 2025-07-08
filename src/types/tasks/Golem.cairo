use evolute_duel::types::tasks::interface::TaskTrait;

pub impl Golem of TaskTrait {
    #[inline]
    fn identifier() -> felt252 {
        'GOLEM'
    }

    #[inline]
    fn description(count: u128) -> ByteArray {
        "Unlock Golem skin"
    }
}
