// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "./interfaces/IStakeHub.sol";
import "./interfaces/IBnbX.sol";
import "./interfaces/IOperatorRegistry.sol";
import "./interfaces/IStakeManagerV2.sol";
import "./interfaces/IStakeCredit.sol";

contract StakeManagerV2 is
    IStakeManagerV2,
    AccessControlUpgradeable,
    PausableUpgradeable
{
    IStakeHub public constant STAKE_HUB =
        IStakeHub(0x0000000000000000000000000000000000002002);
    IOperatorRegistry public operatorRegistry;
    IBnbX public bnbX;

    mapping(address => WithdrawalRequest[]) private userWithdrawalRequests;

    // @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _operatorRegistry,
        address _bnbX
    ) external initializer {
        __AccessControl_init();
        __Pausable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        operatorRegistry = IOperatorRegistry(_operatorRegistry);
        bnbX = IBnbX(_bnbX);
    }

    function delegate()
        external
        payable
        override
        whenNotPaused
        returns (uint256)
    {
        if (msg.value < STAKE_HUB.minDelegationBNBChange())
            revert DelegationAmountTooSmall();

        uint256 amountToMint = convertBnbToBnbX(msg.value);

        bnbX.mint(msg.sender, amountToMint);

        address preferredOperatorAddress = IOperatorRegistry(operatorRegistry)
            .preferredDepositOperator();
        STAKE_HUB.delegate{value: msg.value}(preferredOperatorAddress, true);

        emit Delegate(preferredOperatorAddress, msg.value);
        return amountToMint;
    }

    function requestWithdraw(
        uint256 _amount
    ) external override whenNotPaused returns (uint256) {
        if (_amount == 0) revert ZeroAmount();

        uint256 totalAmount2WithdrawInBnb = convertBnbXToBnb(_amount);
        uint256 leftAmount2WithdrawInBnb = totalAmount2WithdrawInBnb;
        bnbX.burn(msg.sender, _amount);

        address preferredOperator = operatorRegistry
            .preferredWithdrawalOperator();
        uint256 currentIdx = 0;
        uint256 operatorsLength = operatorRegistry.getOperatorsLength();
        for (; currentIdx < operatorsLength; ++currentIdx) {
            if (preferredOperator == operatorRegistry.getOperatorAt(currentIdx))
                break;
        }

        while (leftAmount2WithdrawInBnb > 0) {
            leftAmount2WithdrawInBnb -= _undelegate(
                operatorRegistry.getOperatorAt(currentIdx),
                leftAmount2WithdrawInBnb
            );

            currentIdx = currentIdx + 1 < operatorsLength ? currentIdx + 1 : 0;
        }

        emit RequestWithdraw(msg.sender, _amount, totalAmount2WithdrawInBnb);
        return totalAmount2WithdrawInBnb;
    }

    function claimWithdrawal(
        uint256 _idx
    ) external override whenNotPaused returns (uint256) {
        WithdrawalRequest[] storage userRequests = userWithdrawalRequests[
            msg.sender
        ];
        WithdrawalRequest memory userRequest = userRequests[_idx];
        uint256 amountToClaim = userRequest.bnbAmount;
        if (block.timestamp < userRequest.unlockTime) revert Unbonding();

        STAKE_HUB.claim(userRequest.operator, 0);

        // swap with the last item and pop it.
        userRequests[_idx] = userRequests[userRequests.length - 1];
        userRequests.pop();

        uint256 _gasLimit = STAKE_HUB.transferGasLimit();
        (bool success, ) = payable(msg.sender).call{
            gas: _gasLimit,
            value: amountToClaim
        }("");
        if (!success) revert TransferFailed();

        emit ClaimWithdrawal(msg.sender, _idx, amountToClaim);
        return amountToClaim;
    }

    function redelegate(
        address _fromOperator,
        address _toOperator,
        uint256 _amount
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (operatorRegistry.operatorExists(_fromOperator) == false)
            revert OperatorNotExisted();
        if (operatorRegistry.operatorExists(_toOperator) == false)
            revert OperatorNotExisted();
        if (_amount < STAKE_HUB.minDelegationBNBChange())
            revert DelegationAmountTooSmall();

        uint256 shares = IStakeCredit(
            STAKE_HUB.getValidatorCreditContract(_fromOperator)
        ).getSharesByPooledBNB(_amount);

        STAKE_HUB.redelegate(_fromOperator, _toOperator, shares, true);

        emit Redelegate(_fromOperator, _toOperator, _amount);
    }

    /**
     * @dev Flips the pause state
     */
    function togglePause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        paused() ? _unpause() : _pause();
    }

    function _undelegate(
        address _operator,
        uint256 _amount
    ) internal returns (uint256) {
        address creditContract = STAKE_HUB.getValidatorCreditContract(
            _operator
        );
        uint256 pooledBnb = IStakeCredit(creditContract).getPooledBNB(
            address(this)
        );

        uint256 amount2WithdrawFromOperator = (pooledBnb <= _amount)
            ? pooledBnb
            : _amount;

        uint256 shares = IStakeCredit(creditContract).getSharesByPooledBNB(
            amount2WithdrawFromOperator
        );
        STAKE_HUB.undelegate(_operator, shares);

        userWithdrawalRequests[msg.sender].push(
            WithdrawalRequest({
                shares: shares,
                bnbAmount: amount2WithdrawFromOperator,
                unlockTime: block.timestamp + STAKE_HUB.unbondPeriod(),
                operator: _operator
            })
        );

        return amount2WithdrawFromOperator;
    }

    /**
     * @dev Calculates amount of BnbX for `_amount` Bnb
     */
    function convertBnbToBnbX(
        uint256 _amount
    ) public view override returns (uint256) {
        uint256 totalShares = bnbX.totalSupply();
        totalShares = totalShares == 0 ? 1 : totalShares;

        uint256 totalPooledBnb = getTotalStakeAcrossAllOperators();
        totalPooledBnb = totalPooledBnb == 0 ? 1 : totalPooledBnb;

        uint256 amountInBnbX = (_amount * totalShares) / totalPooledBnb;

        return amountInBnbX;
    }

    /**
     * @dev Calculates amount of Bnb for `_amountInBnbX` BnbX
     */
    function convertBnbXToBnb(
        uint256 _amountInBnbX
    ) public view override returns (uint256) {
        uint256 totalShares = bnbX.totalSupply();
        totalShares = totalShares == 0 ? 1 : totalShares;

        uint256 totalPooledBnb = getTotalStakeAcrossAllOperators();
        totalPooledBnb = totalPooledBnb == 0 ? 1 : totalPooledBnb;

        uint256 amountInBnb = (_amountInBnbX * totalPooledBnb) / totalShares;

        return amountInBnb;
    }

    function getTotalStakeAcrossAllOperators() public view returns (uint256) {
        uint256 totalStake;
        uint256 operatorsLength = operatorRegistry.getOperatorsLength();
        for (uint256 i; i < operatorsLength; ++i) {
            address creditContract = STAKE_HUB.getValidatorCreditContract(
                operatorRegistry.getOperatorAt(i)
            );

            totalStake += IStakeCredit(creditContract).getPooledBNB(
                address(this)
            );
        }
        return totalStake;
    }
}
