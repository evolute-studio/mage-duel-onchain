use dojo::{world::WorldStorage, event::EventStorage};
use evolute_duel::{
    models::{game::Game}, events::{GameCreateFailed, GameJoinFailed, SnapshotCreateFailed},
    types::{packing::GameStatus},
};
#[generate_trait]
pub impl AssersImpl of AssertsTrait {
    fn assert_ready_to_create_game(self: @Game, mut world: WorldStorage) -> bool {
        let status = *self.status;
        if status == GameStatus::InProgress || status == GameStatus::Created {
            world.emit_event(@GameCreateFailed { host_player: *self.player, status });
            println!("Game already created or in progress");
            return false;
        }
        true
    }

    fn assert_ready_to_join_game(guest: @Game, host: @Game, mut world: WorldStorage) -> bool {
        if *host.status != GameStatus::Created
            || *guest.status == GameStatus::Created
            || *guest.status == GameStatus::InProgress
            || host.player == guest.player {
            world
                .emit_event(
                    @GameJoinFailed {
                        host_player: *host.player,
                        guest_player: *guest.player,
                        host_game_status: *host.status,
                        guest_game_status: *guest.status,
                    },
                );
            println!("Game join failed");
            return false;
        }
        true
    }
}
