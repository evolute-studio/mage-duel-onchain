use starknet::ContractAddress;

/// Interface defining core game actions and player interactions.
#[starknet::interface]
pub trait IMetaGame<T> {
    fn place_tile(ref self: T, tile_index: u32, col: u32, row: u32, rotation: u8);

    // Testing methods
    fn get_random_deck(ref self: T, player_address: ContractAddress);
}


// dojo decorator
#[dojo::contract]
pub mod metagame {
    use super::*;
    const CENTER_BOARD_COL: u32 = 16384;
    const CENTER_BOARD_ROW: u32 = 16384;
    const BOARD_SIZE: u32 = 32768; // Assuming a board size of 32768x32768 for the metagame

    use super::IMetaGame;
    use evolute_duel::{
        models::metagame::{MetagameBoardBounds, MetagamePlayerData, Position},
        systems::{
            helpers::{
                validation::{is_valid_move},
                prizes::prize_system::{has_prize_at},
            },
        },
        types::packing::{PlayerSide},
        libs::{
            scoring::{ScoringImpl},
        },
        interfaces::dns::{DnsTrait, IRewardsManagerDispatcherTrait}, 
    };

    use dojo::{
        world::{WorldStorage},
        model::{ModelStorage},
    };
    use starknet::{
        {get_caller_address},
        storage::{StoragePointerReadAccess, StoragePointerWriteAccess},
    };
    use origami_random::deck::{DeckTrait};
    
    #[storage]
    struct Storage {
        current_season_id: felt252,
    }

    fn dojo_init(self: @ContractState) {
        let mut world = self.world_default();
        // Initialize the metagame board bounds
        let board_bounds = MetagameBoardBounds {
            season_id: 1000000000, // Default season ID
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
            println!("=== DEBUG place_tile START ===");
            println!("Input parameters: tile_index={}, col={}, row={}, rotation={}", tile_index, col, row, rotation);
            
            self.current_season_id.write(1000000000); // Assuming a default season ID for simplicity
            let mut world = self.world_default();
            let season_id = self.current_season_id.read();
            println!("Season ID: {}", season_id);
            
            // Retrieve the current board bounds
            let mut board_bounds: MetagameBoardBounds = world.read_model(season_id);
            println!("Board bounds: min_col={}, max_col={}, min_row={}, max_row={}, gap_size={}", 
                board_bounds.min_col, board_bounds.max_col, board_bounds.min_row, board_bounds.max_row, board_bounds.gap_size);
            
            // Check if the tile placement is within bounds
            println!("Checking bounds: col({}) >= min_col({}) && col({}) <= max_col({})", col, board_bounds.min_col, col, board_bounds.max_col);
            println!("Checking bounds: row({}) >= min_row({}) && row({}) <= max_row({})", row, board_bounds.min_row, row, board_bounds.max_row);
            
            if col < board_bounds.min_col || col > board_bounds.max_col ||
               row < board_bounds.min_row || row > board_bounds.max_row {
                println!("ERROR: Tile placement out of bounds!");
                panic!("Tile placement out of bounds");
            }
            println!("Bounds check passed");

            let player_address = get_caller_address();
            println!("Player address: {:?}", player_address);
            
            // Retrieve or create the player's deck
            let mut player_data: MetagamePlayerData = world.read_model((season_id, player_address));
            println!("Player data: deck_len={}, tiles_placed={}", player_data.deck.len(), player_data.tiles_placed);
            println!("First tile placed: {:?}", player_data.first_tile_placed);
            
            if tile_index >= player_data.deck.len() {
                println!("ERROR: Invalid tile index {} >= deck length {}", tile_index, player_data.deck.len());
                panic!("Invalid tile index");
            }
            println!("Tile index validation passed");

            let tile = *player_data.deck[tile_index];
            println!("Selected tile: {:?}", tile);
            
            println!("Calling is_valid_move with parameters:");
            println!("  season_id: {}", self.current_season_id.read());
            println!("  tile: {:?}", tile);
            println!("  rotation: {}", rotation);
            println!("  col: {}, row: {}", col, row);
            println!("  board_size: {}", BOARD_SIZE);
            println!("  bounds: min_col={}, min_row={}, max_col={}, max_row={}", 
                board_bounds.min_col, board_bounds.min_row, board_bounds.max_col, board_bounds.max_row);
            println!("  is_first_tile: {}", player_data.tiles_placed == 0);
            
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
                world
            ) {
                println!("ERROR: Invalid move detected by is_valid_move");
                panic!("Invalid move");
            }
            println!("Move validation passed");

            // Create the tile placement logic here
            println!("Calling calculate_move_scoring...");
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
            println!("Scoring calculation completed");

            println!("Creating new deck by removing tile at index {}", tile_index);
            let mut new_player_deck = array![];
            for i in 0..player_data.deck.len() {
                if i != tile_index {
                    new_player_deck.append(*player_data.deck[i]);
                }
            };
            player_data.deck = new_player_deck.span();
            player_data.tiles_placed += 1;
            println!("New deck length: {}, tiles_placed: {}", player_data.deck.len(), player_data.tiles_placed);
            
            if player_data.first_tile_placed.is_none() {
                println!("Setting first tile position to col={}, row={}", col, row);
                player_data.first_tile_placed = Option::Some(
                    Position {
                        col,
                        row
                    }
                );
            } else {
                println!("First tile already placed, keeping existing position");
            }
            
            println!("Writing updated player data to world");
            world.write_model(@player_data);

            // Update bounds if necessary
            println!("Current bounds before update: min_col={}, max_col={}, min_row={}, max_row={}", 
                board_bounds.min_col, board_bounds.max_col, board_bounds.min_row, board_bounds.max_row);
                
            let old_bounds = board_bounds;
            if col - board_bounds.gap_size < board_bounds.min_col {
                board_bounds.min_col = col - board_bounds.gap_size;
                println!("Updated min_col to {}", board_bounds.min_col);
            }
            if col + board_bounds.gap_size > board_bounds.max_col {
                board_bounds.max_col = col + board_bounds.gap_size; 
                println!("Updated max_col to {}", board_bounds.max_col);
            }
            if row - board_bounds.gap_size < board_bounds.min_row {
                board_bounds.min_row = row - board_bounds.gap_size;
                println!("Updated min_row to {}", board_bounds.min_row);
            }
            if row + board_bounds.gap_size > board_bounds.max_row {
                board_bounds.max_row = row + board_bounds.gap_size;
                println!("Updated max_row to {}", board_bounds.max_row);
            }
            
            if old_bounds.min_col != board_bounds.min_col || old_bounds.max_col != board_bounds.max_col ||
               old_bounds.min_row != board_bounds.min_row || old_bounds.max_row != board_bounds.max_row {
                println!("Bounds updated, writing to world");
                world.write_model(@board_bounds);
            } else {
                println!("No bounds update needed");
            }
            
            // Check if the placed tile has a prize
            println!("Checking for prizes...");
            match player_data.first_tile_placed {
                Option::Some(position) => {
                    println!("First tile position: col={}, row={}", position.col, position.row);
                    println!("Checking prize at current position: col={}, row={}", col, row);
                    match has_prize_at(
                        player_address,
                        col,
                        row,
                        position.col,
                        position.row,
                        season_id,
                    ) {
                        Option::Some(prize) => {
                            println!("Prize found: {:?}", prize);
                            let rewards_manager_dispatcher = world.rewards_manager_dispatcher();
                            rewards_manager_dispatcher
                                .transfer_rewards(
                                    player_address,
                                    prize
                                );
                            println!("Prize transferred to player");
                        },
                        Option::None => {
                            println!("No prize at this position");
                        }
                    }
                },
                Option::None => {
                    println!("No first tile placed yet, skipping prize check");
                }
            }
            
            println!("=== DEBUG place_tile END ===");
        }

        fn get_random_deck(ref self: ContractState, player_address: ContractAddress) {
            self.current_season_id.write(1000000000); // Assuming a default season ID for simplicity
            let mut world = self.world_default();
            let season_id = self.current_season_id.read();
            let mut player_data: MetagamePlayerData = world.read_model((season_id, player_address));
            let mut new_deck = array![];
            let mut random_deck = DeckTrait::new('SEED', 24);
            // Generate a random deck of tiles for the player
            for i in 0..5_u8 { // Assuming a deck size of 20 tiles
                let tile = random_deck.draw();
                new_deck.append(tile);
            };
            player_data.deck = new_deck.span();
            world.write_model(@player_data);
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> WorldStorage {
            self.world(@"evolute_duel")
        }
    }
}