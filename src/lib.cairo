pub mod systems {
    pub mod game;
    pub mod player_profile_actions;
    pub mod helpers {
        pub mod board;
        pub mod union_find;
        pub mod city_scoring;
        pub mod tile_helpers;
        pub mod road_scoring;
        pub mod validation;
    }
}

pub mod models {
    pub mod player;
    pub mod game;
    pub mod scoring;
    pub mod skins;
}
     
pub mod events;
pub mod packing;

pub mod types {
    pub mod trophies;
    pub mod tasks;
}

pub mod libs {
    pub mod achievements;
}

pub mod utils {
    pub mod hash;
}

pub mod tests {
    pub mod test_helpers {
        pub mod game_caller;
    }
    pub mod test_world;
    pub mod test_scoring;
}
