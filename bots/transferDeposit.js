const { BncClient } = require("@binance-chain/javascript-sdk");
const AWS = require("aws-sdk");

module.exports = async function transferDeposit(settings) {
  // AWS tools
  const secretClient = new AWS.SecretsManager({
    region: settings.secretRegion,
  });
  const secretResponse = await secretClient
    .getSecretValue({
      SecretId: settings.secretId,
    })
    .promise();

  // BC tools
  const client = new BncClient(settings.rpcBC);
  const secret = JSON.parse(secretResponse.SecretString);
  client.chooseNetwork("mainnet");
  await client.setPrivateKey(secret["bc-deposit"]);
  await client.initChain();

  const stakingWalletAddress = client.getClientKeyAddress();
  console.log("Staking wallet address:", stakingWalletAddress);

  const nowUnix = Math.floor(new Date().getTime() / 1000);
  const weekBeforeUnix = Math.floor(
    (new Date().getTime() - 24 * 60 * 60 * 1000 * 25) / 1000
  ); // 7 days

  console.log(weekBeforeUnix);
  const tx = await client.getTxs(stakingWalletAddress, weekBeforeUnix, nowUnix);
  console.log(tx);

  const message = "A note to you"; // memo string

  return null;
};
