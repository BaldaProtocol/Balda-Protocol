// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title  BaldaAirdrop
 * @author Balda Protocol
 * @notice Automated airdrop contract for the BALDA (BLD) token.
 *
 * ═══════════════════════════════════════════════════════════════════════
 * OVERVIEW
 * ═══════════════════════════════════════════════════════════════════════
 *
 * Distributes 70,000 BLD across three sequential phases with no owner,
 * no admin keys, and no upgrade path.
 *
 *   Cycle 1       — 50,000 BLD base | 8 periods | 396 days total
 *   Cycle 2       — 20,000 BLD base + Cycle 1 remainders | 5 periods | 165 days
 *                   Starts exactly 11 Gregorian years after deploy
 *   Final Phase   — All accumulated remainders | unlimited duration | safety net
 *
 * ═══════════════════════════════════════════════════════════════════════
 * UNIVERSAL RULES
 * ═══════════════════════════════════════════════════════════════════════
 *
 * 1. ONE WALLET — ONE CLAIM  (absolute, for the entire contract lifetime)
 *    Each wallet may claim exactly once, regardless of phase or period.
 *    Once claimed, that wallet is permanently excluded.
 *
 * 2. LINEAR VESTING — 180 DAYS  (Cycle 1 only)
 *    Vesting applies exclusively to all 8 Cycle 1 periods.
 *    Vesting always starts from the beginning of the period, not from
 *    the exact moment of the claim.
 *    At claim time: the already-matured portion (period start → now)
 *    is transferred immediately. The remainder is held in the contract
 *    and withdrawable at any time via withdrawVesting(). No cliff.
 *    Cycle 2 and Final Phase pay the full prize immediately — no vesting.
 *
 * 3. REMAINDERS
 *    Tokens not distributed by the natural end of a period carry over to
 *    the next period, adding to its base allocation.
 *    The same rollover logic applies from Cycle 1 to Cycle 2.
 *
 * 4. DUST RULE  (C2-P5 and Final Phase only)
 *    Normal periods (C1-P1 through C1-P8, C2-P1 through C2-P4):
 *      if mcapAvailable < prize → claim REVERTS.
 *      Residual tokens wait for natural period expiry and roll over.
 *    C2-P5 and Final Phase:
 *      if mcapAvailable < prize → Dust Rule activates.
 *      The last claiming wallet receives ALL remaining tokens.
 *      The contract closes permanently.
 *
 * 5. AUTOMATIC CLOSURE
 *    C2-P5 Dust Rule triggers    → ContractClosed("Distribution complete. Thank you all.")
 *    C2-P5 ends with remainders  → Final Phase starts
 *    Final Phase Dust Rule       → ContractClosed("Distribution complete. Thank you all.")
 *
 * ═══════════════════════════════════════════════════════════════════════
 * TIMING  (seconds, proleptic Gregorian calendar)
 * ═══════════════════════════════════════════════════════════════════════
 *
 *   1 day      =        86,400 s
 *   180 days   =    15,552,000 s  (vesting duration, Cycle 1 only)
 *   11 years   =   347,126,472 s  (Cycle 2 start delay)
 *
 * ═══════════════════════════════════════════════════════════════════════
 * CYCLE 1 BASE ALLOCATION  (18 decimals, verified sum = 50,000 BLD)
 * ═══════════════════════════════════════════════════════════════════════
 *
 *   P1 : 10,101.000000000000000000  BLD  (111 × 91, fixed)
 *   P2 :  1,424.964285714285714285  BLD  (d × 1)
 *   P3 :  2,849.928571428571428570  BLD  (d × 2)
 *   P4 :  4,274.892857142857142855  BLD  (d × 3)
 *   P5 :  5,699.857142857142857140  BLD  (d × 4)
 *   P6 :  7,124.821428571428571425  BLD  (d × 5)
 *   P7 :  8,549.785714285714285710  BLD  (d × 6)
 *   P8 :  9,974.750000000000000015  BLD  (d × 7 + 20 wei dust)
 *   where d = 39,899 / 28 ≈ 1,424.964285714... BLD
 *
 * ═══════════════════════════════════════════════════════════════════════
 * CYCLE 2 BASE ALLOCATION  (18 decimals, verified sum = 20,000 BLD)
 * ═══════════════════════════════════════════════════════════════════════
 *
 *   P1 :  1,333.333333333333333333  BLD  (ratio × 1)
 *   P2 :  2,666.666666666666666666  BLD  (ratio × 2)
 *   P3 :  4,000.000000000000000000  BLD  (ratio × 3, exact)
 *   P4 :  5,333.333333333333333332  BLD  (ratio × 4)
 *   P5 :  6,666.666666666666666669  BLD  (ratio × 5 + 5 wei dust)
 *   where ratio = 20,000 / 15 ≈ 1,333.333... BLD
 *
 * ═══════════════════════════════════════════════════════════════════════
 * PRIZE SERIES  (geometric, ratio 1/2, base 111 BLD)
 * ═══════════════════════════════════════════════════════════════════════
 *
 *   C1-P1 : 111            BLD  (111 / 2^0)
 *   C1-P2 : 55.5           BLD  (111 / 2^1)
 *   C1-P3 : 27.75          BLD  (111 / 2^2)
 *   C1-P4 : 13.875         BLD  (111 / 2^3)
 *   C1-P5 : 6.9375         BLD  (111 / 2^4)
 *   C1-P6 : 3.46875        BLD  (111 / 2^5)
 *   C1-P7 : 1.734375       BLD  (111 / 2^6)
 *   C1-P8 : 0.8671875      BLD  (111 / 2^7)
 *   C2-P1 : 0.43359375     BLD  (111 / 2^8)
 *   C2-P2 : 0.216796875    BLD  (111 / 2^9)
 *   C2-P3 : 0.108398437    BLD  (111 / 2^10)
 *   C2-P4 : 0.054199218    BLD  (111 / 2^11)
 *   C2-P5 : 0.027099609    BLD  (111 / 2^12)
 *   Final : 0.013549804    BLD  (111 / 2^13)
 */
contract BaldaAirdrop {
    using SafeERC20 for IERC20;

    // ─── Timing constants ─────────────────────────────────────────────────

    uint256 public constant SECONDS_PER_DAY    =        86_400;
    uint256 public constant VESTING_DURATION   =    15_552_000; // 180 days
    uint256 public constant CYCLE2_START_DELAY =   347_126_472; // 11 Gregorian years

    // ─── Data structures ──────────────────────────────────────────────────

    struct Period {
        uint256 prize;      // Prize per wallet (wei)
        uint256 baseMcap;   // Base allocation without rollover remainders (wei)
        uint256 duration;   // Duration in seconds (type(uint256).max = infinite)
        uint256 maxWallets; // Maximum claimants this period (0 = unlimited)
    }

    struct PeriodState {
        uint256 startTime;     // Unix timestamp when this period started
        uint256 mcapAvailable; // Available allocation including rolled-over remainders (wei)
        uint256 walletsCount;  // Number of wallets that claimed in this period
        bool    finalized;     // True once this period has been closed
    }

    struct VestingInfo {
        uint256 totalAmount;  // Total prize assigned to this wallet (wei)
        uint256 vestingStart; // Vesting start timestamp (equals period start time)
        uint256 withdrawn;    // Amount already withdrawn, including the immediate transfer (wei)
    }

    // ─── Immutable state ──────────────────────────────────────────────────

    IERC20  public immutable token;      // BLD token contract
    uint256 public immutable deployTime; // Block timestamp at deployment

    // ─── Phase / period state ─────────────────────────────────────────────
    //
    // currentPhase values:
    //   0 = Cycle 1
    //   1 = Cycle 2
    //   2 = Final Phase
    //   3 = Closed

    uint8 public currentPhase;
    uint8 public currentPeriodIndex; // Zero-based index within the current phase

    PeriodState public activePeriod;
    uint256     public pendingRemainders; // Cycle 1 remainders held until Cycle 2 starts

    // ─── Wallet state ─────────────────────────────────────────────────────

    mapping(address => bool)        public hasClaimed;
    mapping(address => VestingInfo) public vestingOf;

    // ─── Events ───────────────────────────────────────────────────────────

    event Claimed(
        address indexed wallet,
        uint8   phase,
        uint8   periodIndex,
        uint256 immediateAmount,
        uint256 vestingAmount
    );
    event VestingWithdrawn(address indexed wallet, uint256 amount);
    event PeriodFinalized(uint8 phase, uint8 periodIndex, uint256 remainders);
    event PhaseAdvanced(uint8 newPhase);
    event ContractClosed(string message);

    // ─── Constructor ──────────────────────────────────────────────────────

    /**
     * @param _token  Address of the BLD token contract.
     */
    constructor(address _token) {
        require(_token != address(0), "BaldaAirdrop: token address is zero");
        token      = IERC20(_token);
        deployTime = block.timestamp;
        _startPeriod(0, 0, 0);
    }

    // ═════════════════════════════════════════════════════════════════════
    // CLAIM
    // ═════════════════════════════════════════════════════════════════════

    /**
     * @notice Claim the prize for the current period.
     *
     * Vesting behaviour:
     *   Cycle 1  → 180-day linear vesting from period start.
     *              The matured portion is transferred immediately;
     *              the remainder is withdrawable via withdrawVesting().
     *   Cycle 2  → Full prize transferred immediately. No vesting.
     *   Final    → Full prize transferred immediately. No vesting.
     *
     * Dust Rule (C2-P5 and Final Phase only):
     *   If mcapAvailable < prize, the wallet receives ALL remaining tokens
     *   and the contract closes permanently.
     *
     * Normal periods (C1 all, C2-P1 through C2-P4):
     *   If mcapAvailable < prize, the call REVERTS. Tokens roll over.
     */
    function claim() external {
        require(currentPhase < 3, "BaldaAirdrop: contract is closed");
        require(!hasClaimed[msg.sender], "BaldaAirdrop: wallet has already claimed");

        _updateState();

        require(currentPhase < 3, "BaldaAirdrop: contract closed during state update");

        PeriodState storage ps = activePeriod;
        Period memory p = _getPeriod(currentPhase, currentPeriodIndex);

        // Enforce wallet cap (C1-P1 only: maximum 91 wallets).
        if (p.maxWallets > 0) {
            require(
                ps.walletsCount < p.maxWallets,
                "BaldaAirdrop: wallet cap reached for this period"
            );
        }

        // Dust Rule is active only in C2-P5 and the Final Phase.
        bool dustRuleActive = (currentPhase == 2) ||
                              (currentPhase == 1 && currentPeriodIndex == 4);

        uint256 prize;
        bool    isDust = false;

        if (ps.mcapAvailable < p.prize) {
            if (dustRuleActive) {
                prize  = ps.mcapAvailable;
                isDust = true;
                require(prize > 0, "BaldaAirdrop: no tokens remaining");
            } else {
                revert("BaldaAirdrop: insufficient allocation, wait for period end");
            }
        } else {
            require(ps.mcapAvailable > 0, "BaldaAirdrop: no tokens remaining");
            prize = p.prize;
        }

        hasClaimed[msg.sender] = true;
        ps.walletsCount       += 1;
        ps.mcapAvailable      -= prize;

        // ── Vesting calculation ──────────────────────────────────────────
        // Cycle 1: 180-day linear vesting measured from period start.
        // Cycle 2 / Final: entire prize transferred immediately.

        uint256 immediate;
        uint256 deferred;

        if (currentPhase == 0) {
            uint256 elapsed = block.timestamp - ps.startTime;
            immediate = (elapsed >= VESTING_DURATION)
                        ? prize
                        : (prize * elapsed) / VESTING_DURATION;
            deferred  = prize - immediate;
        } else {
            immediate = prize;
            deferred  = 0;
        }

        vestingOf[msg.sender] = VestingInfo({
            totalAmount:  prize,
            vestingStart: ps.startTime,
            withdrawn:    immediate
        });

        if (immediate > 0) {
            token.safeTransfer(msg.sender, immediate);
        }

        emit Claimed(msg.sender, currentPhase, currentPeriodIndex, immediate, deferred);

        if (isDust) {
            _finalizeCurrentPeriod(true);
        }
    }

    // ═════════════════════════════════════════════════════════════════════
    // WITHDRAW VESTING
    // ═════════════════════════════════════════════════════════════════════

    /**
     * @notice Withdraw all currently matured vesting tokens.
     *         No cliff. No minimum. Only relevant for Cycle 1 claimants.
     */
    function withdrawVesting() external {
        VestingInfo storage v = vestingOf[msg.sender];
        require(v.totalAmount > 0, "BaldaAirdrop: no active vesting for this wallet");

        uint256 available = _availableVesting(msg.sender);
        require(available > 0, "BaldaAirdrop: nothing to withdraw yet");

        v.withdrawn += available;
        token.safeTransfer(msg.sender, available);

        emit VestingWithdrawn(msg.sender, available);
    }

    /**
     * @notice Returns the amount of vesting tokens currently available to withdraw.
     * @param wallet  Address to query.
     * @return        Withdrawable vesting amount right now.
     */
    function availableVesting(address wallet) external view returns (uint256) {
        return _availableVesting(wallet);
    }

    function _availableVesting(address wallet) internal view returns (uint256) {
        VestingInfo storage v = vestingOf[wallet];
        if (v.totalAmount == 0) return 0;

        uint256 elapsed = block.timestamp - v.vestingStart;
        uint256 vested  = (elapsed >= VESTING_DURATION)
                          ? v.totalAmount
                          : (v.totalAmount * elapsed) / VESTING_DURATION;

        if (vested <= v.withdrawn) return 0;
        return vested - v.withdrawn;
    }

    // ═════════════════════════════════════════════════════════════════════
    // FINALIZE PERIOD  (public — callable by anyone)
    // ═════════════════════════════════════════════════════════════════════

    /**
     * @notice Advance the contract state if the current period has expired.
     *
     * Anyone may call this function. It is useful when no claims occur during
     * a period: once the period expires, calling finalizePeriod() carries
     * unclaimed tokens forward as remainders for the next period.
     */
    function finalizePeriod() external {
        _updateState();
    }

    // ═════════════════════════════════════════════════════════════════════
    // CYCLE 2 MANUAL START  (public — callable by anyone)
    // ═════════════════════════════════════════════════════════════════════

    /**
     * @notice Manually start Cycle 2 once Cycle 1 has ended and 11 years have elapsed.
     *
     * Only needed if Cycle 1 finished before the 11-year mark and no claim or
     * finalizePeriod() call has triggered automatic advancement.
     */
    function startCycle2() external {
        require(currentPhase == 0,       "BaldaAirdrop: not in the waiting state for Cycle 2");
        require(currentPeriodIndex == 8, "BaldaAirdrop: Cycle 1 has not finished yet");
        require(
            block.timestamp >= deployTime + CYCLE2_START_DELAY,
            "BaldaAirdrop: too early to start Cycle 2"
        );

        emit PhaseAdvanced(1);
        _startPeriod(1, 0, pendingRemainders);
        pendingRemainders = 0;
    }

    // ═════════════════════════════════════════════════════════════════════
    // VIEW — CURRENT STATE
    // ═════════════════════════════════════════════════════════════════════

    /**
     * @notice Returns all data for the current period in a single call.
     */
    function currentPeriodInfo() external view returns (
        uint8   phase,
        uint8   periodIndex,
        uint256 prize,
        uint256 mcapAvailable,
        uint256 walletsCount,
        uint256 periodStart,
        uint256 periodEnd,
        uint256 maxWallets,
        bool    dustRuleActive
    ) {
        phase         = currentPhase;
        periodIndex   = currentPeriodIndex;

        // Waiting state between Cycle 1 and Cycle 2.
        if (phase == 0 && periodIndex == 8) {
            prize          = 0;
            mcapAvailable  = 0;
            walletsCount   = 0;
            periodStart    = activePeriod.startTime;
            periodEnd      = deployTime + CYCLE2_START_DELAY;
            maxWallets     = 0;
            dustRuleActive = false;
            return;
        }

        Period memory p = _getPeriod(phase, periodIndex);
        prize         = p.prize;
        mcapAvailable = activePeriod.mcapAvailable;
        walletsCount  = activePeriod.walletsCount;
        periodStart   = activePeriod.startTime;
        periodEnd     = (p.duration == type(uint256).max)
                        ? type(uint256).max
                        : activePeriod.startTime + p.duration;
        maxWallets    = p.maxWallets;
        dustRuleActive = (phase == 2) || (phase == 1 && periodIndex == 4);
    }

    /**
     * @notice Returns the seconds remaining in the current period.
     *         Returns type(uint256).max for the Final Phase (infinite duration).
     *         Returns 0 during the waiting state between Cycle 1 and Cycle 2.
     */
    function timeLeftInPeriod() external view returns (uint256) {
        if (currentPhase == 0 && currentPeriodIndex == 8) return 0;
        Period memory p = _getPeriod(currentPhase, currentPeriodIndex);
        if (p.duration == type(uint256).max) return type(uint256).max;
        uint256 end = activePeriod.startTime + p.duration;
        if (block.timestamp >= end) return 0;
        return end - block.timestamp;
    }

    /**
     * @notice Returns the exact Unix timestamp when Cycle 2 will start.
     *         Convert this value to a human-readable date using any block
     *         explorer, wallet, or online Unix timestamp converter.
     *         Returns 0 if Cycle 2 has already started.
     */
    function cycle2StartTime() external view returns (uint256) {
        uint256 cycle2Start = deployTime + CYCLE2_START_DELAY;
        if (block.timestamp >= cycle2Start) return 0;
        return cycle2Start;
    }

    /**
     * @notice Returns true if the contract is in the waiting state between
     *         Cycle 1 and Cycle 2 (Cycle 1 complete, 11-year delay not yet elapsed).
     *         Call cycle2StartTime() to get the exact unlock date.
     */
    function isWaitingForCycle2() external view returns (bool) {
        return currentPhase == 0 && currentPeriodIndex == 8;
    }

    // ═════════════════════════════════════════════════════════════════════
    // INTERNAL — STATE MACHINE
    // ═════════════════════════════════════════════════════════════════════

    function _updateState() internal {
        if (currentPhase == 3) return;

        // Waiting state: Cycle 1 complete, 11-year delay not yet elapsed.
        if (currentPhase == 0 && currentPeriodIndex == 8) {
            if (block.timestamp >= deployTime + CYCLE2_START_DELAY) {
                emit PhaseAdvanced(1);
                _startPeriod(1, 0, pendingRemainders);
                pendingRemainders = 0;
            }
            return;
        }

        Period memory p = _getPeriod(currentPhase, currentPeriodIndex);

        // Final Phase never expires by timer.
        if (p.duration == type(uint256).max) return;

        uint256 periodEnd = activePeriod.startTime + p.duration;
        if (block.timestamp < periodEnd) return;

        _finalizeCurrentPeriod(false);
    }

    /**
     * @dev Finalize the current period and advance to the next contract state.
     * @param dustClose  True only when the Dust Rule consumed all tokens in C2-P5 or Final Phase.
     */
    function _finalizeCurrentPeriod(bool dustClose) internal {
        uint256 remainders = activePeriod.mcapAvailable;

        emit PeriodFinalized(currentPhase, currentPeriodIndex, remainders);

        if (currentPhase == 0) {

            if (currentPeriodIndex < 7) {
                // Advance to the next Cycle 1 period.
                _startPeriod(0, currentPeriodIndex + 1, remainders);
            } else {
                // End of C1-P8 — accumulate remainders and attempt to start Cycle 2.
                pendingRemainders += remainders;
                _tryStartCycle2();
            }

        } else if (currentPhase == 1) {

            if (currentPeriodIndex < 4) {
                // Advance to the next Cycle 2 period.
                _startPeriod(1, currentPeriodIndex + 1, remainders);
            } else {
                // End of C2-P5.
                if (dustClose || remainders == 0) {
                    currentPhase = 3;
                    emit ContractClosed("Distribution complete. Thank you all.");
                } else {
                    _startFinalPhase(remainders);
                }
            }

        } else if (currentPhase == 2) {

            // Final Phase only closes via the Dust Rule.
            currentPhase = 3;
            emit ContractClosed("Distribution complete. Thank you all.");
        }
    }

    function _tryStartCycle2() internal {
        uint256 cycle2Start = deployTime + CYCLE2_START_DELAY;

        if (block.timestamp >= cycle2Start) {
            emit PhaseAdvanced(1);
            _startPeriod(1, 0, pendingRemainders);
            pendingRemainders = 0;
        } else {
            // Enter the waiting state — sentinel period index 8.
            currentPhase       = 0;
            currentPeriodIndex = 8;
            activePeriod = PeriodState({
                startTime:     cycle2Start,
                mcapAvailable: 0,
                walletsCount:  0,
                finalized:     false
            });
        }
    }

    function _startFinalPhase(uint256 mcap) internal {
        emit PhaseAdvanced(2);
        currentPhase       = 2;
        currentPeriodIndex = 0;
        activePeriod = PeriodState({
            startTime:     block.timestamp,
            mcapAvailable: mcap,
            walletsCount:  0,
            finalized:     false
        });
    }

    function _startPeriod(uint8 phase, uint8 periodIdx, uint256 extraMcap) internal {
        currentPhase       = phase;
        currentPeriodIndex = periodIdx;

        Period memory p = _getPeriod(phase, periodIdx);

        uint256 startTime;
        if      (phase == 0 && periodIdx == 0) startTime = deployTime;
        else if (phase == 1 && periodIdx == 0) startTime = deployTime + CYCLE2_START_DELAY;
        else                                   startTime = block.timestamp;

        activePeriod = PeriodState({
            startTime:     startTime,
            mcapAvailable: p.baseMcap + extraMcap,
            walletsCount:  0,
            finalized:     false
        });
    }

    // ═════════════════════════════════════════════════════════════════════
    // INTERNAL — PERIOD DATA
    // ═════════════════════════════════════════════════════════════════════

    /**
     * @dev Returns the static Period definition for a given phase and period index.
     *      All values are hardcoded constants; nothing is stored in state.
     */
    function _getPeriod(uint8 phase, uint8 idx) internal pure returns (Period memory) {

        // ── Cycle 1 (phase == 0) ──────────────────────────────────────────
        if (phase == 0) {
            uint256 prize;
            if      (idx == 0) prize = 111_000000000000000000;
            else if (idx == 1) prize =  55_500000000000000000;
            else if (idx == 2) prize =  27_750000000000000000;
            else if (idx == 3) prize =  13_875000000000000000;
            else if (idx == 4) prize =   6_937500000000000000;
            else if (idx == 5) prize =   3_468750000000000000;
            else if (idx == 6) prize =   1_734375000000000000;
            else               prize =     867187500000000000;

            uint256 mcap;
            if      (idx == 0) mcap = 10_101_000000000000000000;
            else if (idx == 1) mcap =  1_424_964285714285714285;
            else if (idx == 2) mcap =  2_849_928571428571428570;
            else if (idx == 3) mcap =  4_274_892857142857142855;
            else if (idx == 4) mcap =  5_699_857142857142857140;
            else if (idx == 5) mcap =  7_124_821428571428571425;
            else if (idx == 6) mcap =  8_549_785714285714285710;
            else               mcap =  9_974_750000000000000015;

            // Period duration = (idx + 1) × 11 days.
            // C1-P1 is the only period with a wallet cap (max 91).
            return Period(
                prize,
                mcap,
                uint256(idx + 1) * 11 * SECONDS_PER_DAY,
                idx == 0 ? 91 : 0
            );
        }

        // ── Cycle 2 (phase == 1) ──────────────────────────────────────────
        if (phase == 1) {
            uint256 prize;
            if      (idx == 0) prize = 433593750000000000;
            else if (idx == 1) prize = 216796875000000000;
            else if (idx == 2) prize = 108398437500000000;
            else if (idx == 3) prize =  54199218750000000;
            else               prize =  27099609375000000;

            uint256 mcap;
            if      (idx == 0) mcap = 1_333_333333333333333333;
            else if (idx == 1) mcap = 2_666_666666666666666666;
            else if (idx == 2) mcap = 4_000_000000000000000000;
            else if (idx == 3) mcap = 5_333_333333333333333332;
            else               mcap = 6_666_666666666666666669;

            // Period duration = (idx + 1) × 11 days. No wallet cap.
            return Period(
                prize,
                mcap,
                uint256(idx + 1) * 11 * SECONDS_PER_DAY,
                0
            );
        }

        // ── Final Phase (phase == 2) ──────────────────────────────────────
        // Infinite duration (type(uint256).max). No base allocation. No wallet cap.
        return Period(
            13549804687500000, // 111 / 2^13
            0,
            type(uint256).max,
            0
        );
    }
}
