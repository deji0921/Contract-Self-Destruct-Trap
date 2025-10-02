// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IEmergencyController {
    function pause(address target) external;
    function emergencyWithdraw(address target, address asset) external;
}
