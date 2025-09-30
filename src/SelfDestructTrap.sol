// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ITrap} from "./interfaces/ITrap.sol";
import {ISdRegistry} from "./interfaces/ISdRegistry.sol";

contract SelfDestructTrap is ITrap {
    ISdRegistry public immutable REGISTRY;

    constructor(ISdRegistry registry) {
        REGISTRY = registry;
    }

    function collect() external pure override returns (bytes memory) {
        // As per the feedback, this is kept minimal.
        // The off-chain detector prepares the data for shouldRespond.
        return abi.encode();
    }

    function shouldRespond(bytes[] calldata data)
        external
        pure
        override
        returns (bool, bytes memory)
    {
        if (data.length == 0 || data[0].length == 0) {
            return (false, "");
        }

        // The data is prepared by the off-chain detector.
        (address target, address asset, bool armed, uint64 expiry) =
            abi.decode(data[0], (address, address, bool, uint64));

        if (!armed) {
            return (false, "");
        }

        // Expiry check is not possible in a pure function without access to block.timestamp.
        // The feedback mentions this is optional and can be handled by the detector or responder.
        // if (expiry != 0 && block.timestamp > expiry) return (false, "");

        return (true, abi.encode(target, asset, bytes32("ARMED_SELFDESTRUCT")));
    }
}