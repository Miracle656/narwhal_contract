# Narwhal Move Contracts 🐋

This package contains the **Sui Move** smart contracts that power the **Narwhal.net** ecosystem. It handles the creation of Dynamic NFTs (Avatars) and manages the decentralized game state.

## 📦 Modules

### 1. `avatar::avatar`
Defines the `Avatar` object and the logic for its lifecycle.
- **Dynamic Fields**: Uses dynamic fields to store upgradeable traits.
- **DNA Generation**: Deterministically generates unique DNA based on the minter's address.
- **Evolution**: Handles the logic for `evolve_avatar`, updating the `level` and visual attributes on-chain.

### 2. `game::game`
Manages the multiplayer lobby and game sessions.
- **Lobby Creation**: Allows users to spawn new game instances (`create_game`).
- **Joining**: Handles player entry into lobbies (`join_game`).
- **State Management**: Tracks active players and game status.

## 🛠 Development

### prerequisites
- [Sui CLI](https://docs.sui.io/guides/developer/getting-started/sui-install) installed.

### Build
To compile the contracts:
```bash
sui move build
```

### Test
Run the unit tests:
```bash
sui move test
```

### Publish
To deploy to the Sui network (Testnet/Mainnet):
```bash
sui client publish --gas-budget 100000000
```

## 🔗 Deployed Objects
*Keep track of your Package ID after publishing to update the frontend constants.*
