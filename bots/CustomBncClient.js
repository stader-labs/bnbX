const { ethers } = require("ethers");
const {
  BncClient,
  crypto,
  types,
  Transaction,
  amino,
} = require("@binance-chain/javascript-sdk");

class CustomBncClient {
  constructor(rpc, privateKey = null) {
    this.client = new BncClient(rpc);
    this.client.chooseNetwork("mainnet");

    if (privateKey) {
      this.client.setPrivateKey(privateKey);
    }

    this.client.useDefaultSigningDelegate();
    this.client.useDefaultBroadcastDelegate();
  }

  async init() {
    await this.client.initChain();
  }

  _parseTransactions(response) {
    console.log(`Parsing transactions: ${response}`);
    if (response == null || response.length === 0)
      throw new Error(`Emptry response: ${response}`);
    const result = response.result;
    if (result == null) throw new Error(`Result is empty: ${response}`);
    const transactions = result.tx;
    if (transactions === []) throw new Error(`No transaction: ${transactions}`);

    console.log("Transactions:", transactions);
    return transactions;
  }

  async getTransactions(address) {
    const response = await this.client.getTransactions(address);
    return this._parseTransactions(response);
  }

  async delegate({ validatorAddress, amount, memo }) {
    console.log(
      `Delegating ${amount} BNB to ${validatorAddress} with memo: ${memo}`
    );
    const delegateAddress = this.client.getClientKeyAddress();
    const delegateMessage = this.buildDelegateMsg({
      validatorAddress: validatorAddress,
      delegateAddress: delegateAddress,
      amount: amount,
    });

    const signedTx = await this.client._prepareTransaction(
      delegateMessage.getMsg(),
      delegateMessage.getSignMsg(),
      delegateAddress,
      null,
      memo.toString()
    );

    return await this.client._broadcastDelegate(signedTx);
  }

  buildDelegateMsg({ delegateAddress, validatorAddress, amount }) {
    if (!amount) {
      throw new Error("amount should not be empty");
    }

    if (!delegateAddress) {
      throw new Error("delegate address should not be null");
    }

    if (!crypto.checkAddress(validatorAddress, "bva")) {
      throw new Error("validator address is not valid");
    }

    const amountInBnb = Number(ethers.utils.parseUnits(amount, 8));
    return new types.BscDelegateMsg({
      delegator_addr: delegateAddress,
      validator_addr: validatorAddress,
      delegation: { denom: "BNB", amountInBnb },
      side_chain_id: "bsc",
    });
  }

  async transfer({ toAddress, amount, memo }) {
    console.log(
      `Sending ${amount} BNB to ${toAddress} with memo: ${memo} from ${this.getClientKeyAddress()}`
    );

    amount = Number(ethers.utils.parseUnits(amount, 8));

    const message = await this.buildtransferMsg({
      fromAddress: this.getClientKeyAddress(),
      toAddress: toAddress,
      amount: amount,
      denom: "BNB",
      memo: memo.toString(),
    });

    const tx = new Transaction(message);
    const signedTx = tx.sign(this.client.getPrivateKey());
    const txBytes = signedTx.serialize();
    return this.client.sendRawTransaction(txBytes);
  }

  async buildtransferMsg({ fromAddress, toAddress, amount, denom, memo }) {
    const outputs = [
      {
        address: toAddress,
        coins: [
          {
            denom: denom,
            amount: amount,
          },
        ],
      },
    ];
    const sendMsg = new types.SendMsg(fromAddress, outputs);

    const data = await this.client._httpClient.request(
      "get",
      `${this.client.api.getAccount}/${fromAddress}`
    );
    const sequence = data.result.sequence;
    this.client.account_number = data.result.account_number;

    return {
      chainId: "Binance-Chain-Tigris",
      accountNumber: this.client.account_number,
      sequence: sequence,
      baseMsg: sendMsg,
      memo: memo,
      source: this.client._source,
    };
  }

  getClientKeyAddress() {
    return this.client.getClientKeyAddress();
  }

  getAddressFromPrivateKey(address) {
    return crypto.getAddressFromPrivateKey(address, "bnb");
  }
}

module.exports = { CustomBncClient };
