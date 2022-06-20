const startDelegation = require("./startDelegation");
const completeDelegation = require("./completeDelegation");
const doDelegation = require("./doDelegation");
const transferDeposit = require("./transferDeposit");
const stakeManagerJson = require("./StakeManager.json");

const settings = {
  stakeManagerAddress: process.env.STAKE_MANAGER_ADDRESS,
  rpcBSC: process.env.RPC_BSC,
  rpcBC: process.env.RPC_BC,
  secretId: process.env.SECRET_ID,
  secretRegion: process.env.SECRET_REGION,
  stakeThreshold: process.env.STAKE_THRESHOLD_BNB,
  relayFee: process.env.RELAY_FEE,
  stakeManagerAbi: stakeManagerJson.abi,
};

// Handler
exports.handler = async function (event, context) {
  try {
    console.log("Starting bot");

    console.log("stakeManagerAddress:", settings.stakeManagerAddress);
    console.log("rpcBSC:", settings.rpcBSC);
    console.log("rpcBC:", settings.rpcBC);
    console.log("secretId:", settings.secretId);
    console.log("secretRegion:", settings.secretRegion);
    console.log("stakeThreshold", settings.stakeThreshold);
    console.log("relayFee", settings.relayFee);
    console.log("event:", event);

    let result = null;
    switch (event.type) {
      case "startDelegation":
        result = await startDelegation(settings);
        break;
      case "completeDelegation":
        result = await completeDelegation(settings);
        break;
      case "doDelegation":
        result = await doDelegation(settings, event.content);
        break;
      case "transferDeposit":
        result = await transferDeposit(settings);
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
