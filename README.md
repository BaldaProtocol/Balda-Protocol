# Balda Protocol — Technical README

[![Website](https://img.shields.io/badge/Website-Live-brightgreen)](https://baldaprotocol.github.io/Balda-Protocol/) [![Italian README](https://img.shields.io/badge/README-Italiano-blue)](./README_IT.md)

> **Author:** Deaf Italian · *Concept & Decision by Deaf Italian only. Built with AI.*
> **License:** MIT · **Solidity:** ^0.8.20 · **Dependencies:** OpenZeppelin

---

## Table of Contents

1. [Overview](#overview)
2. [Token: Balda (BLD)](#1-baldasol--balda-bld-token)
3. [BaldaReserve](#2-baldareservesol--eternal-reserve)
4. [VaultCreator](#3-vaultcreatorsol--founder-vesting)
5. [BaldaAirdrop](#4-baldaairdropsol--automated-airdrop)
6. [LiquidityVault](#5-liquidityvaultsol--liquidity-lock)
7. [Supply Distribution Summary](#supply-distribution-summary)
8. [Deployment Order](#deployment-order)
9. [Security Properties](#security-properties)
10. [Key Risks & Observations](#key-risks--observations)

---

## Overview

**Balda Protocol** is a fully autonomous, ownerless token system built on Ethereum. It consists of five smart contracts whose interactions are determined entirely at deploy time. There are no admin keys, no upgrade paths, and no privileged roles after deployment. All token distribution rules are enforced immutably on-chain.

The system is designed around three principles:
- **Immutability** — no contract can be modified after deployment.
- **Trustlessness** — no human action is required to enforce rules; the contracts enforce themselves.
- **Transparency** — every rule, amount, and timing constant is hardcoded and publicly verifiable.

---

## 1. `Balda.sol` — Balda (BLD) Token

### Summary

A pure, minimal ERC-20 token with a **fixed total supply of 91,000 BLD** (18 decimals). The entire supply is minted in a single atomic operation inside the constructor. There is no minting function, no burn function, no owner, no pause, no blacklist, and no transfer tax.

### Supply Constants

| Constant          | Value        | Recipient            |
|-------------------|--------------|----------------------|
| `AIRDROP_AMOUNT`  | 70,000 BLD   | `BaldaAirdrop` contract |
| `VAULT_AMOUNT`    | 10,000 BLD   | `VaultCreator` contract |
| `RESERVE_AMOUNT`  |  6,000 BLD   | `BaldaReserve` contract |
| `DEPLOYER_AMOUNT` |  5,000 BLD   | Deployer wallet       |
| **TOTAL_SUPPLY**  | **91,000 BLD** | —                  |

### Constructor Logic

```
constructor(airdropContract, reserveContract, vaultContract)
```

- Validates that all three addresses are non-zero.
- Calls `_mint()` four times (one per recipient).
- Includes a final `assert(totalSupply() == TOTAL_SUPPLY)` safety check — if the arithmetic ever disagrees, the entire deployment reverts.

### Properties

- No `Ownable` import — the contract is ownerless by design.
- Standard ERC-20: `transfer`, `approve`, `transferFrom` only.
- Once deployed, the contract has zero administrative surface.

---

## 2. `BaldaReserve.sol` — Eternal Reserve

### Summary

The simplest contract in the system. It is an intentionally **empty contract** with no state variables, no functions, no constructor logic, no fallback, and no receive hook.

Its sole purpose is to act as a **permanent black hole** for 6,000 BLD. When the Balda token is deployed, tokens are minted directly into this contract's address. Because the contract has no functions, those tokens can never be moved by anyone, ever.

### Why This Matters

The reserve is not merely "locked" — it is **provably inaccessible**. Anyone can inspect the source code on-chain and confirm in seconds that no transfer path exists. This is a stronger guarantee than a time lock or multisig.

---

## 3. `VaultCreator.sol` — Founder Vesting

### Summary

Holds **10,000 BLD** allocated to the protocol founder, split into two independent mechanisms:

| Mechanism       | Amount     | Rules |
|-----------------|------------|-------|
| Linear Vesting  | 5,000 BLD  | Continuous per-second stream over 11 Gregorian years from deploy |
| Tranche 1       | 2,500 BLD  | Claimable after 11 years from deploy |
| Tranche 2       | 1,250 BLD  | Claimable after 22 years from deploy |
| Tranche 3       | 1,250 BLD  | Claimable after 33 years from deploy |

### Timing Constants

All durations use the proleptic Gregorian year (365.2425 × 86,400 seconds):

| Constant          | Seconds       | Human Duration |
|-------------------|---------------|----------------|
| `VESTING_DURATION`| 347,126,472   | 11 years       |
| `TRANCHE_1_DELAY` | 347,126,472   | 11 years       |
| `TRANCHE_2_DELAY` | 694,252,944   | 22 years       |
| `TRANCHE_3_DELAY` | 1,041,379,416 | 33 years       |

### A) Linear Vesting

- Starts at deployment (`deployTime`).
- Accrues continuously, second by second.
- No cliff, no minimum withdrawal amount.
- `withdrawVesting()` is callable only by the `founder` address set at deploy time.
- The founder may withdraw partial amounts at any frequency they choose.
- After 11 years, the full 5,000 BLD is unlocked.

**Key functions:**
- `vestedAmount()` — view: cumulative BLD vested so far.
- `availableVesting()` — view: BLD currently withdrawable.
- `withdrawVesting()` — action: transfer available BLD to founder.

### B) Tranches (Password-Protected Wallet Registration)

The tranche mechanism uses a **commit-reveal scheme** to protect the tranche wallet address:

1. At deploy time, only `keccak256(abi.encodePacked(secretPassword))` is stored — the actual password is never on-chain.
2. The founder calls `registerTrancheWallet(password)` at any time. The contract verifies the hash and permanently registers `msg.sender` as `trancheWallet`.
3. **Security note:** The password must be submitted via Flashbots or a private transaction bundle to prevent mempool front-running.
4. Once registered, `trancheWallet` is immutable.
5. Tranche claims require only the `trancheWallet` address — no password is needed after registration.

**Tranche functions:**
- `registerTrancheWallet(password)` — one-time registration.
- `claimTranche1()` — callable by `trancheWallet` after 11 years.
- `claimTranche(2)` — callable by `trancheWallet` after 22 years.
- `claimTranche(3)` — callable by `trancheWallet` after 33 years.
- `trancheUnlockAt(id)` — view: Unix timestamp when tranche becomes claimable (returns 0 if already unlocked).

### Security

- No owner after deploy.
- No administrative functions.
- No upgrade path.
- No rescue function.
- The `founder` and `passwordHash` are set once, stored as `immutable`, and can never change.

---

## 4. `BaldaAirdrop.sol` — Automated Airdrop

This is the most complex contract in the system. It distributes **70,000 BLD** autonomously across three sequential phases with no owner, no admin keys, and no upgrade path.

### High-Level Structure

| Phase         | BLD Base   | Periods | Duration     | Notes |
|---------------|------------|---------|--------------|-------|
| Cycle 1       | 50,000 BLD | 8       | ~396 days    | 180-day linear vesting per claim |
| Cycle 2       | 20,000 BLD | 5       | ~165 days    | Starts 11 years after deploy; full immediate payout |
| Final Phase   | Remainders | 1       | Infinite     | Safety net; full immediate payout |

### Universal Rules

**1. One Wallet, One Claim — Forever**
Each address may claim exactly once across the entire lifetime of the contract, regardless of phase or period. The `hasClaimed` mapping is permanent and global.

**2. Linear Vesting (Cycle 1 only)**
All 8 Cycle 1 periods apply 180-day linear vesting. Vesting starts from the *period start time*, not the claim time.
- At claim: the already-matured fraction `(elapsed / 180 days) × prize` is transferred immediately.
- The remainder is held in the contract and released via `withdrawVesting()`.
- No cliff, no minimum.
- Cycle 2 and Final Phase pay the full prize with no vesting.

**3. Rollover Remainders**
Tokens not claimed by the end of a period roll over to the next period's allocation. All Cycle 1 remainders accumulate and are injected into Cycle 2 as extra mcap when Cycle 2 starts.

**4. Dust Rule (C2-P5 and Final Phase only)**
- Normal periods (C1-P1 through C2-P4): if the period's remaining allocation is less than the prize, the claim **reverts**. Tokens wait for natural period expiry and roll over.
- C2-P5 and Final Phase: if `mcapAvailable < prize`, the **Dust Rule** activates — the claiming wallet receives *all remaining tokens* and the contract closes permanently.

**5. Automatic Closure**
The contract closes (phase = 3) in two ways:
- C2-P5 Dust Rule triggers.
- C2-P5 ends with no remainders.
- Final Phase Dust Rule triggers.

Closure emits: `ContractClosed("Distribution complete. Thank you all.")`

---

### Cycle 1 — Periods Detail

Period durations follow the formula `(index + 1) × 11 days`. Only C1-P1 has a wallet cap (max 91 wallets).

| Period | Duration | Prize per Wallet | Base Allocation |
|--------|----------|-----------------|-----------------|
| C1-P1  | 11 days  | 111 BLD         | 10,101 BLD      |
| C1-P2  | 22 days  | 55.5 BLD        | 1,424.964… BLD  |
| C1-P3  | 33 days  | 27.75 BLD       | 2,849.928… BLD  |
| C1-P4  | 44 days  | 13.875 BLD      | 4,274.892… BLD  |
| C1-P5  | 55 days  | 6.9375 BLD      | 5,699.857… BLD  |
| C1-P6  | 66 days  | 3.46875 BLD     | 7,124.821… BLD  |
| C1-P7  | 77 days  | 1.734375 BLD    | 8,549.785… BLD  |
| C1-P8  | 88 days  | 0.8671875 BLD   | 9,974.750… BLD  |

**Total C1 base: 50,000 BLD** (sum verified to the wei in the contract).

The prize series is geometric with ratio 1/2 and base 111 BLD:
`prize[n] = 111 / 2^n` (n = 0 for P1)

---

### Cycle 2 — Periods Detail

Cycle 2 starts exactly **11 Gregorian years** (347,126,472 seconds) after deployment. It inherits all accumulated Cycle 1 remainders.

| Period | Duration | Prize per Wallet    | Base Allocation     |
|--------|----------|---------------------|---------------------|
| C2-P1  | 11 days  | ≈ 0.43359375 BLD    | ≈ 1,333.333… BLD    |
| C2-P2  | 22 days  | ≈ 0.216796875 BLD   | ≈ 2,666.666… BLD    |
| C2-P3  | 33 days  | ≈ 0.108398437 BLD   | 4,000 BLD (exact)   |
| C2-P4  | 44 days  | ≈ 0.054199218 BLD   | ≈ 5,333.333… BLD    |
| C2-P5  | 55 days  | ≈ 0.027099609 BLD   | ≈ 6,666.666… BLD    |

**Total C2 base: 20,000 BLD** (sum verified to the wei in the contract).

The prize series continues the same geometric progression from Cycle 1 (dividing by 2 each time).

---

### Final Phase

If C2-P5 ends with remaining tokens, the Final Phase begins. It has:
- **Infinite duration** (`type(uint256).max`).
- **No base allocation** — only whatever remainders survive from C2-P5.
- **Prize:** ≈ 0.013549804 BLD (111 / 2^13).
- **Dust Rule active** from the first claim.

---

### State Machine

```
Phase 0 (Cycle 1)
  P0 → P1 → P2 → P3 → P4 → P5 → P6 → P7
  └─ After P7 ends → Waiting state (periodIndex == 8)
       └─ After 11 years → Phase 1 (Cycle 2)
            P0 → P1 → P2 → P3 → P4
            └─ P4 ends with remainders → Phase 2 (Final Phase)
            └─ P4 Dust Rule or 0 remainders → Phase 3 (Closed)
Phase 2 (Final Phase): Dust Rule → Phase 3 (Closed)
```

The sentinel value `currentPeriodIndex == 8` while `currentPhase == 0` represents the waiting state between cycles.

---

### Public Functions

| Function | Access | Description |
|----------|--------|-------------|
| `claim()` | anyone (unclaimed wallet) | Claim current period prize |
| `withdrawVesting()` | Cycle 1 claimants | Withdraw matured vesting tokens |
| `finalizePeriod()` | anyone | Advance state if current period has expired |
| `startCycle2()` | anyone | Manually trigger Cycle 2 start if 11 years elapsed and waiting |

### View Functions

| Function | Returns |
|----------|---------|
| `currentPeriodInfo()` | Full period state tuple |
| `timeLeftInPeriod()` | Seconds remaining in current period |
| `cycle2StartTime()` | Unix timestamp of Cycle 2 start (0 if started) |
| `isWaitingForCycle2()` | True if in the inter-cycle waiting state |
| `availableVesting(wallet)` | Vesting tokens currently withdrawable |
| `hasClaimed(wallet)` | Whether wallet has already claimed |
| `vestingOf(wallet)` | Full VestingInfo struct for wallet |

---

## 5. `LiquidityVault.sol` — Liquidity Lock

### Summary

A permanent one-way lock for Uniswap V2 LP tokens representing the BLD/ETH pool. Once deposited, LP tokens can never be retrieved. They can optionally be sent to the dead address (`0x000...dEaD`) via `burnLP()`.

### Rules

1. **Deposit once, lock forever.** `depositLP()` may only be called once. The LP token address is registered on the first call and is immutable thereafter.
2. **No withdrawal.** No withdraw function, no rescue function, no owner.
3. **Public burn.** Anyone may call `burnLP()` at any time after deposit. The entire LP balance is sent atomically to `0x000...dEaD`, making the liquidity lock permanently and publicly verifiable on-chain.

### Functions

| Function | Access | Description |
|----------|--------|-------------|
| `depositLP(lpToken, amount)` | anyone (one-time) | Deposit and lock LP tokens |
| `burnLP()` | anyone | Send all LP tokens to dead address |
| `lpBalance()` | view | Current LP token balance |
| `vaultStatus()` | view | Full status: deposited, burned, lp address, amount, balance |

### Deployment Flow

1. Deploy `LiquidityVault`.
2. Deploy `Balda` token — deployer receives 5,000 BLD.
3. Add BLD + ETH liquidity on Uniswap V2 — receive LP tokens.
4. Approve `LiquidityVault` to spend LP tokens.
5. Call `depositLP(lpTokenAddress, amount)`.
6. Call `burnLP()` to send LP tokens to dead address permanently.

### Security

- No owner, no admin, no upgrade, no proxy, no rescue, no selfdestruct, no delegatecall.
- All token transfers use OpenZeppelin `SafeERC20`.
- Immutable after deployment.

---

## Supply Distribution Summary

```
Total Supply: 91,000 BLD
│
├── 70,000 BLD (76.9%) → BaldaAirdrop   — Distributed over ~11+ years via claim phases
├── 10,000 BLD (11.0%) → VaultCreator   — Founder: 5,000 linear + 3 tranches over 33 years
├──  6,000 BLD  (6.6%) → BaldaReserve   — Locked forever, permanently inaccessible
└──  5,000 BLD  (5.5%) → Deployer wallet — For DEX liquidity provisioning
```

---

## Deployment Order

The contracts must be deployed in this exact sequence:

```
1. BaldaReserve.sol    — No dependencies
2. VaultCreator.sol    — Requires: token address (use placeholder or deploy order trick), founder address, passwordHash
3. BaldaAirdrop.sol    — Requires: token address
4. Balda.sol           — Requires: BaldaAirdrop address, BaldaReserve address, VaultCreator address
```

> **Note:** `VaultCreator` and `BaldaAirdrop` require the BLD token address in their constructors, but BLD must be deployed last. In practice this is handled by deploying the dependent contracts first with the known future token address (pre-computed via `CREATE2` or `nonce`-based address prediction), or by using a two-step initializer pattern.

---

## Security Properties

| Property | Status |
|----------|--------|
| Fixed supply, no minting | ✅ |
| No burn function | ✅ |
| No owner / admin | ✅ |
| No upgrade / proxy | ✅ |
| No pause / blacklist | ✅ |
| No transfer tax | ✅ |
| No rescue functions | ✅ |
| SafeERC20 used throughout | ✅ |
| Immutable after deployment | ✅ |
| Global one-wallet-one-claim enforcement | ✅ |
| Timing uses Gregorian calendar seconds | ✅ |

---

## Key Risks & Observations

1. **Tranche password front-running:** The `registerTrancheWallet()` function submits the plaintext password on-chain. If called via a standard transaction, a MEV bot could see the password in the mempool and front-run the registration with a different wallet. **Mitigation:** the contract explicitly recommends using Flashbots or a private transaction bundle.

2. **No token address in `VaultCreator`/`BaldaAirdrop` constructors before BLD exists:** The deployment order requires that BLD token addresses be known before BLD is deployed. This requires careful address pre-computation.

3. **`finalizePeriod()` and `startCycle2()` are public:** Anyone can advance the state machine. This is intentional — it prevents stalling — but means the state can transition without any claim activity.

4. **Cycle 2 starts exactly 11 years post-deploy regardless of Cycle 1 activity:** If Cycle 1 ends early, the contract enters a waiting state. Cycle 2 cannot start until the full 11-year delay elapses.

5. **BaldaReserve tokens are permanently inaccessible:** 6,000 BLD (6.6% of supply) will never circulate. This is a deliberate design choice for the protocol's reserve accounting, not a bug.

6. **The deployer's 5,000 BLD are freely usable:** These tokens have no vesting and are intended for DEX liquidity provisioning. The deployer retains full control over these tokens post-deployment.

7. **LiquidityVault LP burn is irreversible:** Once `burnLP()` is called by any party, the BLD/ETH liquidity is permanently locked. This benefits token holders by eliminating rug-pull risk, but also means liquidity can never be adjusted in response to market conditions.

---

*Balda Protocol — Concept & Decision by Deaf Italian only. Built with AI.*
