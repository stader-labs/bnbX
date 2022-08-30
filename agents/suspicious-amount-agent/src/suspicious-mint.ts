import {
  ethers,
  Finding,
  FindingSeverity,
  FindingType,
  HandleTransaction,
  TransactionEvent,
} from "forta-agent";
import {
  BEP20_TRANSFER_EVENT,
  BNBx,
  BNBX_MINT_THRESHOLD,
  protocol,
} from "./constants";

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
          protocol: protocol,
          severity: FindingSeverity.High,
          type: FindingType.Info,
          metadata: {
            to,
            value: value.toString(),
          },
        })
      );
    }
  });

  return findings;
};

export { handleTransaction };
