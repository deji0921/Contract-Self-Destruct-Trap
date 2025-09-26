// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "forge-std/interfaces/IERC20.sol";

interface IWithdraw {
    function withdraw() external;
    function withdraw(address) external;
    function withdraw(uint256) external;
    function withdrawAll() external;
    function withdrawAll(address) external;
}

contract ResponseProtocol {
    address public lastCaller;
    address public lastTarget;
    address public lastAsset;
    uint256 public lastAmount;

    event Rescued(
        address indexed caller,
        address indexed target,
        address indexed asset,
        uint256 amount
    );

    function rescue(address target, address asset) external {
        lastCaller = msg.sender;
        lastTarget = target;
        lastAsset = asset;

        if (asset == address(0)) {
            // Rescue ETH
            uint256 balance = target.balance;
            if (balance > 0) {
                try IWithdraw(target).withdrawAll() {} catch {
                    try IWithdraw(target).withdraw() {} catch {
                        // Fallback for ETH
                    }
                }
                lastAmount = balance;
            }
        } else {
            // Rescue ERC20
            uint256 balance = IERC20(asset).balanceOf(target);
            if (balance > 0) {
                try IWithdraw(target).withdrawAll(asset) {} catch {
                    try IWithdraw(target).withdraw(asset) {} catch {
                        try IWithdraw(target).withdraw(balance) {} catch {
                            // Fallback for ERC20
                        }
                    }
                }
                lastAmount = balance;
            }
        }

        emit Rescued(msg.sender, target, asset, lastAmount);
    }
}
