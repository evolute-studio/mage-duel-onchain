pub mod systems {
    pub mod game;
    pub mod metagame;
    pub mod player_profile_actions;
    pub mod rewards_manager;
    pub mod helpers {
        pub mod board;
        pub mod union_find;
        // pub mod city_scoring;
        pub mod tile_helpers;
        // pub mod road_scoring;
        pub mod scoring;
        pub mod validation;
    }
    pub mod tokens {
        pub mod evolute_coin;
    }
}

pub mod models {
    pub mod player;
    pub mod game;
    pub mod scoring;
    pub mod skins;
    pub mod metagame;
    pub mod config;
}

pub mod events;

pub mod types {
    pub mod trophies;
    pub mod tasks;
    pub mod packing;
}

pub mod libs {
    pub mod achievements;
    pub mod asserts;
    pub mod timing;
    pub mod scoring;
    pub mod move_execution;
    pub mod tile_reveal;
    pub mod game_finalization;
    pub mod phase_management;
    pub mod player_data;
}

pub mod components {
    pub mod coin_component;
}

pub mod utils {
    pub mod hash;
}

pub mod interfaces {
    pub mod dns;
    pub mod ierc20;
    pub mod ierc721;
    pub mod vrf;
}

pub mod tests {
    pub mod test_helpers {
        pub mod game_caller;
        // pub mod trait_test_helpers;
    }
    pub mod test_world;
    // pub mod test_scoring;
    // pub mod test_tile_reveal;
    // pub mod test_game_finalization;
    // pub mod test_phase_management;
    // pub mod test_player_data;
}
