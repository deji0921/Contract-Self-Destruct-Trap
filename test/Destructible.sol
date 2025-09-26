// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract Destructible {
    address public owner;
    IERC20 public token;

    constructor(address tokenAddress) {
        owner = msg.sender;
        if (tokenAddress != address(0)) {
            token = IERC20(tokenAddress);
        }
    }

    receive() external payable {}

    function withdraw() external {
        payable(msg.sender).transfer(address(this).balance);
    }

    function withdraw(address asset) external {
        if (asset != address(0)) {
            IERC20(asset).transfer(msg.sender, IERC20(asset).balanceOf(address(this)));
        }
    }

    function die() public {
        if (address(token) != address(0)) {
            token.transfer(owner, token.balanceOf(address(this)));
        }
        selfdestruct(payable(owner));
    }
}
