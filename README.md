# Drosera Self-Destruct Asset Rescue Trap

This repository contains a Drosera trap designed to rescue assets from a contract that is about to self-destruct. It follows Drosera's recommended architecture for stateless traps, separating responsibilities between an off-chain detector, an on-chain registry, a stateless trap, and a response protocol.

[![view - Documentation](https://img.shields.io/badge/view-Documentation-blue?style=for-the-badge)](https://dev.drosera.io "Project documentation")
[![Twitter](https://img.shields.io/twitter/follow/DroseraNetwork?style=for-the-badge)](https://x.com/DroseraNetwork)

## Architecture Overview

The system is composed of four main components:

1.  **Off-Chain Detector (Operator's responsibility):** This component is responsible for monitoring the mempool for transactions that will lead to a contract self-destructing. When it detects such a transaction, it calls the `arm` function on the `SelfDestructRegistry` to mark the target contract as "armed".
2.  **`SelfDestructRegistry.sol`:** A simple on-chain registry that stores a list of contracts that are about to self-destruct. The off-chain detector writes to this registry.
3.  **`SelfDestructTrap.sol`:** A stateless Drosera trap.
    *   `collect()`: This function is designed to be extremely cheap, returning an empty `bytes` array.
    *   `shouldRespond()`: This `pure` function is called by Drosera operators. The data about armed targets is provided by the operators' off-chain detectors. It decodes the data and, if a target is armed, returns a payload for the `ResponseProtocol`.
4.  **`ResponseProtocol.sol`:** This contract receives the payload from the trap and executes the rescue logic. It calls a pre-configured `EmergencyController` contract to perform actions like pausing the target contract or withdrawing assets. Authorization is handled by the Drosera network, which ensures only whitelisted operators can successfully call the `rescue` function.

## Configure dev environment

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup

# The trap-foundry-template utilizes node modules for dependency management
# install Bun (optional)
curl -fsSL https://bun.sh/install | bash

# install node modules
bun install

# install vscode (optional)
# - add solidity extension JuanBlanco.solidity

# install drosera-cli
curl -L https://app.drosera.io/install | bash
droseraup
```

Open the VSCode preferences and select `Solidity: Change workspace compiler version (Remote)`. Select version `0.8.26`.

## Deployment and Configuration

The deployment process involves several steps:

1.  **Deploy `SelfDestructRegistry.sol`:**
    ```bash
    forge create src/SelfDestructRegistry.sol:SelfDestructRegistry --rpc-url <your_rpc_url> --private-key <your_private_key>
    ```
    Take note of the deployed registry address.

2.  **Deploy an Emergency Controller:**
    You need a controller contract that can pause or withdraw funds from your target contracts. A mock is provided (`test/SelfDestructTrap.t.sol:MockEmergencyController`), but for a real scenario, you would deploy your own.
    ```bash
    # Example deploying the mock
    forge create test/SelfDestructTrap.t.sol:MockEmergencyController --rpc-url <your_rpc_url> --private-key <your_private_key>
    ```
    Take note of the deployed controller address.

3.  **Deploy `ResponseProtocol.sol`:**
    Deploy the responder, passing the controller's address to the constructor.
    ```bash
    forge create src/ResponseProtocol.sol:ResponseProtocol --rpc-url <your_rpc_url> --private-key <your_private_key> --constructor-args <controller_address>
    ```
    Take note of the deployed responder address.

4.  **Update `drosera.toml`:**
    *   Replace the placeholder `response_contract` address with the address of your deployed `ResponseProtocol`.
    *   Update `response_function` to `"rescue(bytes)"`.

5.  **Deploy the Trap:**
    The `SelfDestructTrap` constructor requires the address of the `SelfDestructRegistry`. This must be passed during the Drosera deployment process.
    ```bash
    # Compile the Trap
    forge build

    # Deploy the Trap
    DROSERA_PRIVATE_KEY=0x... drosera apply --constructor-args <registry_address>
    ```

6.  **Configure Off-Chain Detector:**
    Your off-chain detector needs the address of the `SelfDestructRegistry` and a private key to call the `arm` and `disarm` functions.

## Testing

Example tests are included in the `test` directory. They simulate the full workflow from arming a target in the registry to the responder executing the rescue. To run the tests, execute the following command:

```bash
forge test
```