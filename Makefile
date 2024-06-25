# include .env file and export its env vars
# (-include to ignore error if it does not exist)
# Note that any unset variables here will wipe the variables if they are set in
# .zshrc or .bashrc. Make sure that the variables are set in .env, especially if
# you're running into issues with fork tests
include .env

# add your private key using below command
# cast wallet import devKey --interactive

# deploy contracts for kelp june upgrade
migrate-mainnet :; forge script script/foundry-scripts/migration/Migration.s.sol:Migration --rpc-url ${BSC_MAINNET_RPC_URL} --account devKey --sender ${DEV_PUB_ADDR}  --broadcast --etherscan-api-key ${BSC_SCAN_API_KEY} --verify  -vvv
migrate-local-test :; forge script script/foundry-scripts/migration/Migration.s.sol:Migration --rpc-url http://127.0.0.1:8545 --account devKey --sender ${DEV_PUB_ADDR} -vvv