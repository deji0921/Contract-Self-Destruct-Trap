// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IEmergencyController} from "./interfaces/IEmergencyController.sol";

contract ResponseProtocol {
    address public owner;
    IEmergencyController public controller;

    event Rescued(address indexed operator, address indexed target, address indexed asset, bytes32 reason);
    event ControllerSet(address indexed newController);

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }

    constructor(IEmergencyController _controller) {
        owner = msg.sender;
        controller = _controller;
        emit ControllerSet(address(_controller));
    }

    function rescue(bytes calldata payload) external {
        (address target, address asset, bytes32 reason) = abi.decode(payload, (address, address, bytes32));
        
        // Call known controller hooks; do NOT assume arbitrary target methods exist.
        if (address(controller) != address(0)) {
            controller.pause(target);
            controller.emergencyWithdraw(target, asset);
        }
        
        emit Rescued(msg.sender, target, asset, reason);
    }

    function setController(IEmergencyController _controller) external onlyOwner {
        controller = _controller;
        emit ControllerSet(address(_controller));
    }
}