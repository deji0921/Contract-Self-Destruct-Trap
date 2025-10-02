// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ISdRegistry {
    function isArmed(address target) external view returns (bool);
    function assetFor(address target) external view returns (address);
    function expiryFor(address target) external view returns (uint64);
    function arm(address target, address asset, uint64 expiry) external;
    function disarm(address target) external;
}