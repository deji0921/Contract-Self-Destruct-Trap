// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

interface IDestructible {
    function withdraw() external;
    function withdraw(address asset) external;
}

contract ResponseProtocol {
    event Rescued(
        address indexed caller,
        address indexed target,
        address indexed asset,
        uint256 amount
    );

    address public owner;
    mapping(address => bool) public operator;
    bytes4 public constant EXPECTED_TAG = 0x53445231; // "SDR1"

    modifier onlyAuth() {
        require(
            msg.sender == owner || operator[msg.sender],
            "not authorized"
        );
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setOperator(address op, bool ok) external {
        require(msg.sender == owner, "only owner");
        operator[op] = ok;
    }

    receive() external payable {}

    // Drosera should call execute(bytes), but if your wiring calls rescue(target,asset) directly,
    // make sure only authorized callers can invoke it.
    function rescue(address target, address asset) external onlyAuth {
        uint256 amount = (asset == address(0))
            ? target.balance
            : IERC20(asset).balanceOf(target);

        if (asset == address(0)) {
            IDestructible(target).withdraw();
        } else {
            IDestructible(target).withdraw(asset);
        }

        emit Rescued(msg.sender, target, asset, amount);
    }
}