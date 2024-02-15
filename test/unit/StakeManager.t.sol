// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {DeployStakeManager} from "../../script/DeployStakeManager.s.sol";
import {StakeManager} from "../../src/StakeManager.sol";

contract StakeManagerTest is Test {
    DeployStakeManager deployer;
    StakeManager stakeManager;

    address public USERA = makeAddr("userA");
    address public COLLECTOR = makeAddr("collector");

    function setUp() public {
        deployer = new DeployStakeManager();
        address proxy = deployer.run();
        stakeManager = StakeManager(proxy);
        vm.deal(USERA, 1000 ether);
    }

    modifier configuration() {
        vm.prank(address(deployer));
        stakeManager.setConfiguration(1 ether, 1000);
        vm.stopPrank();
        _;
    }

    modifier register() {
        vm.prank(USERA);
        stakeManager.register{value: 1 ether}();
        vm.stopPrank();
        _;
    }

    modifier registerAndStake() {
        vm.prank(USERA);
        stakeManager.register{value: 1 ether}();
        vm.stopPrank();
        vm.prank(USERA);
        stakeManager.stake{value: 1 ether}();
        vm.stopPrank();
        _;
    }

    modifier registerStakeAndUnstake() {
        vm.prank(USERA);
        stakeManager.register{value: 1 ether}();
        vm.stopPrank();
        vm.prank(USERA);
        stakeManager.stake{value: 1 ether}();
        vm.stopPrank();
        vm.prank(USERA);
        stakeManager.unstake();
        vm.stopPrank();
        _;
    }

    modifier registerStakeUnstakeAndWithdraw() {
        vm.prank(USERA);
        stakeManager.register{value: 1 ether}();
        vm.stopPrank();
        vm.prank(USERA);
        stakeManager.stake{value: 1 ether}();
        vm.stopPrank();
        vm.prank(USERA);
        stakeManager.unstake();
        vm.stopPrank();
        vm.warp(1001);
        vm.prank(USERA);
        stakeManager.withdraw();
        vm.stopPrank();
        _;
    }

    ///////////////////////
    // Initializer Tests //
    ///////////////////////

    function testAdminUser() public {
        assertEq(stakeManager.owner(), address(deployer));
        assertEq(uint8(stakeManager.getRole(address(deployer))), 2);
    }

    /////////////////////////
    // Configuration Tests //
    /////////////////////////

    function testSetConfigurationRevertsWhenNotOwner() public {
        vm.expectRevert();
        stakeManager.setConfiguration(1 ether, 1000);
    }

    function testSetConfigurationRevertsInvalidDepositAmount() public {
        vm.prank(address(deployer));
        vm.expectRevert(
            StakeManager.StakeManager__InvalidDepositAmount.selector
        );
        stakeManager.setConfiguration(0, 1000);
        vm.stopPrank();
    }

    function testSetConfigurationRevertsInvalidWaitTime() public {
        vm.prank(address(deployer));
        vm.expectRevert(StakeManager.StakeManager__InvalidWaitTime.selector);
        stakeManager.setConfiguration(1 ether, 0);
        vm.stopPrank();
    }

    function testSetConfiguration() public {
        vm.prank(address(deployer));
        stakeManager.setConfiguration(1 ether, 1000);
        assertEq(stakeManager.registrationDepositAmount(), 1 ether);
        assertEq(stakeManager.registrationWaitTime(), 1000);
        vm.stopPrank();
    }

    ////////////////////
    // Register Tests //
    ////////////////////

    function testRegisterRevertsWhenAlreadyRegistered() public configuration {
        stakeManager.register{value: 1 ether}();
        vm.expectRevert(StakeManager.StakeManager__AlreadyRegistered.selector);
        stakeManager.register{value: 1 ether}();
    }

    function testRegiserRevertsWhenNotEnoughDeposit() public configuration {
        vm.expectRevert(
            StakeManager.StakeManager__InvalidDepositAmount.selector
        );
        stakeManager.register{value: 0.9 ether}();
    }

    function testRegister() public configuration {
        stakeManager.register{value: 1 ether}();
        assertEq(uint8(stakeManager.getRole(address(this))), 1);
        (uint256 deposit, , ) = stakeManager.stakers(address(this));
        assertEq(deposit, 1 ether);
    }

    //////////////////////
    // Unregister Tests //
    //////////////////////

    function testUnregisterRevertsWhenPositiveDeposit() public configuration {
        stakeManager.register{value: 1 ether}();
        vm.expectRevert(
            StakeManager
                .StakeManager__CannotUnregisterWithPositiveDeposit
                .selector
        );
        stakeManager.unregister();
    }

    function testUnregister()
        public
        configuration
        registerStakeUnstakeAndWithdraw
    {
        vm.prank(USERA);
        stakeManager.unregister();
        assertEq(uint8(stakeManager.getRole(address(this))), 0);
        vm.stopPrank();
    }

    /////////////////
    // Stake Tests //
    /////////////////

    function testStakeRevertsWhenNotStaker() public configuration {
        vm.expectRevert(
            StakeManager.StakeManager__SenderMustHaveTheRequiredRole.selector
        );
        stakeManager.stake{value: 1 ether}();
    }

    function testStake() public configuration register {
        vm.prank(USERA);
        stakeManager.stake{value: 1 ether}();
        (uint256 deposit, , ) = stakeManager.stakers(USERA);
        assertEq(deposit, 2 ether);
        vm.stopPrank();
    }

    ///////////////////
    // Unstake Tests //
    ///////////////////

    function testUnstakeRevertsWhenNotStaker() public configuration {
        vm.expectRevert(
            StakeManager.StakeManager__SenderMustHaveTheRequiredRole.selector
        );
        stakeManager.unstake();
    }

    function testUnstake() public configuration registerAndStake {
        vm.prank(USERA);
        stakeManager.unstake();
        (uint256 deposit, uint256 unstakeTimestamp, ) = stakeManager.stakers(
            USERA
        );
        assertEq(deposit, 2 ether);
        assertEq(unstakeTimestamp, block.timestamp);
        vm.stopPrank();
    }

    ////////////////////
    // Withdraw Tests //
    ////////////////////

    function testWithdrawRevertsWhenNotStaker() public configuration {
        vm.expectRevert(
            StakeManager.StakeManager__SenderMustHaveTheRequiredRole.selector
        );
        stakeManager.withdraw();
    }

    function testWithdrawRevertsWhenWithdrawalPeriodNotElapsed()
        public
        configuration
        registerStakeAndUnstake
    {
        vm.expectRevert(
            StakeManager.StakeManager__WithdrawalPeriodNotElapsed.selector
        );
        vm.prank(USERA);
        stakeManager.withdraw();
        vm.stopPrank();
    }

    function testWithdrawRevertsWhenNoStakeInitiated()
        public
        configuration
        registerAndStake
    {
        vm.expectRevert(StakeManager.StakeManager__NoStakeInitiated.selector);
        vm.prank(USERA);
        stakeManager.withdraw();
        vm.stopPrank();
    }

    function testWithdraw() public configuration registerStakeAndUnstake {
        vm.prank(USERA);
        vm.warp(1001);
        stakeManager.withdraw();
        (uint256 deposit, uint256 unstakeTimestamp, ) = stakeManager.stakers(
            USERA
        );
        assertEq(deposit, 0);
        assertEq(unstakeTimestamp, 0);
        vm.stopPrank();
    }

    /////////////////
    // Slash Tests //
    /////////////////

    function testSlashRevertsWhenNotOwner() public configuration {
        vm.expectRevert(
            StakeManager.StakeManager__SenderMustHaveTheRequiredRole.selector
        );
        stakeManager.slash(USERA, 1 ether);
    }

    function testSlashRevertsWhenNotStaker() public configuration {
        vm.expectRevert(
            StakeManager.StakeManager__CannotSlashNonStaker.selector
        );
        vm.prank(address(deployer));
        stakeManager.slash(USERA, 1 ether);
        vm.stopPrank();
    }

    function testSlashRevertsWhenInsufficientStakeToSlash()
        public
        configuration
        registerAndStake
    {
        vm.expectRevert(
            StakeManager.StakeManager__InsufficientStakeToSlash.selector
        );
        vm.prank(address(deployer));
        stakeManager.slash(USERA, 3 ether);
        vm.stopPrank();
    }

    function testSlash() public configuration registerAndStake {
        vm.prank(address(deployer));
        stakeManager.slash(USERA, 1 ether);
        vm.stopPrank();
        vm.prank(address(deployer));
        uint totalSlashed = stakeManager.getTotalSlashed();
        (uint256 deposit, , ) = stakeManager.stakers(USERA);
        assertEq(deposit, 1 ether);
        assertEq(totalSlashed, 1 ether);
        vm.stopPrank();
    }

    ///////////////////////////
    // WithdrawSlashed Tests //
    ///////////////////////////

    function testWithdrawSlashedRevertsWhenNotOwner() public configuration {
        vm.expectRevert(
            StakeManager.StakeManager__SenderMustHaveTheRequiredRole.selector
        );
        stakeManager.withdrawSlashed(address(this));
    }

    function testWithdrawSlashedRevertsWhenNoSlashedAmountToWithdraw()
        public
        configuration
    {
        vm.expectRevert(
            StakeManager.StakeManager__NoSlashedAmountToWithdraw.selector
        );
        vm.prank(address(deployer));
        stakeManager.withdrawSlashed(address(this));
        vm.stopPrank();
    }

    function testWithdrawSlashedRevertsWhenAddressZero()
        public
        configuration
        registerAndStake
    {
        vm.prank(address(deployer));
        stakeManager.slash(USERA, 1 ether);
        vm.stopPrank();
        vm.prank(address(deployer));
        vm.expectRevert(StakeManager.StakeManager__AddressZero.selector);
        stakeManager.withdrawSlashed(address(0));
        vm.stopPrank();
    }

    function testWithdrawSlashed() public configuration registerAndStake {
        vm.prank(address(deployer));
        stakeManager.slash(USERA, 1 ether);
        vm.stopPrank();
        vm.prank(address(deployer));
        stakeManager.withdrawSlashed(COLLECTOR);
        vm.stopPrank();
        vm.prank(address(deployer));
        uint totalSlashed = stakeManager.getTotalSlashed();
        assertEq(totalSlashed, 0);
        assertEq(address(COLLECTOR).balance, 1 ether);
        vm.stopPrank();
    }
}
