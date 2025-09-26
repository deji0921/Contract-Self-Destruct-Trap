// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITrap {
    function collect() external view returns (bytes memory);
    function shouldRespond(bytes[] calldata data) external pure returns (bool, bytes memory);
}
interface ISelfDestructRegistry { function armedAsset(address) external view returns (address); }

contract SelfDestructTrap is ITrap {
    // Hardcode or read from a config contract (no constructor args in Drosera)
    address public REGISTRY;
    address public TARGET;

    bytes4  public constant TAG = 0x53445231; // "SDR1"

    struct Sample { uint256 blockNumber; address target; address asset; bool armed; }

    function setAddresses(address registry, address target) external {
        REGISTRY = registry;
        TARGET = target;
    }

    function collect() external view returns (bytes memory) {
        address asset = ISelfDestructRegistry(REGISTRY).armedAsset(TARGET);
        bool armed = (asset != address(0));
        return abi.encode(Sample({ blockNumber: block.number, target: TARGET, asset: asset, armed: armed }));
    }

    // data[0] = newest
    function shouldRespond(bytes[] calldata data) external pure returns (bool, bytes memory) {
        if (data.length == 0) return (false, "");
        Sample memory s = abi.decode(data[0], (Sample));
        if (s.armed) {
            // payload: TAG || abi.encode(target, asset) to match response_function
            return (true, abi.encodePacked(TAG, abi.encode(s.target, s.asset)));
        }
        return (false, "");
    }
}