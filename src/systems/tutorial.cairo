use starknet::ContractAddress;

/// Interface defining core game actions and player interactions.
#[starknet::interface]
pub trait ITutorial<T> {
    fn create_tutorial_game(
        ref self: T,
        bot_address: ContractAddress,
    );

    // fn make_move(
    //     ref self: T,
    //     player: ContractAddress,
    //     tile_index: u8,
    //     position: u8
    // ) -> ();
}   


// dojo decorator
#[dojo::contract]
pub mod tutorial {
    use super::*;
    use starknet::{
        ContractAddress,
        get_caller_address,
    };
    use dojo::{
        world::WorldStorage,
        event::EventStorage,
        model::ModelStorage,
    };
    use evolute_duel::{
        libs::{
            asserts::AssertsTrait,
        },
        models::{
            game::{Game},
        },
        types::{
            packing::{GameStatus},
        },
        systems::helpers::{
            board::{BoardTrait},
        },
        events::{GameCreated},
    };
    
    #[abi(embed_v0)]
    impl TutorialImpl of ITutorial<ContractState> {
        fn create_tutorial_game(
            ref self: ContractState,
            bot_address: ContractAddress,
        ) {
            let mut world = self.world_default();

            let host_player = get_caller_address();

            let mut game: Game = world.read_model(host_player);

            if !AssertsTrait::assert_ready_to_create_game(@game, world) {
                return;
            }

            let board = BoardTrait::create_tutorial_board(
                world,
                host_player,
                bot_address,
            );
                

            game.status = GameStatus::Created;
            game.board_id = Option::Some(board.id);

            world.write_model(@game);
            
            // For now, we will just emit an event indicating the game has been created
            world.emit_event(@GameCreated { 
                host_player,
                status: GameStatus::Created,
            });
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"evolute_duel")
        }
    }
   
}