import { BNBx, STAKE_MANAGER } from "../../constants";

const BEP20_TRANSFER_EVENT =
  "event Transfer(address indexed from, address indexed to, uint256 value)";
const REQUEST_WITHDRAW_EVENT =
  "event RequestWithdraw(address indexed _account, uint256 _amountInBnbX)";
const REWARD_EVENT = "event Redelegate(uint256 _rewardsId, uint256 _amount)";

const BNBX_MINT_THRESHOLD = "500";
const BNBX_UNSTAKE_THRESHOLD = "500";
const MIN_REWARD_THRESHOLD = "1";
const MAX_REWARD_THRESHOLD = "20";

export {
  BNBx,
  STAKE_MANAGER,
  BEP20_TRANSFER_EVENT,
  REQUEST_WITHDRAW_EVENT,
  REWARD_EVENT,
  BNBX_MINT_THRESHOLD,
  BNBX_UNSTAKE_THRESHOLD,
  MIN_REWARD_THRESHOLD,
  MAX_REWARD_THRESHOLD,
};
