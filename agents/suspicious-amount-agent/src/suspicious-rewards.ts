import {
  ethers,
  Finding,
  FindingSeverity,
  FindingType,
  HandleTransaction,
  TransactionEvent,
} from "forta-agent";
import {
  MAX_REWARD_THRESHOLD,
  MIN_REWARD_THRESHOLD,
  REWARD_EVENT,
  STAKE_MANAGER,
} from "./constants";

const handleTransaction: HandleTransaction = async (
  txEvent: TransactionEvent
) => {
  const findings: Finding[] = [];

  const bnbxRewardEvents = txEvent.filterLog(REWARD_EVENT, STAKE_MANAGER);

  bnbxRewardEvents.forEach((rewardEvents) => {
    const { _rewardsId, _amount } = rewardEvents.args;

    const normalizedValue = ethers.utils.formatEther(_amount);
    const minThreshold = ethers.utils.parseEther(MIN_REWARD_THRESHOLD);
    const maxThreshold = ethers.utils.parseEther(MAX_REWARD_THRESHOLD);

    if (_amount.lt(minThreshold)) {
      findings.push(
        Finding.fromObject({
          name: "Low BNBx Reward",
          description: `Low amount of BNBx Reward Received: ${normalizedValue}`,
          alertId: "BNBx-3",
          severity: FindingSeverity.High,
          type: FindingType.Info,
          metadata: {
            _rewardsId,
            _amount,
          },
        })
      );
    }

    if (_amount.gt(maxThreshold)) {
      findings.push(
        Finding.fromObject({
          name: "High BNBx Reward",
          description: `High amount of BNBx Reward Received: ${normalizedValue}`,
          alertId: "BNBx-4",
          severity: FindingSeverity.High,
          type: FindingType.Info,
          metadata: {
            _rewardsId,
            _amount,
          },
        })
      );
    }
  });

  return findings;
};

export { handleTransaction };
