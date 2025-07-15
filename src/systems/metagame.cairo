use starknet::ContractAddress;

/// Interface defining core game actions and player interactions.
#[starknet::interface]
pub trait IMetaGame<T> {
    fn place_tile(ref self: T, tile_index: u32, col: u32, row: u32, rotation: u8);
}


// dojo decorator
#[dojo::contract]
pub mod metagame {
    use super::super::rewards_manager::IRewardsManagerDispatcherTrait;
const CENTER_BOARD_COL: u32 = 16384;
    const CENTER_BOARD_ROW: u32 = 16384;
    const BOARD_SIZE: u32 = 32768; // Assuming a board size of 32768x32768 for the metagame

    use super::IMetaGame;
    use evolute_duel::{
        models::metagame::{MetagameBoardBounds, MetagamePlayerData, Position},
        systems::helpers::{
            validation::{is_valid_move},
            prizes::prize_system::{has_prize_at},
        },
        types::packing::{Tile, TEdge, PlayerSide},
        libs::{
            scoring::{ScoringTrait, ScoringImpl},
        },
        interfaces::dns::{DnsTrait}, 
    };

    use dojo::{
        world::{WorldStorage},
        model::{ModelStorage},
    };
    use starknet::{
        {get_caller_address, ContractAddress},
        storage::{StoragePointerReadAccess, StoragePointerWriteAccess},
    };
    
    #[storage]
    struct Storage {
        current_season_id: felt252,
    }

    fn dojo_init(self: @ContractState) {
        let mut world = self.world_default();
        // Initialize the metagame board bounds
        let board_bounds = MetagameBoardBounds {
            season_id: 0, // Default season ID
            min_col: CENTER_BOARD_COL, 
            max_col: CENTER_BOARD_COL,
            min_row: CENTER_BOARD_ROW,
            max_row: CENTER_BOARD_ROW,
            gap_size: 10, // Default gap size between tiles
        };
        world.write_model(@board_bounds);
    }

    #[abi(embed_v0)]
    impl MetagameImpl of IMetaGame<ContractState> {
        fn place_tile(ref self: ContractState, tile_index: u32, col: u32, row: u32, rotation: u8) {
            let mut world = self.world_default();
            let season_id = self.current_season_id.read();
            // Retrieve the current board bounds
            let mut board_bounds: MetagameBoardBounds = world.read_model(season_id);
            
            // Check if the tile placement is within bounds
            if col < board_bounds.min_col || col > board_bounds.max_col ||
               row < board_bounds.min_row || row > board_bounds.max_row {
                panic!("Tile placement out of bounds");
            }

            let player_address = get_caller_address();
            // Retrieve or create the player's deck
            let mut player_data: MetagamePlayerData = world.read_model((season_id, player_address));
            if tile_index >= player_data.deck.len() {
                panic!("Invalid tile index");
            }

            let tile = *player_data.deck[tile_index];
            
            if !is_valid_move(
                self.current_season_id.read(), // Assuming board_id is not used in this context
                tile.into(),
                rotation, // Assuming no rotation for simplicity
                col,
                row,
                BOARD_SIZE,
                board_bounds.min_col,
                board_bounds.min_row,
                board_bounds.max_col,
                board_bounds.max_row,
                player_data.tiles_placed == 0, // Allow placing not adjacent tiles only for the first tile
                world.clone()
            ) {
                panic!("Invalid move");
            }

            // Create the tile placement logic here
            ScoringImpl::calculate_move_scoring(
                tile.into(),
                rotation,
                col,
                row,
                PlayerSide::None,  // TODO: Think about player side
                player_address,
                self.current_season_id.read(),
                BOARD_SIZE,
                world.clone()
            );

            let mut new_player_deck = array![];
            for i in 0..player_data.deck.len() {
                if i != tile_index {
                    new_player_deck.append(*player_data.deck[i]);
                }
            };
            player_data.deck = new_player_deck.span();
            player_data.tiles_placed += 1;
            if player_data.first_tile_placed.is_none() {
                player_data.first_tile_placed = Option::Some(
                    Position {
                        col,
                        row
                    }
                );
            }
            world.write_model(@player_data);

            // Update bounds if necessary
            if col - board_bounds.gap_size < board_bounds.min_col {
                board_bounds.min_col = col - board_bounds.gap_size;
            }
            if col + board_bounds.gap_size > board_bounds.max_col {
                board_bounds.max_col = col + board_bounds.gap_size; 
            }
            if row - board_bounds.gap_size < board_bounds.min_row {
                board_bounds.min_row = row - board_bounds.gap_size;
            }
            if row + board_bounds.gap_size > board_bounds.max_row {
                board_bounds.max_row = row + board_bounds.gap_size;
            }
            
            world.write_model(@board_bounds);
            // Check if the placed tile has a prize
            match player_data.first_tile_placed {
                Option::Some(position) => {
                    match has_prize_at(
                        player_address,
                        col,
                        row,
                        position.col,
                        position.row,
                        season_id,
                    ) {
                        Option::Some(prize) => {
                            let rewards_manager_dispatcher = world.rewards_manager_dispatcher();
                            rewards_manager_dispatcher
                                .transfer_rewards(
                                    player_address,
                                    prize
                                );
                        },
                        Option::None => {
                            // No prize at this position, do nothing
                        }
                    }
                },
                Option::None => {
                    // If no first tile placed, do nothing
                }
            }
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> WorldStorage {
            self.world(@"evolute_duel")
        }
    }
}