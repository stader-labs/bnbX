const { ethers } = require("ethers");
const AWS = require("aws-sdk");

module.exports = async function startDelegation(settings, content) {
  // AWS tools
  const secretClient = new AWS.SecretsManager({
    region: settings.secretRegion,
  });
  const secretResponse = await secretClient
    .getSecretValue({
      SecretId: settings.secretId,
    })
    .promise();
  const uuid = 123124;

  // BSC tools
  const provider = new ethers.providers.JsonRpcProvider(settings.rpc);
  const secret = JSON.parse(secretResponse.SecretString);
  const depositBotWallet = new ethers.Wallet(secret.key, provider);
  const stakeManagerContractConnected = new ethers.Contract(
    settings.stakeManagerAddress,
    settings.stakeManagerAbi,
    depositBotWallet
  );
  const response = await stakeManagerContractConnected.completeDelegation(uuid);
  console.log(response);

  return null;
};
