# Synthetic Forex Trading Smart Contract

A Clarity smart contract that enables trading of synthetic forex pairs on the Stacks blockchain. The contract implements an automated market maker (AMM) system with built-in price oracles, rebase mechanism, and governance controls.

## Features

- **Synthetic Forex Pairs**: Create and trade synthetic assets representing forex pairs
- **Oracle Integration**: Price feed system for real-time forex rates
- **Automated Market Making**: Swap between different synthetic forex pairs
- **Rebase Mechanism**: Automatic supply adjustments to maintain price parity
- **Governance Parameters**: Configurable protocol parameters with owner controls

## Core Functions

### Asset Management

- `create-forex-pair`: Create a new synthetic forex pair
- `mint-synthetic`: Mint new synthetic tokens by providing collateral
- `burn-synthetic`: Burn synthetic tokens to retrieve collateral

### Trading

- `swap`: Exchange between different synthetic forex pairs
- `trigger-rebase`: Adjust token supply based on price deviations

### Oracle Operations

- `update-price-feed`: Update price data for forex pairs
- `get-price`: Retrieve current price for a forex pair

### Governance

- `update-governance-param`: Modify protocol parameters
- `pause-trading`: Emergency pause function
- `resume-trading`: Resume trading after pause

## Key Parameters

- **Rebase Threshold**: 1% deviation trigger
- **Minimum Collateral Ratio**: 150%
- **Protocol Fee**: 0.25%

## Error Codes

- `u100`: Owner-only operation
- `u101`: Invalid pair
- `u102`: Insufficient balance
- `u103`: Invalid price
- `u104`: Not initialized
- `u105`: Already initialized

## Data Structures

### Pairs Map
```clarity
{
    base: (string-ascii 10),
    quote: (string-ascii 10),
    price: uint,
    supply: uint,
    last-rebase: uint
}
```

### Price Feeds Map
```clarity
{
    price: uint,
    timestamp: uint,
    valid: bool
}
```

### User Balances Map
```clarity
{
    balance: uint
}
```

## Usage Examples

### Creating a New Forex Pair
```clarity
(contract-call? .forex-contract create-forex-pair "EUR" "USD" u100000000)
```

### Minting Synthetic Tokens
```clarity
(contract-call? .forex-contract mint-synthetic u1 u1000000000)
```

### Performing a Swap
```clarity
(contract-call? .forex-contract swap u1 u2 u500000000)
```

## Security Considerations

1. **Oracle Dependency**: Price feeds must be kept up-to-date and accurate
2. **Collateralization**: Users must maintain minimum collateral ratio
3. **Rebase Impact**: Large price deviations can trigger supply adjustments

## Contract Owner Responsibilities

- Maintain accurate price feeds
- Monitor system parameters
- Respond to emergency situations
- Update governance parameters as needed

## Best Practices

1. Monitor collateral ratios regularly
2. Check price feeds before large trades
3. Be aware of rebase conditions
4. Understand fee implications