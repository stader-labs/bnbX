const AWS = require("aws-sdk");
const { ethers } = require("ethers");

const { CustomBncClient } = require("./CustomBncClient.js");
const { isDelegateTx } = require("./utils.js");

module.exports = async function startDelegation(settings) {
  // AWS tools
  const secretClient = new AWS.SecretsManager({
    region: settings.secretRegion,
  });
  const secretResponse = await secretClient
    .getSecretValue({
      SecretId: settings.secretId,
    })
    .promise();
  const secret = JSON.parse(secretResponse.SecretString);

  // BC tools
  const client = new CustomBncClient(settings.rpcBC);
  await client.init();

  const stakingWalletAddress = client.getAddressFromPrivateKey(
    secret["bc-staking"]
  );
  console.log("Staking wallet address:", stakingWalletAddress);

  const transactions = await client.getTransactions(stakingWalletAddress);
  const delegateTxs = transactions.filter((tx) => isDelegateTx(tx));
  console.log("Delegate txs:", delegateTxs);

  // BSC tools
  const provider = new ethers.providers.JsonRpcProvider(settings.rpcBSC);
  const depositBotWallet = new ethers.Wallet(secret.bsc, provider);
  const stakeManagerContractConnected = new ethers.Contract(
    settings.stakeManagerAddress,
    settings.stakeManagerAbi,
    depositBotWallet
  );
  for (const tx of delegateTxs) {
    const response = await stakeManagerContractConnected.completeDelegation(
      tx.memo
    );
    console.log(response);
  }
};
