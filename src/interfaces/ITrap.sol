// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ITrap {
    function collect() external view returns (bytes memory);
    function shouldRespond(bytes[] calldata data) external view returns (bool, bytes memory);
}