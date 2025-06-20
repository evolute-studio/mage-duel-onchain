use achievement::types::task::Task as BushidoTask;
use evolute_duel::types::trophies;

pub const TROPHY_COUNT: u8 = 13;

#[derive(Copy, Drop)]
pub enum Trophy {
    None,
    SeasonedI,
    SeasonedII,
    SeasonedIII,
    WinnerI,
    WinnerII,
    WinnerIII,
    RoadBuilder,
    CityBuilder,
    Bandi,
    Golem,
    FirstCity,
    FristRoad,
    Mammoth,
}

#[generate_trait]
pub impl TrophyImpl of TrophyTrait {
    #[inline]
    fn identifier(self: @Trophy) -> felt252 {
        match self {
            Trophy::None => 0,
            Trophy::SeasonedI => trophies::Seasoned::Seasoned::identifier(0),
            Trophy::SeasonedII => trophies::Seasoned::Seasoned::identifier(1),
            Trophy::SeasonedIII => trophies::Seasoned::Seasoned::identifier(2),
            Trophy::WinnerI => trophies::Winner::Winner::identifier(0),
            Trophy::WinnerII => trophies::Winner::Winner::identifier(1),
            Trophy::WinnerIII => trophies::Winner::Winner::identifier(2),
            Trophy::RoadBuilder => trophies::RoadBuilder::RoadBuilder::identifier(0),
            Trophy::CityBuilder => trophies::CityBuilder::CityBuilder::identifier(0),
            Trophy::Bandi => trophies::Bandi::Bandi::identifier(0),
            Trophy::Golem => trophies::Golem::Golem::identifier(0),
            Trophy::FirstCity => trophies::FirstCity::FirstCity::identifier(0),
            Trophy::FristRoad => trophies::FirstRoad::FirstRoad::identifier(0),
            Trophy::Mammoth => trophies::Mammoth::Mammoth::identifier(0),
        }
    }

    #[inline]
    fn hidden(self: @Trophy) -> bool {
        match self {
            Trophy::None => true,
            Trophy::SeasonedI => false,
            Trophy::SeasonedII => false,
            Trophy::SeasonedIII => false,
            Trophy::WinnerI => false,
            Trophy::WinnerII => false,
            Trophy::WinnerIII => false,
            Trophy::RoadBuilder => false,
            Trophy::CityBuilder => false,
            Trophy::Bandi => false,
            Trophy::Golem => false,
            Trophy::FirstCity => false,
            Trophy::FristRoad => false,
            Trophy::Mammoth => false,
        }
    }

    #[inline]
    fn index(self: @Trophy) -> u8 {
        match self {
            Trophy::None => 0,
            Trophy::SeasonedI => trophies::Seasoned::Seasoned::index(0),
            Trophy::SeasonedII => trophies::Seasoned::Seasoned::index(1),
            Trophy::SeasonedIII => trophies::Seasoned::Seasoned::index(2),
            Trophy::WinnerI => trophies::Winner::Winner::index(0),
            Trophy::WinnerII => trophies::Winner::Winner::index(1),
            Trophy::WinnerIII => trophies::Winner::Winner::index(2),
            Trophy::RoadBuilder => trophies::RoadBuilder::RoadBuilder::index(0),
            Trophy::CityBuilder => trophies::CityBuilder::CityBuilder::index(0),
            Trophy::Bandi => trophies::Bandi::Bandi::index(0),
            Trophy::Golem => trophies::Golem::Golem::index(0),
            Trophy::FirstCity => trophies::FirstCity::FirstCity::index(0),
            Trophy::FristRoad => trophies::FirstRoad::FirstRoad::index(0),
            Trophy::Mammoth => trophies::Mammoth::Mammoth::index(0),
        }
    }

    #[inline]
    fn points(self: @Trophy) -> u16 {
        match self {
            Trophy::None => 0,
            Trophy::SeasonedI => trophies::Seasoned::Seasoned::points(0),
            Trophy::SeasonedII => trophies::Seasoned::Seasoned::points(1),
            Trophy::SeasonedIII => trophies::Seasoned::Seasoned::points(2),
            Trophy::WinnerI => trophies::Winner::Winner::points(0),
            Trophy::WinnerII => trophies::Winner::Winner::points(1),
            Trophy::WinnerIII => trophies::Winner::Winner::points(2),
            Trophy::RoadBuilder => trophies::RoadBuilder::RoadBuilder::points(0),
            Trophy::CityBuilder => trophies::CityBuilder::CityBuilder::points(0),
            Trophy::Bandi => trophies::Bandi::Bandi::points(0),
            Trophy::Golem => trophies::Golem::Golem::points(0),
            Trophy::FirstCity => trophies::FirstCity::FirstCity::points(0),
            Trophy::FristRoad => trophies::FirstRoad::FirstRoad::points(0),
            Trophy::Mammoth => trophies::Mammoth::Mammoth::points(0),
        }
    }

    #[inline]
    fn group(self: @Trophy) -> felt252 {
        match self {
            Trophy::None => 0,
            Trophy::SeasonedI => trophies::Seasoned::Seasoned::group(),
            Trophy::SeasonedII => trophies::Seasoned::Seasoned::group(),
            Trophy::SeasonedIII => trophies::Seasoned::Seasoned::group(),
            Trophy::WinnerI => trophies::Winner::Winner::group(),
            Trophy::WinnerII => trophies::Winner::Winner::group(),
            Trophy::WinnerIII => trophies::Winner::Winner::group(),
            Trophy::RoadBuilder => trophies::RoadBuilder::RoadBuilder::group(),
            Trophy::CityBuilder => trophies::CityBuilder::CityBuilder::group(),
            Trophy::Bandi => trophies::Bandi::Bandi::group(),
            Trophy::Golem => trophies::Golem::Golem::group(),
            Trophy::FirstCity => trophies::FirstCity::FirstCity::group(),
            Trophy::FristRoad => trophies::FirstRoad::FirstRoad::group(),
            Trophy::Mammoth => trophies::Mammoth::Mammoth::group(),
        }
    }

    #[inline]
    fn icon(self: @Trophy) -> felt252 {
        match self {
            Trophy::None => 0,
            Trophy::SeasonedI => trophies::Seasoned::Seasoned::icon(0),
            Trophy::SeasonedII => trophies::Seasoned::Seasoned::icon(1),
            Trophy::SeasonedIII => trophies::Seasoned::Seasoned::icon(2),
            Trophy::WinnerI => trophies::Winner::Winner::icon(0),
            Trophy::WinnerII => trophies::Winner::Winner::icon(1),
            Trophy::WinnerIII => trophies::Winner::Winner::icon(2),
            Trophy::RoadBuilder => trophies::RoadBuilder::RoadBuilder::icon(0),
            Trophy::CityBuilder => trophies::CityBuilder::CityBuilder::icon(0),
            Trophy::Bandi => trophies::Bandi::Bandi::icon(0),
            Trophy::Golem => trophies::Golem::Golem::icon(0),
            Trophy::FirstCity => trophies::FirstCity::FirstCity::icon(0),
            Trophy::FristRoad => trophies::FirstRoad::FirstRoad::icon(0),
            Trophy::Mammoth => trophies::Mammoth::Mammoth::icon(0),
        }
    }

    #[inline]
    fn title(self: @Trophy) -> felt252 {
        match self {
            Trophy::None => 0,
            Trophy::SeasonedI => trophies::Seasoned::Seasoned::title(0),
            Trophy::SeasonedII => trophies::Seasoned::Seasoned::title(1),
            Trophy::SeasonedIII => trophies::Seasoned::Seasoned::title(2),
            Trophy::WinnerI => trophies::Winner::Winner::title(0),
            Trophy::WinnerII => trophies::Winner::Winner::title(1),
            Trophy::WinnerIII => trophies::Winner::Winner::title(2),
            Trophy::RoadBuilder => trophies::RoadBuilder::RoadBuilder::title(0),
            Trophy::CityBuilder => trophies::CityBuilder::CityBuilder::title(0),
            Trophy::Bandi => trophies::Bandi::Bandi::title(0),
            Trophy::Golem => trophies::Golem::Golem::title(0),
            Trophy::FirstCity => trophies::FirstCity::FirstCity::title(0),
            Trophy::FristRoad => trophies::FirstRoad::FirstRoad::title(0),
            Trophy::Mammoth => trophies::Mammoth::Mammoth::title(0),
        }
    }

    #[inline]
    fn description(self: @Trophy) -> ByteArray {
        match self {
            Trophy::None => "",
            Trophy::SeasonedI => trophies::Seasoned::Seasoned::description(0),
            Trophy::SeasonedII => trophies::Seasoned::Seasoned::description(1),
            Trophy::SeasonedIII => trophies::Seasoned::Seasoned::description(2),
            Trophy::WinnerI => trophies::Winner::Winner::description(0),
            Trophy::WinnerII => trophies::Winner::Winner::description(1),
            Trophy::WinnerIII => trophies::Winner::Winner::description(2),
            Trophy::RoadBuilder => trophies::RoadBuilder::RoadBuilder::description(0),
            Trophy::CityBuilder => trophies::CityBuilder::CityBuilder::description(0),
            Trophy::Bandi => trophies::Bandi::Bandi::description(0),
            Trophy::Golem => trophies::Golem::Golem::description(0),
            Trophy::FirstCity => trophies::FirstCity::FirstCity::description(0),
            Trophy::FristRoad => trophies::FirstRoad::FirstRoad::description(0),
            Trophy::Mammoth => trophies::Mammoth::Mammoth::description(0),
        }
    }

    #[inline]
    fn tasks(self: @Trophy) -> Span<BushidoTask> {
        match self {
            Trophy::None => [].span(),
            Trophy::SeasonedI => trophies::Seasoned::Seasoned::tasks(0),
            Trophy::SeasonedII => trophies::Seasoned::Seasoned::tasks(1),
            Trophy::SeasonedIII => trophies::Seasoned::Seasoned::tasks(2),
            Trophy::WinnerI => trophies::Winner::Winner::tasks(0),
            Trophy::WinnerII => trophies::Winner::Winner::tasks(1),
            Trophy::WinnerIII => trophies::Winner::Winner::tasks(2),
            Trophy::RoadBuilder => trophies::RoadBuilder::RoadBuilder::tasks(0),
            Trophy::CityBuilder => trophies::CityBuilder::CityBuilder::tasks(0),
            Trophy::Bandi => trophies::Bandi::Bandi::tasks(0),
            Trophy::Golem => trophies::Golem::Golem::tasks(0),
            Trophy::FirstCity => trophies::FirstCity::FirstCity::tasks(0),
            Trophy::FristRoad => trophies::FirstRoad::FirstRoad::tasks(0),
            Trophy::Mammoth => trophies::Mammoth::Mammoth::tasks(0),
        }
    }

    #[inline]
    fn data(self: @Trophy) -> ByteArray {
        ""
    }
}

impl IntoTrophyU8 of Into<Trophy, u8> {
    #[inline]
    fn into(self: Trophy) -> u8 {
        match self {
            Trophy::None => 0,
            Trophy::SeasonedI => 1,
            Trophy::SeasonedII => 2,
            Trophy::SeasonedIII => 3,
            Trophy::WinnerI => 4,
            Trophy::WinnerII => 5,
            Trophy::WinnerIII => 6,
            Trophy::RoadBuilder => 7,
            Trophy::CityBuilder => 8,
            Trophy::Bandi => 9,
            Trophy::Golem => 10,
            Trophy::FirstCity => 11,
            Trophy::FristRoad => 12,
            Trophy::Mammoth => 13,
        }
    }
}

impl IntoU8Trophy of Into<u8, Trophy> {
    #[inline]
    fn into(self: u8) -> Trophy {
        let card: felt252 = self.into();
        match card {
            0 => Trophy::None,
            1 => Trophy::SeasonedI,
            2 => Trophy::SeasonedII,
            3 => Trophy::SeasonedIII,
            4 => Trophy::WinnerI,
            5 => Trophy::WinnerII,
            6 => Trophy::WinnerIII,
            7 => Trophy::RoadBuilder,
            8 => Trophy::CityBuilder,
            9 => Trophy::Bandi,
            10 => Trophy::Golem,
            11 => Trophy::FirstCity,
            12 => Trophy::FristRoad,
            13 => Trophy::Mammoth,
            _ => Trophy::None,
        }
    }
}
// impl TrophyPrint of debug::PrintTrait<Trophy> {
//     #[inline]
//     fn print(self: Trophy) {
//         self.identifier().print();
//     }
// }


