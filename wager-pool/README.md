# BetSport: Decentralized Wagering System for Sporting Events

## Overview

BetSport is a comprehensive smart contract for the Stacks blockchain that enables the creation and management of decentralized betting pools for sporting events. The system allows users to create matches, place wagers on different outcomes, and receive rewards based on configurable distribution models.

## Features

- **Match Creation**: Create betting pools for sporting events with customizable parameters
- **Multiple Reward Models**: Support for three different reward distribution systems:
  - Equal distribution: Divides the total pot equally among winning bets
  - Stake-proportional: Rewards based on the relative size of winning stakes
  - Fixed-rate: Pre-defined payout rates for each outcome
- **Transparent Wagering**: All bets are recorded on the blockchain for full transparency
- **Automated Payouts**: Winners can collect rewards automatically after match outcomes are determined
- **Match Administration**: Ability to close wagering and cancel matches under specific conditions

## Smart Contract Functions

### Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-match-details` | Returns all details for a specified match ID |
| `get-player-wager` | Returns a player's wager for a specific match |
| `get-current-height` | Returns the current block height |

### Public Functions

| Function | Description |
|----------|-------------|
| `create-new-match` | Creates a new betting pool for a sporting event |
| `place-wager` | Places a wager on a specific outcome for a match |
| `close-match-wagering` | Closes wagering for a match (requires host or admin) |
| `cancel-match` | Cancels a match and initiates refunds (requires host) |
| `collect-winnings` | Allows winners to collect their rewards after match outcome is determined |
| `set-match-outcome` | Sets the winning outcome(s) for a match (admin only) |

## Usage Guide

### Creating a Match

To create a new betting pool for a sporting event:

```clarity
(contract-call? .betsport create-new-match 
  "NBA Finals Game 1: Lakers vs Celtics" 
  (list "Lakers Win" "Celtics Win" "Tie") 
  u725000 
  "stake-proportional" 
  none)
```

Parameters:
- `match-description`: A description of the sporting event (max 256 ASCII characters)
- `possible-outcomes`: List of possible outcomes (max 10, each max 64 ASCII characters)
- `close-height`: Block height at which wagering will close
- `reward-distribution`: Reward model ("equal-distribution", "stake-proportional", or "fixed-rate")
- `payout-rates`: Optional list of payout rates for fixed-rate model (percentage values as uint)

### Placing a Wager

To place a wager on a match outcome:

```clarity
(contract-call? .betsport place-wager u1 u2 u100000000)
```

Parameters:
- `match-id`: ID of the match to wager on
- `outcome-choice`: ID of the chosen outcome (1-based index)
- `wager-amount`: Wager amount in microSTX (uSTX)

### Collecting Winnings

After a match outcome is determined, winners can collect their rewards:

```clarity
(contract-call? .betsport collect-winnings u1)
```

Parameters:
- `match-id`: ID of the match to collect winnings from

### Administration Functions

#### Close Match Wagering

```clarity
(contract-call? .betsport close-match-wagering u1)
```

Parameters:
- `match-id`: ID of the match to close wagering for

#### Cancel Match

```clarity
(contract-call? .betsport cancel-match u1)
```

Parameters:
- `match-id`: ID of the match to cancel

#### Set Match Outcome

```clarity
(contract-call? .betsport set-match-outcome u1 (list u2))
```

Parameters:
- `match-id`: ID of the match to set outcome for
- `outcome-ids`: List of winning outcome IDs (1-based index, max 5 winners)

## Error Codes

| Error Code | Description |
|------------|-------------|
| `ERR-ACCESS-DENIED` | User does not have permission for this action |
| `ERR-MATCH-DOES-NOT-EXIST` | The specified match ID does not exist |
| `ERR-WAGERING-DISABLED` | Wagering is not currently allowed for this match |
| `ERR-FUNDS-TOO-LOW` | Insufficient funds for the transaction |
| `ERR-OUTCOME-ALREADY-DETERMINED` | Match outcome has already been set |
| `ERR-EARLY-MATCH-CLOSURE` | Attempting to close match before deadline |
| `ERR-EARLY-MATCH-CANCELLATION` | Attempting to cancel match after deadline |
| `ERR-TOO-FEW-OPTIONS` | Match requires at least two outcome options |
| `ERR-INVALID-CLOSING-HEIGHT` | Closing height must be in the future |
| `ERR-UNKNOWN-REWARD-MODEL` | Unrecognized reward distribution model |
| `ERR-PAYOUT-RATES-NEEDED` | Fixed-rate model requires payout rates |
| `ERR-OUTCOME-CHOICE-INVALID` | Invalid outcome choice |
| `ERR-MATCH-CONCLUDED` | Match has already concluded |
| `ERR-WINNING-OPTIONS-REQUIRED` | At least one winning option must be provided |
| `ERR-MAX-WINNERS-EXCEEDED` | Maximum of 5 winning outcomes allowed |
| `ERR-INVALID-WINNER-IDS` | Invalid winning outcome IDs |
| `ERR-BET-NOT-WINNING` | User's bet is not a winning bet |
| `ERR-REFUND-FAILED` | Failed to process refund |
| `ERR-REFUND-EXCEPTION` | Exception occurred during refund processing |
| `ERR-EMPTY-MATCH-DESCRIPTION` | Match description cannot be empty |
| `ERR-WAGER-AMOUNT-INVALID` | Wager amount must be greater than zero |

## Security Considerations

- The contract uses the principle of least privilege, with certain functions restricted to the admin or match host
- Funds are held in the contract until match outcomes are determined or refunds are processed
- Wagers cannot be placed after the wagering deadline
- Multiple validation checks are in place to ensure correct operation

## Example Workflow

1. Admin or user creates a new match using `create-new-match`
2. Users place wagers on different outcomes using `place-wager`
3. When the wagering deadline is reached, the host or admin calls `close-match-wagering`
4. Admin determines the match outcome and calls `set-match-outcome`
5. Winners call `collect-winnings` to receive their rewards