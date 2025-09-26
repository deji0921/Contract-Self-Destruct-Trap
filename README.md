# Drosera Self-Destruct Asset Rescue Trap

This repository contains a Drosera trap designed to rescue assets from a contract that is about to self-destruct. It demonstrates a powerful, reactive use case for the Drosera network, preventing asset loss rather than just reporting it.

[![view - Documentation](https://img.shields.io/badge/view-Documentation-blue?style=for-the-badge)](https://dev.drosera.io "Project documentation")
[![Twitter](https://img.shields.io/twitter/follow/DroseraNetwork?style=for-the-badge)](https://x.com/DroseraNetwork)

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

## Quick Start

### Self-Destruct Asset Rescue Trap

The `drosera.toml` file is configured to deploy the `SelfDestructTrap`. This trap monitors a target contract for a pending `selfdestruct` operation. If detected, it triggers a `ResponseProtocol` contract to rescue the assets (ETH or ERC20 tokens) from the target contract before it is destroyed.

To deploy the trap, you first need to deploy the `ResponseProtocol.sol` contract to get its address.

1.  **Deploy `ResponseProtocol.sol`:**
    ```bash
    forge script scripts/DeployResponseProtocol.s.sol --rpc-url <your_rpc_url> --private-key <your_private_key> --broadcast
    ```
    Take note of the deployed contract address.

2.  **Update `drosera.toml`:**
    Replace the placeholder `response_contract` address with the address of your deployed `ResponseProtocol` contract.

3.  **Deploy the Trap:**
    ```bash
    # Compile the Trap
    forge build

    # Deploy the Trap
    DROSERA_PRIVATE_KEY=0x.. drosera apply
    ```

After successfully deploying the trap, the CLI will add an `address` field to the `drosera.toml` file for the `self_destruct_trap`.

## Testing

Example tests are included in the `test` directory. They simulate how Drosera Operators execute traps and trigger the asset rescue mechanism. To run the tests, execute the following command:

```bash
forge test
```
