const protocol = "BNBx Stader";
const BNBx = "0x1bdd3Cf7F79cfB8EdbB955f20ad99211551BA275";
const STAKE_MANAGER = "0x7276241a669489E4BBB76f63d2A43Bfe63080F2F";

const BEP20_TRANSFER_EVENT =
  "event Transfer(address indexed from, address indexed to, uint256 value)";
const REQUEST_WITHDRAW_EVENT =
  "event RequestWithdraw(address indexed _account, uint256 _amountInBnbX)";
const REWARD_EVENT = "event Redelegate(uint256 _rewardsId, uint256 _amount)";

const BNBX_MINT_THRESHOLD = "500";
const BNBX_UNSTAKE_THRESHOLD = "500";
const MIN_REWARD_THRESHOLD = "1";
const MAX_REWARD_THRESHOLD = "20";

const BNBX_SUPPLY_CHANGE_PCT = 10;
const BNBX_SUPPLY_CHANGE_HOURS = 1;

export {
  protocol,
  BNBx,
  STAKE_MANAGER,
  BEP20_TRANSFER_EVENT,
  REQUEST_WITHDRAW_EVENT,
  REWARD_EVENT,
  BNBX_MINT_THRESHOLD,
  BNBX_UNSTAKE_THRESHOLD,
  MIN_REWARD_THRESHOLD,
  MAX_REWARD_THRESHOLD,
  BNBX_SUPPLY_CHANGE_PCT,
  BNBX_SUPPLY_CHANGE_HOURS,
};
