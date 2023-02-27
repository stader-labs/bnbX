const protocol = "BNBx Stader";
const BNBx = "0x1bdd3Cf7F79cfB8EdbB955f20ad99211551BA275";
const STAKE_MANAGER = "0x7276241a669489E4BBB76f63d2A43Bfe63080F2F";
export const TIMELOCK_CONTRACT = "0xd990a252e7e36700d47520e46cd2b3e446836488";
export const PROXY_ADMIN = "0xF90e293D34a42CB592Be6BE6CA19A9963655673C";

const BEP20_TRANSFER_EVENT =
  "event Transfer(address indexed from, address indexed to, uint256 value)";
const REQUEST_WITHDRAW_EVENT =
  "event RequestWithdraw(address indexed _account, uint256 _amountInBnbX)";
const REWARD_EVENT = "event Redelegate(uint256 _rewardsId, uint256 _amount)";
const REWARD_CHANGE_PCT = 10; // 0 - 100

export const TIMELOCK_SCHEDULE_EVENT =
  "event CallScheduled(bytes32 indexed id, uint256 indexed index, address target,uint256 value,bytes data,bytes32 predecessor, uint256 delay)";

const BNBX_MINT_THRESHOLD = "250";
const BNBX_UNSTAKE_THRESHOLD = "250";

const BNBX_SUPPLY_CHANGE_PCT = 10;
const BNBX_SUPPLY_CHANGE_HOURS = 1;

export {
  protocol,
  BNBx,
  STAKE_MANAGER,
  BEP20_TRANSFER_EVENT,
  REQUEST_WITHDRAW_EVENT,
  REWARD_EVENT,
  REWARD_CHANGE_PCT,
  BNBX_MINT_THRESHOLD,
  BNBX_UNSTAKE_THRESHOLD,
  BNBX_SUPPLY_CHANGE_PCT,
  BNBX_SUPPLY_CHANGE_HOURS,
};
