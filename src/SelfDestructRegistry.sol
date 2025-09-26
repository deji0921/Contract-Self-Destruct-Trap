// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SelfDestructRegistry {
    event Armed(address indexed target, address indexed asset, address indexed by, uint256 atBlock);
    mapping(address => address) public armedAsset; // target => asset (0 for ETH)

    address public owner;
    mapping(address => bool) public operator;

    modifier onlyAuth() { require(msg.sender == owner || operator[msg.sender], "not auth"); _; }

    constructor() { owner = msg.sender; }
    function setOperator(address op, bool ok) external { require(msg.sender==owner,"only owner"); operator[op]=ok; }

    function arm(address target, address asset) external onlyAuth {
        armedAsset[target] = asset;
        emit Armed(target, asset, msg.sender, block.number);
    }
    function clear(address target) external onlyAuth {
        armedAsset[target] = address(0);
    }
}