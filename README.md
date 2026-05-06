# Cross-Chain Rebase Token (CCRT)

## Overview

A protocol that allows users to deposit funds into a vault and in return, receive rebase tokens that represent their underlying balance. The protocol is designed to incentivize early adoption through a decreasing global interest rate system and supports cross-chain functionality via Chainlink CCIP.

## Core Concepts

1. **Rebase Mechanism**
   - A protocol that allows users to deposit funds into a vault and in return, receive rebase tokens that represent their underlying balance.
   - Rebase token → `balanceOf` function is dynamic to show changing balance over time.
   - Balance increases linearly over time.
   - Tokens are minted to users every time they make an action (minting, burning, transferring or bridging etc...)
   - Passing `type(uint256).max` to `burn` or `transfer` will automatically resolve to the user's full balance — no need to calculate it yourself.

2. **Interest Rates**
   - Individually set an interest rate for each user based on the global interest rate of the protocol at the time the user deposits into the vault.
   - This global interest rate decreases over time to incentivize/reward early adopters.
   - Interest rate can only be decreased, not increased.
   - Each user's individual interest rate is locked in at the time of their deposit.
   - When a user transfers tokens to a new address (zero balance), the recipient inherits the sender's interest rate.

3. **Cross-Chain Functionality**
   - Tokens can be bridged across chains using Chainlink CCIP.
   - When tokens are burned on the source chain, they are minted on the destination chain at the destination chain's current global interest rate.
   - The pool handles its own mint/burn permissions — no manual interest rate encoding needed.

## Smart Contracts

### RebaseToken.sol
- **Purpose**: The core ERC20 token contract with rebase functionality.
- **Key Features**:
  - Dynamic `balanceOf` that calculates accrued interest on-the-fly.
  - Automatic interest accrual on transfers, mints, and burns via `_mintAccruedInterest`.
  - Per-user interest rates locked in at deposit time, with a `getPrincipleAmount` getter to read the raw (pre-interest) balance separately from the dynamic one.
  - Role-based access control via OpenZeppelin `AccessControl` — minting and burning are gated behind `MINT_AND_BURN_ROLE`, granted explicitly to the Vault and Pool.
  - Global interest rate that can only decrease over time, enforced by a custom error `RebaseToken__InterestRateCanOnlyDecrease`.
  - `grantMintAndBurnRole(address)` exposed so the deployer can authorize the Vault and Pool after deployment.

### Vault.sol
- **Purpose**: Allows users to deposit ETH and receive rebase tokens, and redeem them back for ETH.
- **Key Features**:
  - ETH-only vault — accepts deposits via a payable `deposit()` function and redeems via `redeem(uint256 _amount)`.
  - Mints rebase tokens at the current global interest rate at deposit time.
  - Passing `type(uint256).max` to `redeem` automatically redeems the full balance.
  - Emits `Deposit` and `Redeem` events.
  - Exposes `getRebaseTokenAddress()` for downstream integrations.

### RebaseTokenPool.sol
- **Purpose**: Enables cross-chain bridging of rebase tokens via Chainlink CCIP.
- **Key Features**:
  - Inherits from Chainlink's `TokenPool` contract.
  - Overrides `_lockOrBurn` to burn tokens on the source chain and `_releaseOrMint` to mint on the destination chain at the destination chain's current interest rate.
  - Constructed with the token address, an allow-list, RMN proxy, and router — wired up automatically by the deployer scripts.

### IRebaseToken.sol
- **Purpose**: Interface defining the public API for the RebaseToken contract, used by both the Vault and the Pool to interact with the token without tight coupling.
- **Key Methods**:
  - `mint(address _to, uint256 _amount, uint256 _userInterestRate)`: Mint tokens with a specific interest rate.
  - `burn(address _from, uint256 _amount)`: Burn tokens.
  - `balanceOf(address account)`: Get dynamic balance including accrued interest.
  - `getInterestRate()`: Get the current global interest rate.
  - `getUserInterestRate(address _user)`: Get a specific user's locked-in interest rate.
  - `grantMintAndBurnRole(address _account)`: Grant mint/burn permissions to an address.

## Architecture

1. User deposits ETH into the **Vault**.
2. Vault reads the current global interest rate from **RebaseToken** and mints tokens to the user at that rate.
3. User's interest rate is fixed at the time of deposit.
4. Token balance grows automatically through the rebase mechanism — no user action needed.
5. Users can transfer tokens (accrued interest is settled for both parties before the transfer).
6. Users can bridge tokens to other chains via the **RebaseTokenPool** and Chainlink CCIP — the pool burns on the source chain and mints on the destination chain at the destination's current rate.
7. Users can redeem their tokens at any time by calling `redeem` on the Vault, which burns their tokens and sends back the equivalent ETH.

## Deployment Scripts

There are three deployment scripts under `script/`, meant to be run in order when deploying to a new chain or configuring a cross-chain lane.

### Deployer.s.sol

Contains two scripts:

- **`TokenAndPoolDeployer`** — Deploys a `RebaseToken` and a `RebaseTokenPool` on the current chain. Automatically reads network details from `CCIPLocalSimulatorFork`, grants the pool the mint/burn role, registers the token with the `RegistryModuleOwnerCustom`, accepts the admin role, and sets the pool in the `TokenAdminRegistry`. This is the first script you run on each chain.

- **`VaultDeployer`** — Deploys a `Vault` for a given `RebaseToken` address and grants it the mint/burn role. Run this after `TokenAndPoolDeployer` on the chain where users will deposit.

### ConfigurePool.s.sol

Wires up a local pool to recognize a remote chain. Takes the local pool address, the remote chain selector, the remote pool address, the remote token address, and inbound/outbound rate limiter configs as arguments. Run this on both chains after deploying to both — once pointing source → destination and once pointing destination → source.

### BridgeTokens.s.sol

Sends tokens cross-chain via CCIP. Takes the receiver address, destination chain selector, token address, amount, LINK token address, and router address. Handles fee calculation, approvals, and the `ccipSend` call in a single script run.

## Tests

Tests are split into two files under `test/`.

### RebaseToken.t.sol
Unit tests covering the core token mechanics — deposits, interest accrual over time, interest rate decrease enforcement, transfers preserving interest rates for new recipients, and redeem flows.

### CrossChain.t.sol
Fork tests using `CCIPLocalSimulatorFork` to simulate a full cross-chain round trip between Sepolia and Arbitrum Sepolia. The test suite:
- Spins up two forks and deploys the full stack (token, pool, vault) on each.
- Configures both pools to recognize each other's chain.
- Deposits ETH on Sepolia, bridges the full balance to Arbitrum Sepolia, waits for interest to accrue, then bridges back.
- Asserts balances are correct and that the user's interest rate is preserved across both bridge directions.

## Build

```bash
forge build --via-ir
```

## Test

```bash
forge test --via-ir
```

> **Note**: `--via-ir` is required. Without it you'll hit a `Stack too deep` compiler error due to the complexity of the cross-chain contracts.

To run only the unit tests (faster, no RPC needed):

```bash
forge test --via-ir --match-path test/RebaseToken.t.sol
```

To run the fork tests (requires RPC URLs for `sepolia` and `arb-sepolia` configured in your `foundry.toml` or environment):

```bash
forge test --via-ir --match-path test/CrossChain.t.sol
```
