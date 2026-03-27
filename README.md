# Cross-Chain Rebase Token

1. A protocol that allows user to deposit funds into a vault and in return, receive rebase tokens that represent their underlying balance.

2. Rebase token -> balanceOf function is dynamic to show changing balance over time. 
- Balance increases linearly over time.
- mint tokens to users everytime they make an action (minting, burning, transferring or bridging etc...)

3. Interest rates
- Individually set an interest rate for each user based on some global interest rate of the protocol at the time the user deposits into the vault.
- This global interest rate decreases over time to incentivize/reward early adopters.