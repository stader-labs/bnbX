const startDelegation = require("./startDelegation");
const completeDelegation = require("./completeDelegation");

const settings = {
  stakeManagerAddress: process.env.STAKE_MANAGER_ADDRESS,
  rpc: process.env.RPC,
  queueUrl: process.env.QUEUE_URL,
  secretId: process.env.SECRET_ID,
  secretRegion: process.env.SECRET_REGION,
  stakeManagerAbi: [
    {
      inputs: [],
      name: "getContracts",
      outputs: [
        {
          internalType: "address",
          name: "_bnbX",
          type: "address",
        },
        {
          internalType: "address",
          name: "_tokenHub",
          type: "address",
        },
        {
          internalType: "address",
          name: "_bcDepositWallet",
          type: "address",
        },
      ],
      stateMutability: "view",
      type: "function",
    },
    {
      inputs: [],
      name: "startDelegation",
      outputs: [
        {
          internalType: "uint256",
          name: "",
          type: "uint256",
        },
      ],
      stateMutability: "nonpayable",
      type: "function",
    },
    {
      inputs: [
        {
          internalType: "uint256",
          name: "uuid",
          type: "uint256",
        },
      ],
      name: "completeDelegation",
      outputs: [],
      stateMutability: "nonpayable",
      type: "function",
    },
  ],
};

// Handler
exports.handler = async function (event, context) {
  try {
    console.log("stakeManagerAddress:", settings.stakeManagerAddress);
    console.log("rpc:", settings.rpc);
    console.log("queueUrl:", settings.queueUrl);
    console.log("secretId:", settings.secretId);
    console.log("secretRegion:", settings.secretRegion);
    console.log("event:", event);

    let result = null;
    switch (event.type) {
      case "startDelegation":
        result = await startDelegation(settings);
        break;
      case "completeDelegation":
        result = await completeDelegation(settings, event.content);
        break;
      default:
        context.fail("Unsupported event type");
        break;
    }

    context.succeed(result);
  } catch (err) {
    context.fail(err);
  }
};
