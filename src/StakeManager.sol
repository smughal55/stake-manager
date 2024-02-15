// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IStakeManager} from "./interfaces/IStakeManager.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title StakeManager
 * @dev Manages staking functionality and roles.
 */
contract StakeManager is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    IStakeManager
{
    ///////////////////
    // Errors
    ///////////////////
    error StakeManager__SenderMustHaveTheRequiredRole();
    error StakeManager__InvalidDepositAmount();
    error StakeManager__InvalidWaitTime();
    error StakeManager__AlreadyRegistered();
    error StakeManager__CannotUnregisterWithPositiveDeposit();
    error StakeManager__NoStakeToUnstake();
    error StakeManager__NoStakeInitiated();
    error StakeManager__WithdrawalPeriodNotElapsed();
    error StakeManager__WithdrawalFailed();
    error StakeManager__CannotSlashNonStaker();
    error StakeManager__InsufficientStakeToSlash();
    error StakeManager__NoSlashedAmountToWithdraw();
    error StakeManager__AddressZero();

    ///////////////////
    // Types
    ///////////////////
    enum ROLES {
        NONE,
        STAKER_ROLE,
        ADMIN_ROLE
    }

    struct Staker {
        uint256 deposit;
        uint256 unstakeTimestamp;
        ROLES role;
    }

    ///////////////////
    // State Variables
    ///////////////////

    mapping(address => Staker) public stakers;

    uint256 public registrationDepositAmount;
    uint256 public registrationWaitTime;

    uint private totalSlashed;

    ///////////////////
    // Modifiers
    ///////////////////
    /**
     * @dev Modifier to check if the sender has a specific role.
     * @param role The required role.
     */
    modifier onlyRole(ROLES role) {
        if (getRole(msg.sender) != role)
            revert StakeManager__SenderMustHaveTheRequiredRole();
        _;
    }

    ///////////////////
    // Functions
    ///////////////////
    /**
     * @dev Disables the use of initializer functions in this contract.
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract.
     */
    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        stakers[msg.sender].role = ROLES.ADMIN_ROLE;
    }

    /// @inheritdoc IStakeManager
    function setConfiguration(
        uint256 _registrationDepositAmount,
        uint256 _registrationWaitTime
    ) external override onlyOwner {
        if (_registrationDepositAmount == 0)
            revert StakeManager__InvalidDepositAmount();
        if (_registrationWaitTime == 0) revert StakeManager__InvalidWaitTime();
        registrationDepositAmount = _registrationDepositAmount;
        registrationWaitTime = _registrationWaitTime;
    }

    /// @inheritdoc IStakeManager
    function register() external payable override {
        Staker storage staker = stakers[msg.sender];
        if (staker.role != ROLES.NONE) revert StakeManager__AlreadyRegistered();
        if (msg.value != registrationDepositAmount)
            revert StakeManager__InvalidDepositAmount();
        staker.role = ROLES.STAKER_ROLE;
        staker.deposit += msg.value;
    }

    /// @inheritdoc IStakeManager
    function unregister() external override {
        Staker storage staker = stakers[msg.sender];
        if (staker.deposit != 0)
            revert StakeManager__CannotUnregisterWithPositiveDeposit();
        staker.role = ROLES.NONE;
    }

    /// @inheritdoc IStakeManager
    function stake() external payable override onlyRole(ROLES.STAKER_ROLE) {
        stakers[msg.sender].deposit += msg.value;
    }

    /// @inheritdoc IStakeManager
    function unstake() external override onlyRole(ROLES.STAKER_ROLE) {
        Staker storage staker = stakers[msg.sender];
        if (staker.deposit == 0) revert StakeManager__NoStakeToUnstake();
        staker.unstakeTimestamp = block.timestamp;
    }

    /**
     * @dev Follow CEI.
     */
    /// @inheritdoc IStakeManager
    function withdraw() external override onlyRole(ROLES.STAKER_ROLE) {
        Staker storage staker = stakers[msg.sender];
        if (staker.unstakeTimestamp == 0)
            revert StakeManager__NoStakeInitiated();
        if (block.timestamp < staker.unstakeTimestamp + registrationWaitTime)
            revert StakeManager__WithdrawalPeriodNotElapsed();
        uint256 amount = staker.deposit;
        staker.deposit = 0;
        staker.unstakeTimestamp = 0;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert StakeManager__WithdrawalFailed();
    }

    /// @inheritdoc IStakeManager
    function slash(
        address staker,
        uint256 amount
    ) external override onlyRole(ROLES.ADMIN_ROLE) {
        Staker storage s = stakers[staker];
        if (s.role != ROLES.STAKER_ROLE)
            revert StakeManager__CannotSlashNonStaker();
        if (s.deposit < amount) revert StakeManager__InsufficientStakeToSlash();
        s.deposit -= amount;
        totalSlashed += amount;
    }

    /**
     * @dev Allows the owner to withdraw the slashed amount.
     * @param beneficiary The address to send the slashed amount to.
     */
    function withdrawSlashed(
        address beneficiary
    ) external onlyRole(ROLES.ADMIN_ROLE) {
        if (totalSlashed == 0) revert StakeManager__NoSlashedAmountToWithdraw();
        if (beneficiary == address(0)) revert StakeManager__AddressZero();
        uint256 amount = totalSlashed;
        totalSlashed = 0;
        (bool success, ) = payable(beneficiary).call{value: amount}("");
        if (!success) revert StakeManager__WithdrawalFailed();
    }

    /**
     * @dev Gets the role of an address.
     * @param account The address to query.
     * @return The role of the address.
     */
    function getRole(address account) public view returns (ROLES) {
        return stakers[account].role;
    }

    /**
     * @dev Gets the total slashed amount.
     * @return The total slashed amount.
     */
    function getTotalSlashed()
        external
        view
        onlyRole(ROLES.ADMIN_ROLE)
        returns (uint)
    {
        return totalSlashed;
    }

    ///////////////////////////////
    // Private & Internal Functions
    ///////////////////////////////

    /**
     * @dev Authorizes the upgrade of the contract.
     * @param newImplementation The address of the new implementation.
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
