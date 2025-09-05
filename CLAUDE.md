# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is **Evolute Kingdom: Mage Duel**, a sophisticated on-chain strategy game built with Cairo/Starknet using the Dojo engine v1.6.0-alpha.2. It's a territory-based tile placement game with multiple game modes, tournament systems, and complex token economics.

## Development Commands

### Building and Testing
```bash
# Build the project (use sozo, not scarb)
sozo build

# Run all tests
sozo test

# Run specific test
sozo test -f test_name
# or
sozo test --filter test_name

# Migrate (build + deploy)
sozo migrate
# or
scarb run migrate
```

### Game Commands (via Scarb scripts)
```bash
# Create and join games
scarb run create_game
scarb run join_game

# Tournament operations  
scarb run tournament_initializer
scarb run create_tournament

# Player profile actions
scarb run balance
scarb run change_username
scarb run set_balance
```

### Linting and Type Checking
- Run `sozo build` for compilation and type checking (not `scarb build`)
- Cairo uses strict typing - all types must be explicitly declared

## Architecture Overview

### Core Game System
The game is built around a **multi-modal system** supporting 4 distinct game modes:

1. **Tutorial Mode**: Guided learning experience
2. **Casual Mode**: Quick matches, 5x5 boards  
3. **Ranked Mode**: Competitive ELO-based matchmaking, 8x8 boards
4. **Tournament Mode**: Structured competitions with prizes, 10x10 boards

### Game Flow
```
Creating → Reveal → Move → Finished
```

Each game progresses through phases with time limits. Players place tiles strategically to control territory, using a union-find algorithm for scoring connected regions.

### Tournament Architecture

The tournament system has **dual integration**:

**Budokan Tournament Management** (External)
- Tournament creation, entry, prizes
- Leaderboards and scoring
- Entry fee collection (EVLT tokens)

**Tournament Token System** (Internal) 
- NFT-based tournament passes
- 4-phase lifecycle: `enlist` → `start` → `join_duel` → `end`
- Automatic matchmaking integration

### Token Economics

**EVLT Token** (`src/systems/tokens/evlt_token.cairo`)
- Main premium currency (18 decimals)
- Used for: entry fees, jokers, premium features
- Minting controlled by admin addresses

**eEVLT (Tournament Token)** (`src/systems/tokens/tournament_token.cairo`)
- Free tournament games (no decimals) 
- 1 eEVLT = 1 game entry
- Auto-distributed to tournament participants

**Tournament Pass NFTs**
- ERC721 tokens representing tournament registration
- Required for tournament matchmaking
- Managed via Tournament Token contract

### Key Systems

**Matchmaking** (`src/systems/matchmaking.cairo`)
- Universal system handling all game modes
- Queue management with automatic opponent pairing
- ELO rating integration for ranked matches

**Game Engine** (`src/systems/game.cairo`)
- Core game logic, move validation, scoring
- Multi-phase game state management
- Tile placement and territory control

**Player Profiles** (`src/systems/player_profile_actions.cairo`)
- Username management, balance tracking
- Skin selection, achievement progress
- Migration support for account upgrades

### Data Models

**Game Models** (`src/models/game.cairo`)
- `Game`: Core game state and player info
- `Board`: 2D grid state with tile placements  
- `Move`: Individual player actions
- `Rules`: Game mode configurations

**Tournament Models** (`src/models/tournament.cairo`)  
- `TournamentPass`: NFT metadata and states
- `TournamentStateModel`: Current tournament phase
- `PlayerTournamentIndex`: Player-tournament associations

**Player Models** (`src/models/player.cairo`)
- `Player`: Profile data, ratings, balances
- `PlayerAssignment`: Game room assignments

### External Dependencies

**Budokan Tournaments** (`tournaments` package)
- Professional tournament management system
- Prize distribution and leaderboards
- Entry requirement validation

**Alexandria Math** (`alexandria_math`)
- Advanced mathematical operations
- Used for complex scoring calculations

**OpenZeppelin** (`openzeppelin_*`)
- Standard ERC20/ERC721 implementations
- Access control and security patterns

### Configuration Files

**dojo_dev.toml** - Development environment
- Local Katana node configuration
- Contract deployment settings
- Writer permissions for systems

**Scarb.toml** - Build configuration  
- Cairo 2.10.1 with Dojo dependencies
- External contract integrations
- Deployment scripts and commands

### Payment Flow Architecture

The game uses a sophisticated **dual-token payment system**:

1. **EVLT Payment Path**: Premium games, tournaments
2. **eEVLT Fallback Path**: Free tournament games  
3. **Automatic Fallback**: If EVLT insufficient, tries eEVLT
4. **Queue Integration**: Payment verification before matchmaking

### Testing Strategy

**Integration Tests** (`src/tests/`)
- `test_tournament_system.cairo`: End-to-end tournament flows
- `test_evlt_token.cairo`: Token mechanics
- `test_matchmaking.cairo`: Queue and pairing logic

**Test Utilities**
- Mock tournament dispatchers for isolated testing
- Standardized test constants (addresses, amounts)
- Comprehensive game state verification

### Client Integration

**TypeScript Bindings**: Generated from Cairo contracts
**Unity Integration**: C# bindings for game client  
**Web3 Integration**: Starknet.js for browser clients

### Deployment Environments

- **Development**: Local Katana node
- **Testing**: Internal test networks  
- **Provable**: Production-ready deployment
- **Release**: Full production environment

### Important Development Notes

- **Use sozo commands**: Always use `sozo build` and `sozo test`, not `scarb build` or `scarb test`
- **Time-sensitive Operations**: Games and tournaments have strict timing requirements
- **State Synchronization**: Multiple systems must coordinate (game, tournament, tokens)
- **Gas Optimization**: Complex operations require careful gas management  
- **Error Handling**: Comprehensive error types for different failure modes
- **Upgradability**: Contracts designed for iterative improvements

### Common Development Patterns

- **Component Architecture**: Dojo systems with embedded components
- **Event-Driven**: Comprehensive event logging for client sync
- **Permission-Based**: Role-based access control throughout
- **Fallback Mechanisms**: Graceful degradation for payment/matching failures