// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {SelfDestructTrap} from "../src/SelfDestructTrap.sol";
import {ResponseProtocol} from "../src/ResponseProtocol.sol";
import {Destructible} from "./Destructible.sol";
import {MockERC20} from "./MockERC20.sol";

contract SelfDestructTrapTest is Test {
    SelfDestructTrap public trap;
    ResponseProtocol public responseProtocol;
    Destructible public destructible;
    MockERC20 public token;
    address owner = makeAddr("owner");
    address user = makeAddr("user");

    function setUp() public {
        vm.prank(owner);
        trap = new SelfDestructTrap();
        responseProtocol = new ResponseProtocol();
        token = new MockERC20("Mock Token", "MT", 18);
        destructible = new Destructible(address(token));
    }

    function test_Trap_ShouldRescueETH() public {
        // Fund the destructible contract with ETH
        payable(address(destructible)).transfer(1 ether);

        // Add the contract to the monitored list for ETH rescue
        vm.prank(owner);
        trap.addContract(address(destructible), address(0));

        // Destroy the contract
        destructible.die();
        vm.etch(address(destructible), bytes(""));

        // Check if the trap alerts and returns the correct response
        (bool alert, bytes memory response) = trap.trap(address(destructible), "");
        assertTrue(alert, "Trap should alert for ETH rescue");

        // Decode the response and call the response protocol
        (address target, address asset) = abi.decode(response, (address, address));
        responseProtocol.rescue(target, asset);

        // Verify the rescue operation
        assertEq(responseProtocol.lastTarget(), address(destructible));
        assertEq(responseProtocol.lastAsset(), address(0));
    }

    function test_Trap_ShouldRescueERC20() public {
        // Fund the destructible contract with ERC20 tokens
        token.mint(address(destructible), 100 ether);

        // Add the contract to the monitored list for ERC20 rescue
        vm.prank(owner);
        trap.addContract(address(destructible), address(token));

        // Destroy the contract
        destructible.die();
        vm.etch(address(destructible), bytes(""));

        // Check if the trap alerts and returns the correct response
        (bool alert, bytes memory response) = trap.trap(address(destructible), "");
        assertTrue(alert, "Trap should alert for ERC20 rescue");

        // Decode the response and call the response protocol
        (address target, address asset) = abi.decode(response, (address, address));
        responseProtocol.rescue(target, asset);

        // Verify the rescue operation
        assertEq(responseProtocol.lastTarget(), address(destructible));
        assertEq(responseProtocol.lastAsset(), address(token));
    }

    function test_Trap_ShouldNotAlertForUnmonitoredContracts() public {
        destructible.die();
        (bool alert, ) = trap.trap(address(destructible), "");
        assertFalse(alert, "Trap should not alert for unmonitored contracts");
    }

    function test_Trap_ShouldNotAlertIfNoSelfDestruct() public {
        vm.prank(owner);
        trap.addContract(address(destructible), address(0));
        (bool alert, ) = trap.trap(address(destructible), "");
        assertFalse(alert, "Trap should not alert when no self-destruct has occurred");
    }

    function test_OwnerCanAddAndRemoveContracts() public {
        vm.prank(owner);
        trap.addContract(address(destructible), address(token));
        assertTrue(trap.isMonitored(address(destructible)));
        assertEq(trap.assetToRescue(address(destructible)), address(token));

        vm.prank(owner);
        trap.removeContract(address(destructible));
        assertFalse(trap.isMonitored(address(destructible)));
    }

    function test_NonOwnerCannotAddContract() public {
        vm.prank(user);
        vm.expectRevert();
        trap.addContract(address(destructible), address(0));
    }

    function test_NonOwnerCannotRemoveContract() public {
        vm.prank(owner);
        trap.addContract(address(destructible), address(0));

        vm.prank(user);
        vm.expectRevert();
        trap.removeContract(address(destructible));
    }
}
