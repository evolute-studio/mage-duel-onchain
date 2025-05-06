pub mod systems {
    pub mod game;
    pub mod duel;
    pub mod player_profile_actions;
    pub mod rng;
    pub mod rng_mock;
    pub mod helpers {
        pub mod board;
        pub mod city_union_find;
        pub mod city_scoring;
        pub mod tile_helpers;
        pub mod road_union_find;
        pub mod road_scoring;
        pub mod validation;
    }
    pub mod tokens {
        //ERC721
        pub mod tournament_token;
    }
}

pub mod models {
    pub mod player;
    pub mod skins;
    pub mod challenge;
    pub mod game;
    pub mod scoring;
    pub mod tournament;
    pub mod config;
    pub mod pact;
    pub mod scoreboard;
    pub mod registration;
}

pub mod events;
pub mod packing;

pub mod types {
    pub mod errors {
        pub mod duel;
        pub mod tournament;
        pub mod duelist;
    }
    pub mod timestamp;
    pub mod constants;
    pub mod challenge_state;
    pub mod shuffler;
}

pub mod interfaces {
    pub mod dns;
    pub mod vrf;
}

pub mod utils {
    pub mod bitwise;
    pub mod short_string;
    pub mod misc; 
    pub mod bytemap;
    pub mod nibblemap;
    pub mod hash;
    pub mod math; 
    pub mod byte_arrays;
}

pub mod libs {
    pub mod store;
}

pub mod tests {
    mod test_world;
    mod test_scoring;
}
