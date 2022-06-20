const AWS = require("aws-sdk");
const { ethers, BigNumber } = require("ethers");

const { CustomBncClient } = require("./CustomBncClient.js");
const { isDepositTx } = require("./utils.js");

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
  const secret = JSON.parse(secretResponse.SecretString);

  // BC tools
  const client = new CustomBncClient(settings.rpcBC, secret["bc-deposit"]);
  await client.init();

  const depositWalletAddress = client.getClientKeyAddress();
  console.log("Deposit wallet address:", depositWalletAddress);

  const stakingWalletAddress = client.getAddressFromPrivateKey(
    secret["bc-staking"]
  );
  console.log("Staking wallet address:", stakingWalletAddress);

  const transactions = await client.getTransactions(depositWalletAddress);
  const depositTxs = transactions.filter((tx) =>
    isDepositTx(tx, depositWalletAddress)
  );
  console.log("Deposit txs:", depositTxs);

  // BSC tools
  const provider = new ethers.providers.JsonRpcProvider(settings.rpcBSC);
  const stakeManagerContract = new ethers.Contract(
    settings.stakeManagerAddress,
    settings.stakeManagerAbi,
    provider
  );
  const requests = await getUncompletedDelegateRequests(stakeManagerContract);
  console.log("Uncompleted delegate requests", requests);

  for (const request of requests) {
    if (isAlreadyTransferred(request, depositTxs)) continue;
    const response = await client.transfer({
      toAddress: stakingWalletAddress,
      amount: request.amount,
      memo: request.uuid,
    });
    console.log(response);
  }
};

async function getUncompletedDelegateRequests(stakeManagerContract) {
  const requests = [];
  for (let uuid = 0; ; uuid++) {
    const { startTime, endTime, amount } =
      await stakeManagerContract.getBotDelegateRequest(uuid);
    const amountInEther = ethers.utils.formatEther(amount.toString());

    if (startTime.eq(BigNumber.from(0))) break;
    if (endTime.eq(BigNumber.from(0))) {
      requests.push({ amount: amountInEther, uuid: uuid });
    }
  }

  return requests;
}

function isAlreadyTransferred(request, txs) {
  for (const tx of txs) {
    if (tx.memo === request.uuid) {
      if (tx.amount !== request.amount) {
        throw new Error(
          `Amount is mismatching with BSC delegate request expected: ${request.amount} got: tx.amount`
        );
      }
      return true;
    }
  }

  return false;
}
