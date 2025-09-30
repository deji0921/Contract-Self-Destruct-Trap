// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ISdRegistry} from "./interfaces/ISdRegistry.sol";

contract SelfDestructRegistry is ISdRegistry {
    address public owner;
    mapping(address => address) public assetFor;
    mapping(address => uint64) public expiryFor;
    mapping(address => bool) public isArmed;

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function arm(address target, address asset, uint64 expiry) external override onlyOwner {
        isArmed[target] = true;
        assetFor[target] = asset;
        expiryFor[target] = expiry;
    }

    function disarm(address target) external override onlyOwner {
        // This function is now much simpler as we removed the array logic.
        if (isArmed[target]) {
            isArmed[target] = false;
            assetFor[target] = address(0);
            expiryFor[target] = 0;
        }
    }
}