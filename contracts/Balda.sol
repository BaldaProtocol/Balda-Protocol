// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title  Balda
 * @author Balda Protocol
 * @custom:signature By Deaf Italian, with AI. Concept & Decision by Deaf Italian only.
 * @notice ERC-20 token BALDA (BLD) — fixed supply, immutable, ownerless.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * SUPPLY DISTRIBUTION  (total: 91,000 BLD, 18 decimals)
 * ─────────────────────────────────────────────────────────────────────────
 *
 *   BaldaAirdrop contract  —  70,000 BLD   (automated airdrop)
 *   BaldaReserve contract  —   6,000 BLD   (eternal reserve, untouchable)
 *   VaultCreator contract  —  10,000 BLD   (founder vesting)
 *   Deployer wallet        —   5,000 BLD   (DEX liquidity, freely usable)
 *
 * ─────────────────────────────────────────────────────────────────────────
 * PROPERTIES
 * ─────────────────────────────────────────────────────────────────────────
 *
 *   - No future minting.
 *   - No burn function.
 *   - No owner (Ownable is intentionally not imported).
 *   - No pause, no blacklist, no transfer tax.
 *   - Pure standard ERC-20: transfer, approve, transferFrom.
 *
 * The constructor performs the entire supply distribution in a single
 * atomic operation. After deployment the contract has no administrative
 * functions and is immutable forever.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * DEPLOYMENT ORDER
 * ─────────────────────────────────────────────────────────────────────────
 *
 *   1. BaldaReserve.sol
 *   2. VaultCreator.sol
 *   3. BaldaAirdrop.sol
 *   4. Balda.sol  ← this contract (last)
 *
 * @dev The constructor requires the addresses of BaldaAirdrop, BaldaReserve,
 *      and VaultCreator. The deployer wallet receives the remaining 5,000 BLD.
 */
contract Balda is ERC20 {

    // ─── Supply constants (18 decimals) ───────────────────────────────────

    uint256 public constant TOTAL_SUPPLY    = 91_000 * 1e18;
    uint256 public constant AIRDROP_AMOUNT  = 70_000 * 1e18;
    uint256 public constant RESERVE_AMOUNT  =  6_000 * 1e18;
    uint256 public constant VAULT_AMOUNT    = 10_000 * 1e18;
    uint256 public constant DEPLOYER_AMOUNT =  5_000 * 1e18;

    // ─── Constructor ──────────────────────────────────────────────────────

    /**
     * @param airdropContract  Address of BaldaAirdrop.sol
     * @param reserveContract  Address of BaldaReserve.sol
     * @param vaultContract    Address of VaultCreator.sol
     */
    constructor(
        address airdropContract,
        address reserveContract,
        address vaultContract
    ) ERC20("Balda", "BLD") {
        require(airdropContract != address(0), "Balda: airdrop address is zero");
        require(reserveContract != address(0), "Balda: reserve address is zero");
        require(vaultContract   != address(0), "Balda: vault address is zero");

        // Single mint — entire supply distributed here, never repeatable.
        _mint(airdropContract, AIRDROP_AMOUNT);
        _mint(reserveContract, RESERVE_AMOUNT);
        _mint(vaultContract,   VAULT_AMOUNT);
        _mint(msg.sender,      DEPLOYER_AMOUNT);

        // Safety check: total supply must equal exactly 91,000 BLD.
        assert(totalSupply() == TOTAL_SUPPLY);
    }
}
