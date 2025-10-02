// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IEmergencyController} from "./interfaces/IEmergencyController.sol";

contract ResponseProtocol {
    address public owner;
    IEmergencyController public controller;
    address public droseraRelay;

    event Rescued(address indexed operator, address indexed target, address indexed asset, bytes32 reason);
    event ControllerSet(address indexed newController);
    event DroseraRelaySet(address indexed newRelay);
    event RescueAttemptFailed(address indexed target, address indexed asset, string reason);

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }

    modifier onlyDrosera() {
        require(msg.sender == droseraRelay, "only drosera relay");
        _;
    }

    constructor(IEmergencyController _controller, address _droseraRelay) {
        owner = msg.sender;
        controller = _controller;
        droseraRelay = _droseraRelay;
        emit ControllerSet(address(_controller));
        emit DroseraRelaySet(_droseraRelay);
    }

    function rescue(bytes calldata payload) external onlyDrosera {
        (address target, address asset, bytes32 reason) = abi.decode(payload, (address, address, bytes32));
        
        if (address(controller) == address(0)) {
            emit RescueAttemptFailed(target, asset, "controller not set");
            return;
        }

        try controller.pause(target) {
            // success
        } catch (bytes memory lowLevelData) {
            emit RescueAttemptFailed(target, asset, string(abi.encodePacked("pause failed: ", lowLevelData)));
        }
        
        try controller.emergencyWithdraw(target, asset) {
            // success
        } catch (bytes memory lowLevelData) {
            emit RescueAttemptFailed(target, asset, string(abi.encodePacked("emergencyWithdraw failed: ", lowLevelData)));
        }
        
        emit Rescued(msg.sender, target, asset, reason);
    }

    function setController(IEmergencyController _controller) external onlyOwner {
        controller = _controller;
        emit ControllerSet(address(_controller));
    }

    function setDroseraRelay(address _droseraRelay) external onlyOwner {
        droseraRelay = _droseraRelay;
        emit DroseraRelaySet(_droseraRelay);
    }
}
