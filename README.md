# Cross-Chain Rebase Token (CCRT)

## Overview

A protocol that allows users to deposit funds into a vault and in return, receive rebase tokens that represent their underlying balance. The protocol is designed to incentivize early adoption through a decreasing global interest rate system and supports cross-chain functionality via Chainlink CCIP.

## Core Concepts

1. **Rebase Mechanism**
   - A protocol that allows user to deposit funds into a vault and in return, receive rebase tokens that represent their underlying balance.
   - Rebase token → `balanceOf` function is dynamic to show changing balance over time.
   - Balance increases linearly over time.
   - Tokens are minted to users every time they make an action (minting, burning, transferring or bridging etc...)

2. **Interest Rates**
   - Individually set an interest rate for each user based on some global interest rate of the protocol at the time the user deposits into the vault.
   - This global interest rate decreases over time to incentivize/reward early adopters.
   - Interest rate can only be decreased, not increased.
   - Each user's individual interest rate is locked in at the time of their deposit.

3. **Cross-Chain Functionality**
   - Tokens can be bridged across chains using Chainlink CCIP.
   - When tokens are locked/burned on the source chain, they are minted on the destination chain.
   - User interest rates are preserved when bridging tokens across chains.

## Smart Contracts

### RebaseToken.sol
- **Purpose**: The core ERC20 token contract with rebase functionality.
- **Key Features**:
  - Dynamic `balanceOf` that calculates accrued interest on-the-fly.
  - Automatic interest accrual on transfers, mints, and burns.
  - Per-user interest rates managed at deposit time.
  - Role-based access control for minting and burning (Vault and Pool authorized actors).
  - Global interest rate that can only decrease over time.

### Vault.sol
- **Purpose**: Allows users to deposit funds and receive rebase tokens.
- **Key Features**:
  - Accepts deposits in a base asset (e.g., ETH or ERC20).
  - Mints rebase tokens at the current protocol interest rate.
  - Captures the user's individual interest rate at deposit time.
  - Maintains the principal balance for each depositor.

### RebaseTokenPool.sol
- **Purpose**: Enables cross-chain bridging of rebase tokens via Chainlink CCIP.
- **Key Features**:
  - Inherits from Chainlink's `TokenPool` contract.
  - Locks/burns tokens on source chain and mints on destination chain.
  - Preserves user interest rates when bridging (`destPoolData` encodes interest rates).
  - Automatically calculates local amounts accounting for decimal differences across chains.

### IRebaseToken.sol
- **Purpose**: Interface defining the public API for the RebaseToken contract.
- **Key Methods**:
  - `mint(address _to, uint256 _amount, uint256 _userInterestRate)`: Mint tokens with user interest rate.
  - `burn(address _from, uint256 _amount)`: Burn tokens.
  - `balanceOf(address account)`: Get dynamic balance including accrued interest.
  - `getInterestRate()`: Get the current global interest rate.
  - `getUserInterestRate(address _user)`: Get a specific user's locked-in interest rate.

## Architecture

1. User deposits funds into the **Vault**.
2. Vault mints **RebaseToken** at the current global interest rate.
3. User's interest rate is fixed at the time of deposit.
4. Token balance grows automatically through the rebase mechanism.
5. Users can transfer tokens (balance updates for both parties).
6. Users can bridge tokens to other chains via **RebaseTokenPool** and Chainlink CCIP.
7. On destination chain, tokens are minted at the same interest rate (preserved via pool data).

## Build

```
forge build
```

## Test

```
forge test
```