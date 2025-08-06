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
                mountains::game_integration::{is_position_mountain_for_nearby_prizes},
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
            println!("[PLACE_TILE] === Starting place_tile method ===");
            println!("[PLACE_TILE] Input parameters: tile_index={}, col={}, row={}, rotation={}", tile_index, col, row, rotation);
            
            println!("[PLACE_TILE] Setting season ID...");
            self.current_season_id.write(1000000000); // Assuming a default season ID for simplicity
            let mut world = self.world_default();
            let season_id = self.current_season_id.read();
            println!("[PLACE_TILE] Season ID set to: {}", season_id);
            
            // Retrieve the current board bounds
            println!("[PLACE_TILE] Reading board bounds from world...");
            let mut board_bounds: MetagameBoardBounds = world.read_model(season_id);
            println!("[PLACE_TILE] Board bounds retrieved:");
            println!("[PLACE_TILE]   min_col: {}", board_bounds.min_col);
            println!("[PLACE_TILE]   max_col: {}", board_bounds.max_col);
            println!("[PLACE_TILE]   min_row: {}", board_bounds.min_row);
            println!("[PLACE_TILE]   max_row: {}", board_bounds.max_row);
            println!("[PLACE_TILE]   gap_size: {}", board_bounds.gap_size);
            
            // Check if the tile placement is within bounds
            println!("[PLACE_TILE] Performing bounds validation...");
            println!("[PLACE_TILE] Checking col bounds: {} >= {} && {} <= {}", col, board_bounds.min_col, col, board_bounds.max_col);
            println!("[PLACE_TILE] Checking row bounds: {} >= {} && {} <= {}", row, board_bounds.min_row, row, board_bounds.max_row);
            
            let col_in_bounds = col >= board_bounds.min_col && col <= board_bounds.max_col;
            let row_in_bounds = row >= board_bounds.min_row && row <= board_bounds.max_row;
            println!("[PLACE_TILE] Col in bounds: {}", col_in_bounds);
            println!("[PLACE_TILE] Row in bounds: {}", row_in_bounds);
            
            if !col_in_bounds || !row_in_bounds {
                println!("[PLACE_TILE] ERROR: Tile placement out of bounds!");
                println!("[PLACE_TILE] Target position: ({}, {})", col, row);
                println!("[PLACE_TILE] Valid bounds: col [{}, {}], row [{}, {}]", 
                    board_bounds.min_col, board_bounds.max_col, board_bounds.min_row, board_bounds.max_row);
                panic!("Tile placement out of bounds");
            }
            println!("[PLACE_TILE] PASSED: Bounds check successful");

            println!("[PLACE_TILE] Getting caller address...");
            let player_address = get_caller_address();
            println!("[PLACE_TILE] Player address: {:?}", player_address);
            
            // Retrieve or create the player's deck
            println!("[PLACE_TILE] Reading player data from world...");
            let mut player_data: MetagamePlayerData = world.read_model((season_id, player_address));
            println!("[PLACE_TILE] Player data retrieved:");
            println!("[PLACE_TILE]   deck_len: {}", player_data.deck.len());
            println!("[PLACE_TILE]   tiles_placed: {}", player_data.tiles_placed);
            println!("[PLACE_TILE]   first_tile_placed: {:?}", player_data.first_tile_placed);
            
            println!("[PLACE_TILE] Validating tile index...");
            if tile_index >= player_data.deck.len() {
                println!("[PLACE_TILE] ERROR: Invalid tile index {} >= deck length {}", tile_index, player_data.deck.len());
                panic!("Invalid tile index");
            }
            println!("[PLACE_TILE] PASSED: Tile index {} is valid (deck size: {})", tile_index, player_data.deck.len());

            let tile = *player_data.deck[tile_index];
            println!("[PLACE_TILE] Selected tile from deck[{}]: {:?}", tile_index, tile);

            if player_data.first_tile_placed.is_some() {
                match player_data.first_tile_placed {
                    Option::Some(first_pos) => {
                        println!("[PLACE_TILE] Checking for mountains at target position ({}, {})", col, row);
                        
                        let is_blocked_by_mountain = is_position_mountain_for_nearby_prizes(
                            col,
                            row,
                            player_address,
                            first_pos.col,
                            first_pos.row,
                            season_id
                        );
                        
                        if is_blocked_by_mountain {
                            println!("[PLACE_TILE] ERROR: Cannot place tile on mountain position");
                            panic!("Cannot place tile on mountain");
                        }
                        
                        println!("[PLACE_TILE] PASSED: Position is not blocked by mountains");
                    },
                    Option::None => {
                        println!("[PLACE_TILE] No first tile yet, skipping mountain check");
                    }
                }
            } else {
                println!("[PLACE_TILE] First tile placement, skipping mountain check");
            }
            
            println!("[PLACE_TILE] Preparing to call is_valid_move...");
            println!("[PLACE_TILE] is_valid_move parameters:");
            println!("[PLACE_TILE]   board_id (season_id): {}", self.current_season_id.read());
            println!("[PLACE_TILE]   tile: {:?}", tile);
            println!("[PLACE_TILE]   rotation: {}", rotation);
            println!("[PLACE_TILE]   position: col={}, row={}", col, row);
            println!("[PLACE_TILE]   board_size: {}", BOARD_SIZE);
            println!("[PLACE_TILE]   bounds: min_col={}, min_row={}, max_col={}, max_row={}", 
                board_bounds.min_col, board_bounds.min_row, board_bounds.max_col, board_bounds.max_row);
            println!("[PLACE_TILE]   can_place_not_adjacents (is_first_tile): {}", player_data.tiles_placed == 0);
            
            println!("[PLACE_TILE] Calling is_valid_move...");
            let is_move_valid = is_valid_move(
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
            );
            
            println!("[PLACE_TILE] is_valid_move returned: {}", is_move_valid);
            if !is_move_valid {
                println!("[PLACE_TILE] ERROR: Invalid move detected by is_valid_move");
                panic!("Invalid move");
            }
            println!("[PLACE_TILE] PASSED: Move validation successful");

            // Create the tile placement logic here
            println!("[PLACE_TILE] Starting tile placement scoring...");
            println!("[PLACE_TILE] Calling ScoringImpl::calculate_move_scoring...");
            ScoringImpl::calculate_move_scoring(
                tile.into(),
                rotation,
                col,
                row,
                PlayerSide::Blue,  // TODO: Think about player side
                player_address,
                self.current_season_id.read(),
                BOARD_SIZE,
                world.clone()
            );
            println!("[PLACE_TILE] COMPLETED: Scoring calculation");

            // println!("[PLACE_TILE] Updating player deck...");
            // println!("[PLACE_TILE] Removing tile at index {} from deck of {} tiles", tile_index, player_data.deck.len());
            // let mut new_player_deck = array![];
            // for i in 0..player_data.deck.len() {
            //     if i != tile_index {
            //         println!("[PLACE_TILE]   Keeping tile at index {}: {:?}", i, *player_data.deck[i]);
            //         new_player_deck.append(*player_data.deck[i]);
            //     } else {
            //         println!("[PLACE_TILE]   Removing tile at index {}: {:?}", i, *player_data.deck[i]);
            //     }
            // };
            // player_data.deck = new_player_deck.span();
            player_data.tiles_placed += 1;
            println!("[PLACE_TILE] Updated player data:");
            println!("[PLACE_TILE]   new deck length: {}", player_data.deck.len());
            println!("[PLACE_TILE]   tiles_placed: {}", player_data.tiles_placed);
            
            println!("[PLACE_TILE] Checking if this is the first tile placement...");
            if player_data.first_tile_placed.is_none() {
                println!("[PLACE_TILE] This is the FIRST tile - setting first_tile_placed position");
                println!("[PLACE_TILE] Setting first tile position to col={}, row={}", col, row);
                player_data.first_tile_placed = Option::Some(
                    Position {
                        col,
                        row
                    }
                );
            } else {
                match player_data.first_tile_placed {
                    Option::Some(pos) => {
                        println!("[PLACE_TILE] First tile already placed at col={}, row={}, keeping existing position", pos.col, pos.row);
                    },
                    Option::None => {
                        println!("[PLACE_TILE] This should not happen - first_tile_placed was None but condition failed");
                    }
                }
            }
            
            println!("[PLACE_TILE] Writing updated player data to world...");
            world.write_model(@player_data);
            println!("[PLACE_TILE] COMPLETED: Player data written to world");

            // Update bounds if necessary
            println!("[PLACE_TILE] Checking if board bounds need updating...");
            println!("[PLACE_TILE] Current bounds: min_col={}, max_col={}, min_row={}, max_row={}", 
                board_bounds.min_col, board_bounds.max_col, board_bounds.min_row, board_bounds.max_row);
            println!("[PLACE_TILE] Placed tile at: col={}, row={}", col, row);
            println!("[PLACE_TILE] Gap size: {}", board_bounds.gap_size);
                
            let old_bounds = board_bounds;
            let mut bounds_changed = false;
            
            println!("[PLACE_TILE] Checking min_col update: {} - {} < {}", col, board_bounds.gap_size, board_bounds.min_col);
            if col - board_bounds.gap_size < board_bounds.min_col {
                let new_min_col = col - board_bounds.gap_size;
                println!("[PLACE_TILE] Updating min_col from {} to {}", board_bounds.min_col, new_min_col);
                board_bounds.min_col = new_min_col;
                bounds_changed = true;
            }
            
            println!("[PLACE_TILE] Checking max_col update: {} + {} > {}", col, board_bounds.gap_size, board_bounds.max_col);
            if col + board_bounds.gap_size > board_bounds.max_col {
                let new_max_col = col + board_bounds.gap_size;
                println!("[PLACE_TILE] Updating max_col from {} to {}", board_bounds.max_col, new_max_col);
                board_bounds.max_col = new_max_col;
                bounds_changed = true;
            }
            
            println!("[PLACE_TILE] Checking min_row update: {} - {} < {}", row, board_bounds.gap_size, board_bounds.min_row);
            if row - board_bounds.gap_size < board_bounds.min_row {
                let new_min_row = row - board_bounds.gap_size;
                println!("[PLACE_TILE] Updating min_row from {} to {}", board_bounds.min_row, new_min_row);
                board_bounds.min_row = new_min_row;
                bounds_changed = true;
            }
            
            println!("[PLACE_TILE] Checking max_row update: {} + {} > {}", row, board_bounds.gap_size, board_bounds.max_row);
            if row + board_bounds.gap_size > board_bounds.max_row {
                let new_max_row = row + board_bounds.gap_size;
                println!("[PLACE_TILE] Updating max_row from {} to {}", board_bounds.max_row, new_max_row);
                board_bounds.max_row = new_max_row;
                bounds_changed = true;
            }
            
            if bounds_changed {
                println!("[PLACE_TILE] Bounds were updated - writing new bounds to world");
                println!("[PLACE_TILE] New bounds: min_col={}, max_col={}, min_row={}, max_row={}", 
                    board_bounds.min_col, board_bounds.max_col, board_bounds.min_row, board_bounds.max_row);
                world.write_model(@board_bounds);
            } else {
                println!("[PLACE_TILE] No bounds update needed");
            }
            
            // Check if the placed tile has a prize
            println!("[PLACE_TILE] Checking for prizes at placed position...");
            match player_data.first_tile_placed {
                Option::Some(position) => {
                    println!("[PLACE_TILE] First tile position for reference: col={}, row={}", position.col, position.row);
                    println!("[PLACE_TILE] Current tile position: col={}, row={}", col, row);
                    println!("[PLACE_TILE] Calling has_prize_at with:");
                    println!("[PLACE_TILE]   player_address: {:?}", player_address);
                    println!("[PLACE_TILE]   current_pos: ({}, {})", col, row);
                    println!("[PLACE_TILE]   first_tile_pos: ({}, {})", position.col, position.row);
                    println!("[PLACE_TILE]   season_id: {}", season_id);
                    
                    match has_prize_at(
                        player_address,
                        col,
                        row,
                        position.col,
                        position.row,
                        season_id,
                    ) {
                        Option::Some(prize) => {
                            println!("[PLACE_TILE] PRIZE FOUND! Prize details: {:?}", prize);
                            println!("[PLACE_TILE] Getting rewards manager dispatcher...");
                            let rewards_manager_dispatcher = world.rewards_manager_dispatcher();
                            println!("[PLACE_TILE] Transferring rewards to player...");
                            rewards_manager_dispatcher
                                .transfer_rewards(
                                    player_address,
                                    prize
                                );
                            println!("[PLACE_TILE] COMPLETED: Prize transferred to player");
                        },
                        Option::None => {
                            println!("[PLACE_TILE] No prize found at this position");
                        }
                    }
                },
                Option::None => {
                    println!("[PLACE_TILE] No first tile placed yet, skipping prize check");
                }
            }
            
            println!("[PLACE_TILE] === place_tile method completed successfully ===");
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