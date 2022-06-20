const { ethers } = require("ethers");
const AWS = require("aws-sdk");

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

  // BSC tools
  const provider = new ethers.providers.JsonRpcProvider(settings.rpcBSC);
  const secret = JSON.parse(secretResponse.SecretString);
  const depositBotWallet = new ethers.Wallet(secret.bsc, provider);
  const stakeManagerContractConnected = new ethers.Contract(
    settings.stakeManagerAddress,
    settings.stakeManagerAbi,
    depositBotWallet
  );

  const amountToStake = await stakeManagerContractConnected.totalUnstaked();
  const amountToStakeInBNB = ethers.utils.formatEther(amountToStake);
  const stakeThreshold = ethers.utils.parseEther(settings.stakeThreshold);
  console.log(`Amount to stake: ${amountToStakeInBNB} BNB`);
  if (amountToStake.lt(stakeThreshold)) {
    throw new Error(
      `Amount to stake ${amountToStakeInBNB} BNB is lower than required minimum of ${settings.stakeThreshold} BNB`
    );
  }

  const options = { value: ethers.utils.parseEther(settings.relayFee) };
  const response = await stakeManagerContractConnected.startDelegation(options);
  return response;
};
