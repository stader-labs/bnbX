const { ethers } = require("ethers");
const AWS = require("aws-sdk");

module.exports = async function startDelegation(settings) {
  // AWS tools
  const sqs = new AWS.SQS();
  const secretClient = new AWS.SecretsManager({
    region: settings.secretRegion,
  });
  const secretResponse = await secretClient
    .getSecretValue({
      SecretId: settings.secretId,
    })
    .promise();

  // BSC tools
  const provider = new ethers.providers.JsonRpcProvider(settings.rpc);
  const secret = JSON.parse(secretResponse.SecretString);
  const depositBotWallet = new ethers.Wallet(secret.key, provider);
  const stakeManagerContractConnected = new ethers.Contract(
    settings.stakeManagerAddress,
    settings.stakeManagerAbi,
    depositBotWallet
  );
  const response = await stakeManagerContractConnected.startDelegation();
  console.log(response);

  const params = {
    MessageAttributes: {
      Title: {
        DataType: "String",
        StringValue: "The Whistler",
      },
      Author: {
        DataType: "String",
        StringValue: "John Grisham",
      },
      WeeksOn: {
        DataType: "Number",
        StringValue: "6",
      },
    },
    MessageBody: "a",
    MessageDeduplicationId: "DeduplicationId1",
    MessageGroupId: "Group1",
    QueueUrl: settings.queueUrl,
  };

  return sqs.sendMessage(params).promise();
};
