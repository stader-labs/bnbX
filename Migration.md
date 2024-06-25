## BSC Fusion Migration

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
