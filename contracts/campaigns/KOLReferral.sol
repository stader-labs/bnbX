// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@opengsn/contracts/src/ERC2771Recipient.sol";

contract KOLReferral is Initializable, ERC2771Recipient {
    address public admin;

    mapping(address => string) public walletToReferralId;
    mapping(string => address) public referralIdToWallet;
    mapping(address => string) public userReferredBy;
    mapping(address => address[]) private _kolToUsers;

    address[] private _users;
    address[] private _kols;

    modifier onlyAdmin() {
        require(_msgSender() == admin, "Only Admin");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin_, address trustedForwarder_) external initializer {
        require(admin_ != address(0), "zero address");
        require(trustedForwarder_ != address(0), "zero address");
        admin = admin_;
        _setTrustedForwarder(trustedForwarder_);
    }

    function registerKOL(address wallet, string memory referralId) external onlyAdmin {
        require(referralIdToWallet[referralId] == address(0), "ReferralId is already taken");
        require(bytes(walletToReferralId[wallet]).length == 0, "ReferralId is already assigned for this wallet");
        walletToReferralId[wallet] = referralId;
        referralIdToWallet[referralId] = wallet;
        _kols.push(wallet);
    }

    function storeUserInfo(string memory referralId) external {
        require(referralIdToWallet[referralId] != address(0), "Invalid ReferralId");
        require(bytes(userReferredBy[_msgSender()]).length == 0, "User is already referred before");
        userReferredBy[_msgSender()] = referralId;
        _users.push(_msgSender());

        address kolWallet = referralIdToWallet[referralId];

        require(_msgSender() != kolWallet, "kol not allowed as user");
        _kolToUsers[kolWallet].push(_msgSender());
    }

    function queryUserReferrer(address user) external view returns (address _referrer) {
        string memory referralId = userReferredBy[user];
        return referralIdToWallet[referralId];
    }

    function getKOLUserList(address kol) external view returns (address[] memory) {
        return _kolToUsers[kol];
    }

    function getKOLs() external view returns (address[] memory) {
        return _kols;
    }

    function getUsers(
        uint256 startIdx,
        uint256 maxNumUsers
    )
        external
        view
        returns (uint256 numUsers, address[] memory userList)
    {
        require(startIdx < _users.length, "invalid startIdx");

        if (startIdx + maxNumUsers > _users.length) {
            maxNumUsers = _users.length - startIdx;
        }

        userList = new address[](maxNumUsers);
        for (numUsers = 0; startIdx < _users.length && numUsers < maxNumUsers; numUsers++) {
            userList[numUsers] = _users[startIdx++];
        }

        return (numUsers, userList);
    }

    function getKOLCount() external view returns (uint256) {
        return _kols.length;
    }

    function getUserCount() external view returns (uint256) {
        return _users.length;
    }

    function getKOLRefCount(address kol) external view returns (uint256) {
        return _kolToUsers[kol].length;
    }

    function setAdmin(address admin_) external onlyAdmin {
        require(admin_ != address(0), "zero address");
        require(admin_ != admin, "old admin == new admin");
        admin = admin_;
    }

    function setTrustedForwarder(address trustedForwarder_) external onlyAdmin {
        require(trustedForwarder_ != address(0), "zero address");
        _setTrustedForwarder(trustedForwarder_);
    }
}
