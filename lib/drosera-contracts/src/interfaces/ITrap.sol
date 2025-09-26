// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface ITrap {
    function trap(address target, bytes calldata data) external view returns (bool alert, bytes memory response);
}
