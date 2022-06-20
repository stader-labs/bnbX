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

module.exports = { isDepositTx, isDelegateTx, getUnstakedDepositTxs };
