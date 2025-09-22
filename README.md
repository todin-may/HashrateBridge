# HashrateBridge

HashrateBridge is a cross-chain automated market maker (AMM) liquidity pool that enables seamless swapping between Bitcoin hashrate tokens and STX tokens on the Stacks blockchain. The protocol provides a decentralized mechanism for trading hashrate derivatives while offering liquidity provision rewards to users.

## Features

- **Automated Market Maker**: Constant product formula (x * y = k) for efficient price discovery
- **Cross-Chain Bridge**: Mint and burn hashrate tokens for cross-chain functionality
- **Liquidity Provision**: Users can provide liquidity and earn fees from trades
- **Slippage Protection**: Built-in slippage tolerance for all trading operations
- **Fee Structure**: 0.3% trading fee on all swaps
- **Admin Controls**: Secure token minting/burning for bridge operations

## Technical Specifications

- **Blockchain**: Stacks
- **Language**: Clarity 2.0
- **Token Standards**: Custom fungible tokens (hashrate-token, lp-token)
- **Fee Rate**: 30 basis points (0.3%)
- **Minimum Liquidity**: 1,000 units (prevents zero-division attacks)

## Installation

### Prerequisites

- [Clarinet CLI](https://github.com/hirosystems/clarinet) installed
- Node.js and npm for testing
- Stacks wallet for interaction

### Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd HashrateBridge
```

2. Navigate to the contract directory:
```bash
cd HashrateBridge_contract
```

3. Install dependencies:
```bash
npm install
```

4. Run tests:
```bash
npm run test
```

## Usage Examples

### Initialize the Pool (Owner Only)

```clarity
(contract-call? .HashrateBridge initialize-pool u1000000 u500000)
```

### Add Liquidity

```clarity
(contract-call? .HashrateBridge add-liquidity u100000 u50000 u1000)
```
- `stx-amount`: Amount of STX to add
- `hashrate-amount`: Amount of hashrate tokens to add
- `min-lp-tokens`: Minimum LP tokens expected (slippage protection)

### Remove Liquidity

```clarity
(contract-call? .HashrateBridge remove-liquidity u1000 u90000 u45000)
```
- `lp-amount`: Amount of LP tokens to burn
- `min-stx`: Minimum STX expected back
- `min-hashrate`: Minimum hashrate tokens expected back

### Swap STX for Hashrate Tokens

```clarity
(contract-call? .HashrateBridge swap-stx-for-hashrate u10000 u4500)
```
- `stx-in`: Amount of STX to swap
- `min-hashrate-out`: Minimum hashrate tokens expected

### Swap Hashrate Tokens for STX

```clarity
(contract-call? .HashrateBridge swap-hashrate-for-stx u5000 u9500)
```
- `hashrate-in`: Amount of hashrate tokens to swap
- `min-stx-out`: Minimum STX expected

## Contract Functions Documentation

### Public Functions

#### `initialize-pool`
Initializes the liquidity pool with initial reserves. Only callable by contract owner.
- **Parameters**: `initial-stx` (uint), `initial-hashrate` (uint)
- **Returns**: Amount of LP tokens minted
- **Access**: Owner only

#### `add-liquidity`
Adds liquidity to the pool and receives LP tokens in proportion to contribution.
- **Parameters**: `stx-amount` (uint), `hashrate-amount` (uint), `min-lp-tokens` (uint)
- **Returns**: Amount of LP tokens received
- **Access**: Public

#### `remove-liquidity`
Burns LP tokens to withdraw proportional amounts of both tokens.
- **Parameters**: `lp-amount` (uint), `min-stx` (uint), `min-hashrate` (uint)
- **Returns**: Object with withdrawn amounts
- **Access**: Public

#### `swap-stx-for-hashrate`
Swaps STX tokens for hashrate tokens using AMM pricing.
- **Parameters**: `stx-in` (uint), `min-hashrate-out` (uint)
- **Returns**: Amount of hashrate tokens received
- **Access**: Public

#### `swap-hashrate-for-stx`
Swaps hashrate tokens for STX tokens using AMM pricing.
- **Parameters**: `hashrate-in` (uint), `min-stx-out` (uint)
- **Returns**: Amount of STX received
- **Access**: Public

#### `mint-hashrate-tokens`
Mints new hashrate tokens for cross-chain bridging operations.
- **Parameters**: `amount` (uint), `recipient` (principal)
- **Returns**: Success/failure
- **Access**: Owner only

#### `burn-hashrate-tokens`
Burns hashrate tokens for cross-chain bridging operations.
- **Parameters**: `amount` (uint)
- **Returns**: Success/failure
- **Access**: Public (user burns their own tokens)

### Read-Only Functions

#### `get-reserves`
Returns current pool reserves and LP token supply.

#### `get-user-lp-balance`
Returns LP token balance for a specific user.

#### `get-user-hashrate-balance`
Returns hashrate token balance for a specific user.

#### `get-stx-to-hashrate-price`
Calculates expected hashrate tokens for a given STX input.

#### `get-hashrate-to-stx-price`
Calculates expected STX for a given hashrate token input.

#### `is-pool-initialized`
Returns whether the pool has been initialized.

#### `get-contract-info`
Returns contract configuration details.

## Deployment Guide

### Testnet Deployment

1. Configure your Clarinet.toml for testnet:
```toml
[network]
name = "testnet"
```

2. Deploy the contract:
```bash
clarinet deployments generate --testnet
clarinet deployments apply --testnet
```

### Mainnet Deployment

1. Configure for mainnet in Clarinet.toml
2. Generate deployment plan:
```bash
clarinet deployments generate --mainnet
```
3. Review and apply:
```bash
clarinet deployments apply --mainnet
```

## Security Notes

### Audit Recommendations

- **Slippage Protection**: Always set appropriate slippage limits to prevent MEV attacks
- **Liquidity Checks**: Contract validates sufficient liquidity before executing swaps
- **Integer Overflow**: Clarity's built-in overflow protection prevents arithmetic attacks
- **Access Control**: Admin functions are properly restricted to contract owner

### Known Considerations

- **Price Impact**: Large trades will experience significant price impact due to AMM mechanics
- **Minimum Liquidity**: 1,000 units of minimum liquidity are permanently locked to prevent manipulation
- **Cross-Chain Risk**: Bridge operations require trust in the contract owner for minting/burning

### Best Practices

1. Always use slippage protection parameters
2. Check pool reserves before large transactions
3. Monitor for price impact on significant swaps
4. Verify transaction parameters before signing

## Development

### Testing

Run the test suite:
```bash
npm run test
```

Run tests with coverage:
```bash
npm run test:report
```

Watch mode for development:
```bash
npm run test:watch
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

This project is licensed under the ISC License.

## Contact

For questions, issues, or contributions, please open an issue in the repository.