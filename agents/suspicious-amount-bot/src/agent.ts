import {
  Finding,
  HandleTransaction,
  TransactionEvent,
  FindingSeverity,
  FindingType,
  ethers,
} from "forta-agent";

export const BEP20_TRANSFER_EVENT =
  "event Transfer(address indexed from, address indexed to, uint256 value)";
export const REQUEST_WITHDRAW_EVENT =
  "event RequestWithdraw(address indexed _account, uint256 _amountInBnbX)";

export const BNBx = "0x1bdd3Cf7F79cfB8EdbB955f20ad99211551BA275";
export const STAKE_MANAGER = "0x7276241a669489E4BBB76f63d2A43Bfe63080F2F";

export const BNBX_MINT_THRESHOLD = "50";
export const BNBX_UNSTAKE_THRESHOLD = "10";

const handleTransaction: HandleTransaction = async (
  txEvent: TransactionEvent
) => {
  const findings: Finding[] = [];

  // filter the transaction logs for BNBx mint events
  const bnbxMintEvents = txEvent
    .filterLog(BEP20_TRANSFER_EVENT, BNBx)
    .filter((transferEvent) => {
      const { from } = transferEvent.args;
      return from === "0x0000000000000000000000000000000000000000";
    });

  bnbxMintEvents.forEach((mintEvent) => {
    const { to, value } = mintEvent.args;

    const normalizedValue = ethers.utils.formatEther(value);
    const minThreshold = ethers.utils.parseEther(BNBX_MINT_THRESHOLD);

    if (value.gt(minThreshold)) {
      findings.push(
        Finding.fromObject({
          name: "High BNBx Mint",
          description: `High amount of BNBx minted: ${normalizedValue}`,
          alertId: "BNBx-1",
          severity: FindingSeverity.High,
          type: FindingType.Info,
          metadata: {
            to,
            value,
          },
        })
      );
    }
  });

  // filter the transaction logs for BNBx unstake events
  const bnbxUnstakeEvents = txEvent.filterLog(
    REQUEST_WITHDRAW_EVENT,
    STAKE_MANAGER
  );

  bnbxUnstakeEvents.forEach((unstakeEvents) => {
    const { _account, _amountInBnbX } = unstakeEvents.args;

    const normalizedValue = ethers.utils.formatEther(_amountInBnbX);
    const minThreshold = ethers.utils.parseEther(BNBX_UNSTAKE_THRESHOLD);

    if (_amountInBnbX.gt(minThreshold)) {
      findings.push(
        Finding.fromObject({
          name: "High BNBx Unstake",
          description: `High amount of BNBx unstaked: ${normalizedValue}`,
          alertId: "BNBx-2",
          severity: FindingSeverity.High,
          type: FindingType.Info,
          metadata: {
            _account,
            _amountInBnbX,
          },
        })
      );
    }
  });

  return findings;
};

// const handleBlock: HandleBlock = async (blockEvent: BlockEvent) => {
//   const findings: Finding[] = [];
//   // detect some block condition
//   return findings;
// }

export default {
  handleTransaction,
  // handleBlock
};
