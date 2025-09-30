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

    function pause(address target) external {
        lastPausedTarget = target;
        pauseCount++;
    }

    function emergencyWithdraw(address target, address asset) external {
        lastWithdrawTarget = target;
        lastWithdrawAsset = asset;
        withdrawCount++;
    }
}

contract SelfDestructTrapTest is Test {
    SelfDestructRegistry public registry;
    SelfDestructTrap public trap;
    ResponseProtocol public responder;
    MockEmergencyController public controller;
    MockERC20 public asset;
    address public targetContract;

    function setUp() public {
        registry = new SelfDestructRegistry();
        trap = new SelfDestructTrap(registry);
        controller = new MockEmergencyController();
        responder = new ResponseProtocol(controller);
        asset = new MockERC20("Mock Token", "MOCK", 18);
        targetContract = address(new MockERC20("Target Token", "TGT", 18));
    }

    function test_Registry_ArmAndDisarm() public {
        assertFalse(registry.isArmed(targetContract), "Should not be armed initially");

        // Arm
        uint64 expiry = uint64(block.timestamp + 3600);
        registry.arm(targetContract, address(asset), expiry);
        
        assertTrue(registry.isArmed(targetContract), "isArmed should be true after arming");
        assertEq(registry.assetFor(targetContract), address(asset), "Asset should be correct");
        assertEq(registry.expiryFor(targetContract), expiry, "Expiry should be correct");

        // Disarm
        registry.disarm(targetContract);
        assertFalse(registry.isArmed(targetContract), "isArmed should be false after disarming");
        assertEq(registry.assetFor(targetContract), address(0), "Asset should be cleared after disarming");
        assertEq(registry.expiryFor(targetContract), 0, "Expiry should be cleared after disarming");
    }

    function test_Trap_Collect_AlwaysReturnsEmpty() public view {
        bytes memory result = trap.collect();
        assertTrue(result.length == 0, "Collect should return empty bytes");
    }

    function test_Trap_ShouldRespond_True() public {
        uint64 expiry = uint64(block.timestamp + 3600);
        // This data is what the off-chain detector would provide.
        bytes memory collectedData = abi.encode(targetContract, address(asset), true, expiry);
        bytes[] memory data = new bytes[](1);
        data[0] = collectedData;

        (bool should, bytes memory responsePayload) = trap.shouldRespond(data);
        assertTrue(should, "Should respond should be true");
        
        (address target, address _asset, bytes32 reason) = abi.decode(responsePayload, (address, address, bytes32));
        assertEq(target, targetContract, "Response target should be correct");
        assertEq(_asset, address(asset), "Response asset should be correct");
        assertEq(reason, bytes32("ARMED_SELFDESTRUCT"), "Response reason should be correct");
    }

    function test_Trap_ShouldRespond_False_NotArmed() public {
        bytes memory collectedData = abi.encode(address(0x123), address(0x456), false, 0);
        bytes[] memory data = new bytes[](1);
        data[0] = collectedData;

        (bool should, ) = trap.shouldRespond(data);
        assertFalse(should, "Should respond should be false if not armed");
    }

    function test_Trap_ShouldRespond_False_EmptyData() public {
        bytes[] memory data = new bytes[](0);
        (bool should, ) = trap.shouldRespond(data);
        assertFalse(should, "Should respond should be false for empty data array");

        bytes[] memory data2 = new bytes[](1);
        data2[0] = bytes("");
        (should, ) = trap.shouldRespond(data2);
        assertFalse(should, "Should respond should be false for empty data element");
    }

    function test_Responder_Rescue_Success() public {
        bytes memory payload = abi.encode(targetContract, address(asset), bytes32("TEST_RESCUE"));
        
        assertEq(controller.pauseCount(), 0);
        assertEq(controller.withdrawCount(), 0);

        responder.rescue(payload);

        assertEq(controller.pauseCount(), 1, "Controller pause should be called once");
        assertEq(controller.withdrawCount(), 1, "Controller withdraw should be called once");
        assertEq(controller.lastPausedTarget(), targetContract, "Paused target should be correct");
        assertEq(controller.lastWithdrawTarget(), targetContract, "Withdraw target should be correct");
        assertEq(controller.lastWithdrawAsset(), address(asset), "Withdraw asset should be correct");
    }

    function test_Event_Rescued_Is_Emitted() public {
        address rescuer = vm.addr(10);
        vm.prank(rescuer);
        bytes memory payload = abi.encode(targetContract, address(asset), bytes32("TEST_RESCUE"));
        vm.expectEmit(true, true, true, true);
        emit ResponseProtocol.Rescued(rescuer, targetContract, address(asset), bytes32("TEST_RESCUE"));
        responder.rescue(payload);
    }
}