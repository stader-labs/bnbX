const { ethers } = require("ethers");
const { BncClient, crypto, types } = require("@binance-chain/javascript-sdk");
const AWS = require("aws-sdk");

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

  // BC tools
  const client = new BncClient(settings.rpcBC);
  const secret = JSON.parse(secretResponse.SecretString);
  client.chooseNetwork("mainnet");
  await client.setPrivateKey(secret["bc-staking"]);
  await client.initChain();

  const stakingWalletAddress = client.getClientKeyAddress();
  console.log("Staking wallet address:", stakingWalletAddress);

  const depositWalletAddress = crypto.getAddressFromPrivateKey(
    secret["bc-deposit"],
    "bnb"
  );
  console.log("Deposit wallet address:", depositWalletAddress);

  const response = await client.getTransactions(stakingWalletAddress);
  const transactions = parseTransactions(response);
  console.log("Transactions:", transactions);

  const unstakedDepositTxs = getUnstakedDepositTxs(
    transactions,
    depositWalletAddress
  );
  console.log("Unstaked Deposit Txs:", unstakedDepositTxs);

  for (const tx of unstakedDepositTxs) {
    console.log(
      `Delegating ${tx.value} BNB to ${validatorAddress} with memo: ${tx.memo}`
    );
    const delegateMessage = buildDelegateMsg({
      validatorAddress: validatorAddress,
      delegateAddress: stakingWalletAddress,
      amount: tx.value,
    });
    console.log(delegateMessage);

    const signedTx = await client._prepareTransaction(
      delegateMessage.getMsg(),
      delegateMessage.getSignMsg(),
      stakingWalletAddress,
      null,
      tx.memo
    );
    console.log(signedTx);

    const response = await client._broadcastDelegate(signedTx);
    console.log(response);
  }
};

function parseTransactions(response) {
  console.log(`Parsing transactions: ${response}`);
  if (response == null || response.length === 0)
    throw new Error(`Emptry response: ${response}`);
  const result = response.result;
  if (result == null) throw new Error(`Result is empty: ${response}`);
  const transactions = result.tx;
  if (transactions === []) throw new Error(`No transaction: ${transactions}`);

  return transactions;
}

// Staking

function buildDelegateMsg({ delegateAddress, validatorAddress, amount }) {
  if (!amount) {
    throw new Error("amount should not be empty");
  }

  if (!delegateAddress) {
    throw new Error("delegate address should not be null");
  }

  if (!crypto.checkAddress(validatorAddress, "bva")) {
    throw new Error("validator address is not valid");
  }

  amount = Number(ethers.utils.parseUnits(amount, 8));
  return new types.BscDelegateMsg({
    delegator_addr: delegateAddress,
    validator_addr: validatorAddress,
    delegation: { denom: "BNB", amount },
    side_chain_id: "bsc",
  });
}

// Transaction filtering

function isDepositTx(transaction, correctFromAddr) {
  if (transaction.txType !== "TRANSFER") return false;
  if (transaction.txAsset !== "BNB") return false;
  if (transaction.fromAddr !== correctFromAddr) return false;

  return true;
}

function isDelegateTx(transaction) {
  if (transaction.txType !== "DELEGATE") return false;
  if (transaction.txAsset !== "BNB") return false;

  return true;
}

function getUnstakedDepositTxs(transactions, correctFromAddr) {
  const depositTxs = transactions.filter((tx) =>
    isDepositTx(tx, correctFromAddr)
  );
  const delegateTxs = transactions.filter((tx) => isDelegateTx(tx));
  console.log("Deposit Txs", depositTxs);
  console.log("Delegate Txs", delegateTxs);

  const delegateMemos = delegateTxs.map(function (tx) {
    return tx.memo;
  });
  return depositTxs.filter((tx) => !delegateMemos.includes(tx.memo));
}
