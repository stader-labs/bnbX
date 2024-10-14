# BNBx

## Description

Staderlabs Liquid Staking Product on BSC

## Contracts

### Mainnet

| Name             | Address                                    |
| ---------------- | ------------------------------------------ |
| StakeManagerV2   | 0x3b961e83400D51e6E1AF5c450d3C7d7b80588d28 |
| OperatorRegistry | 0x9C1759359Aa7D32911c5bAD613E836aEd7c621a8 |

### Testnet

| Name             | Address                                    |
| ---------------- | ------------------------------------------ |
| BNBx Token       | 0x6cd3f51A92d022030d6e75760200c051caA7152A |
| StakeManagerV2   | 0x1632E7D92763e7E0A1ABE5b3e9c2A808aeCcbD57 |
| OperatorRegistry | 0x0735aD824354A919Ef32D3157505B7C3bc05e3f6 |

## Development

### 1. setup

import wallet with cast

```bash
cast wallet import devKey --interactive
```

prepare env variables
copy `.env.example` to `.env` and fill it

### 2. compile contracts

```bash
forge build
```

### 3. run tests

```bash
forge test
```

### 4. run script on local

run mainnet fork using anvil

```bash
source .env
anvil --fork-url $BSC_MAINNET_RPC_URL
```

open a new terminal

```bash
make migrate-local-test
```

### 5. run script on mainnet

```bash
make migrate-mainnet
```
