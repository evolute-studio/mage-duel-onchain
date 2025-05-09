use evolute_duel::types::tasks::interface::TaskTrait;

pub impl RoadBuilder of TaskTrait {
    #[inline]
    fn identifier() -> felt252 {
        'ROAD_BUILDER'
    }

    #[inline]
    fn description(count: u32) -> ByteArray {
        format!("Build a road of 7+ edges")
    }
}
