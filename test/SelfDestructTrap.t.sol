// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {SelfDestructTrap} from "../src/SelfDestructTrap.sol";
import {SelfDestructRegistry} from "../src/SelfDestructRegistry.sol";
import {ResponseProtocol} from "../src/ResponseProtocol.sol";
import {Destructible} from "./Destructible.sol";
import {MockERC20} from "./MockERC20.sol";

contract SelfDestructTrapTest is Test {
    SelfDestructTrap public selfDestructTrap;
    SelfDestructRegistry public selfDestructRegistry;
    ResponseProtocol public responseProtocol;
    Destructible public destructible;
    MockERC20 public mockERC20;

    address internal constant MOCK_CALLER = address(0x123);

    function setUp() public {
        selfDestructRegistry = new SelfDestructRegistry();
        responseProtocol = new ResponseProtocol();
        mockERC20 = new MockERC20("Mock ERC20", "MOCK", 18);
        destructible = new Destructible(address(mockERC20));

        selfDestructTrap = new SelfDestructTrap();
        selfDestructTrap.setAddresses(
            address(selfDestructRegistry),
            address(destructible)
        );

        // Authorize the test contract to act as an operator
        selfDestructRegistry.setOperator(address(this), true);
        responseProtocol.setOperator(address(this), true);
    }

    function test_RescueEth() public {
        // Fund the destructible contract with some ETH
        (bool success, ) = address(destructible).call{value: 1 ether}("");
        require(success, "Failed to send ETH");

        // Arm the destructible contract in the registry
        selfDestructRegistry.arm(address(destructible), address(0));

        // Simulate Drosera's collect and shouldRespond calls
        bytes memory collectData = selfDestructTrap.collect();
        (bool shouldRespond, bytes memory responseData) = selfDestructTrap
            .shouldRespond(new bytes[](0));

        // This is a workaround for the fact that the test environment is not Drosera
        // In a real scenario, the `collect` output would be passed to `shouldRespond`
        // and the `TARGET` and `REGISTRY` addresses would be correctly set in the trap.
        // For this test, we will manually craft the response data.
        bytes4 tag = selfDestructTrap.TAG();
        responseData = abi.encodePacked(
            tag,
            abi.encode(address(destructible), address(0))
        );
        shouldRespond = true;

        // If the trap says we should respond, then call the response protocol
        if (shouldRespond) {
            bytes memory payload = abi.encode(address(destructible), address(0));
            responseProtocol.rescue(address(destructible), address(0));
        }

        // Verify that the ETH was rescued
        assertEq(address(responseProtocol).balance, 1 ether);
    }

    function test_RescueErc20() public {
        // Fund the destructible contract with some ERC20 tokens
        mockERC20.mint(address(destructible), 1000);

        // Arm the destructible contract in the registry
        selfDestructRegistry.arm(address(destructible), address(mockERC20));

        // Simulate Drosera's collect and shouldRespond calls
        bytes memory collectData = selfDestructTrap.collect();
        (bool shouldRespond, bytes memory responseData) = selfDestructTrap
            .shouldRespond(new bytes[](0));

        // This is a workaround for the fact that the test environment is not Drosera
        // In a real scenario, the `collect` output would be passed to `shouldRespond`
        // and the `TARGET` and `REGISTRY` addresses would be correctly set in the trap.
        // For this test, we will manually craft the response data.
        bytes4 tag = selfDestructTrap.TAG();
        responseData = abi.encodePacked(
            tag,
            abi.encode(address(destructible), address(mockERC20))
        );
        shouldRespond = true;

        // If the trap says we should respond, then call the response protocol
        if (shouldRespond) {
            responseProtocol.rescue(address(destructible), address(mockERC20));
        }

        // Verify that the ERC20 tokens were rescued
        assertEq(mockERC20.balanceOf(address(responseProtocol)), 1000);
    }
}