# Evolute Kingdom: Mage Duel

Evolute Kingdom: Mage Duel is an on-chain game, built on Starknet using the [Dojo Engine](https://github.com/dojoengine/dojo)

Unity client: https://github.com/evolute-studio/territory-wars-unity-client

Playbook (Lore and Game Rules): https://evolute.notion.site/playbook

Play Evolute Kingdom - Mage Duel 👉 https://mageduel.evolute.network/

# Documentation
Full documentation for both the client and the server can be found here:

https://docs.mageduel.evolute.network/

# Development Setup

To start development, install `cairo` and the necessary toolchain using the [Cairo installation guide](https://book.cairo-lang.org/ch01-01-installation.html). Then, install the latest Dojo toolchain by following the [Dojo installation guide](https://book.dojoengine.org/getting-started). After setup, you will have access to:

- [Sozo](https://book.dojoengine.org/toolchain/sozo) – the development tool for building and deploying smart contracts.
- [Katana](https://book.dojoengine.org/toolchain/katana) – a local Starknet sequencer for testing.
- [Torii](https://book.dojoengine.org/toolchain/torii) – an indexer for querying on-chain data.

# **Building and Running the Project**

1. **Build the project**
    
    ```bash
    sozo build
    ```
    
2. **Start the Starknet sequencer (Katana) in development mode**
    
    ```bash
    katana --dev --dev.no-fee
    ```
    
3. **Migrate the world** (deploy contracts to Katana and obtain the world address)
    
    ```bash
    sozo migrate
    ```
    
    Example output:
    
    ```bash
    🌍 World deployed at block 2 with txn hash: 0x0586002f82db7f903d2fc60edafde45a23d2e40d37dd4192e1d2952fc61c254f
    ⛩️  Migration successful with world at address 0x06a4d87ac4a224fbc633b46ec896545f8783cfc6d87ce8a4ef8c5630a3c17711
    ```
    
4. **Start the Torii indexer**
    
    ```bash
    torii --world <World Address>
    ```
    
    - This launches:
        - A GraphQL API at `http://localhost:8080/graphql`
        - A gRPC API at `http://localhost:8080`
5. **Interact with the game using Sozo scripts**
Predefined scripts in `Scarb.toml` allow local testing:
    
    ```bash
    #Creates the game by predeployed player account
    scarb run create_game
    
    #Joins the game from another player account and game started
    scarb run join_game
    
    #First player makes a move
    scarb run make_move1
    
    #Second player makes a move
    scarb run make_move2
    # and so on...
    ```
    
## Repository Links:

- [Client](https://github.com/evolute-studio/mage-duel-client)

- [Server](https://github.com/evolute-studio/mage-duel-onchain)

- [Wrapper Web Application](https://github.com/evolute-studio/mage-duel-webgl)