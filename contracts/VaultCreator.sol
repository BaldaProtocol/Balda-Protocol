// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title  VaultCreator
 * @author Balda Protocol
 * @notice Founder vesting contract for the BALDA (BLD) token.
 *
 * Manages 10,000 BLD split into two independent mechanisms:
 *
 * ─────────────────────────────────────────────────────────────────────────
 * A) LINEAR VESTING — 5,000 BLD
 * ─────────────────────────────────────────────────────────────────────────
 *
 *   Continuous per-second streaming from deploy time over 11 Gregorian years
 *   (347,126,472 seconds = 11 × 365.2425 × 86,400).
 *   Withdrawable at any time, no cliff, no minimum.
 *   Only the founder address set at deploy time may call withdrawVesting().
 *
 * ─────────────────────────────────────────────────────────────────────────
 * B) TRANCHES — 5,000 BLD (3 tranches)
 * ─────────────────────────────────────────────────────────────────────────
 *
 *   Tranche 1 — 2,500 BLD — unlockable after 11 years from deploy
 *   Tranche 2 — 1,250 BLD — unlockable after 22 years from deploy
 *   Tranche 3 — 1,250 BLD — unlockable after 33 years from deploy
 *
 *   Registration + wallet mechanism:
 *     Only the keccak256 hash of a secret password is stored at deploy time.
 *     Call registerTrancheWallet(password) at any time — no time lock required.
 *     Use Flashbots or a private bundle to protect the password at registration.
 *     The contract verifies: keccak256(abi.encodePacked(password)) == passwordHash
 *     Once registered, trancheWallet is permanent. All three tranches are sent
 *     exclusively to that address. No password is required after registration.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * TIMING  (Gregorian calendar — 1 year = 365.2425 × 86,400 seconds)
 * ─────────────────────────────────────────────────────────────────────────
 *
 *   1 year   =    31,556,952 s
 *   11 years =   347,126,472 s
 *   22 years =   694,252,944 s
 *   33 years = 1,041,379,416 s
 *
 * ─────────────────────────────────────────────────────────────────────────
 * SECURITY
 * ─────────────────────────────────────────────────────────────────────────
 *
 *   - No owner after deploy.
 *   - No administrative functions.
 *   - No upgrade path.
 *   - No rescue function.
 *
 * @dev Deploy this contract before Balda.sol.
 *      Constructor parameters:
 *        _token        — BLD token contract address
 *        _founder      — Recipient of linear vesting withdrawals
 *        _passwordHash — keccak256(abi.encodePacked(secretPassword))
 */
contract VaultCreator {
    using SafeERC20 for IERC20;

    // ─── Timing constants (seconds, Gregorian calendar) ───────────────────

    uint256 public constant SECONDS_PER_YEAR  =    31_556_952;
    uint256 public constant VESTING_DURATION  =   347_126_472; // 11 years
    uint256 public constant TRANCHE_1_DELAY   =   347_126_472; // 11 years
    uint256 public constant TRANCHE_2_DELAY   =   694_252_944; // 22 years
    uint256 public constant TRANCHE_3_DELAY   = 1_041_379_416; // 33 years

    // ─── Amount constants (18 decimals) ───────────────────────────────────

    uint256 public constant VESTING_AMOUNT   = 5_000 * 1e18;
    uint256 public constant TRANCHE_1_AMOUNT = 2_500 * 1e18;
    uint256 public constant TRANCHE_2_AMOUNT = 1_250 * 1e18;
    uint256 public constant TRANCHE_3_AMOUNT = 1_250 * 1e18;

    // ─── Immutable state ──────────────────────────────────────────────────

    IERC20  public immutable token;         // BLD token contract
    address public immutable founder;       // Recipient of linear vesting
    bytes32 public immutable passwordHash;  // keccak256 hash of tranche password
    uint256 public immutable deployTime;    // Block timestamp at deployment

    // ─── Tranche wallet state ─────────────────────────────────────────────

    address public trancheWallet; // Set once via registerTrancheWallet(), never changeable

    // ─── Linear vesting state ─────────────────────────────────────────────

    uint256 public vestingWithdrawn; // BLD already withdrawn from linear vesting

    // ─── Tranche claim state ──────────────────────────────────────────────

    bool public tranche1Claimed;
    bool public tranche2Claimed;
    bool public tranche3Claimed;

    // ─── Events ───────────────────────────────────────────────────────────

    event VestingWithdrawn(address indexed to, uint256 amount);
    event TrancheWalletRegistered(address indexed wallet);
    event TrancheClaimed(uint8 indexed trancheId, address indexed to, uint256 amount);

    // ─── Constructor ──────────────────────────────────────────────────────

    /**
     * @param _token        Address of the BLD token contract.
     * @param _founder      Address that may withdraw linear vesting tokens.
     * @param _passwordHash keccak256(abi.encodePacked(secretPassword)) for tranches.
     */
    constructor(
        address _token,
        address _founder,
        bytes32 _passwordHash
    ) {
        require(_token        != address(0),  "VaultCreator: token address is zero");
        require(_founder      != address(0),  "VaultCreator: founder address is zero");
        require(_passwordHash != bytes32(0),  "VaultCreator: password hash is zero");

        token        = IERC20(_token);
        founder      = _founder;
        passwordHash = _passwordHash;
        deployTime   = block.timestamp;
    }

    // ═════════════════════════════════════════════════════════════════════
    // LINEAR VESTING
    // ═════════════════════════════════════════════════════════════════════

    /**
     * @notice Returns the total BLD vested so far (including already withdrawn).
     * @return vested Cumulative vested amount since deploy.
     */
    function vestedAmount() public view returns (uint256 vested) {
        uint256 elapsed = block.timestamp - deployTime;
        if (elapsed >= VESTING_DURATION) {
            return VESTING_AMOUNT;
        }
        return (VESTING_AMOUNT * elapsed) / VESTING_DURATION;
    }

    /**
     * @notice Returns the BLD currently available to withdraw (vested minus already withdrawn).
     * @return available Withdrawable amount right now.
     */
    function availableVesting() public view returns (uint256 available) {
        uint256 vested = vestedAmount();
        if (vested <= vestingWithdrawn) return 0;
        return vested - vestingWithdrawn;
    }

    /**
     * @notice Withdraw all currently available linear vesting tokens.
     * @dev Only the founder address may call this function.
     */
    function withdrawVesting() external {
        require(msg.sender == founder, "VaultCreator: caller is not the founder");

        uint256 amount = availableVesting();
        require(amount > 0, "VaultCreator: no tokens available to withdraw");

        vestingWithdrawn += amount;
        token.safeTransfer(founder, amount);

        emit VestingWithdrawn(founder, amount);
    }

    // ═════════════════════════════════════════════════════════════════════
    // TRANCHES
    // ═════════════════════════════════════════════════════════════════════

    /**
     * @notice Register the tranche wallet in advance using the secret password.
     *
     * Can be called at any time — no time lock required.
     * Use Flashbots or a private bundle to keep the password off the public
     * mempool. Once registered, the wallet is permanent and all three tranches
     * will be sent exclusively to it.
     * Tranche claims require only the registered wallet, no password.
     *
     * @param password  Plaintext secret password.
     */
    function registerTrancheWallet(string calldata password) external {
        require(trancheWallet == address(0), "VaultCreator: tranche wallet already registered");
        require(
            keccak256(abi.encodePacked(password)) == passwordHash,
            "VaultCreator: incorrect password"
        );

        trancheWallet = msg.sender;
        emit TrancheWalletRegistered(msg.sender);
    }

    /**
     * @notice Claim Tranche 1 once the time lock has elapsed.
     *
     * trancheWallet must be registered first via registerTrancheWallet().
     * Only callable by trancheWallet. No password required.
     */
    function claimTranche1() external {
        require(trancheWallet != address(0), "VaultCreator: tranche wallet not yet registered");
        require(msg.sender == trancheWallet, "VaultCreator: caller is not the registered tranche wallet");
        require(!tranche1Claimed, "VaultCreator: tranche 1 already claimed");
        require(
            block.timestamp >= deployTime + TRANCHE_1_DELAY,
            "VaultCreator: tranche 1 is not yet unlocked"
        );

        tranche1Claimed = true;
        token.safeTransfer(trancheWallet, TRANCHE_1_AMOUNT);
        emit TrancheClaimed(1, trancheWallet, TRANCHE_1_AMOUNT);
    }

    /**
     * @notice Claim Tranche 2 or 3 using only the registered trancheWallet.
     *
     * No password required — trancheWallet is the only key needed.
     * Simply call this function from trancheWallet once the time lock has elapsed.
     *
     * @param trancheId  Tranche to claim: 2 or 3.
     */
    function claimTranche(uint8 trancheId) external {
        require(trancheWallet != address(0), "VaultCreator: tranche wallet not yet registered");
        require(msg.sender == trancheWallet, "VaultCreator: caller is not the registered tranche wallet");

        if (trancheId == 2) {
            require(!tranche2Claimed, "VaultCreator: tranche 2 already claimed");
            require(
                block.timestamp >= deployTime + TRANCHE_2_DELAY,
                "VaultCreator: tranche 2 is not yet unlocked"
            );
            tranche2Claimed = true;
            token.safeTransfer(trancheWallet, TRANCHE_2_AMOUNT);
            emit TrancheClaimed(2, trancheWallet, TRANCHE_2_AMOUNT);

        } else if (trancheId == 3) {
            require(!tranche3Claimed, "VaultCreator: tranche 3 already claimed");
            require(
                block.timestamp >= deployTime + TRANCHE_3_DELAY,
                "VaultCreator: tranche 3 is not yet unlocked"
            );
            tranche3Claimed = true;
            token.safeTransfer(trancheWallet, TRANCHE_3_AMOUNT);
            emit TrancheClaimed(3, trancheWallet, TRANCHE_3_AMOUNT);

        } else {
            revert("VaultCreator: invalid tranche id, must be 2 or 3");
        }
    }

    // ═════════════════════════════════════════════════════════════════════
    // VIEW UTILITIES
    // ═════════════════════════════════════════════════════════════════════

    /**
     * @notice Returns the exact Unix timestamp when a tranche becomes claimable.
     *         Convert this value to a human-readable date using any block
     *         explorer, wallet, or online Unix timestamp converter.
     *         Returns 0 if the tranche is already unlocked.
     * @param trancheId  Tranche to query: 1, 2, or 3.
     */
    function trancheUnlockAt(uint8 trancheId) external view returns (uint256) {
        uint256 delay;
        if      (trancheId == 1) delay = TRANCHE_1_DELAY;
        else if (trancheId == 2) delay = TRANCHE_2_DELAY;
        else if (trancheId == 3) delay = TRANCHE_3_DELAY;
        else revert("VaultCreator: invalid tranche id, must be 1, 2, or 3");

        uint256 unlockTime = deployTime + delay;
        if (block.timestamp >= unlockTime) return 0;
        return unlockTime;
    }
}
