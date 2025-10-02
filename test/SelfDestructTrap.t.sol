// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {SelfDestructTrap} from "../src/SelfDestructTrap.sol";
import {SelfDestructRegistry} from "../src/SelfDestructRegistry.sol";
import {ResponseProtocol} from "../src/ResponseProtocol.sol";
import {IEmergencyController} from "../src/interfaces/IEmergencyController.sol";
import {MockERC20} from "./MockERC20.sol";

contract MockEmergencyController is IEmergencyController {
    address public lastPausedTarget;
    address public lastWithdrawTarget;
    address public lastWithdrawAsset;
    uint256 public pauseCount;
    uint256 public withdrawCount;
    bool public revertPause;
    bool public revertWithdraw;

    function pause(address target) external {
        if (revertPause) {
            revert("Pause failed");
        }
        lastPausedTarget = target;
        pauseCount++;
    }

    function emergencyWithdraw(address target, address asset) external {
        if (revertWithdraw) {
            revert("Withdraw failed");
        }
        lastWithdrawTarget = target;
        lastWithdrawAsset = asset;
        withdrawCount++;
    }

    function setRevert(bool _revertPause, bool _revertWithdraw) external {
        revertPause = _revertPause;
        revertWithdraw = _revertWithdraw;
    }
}

contract SelfDestructTrapTest is Test {
    SelfDestructRegistry public registry;
    SelfDestructTrap public trap;
    ResponseProtocol public responder;
    MockEmergencyController public controller;
    MockERC20 public asset;
    address public targetContract;
    address public droseraRelay;
    address public unauthorizedUser;

    function setUp() public {
        droseraRelay = vm.addr(1);
        unauthorizedUser = vm.addr(2);
        registry = new SelfDestructRegistry();
        trap = new SelfDestructTrap(registry);
        controller = new MockEmergencyController();
        responder = new ResponseProtocol(controller, droseraRelay);
        asset = new MockERC20("Mock Token", "MOCK", 18);
        targetContract = address(new MockERC20("Target Token", "TGT", 18));
    }

    function test_Registry_ArmAndDisarm() public {
        assertFalse(registry.isArmed(targetContract), "Should not be armed initially");
        uint64 expiry = uint64(block.timestamp + 3600);
        registry.arm(targetContract, address(asset), expiry);
        assertTrue(registry.isArmed(targetContract), "isArmed should be true after arming");
        registry.disarm(targetContract);
        assertFalse(registry.isArmed(targetContract), "isArmed should be false after disarming");
    }

    function test_Trap_ShouldRespond_True_TargetHasCode() public {
        bytes memory collectedData = abi.encode(targetContract, address(asset), true, uint64(block.timestamp + 3600));
        bytes[] memory data = new bytes[](1);
        data[0] = collectedData;
        (bool should, ) = trap.shouldRespond(data);
        assertTrue(should, "Should respond should be true when target has code");
    }

    function test_Trap_ShouldRespond_False_TargetHasNoCode() public {
        bytes memory collectedData = abi.encode(targetContract, address(asset), true, uint64(block.timestamp + 3600));
        bytes[] memory data = new bytes[](1);
        data[0] = collectedData;
        vm.etch(targetContract, bytes("")); // Remove code from target contract
        (bool should, ) = trap.shouldRespond(data);
        assertFalse(should, "Should respond should be false when target has no code");
    }

    function test_Responder_Rescue_Success() public {
        vm.prank(droseraRelay);
        bytes memory payload = abi.encode(targetContract, address(asset), bytes32("TEST_RESCUE"));
        responder.rescue(payload);
        assertEq(controller.pauseCount(), 1, "Controller pause should be called once");
        assertEq(controller.withdrawCount(), 1, "Controller withdraw should be called once");
    }

    function test_Responder_Rescue_Fail_Unauthorized() public {
        vm.prank(unauthorizedUser);
        bytes memory payload = abi.encode(targetContract, address(asset), bytes32("TEST_RESCUE"));
        vm.expectRevert("only drosera relay");
        responder.rescue(payload);
    }

    function test_Responder_Rescue_HandlesControllerRevert() public {
        controller.setRevert(true, true);
        vm.prank(droseraRelay);
        bytes memory payload = abi.encode(targetContract, address(asset), bytes32("TEST_RESCUE"));
        
        vm.expectEmit(true, true, true, false);
        emit ResponseProtocol.RescueAttemptFailed(targetContract, address(asset), "pause failed: Error(Pause failed)");

        vm.expectEmit(true, true, true, false);
        emit ResponseProtocol.RescueAttemptFailed(targetContract, address(asset), "emergencyWithdraw failed: Error(Withdraw failed)");
        
        responder.rescue(payload);
        assertEq(controller.pauseCount(), 0, "Pause count should be 0 on revert");
        assertEq(controller.withdrawCount(), 0, "Withdraw count should be 0 on revert");
    }
}
