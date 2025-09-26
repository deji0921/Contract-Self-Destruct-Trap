// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ITrap} from "drosera-contracts/interfaces/ITrap.sol";
import {Owned} from "solmate/auth/Owned.sol";

/// @title SelfDestructTrap
/// @notice A trap that triggers an asset rescue if a monitored contract is about to self-destruct.
/// @dev The owner can add or remove contracts and their corresponding assets to be monitored.
contract SelfDestructTrap is ITrap, Owned {
    /// @notice Stores the asset to rescue for each monitored contract.
    mapping(address => address) public assetToRescue;

    /// @notice Mapping to efficiently check if a contract is being monitored.
    mapping(address => bool) public isMonitored;

    /// @notice The event emitted when a contract is added to the monitored list.
    event ContractAdded(address indexed contractAddress, address indexed assetAddress);

    /// @notice The event emitted when a contract is removed from the monitored list.
    event ContractRemoved(address indexed contractAddress);

    constructor() Owned(msg.sender) {}

    /// @notice The core trap logic that checks for pending self-destructions.
    /// @dev This function is called by the Drosera network. It checks the transaction trace
    /// for a SELFDESTRUCT opcode targeting a monitored contract.
    /// @param target The address of the contract to check.
    /// @return alert A boolean indicating if an alert should be raised.
    /// @return response The response data, containing the target and asset to rescue.
    function trap(address target, bytes calldata)
        external
        view
        override
        returns (bool alert, bytes memory response)
    {
        // This trap logic is simplified for direct testing.
        // In a real Drosera environment, this would involve inspecting transaction traces.
        // For this PoC, we simulate the detection by checking code size.
        if (isMonitored[target] && target.code.length == 0) {
            address asset = assetToRescue[target];
            response = abi.encode(target, asset);
            return (true, response);
        }
        return (false, "");
    }

    /// @notice Adds a contract and its asset to the list of monitored contracts.
    /// @dev Only the owner of this trap can call this function.
    /// @param contractAddress The address of the contract to add.
    /// @param assetAddress The address of the asset to rescue (address(0) for ETH).
    function addContract(address contractAddress, address assetAddress) external onlyOwner {
        require(contractAddress != address(0), "Zero address");
        require(!isMonitored[contractAddress], "Already monitored");

        isMonitored[contractAddress] = true;
        assetToRescue[contractAddress] = assetAddress;
        emit ContractAdded(contractAddress, assetAddress);
    }

    /// @notice Removes a contract from the list of monitored contracts.
    /// @dev Only the owner of this trap can call this function.
    /// @param contractAddress The address of the contract to remove.
    function removeContract(address contractAddress) external onlyOwner {
        require(isMonitored[contractAddress], "Not monitored");

        delete isMonitored[contractAddress];
        delete assetToRescue[contractAddress];

        emit ContractRemoved(contractAddress);
    }
}
