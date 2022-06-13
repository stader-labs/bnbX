# bnbX

```shell
npx hardhat accounts
npx hardhat compile
npx hardhat clean
npx hardhat test
npx hardhat node
npx hardhat help
REPORT_GAS=true npx hardhat test
npx hardhat coverage
npx hardhat run scripts/deploy.ts
TS_NODE_FILES=true npx ts-node scripts/deploy.ts
npx eslint '**/*.{js,ts}'
npx eslint '**/*.{js,ts}' --fix
npx prettier '**/*.{json,sol,md}' --check
npx prettier '**/*.{json,sol,md}' --write
npx solhint 'contracts/**/*.sol'
npx solhint 'contracts/**/*.sol' --fix
```

## Deploying

To deploy contracts, run:

```bash
npx hardhat deployBnbXProxy <manager> --network <network>
npx hardhat deployBnbXImpl --network <network>
npx hardhat deployStakeManagerProxy <bnbX> <manager> <tokenHub> <bcDepositWallet> <bot> --network <network>
npx hardhat deployStakeManagerImpl --network <network>
```

## Verifying on etherscan

```bash
npx hardhat verify <address> <...args> --network <network>
```
