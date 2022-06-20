const AWS = require("aws-sdk");

const { CustomBncClient } = require("./CustomBncClient.js");
const { getUnstakedDepositTxs } = require("./utils.js");

module.exports = async function doDelegation(settings, content) {
  const validatorAddress = content.validatorAddress;
  console.log("Validator Address:", validatorAddress);

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
  const client = new CustomBncClient(settings.rpcBC, secret["bc-staking"]);
  await client.init();

  const stakingWalletAddress = client.getClientKeyAddress();
  console.log("Staking wallet address:", stakingWalletAddress);

  const depositWalletAddress = client.getAddressFromPrivateKey(
    secret["bc-deposit"]
  );
  console.log("Deposit wallet address:", depositWalletAddress);

  const transactions = await client.getTransactions(stakingWalletAddress);
  const unstakedDepositTxs = getUnstakedDepositTxs(
    transactions,
    depositWalletAddress
  );
  console.log("Unstaked Deposit Txs:", unstakedDepositTxs);

  for (const tx of unstakedDepositTxs) {
    const response = await client.delegate({
      validatorAddress: validatorAddress,
      amount: tx.value,
      memo: tx.memo,
    });
    console.log(response);
  }
};
