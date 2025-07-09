use evolute_duel::types::tasks::interface::TaskTrait;

pub impl CityBuilder of TaskTrait {
    #[inline]
    fn identifier() -> felt252 {
        'CITY_BUILDER'
    }

    #[inline]
    fn description(count: u128) -> ByteArray {
        format!("Build a city of 10+ edges")
    }
}
