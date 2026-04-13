// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title  LiquidityVault
 * @author Balda Protocol
 * @notice Permanent liquidity lock for the BALDA (BLD) / ETH Uniswap V2 pool.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * PURPOSE
 * ─────────────────────────────────────────────────────────────────────────
 *
 * Receives Uniswap V2 LP tokens representing the BLD/ETH liquidity position
 * and locks them permanently. Once LP tokens are deposited, no one —
 * including the original depositor — can ever withdraw them.
 *
 * Anyone may call burnLP() at any time to send all LP tokens to the dead
 * address (0x000...dEaD), making the lock permanently verifiable on-chain.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * RULES
 * ─────────────────────────────────────────────────────────────────────────
 *
 * 1. DEPOSIT ONCE, LOCK FOREVER
 *    The first call to depositLP() registers the LP token address immutably
 *    and transfers the tokens into this contract.
 *    Any subsequent depositLP() call reverts. No other token is accepted.
 *
 * 2. NO WITHDRAWAL
 *    There is no withdraw function, no rescue function, and no owner.
 *    Once deposited, LP tokens cannot leave this contract except via burnLP().
 *
 * 3. PUBLIC BURN
 *    Anyone may call burnLP() at any time after deposit.
 *    The entire LP token balance is sent to 0x000...dEaD atomically.
 *    The burn is irreversible and publicly verifiable on Etherscan.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * DEPLOYMENT FLOW
 * ─────────────────────────────────────────────────────────────────────────
 *
 *   1. Deploy LiquidityVault (no constructor arguments needed).
 *   2. Deploy the Balda token — deployer receives 5,000 BLD.
 *   3. Add ETH from your wallet.
 *   4. Create the BLD/ETH pool on Uniswap V2 — receive LP tokens.
 *   5. Approve this contract to spend your LP tokens.
 *   6. Call depositLP(lpTokenAddress, amount) — LP tokens locked forever.
 *   7. Call burnLP() — LP tokens sent to 0x000...dEaD.
 *      Liquidity is now permanent. No one can ever remove it.
 *
 * ─────────────────────────────────────────────────────────────────────────
 * SECURITY
 * ─────────────────────────────────────────────────────────────────────────
 *
 *   - No owner
 *   - No admin
 *   - No upgrade
 *   - No proxy
 *   - No rescue
 *   - No selfdestruct
 *   - No delegatecall
 *   - Immutable after deploy
 *   - OpenZeppelin SafeERC20 for all token transfers
 */
contract LiquidityVault {
    using SafeERC20 for IERC20;

    // ─── Dead address ─────────────────────────────────────────────────────

    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;

    // ─── State ────────────────────────────────────────────────────────────

    IERC20  public lpToken;      // Uniswap V2 LP token — registered on first deposit
    uint256 public lpDeposited;  // Total LP tokens deposited
    bool    public isDeposited;  // True after the first (and only) deposit
    bool    public isBurned;     // True after burnLP() is called

    // ─── Events ───────────────────────────────────────────────────────────

    event LPDeposited(address indexed lpToken, uint256 amount, address indexed depositor);
    event LPBurned(address indexed lpToken, uint256 amount, address indexed caller);

    // ═════════════════════════════════════════════════════════════════════
    // DEPOSIT
    // ═════════════════════════════════════════════════════════════════════

    /**
     * @notice Deposit Uniswap V2 LP tokens into this contract (one-time operation).
     *
     * - Can only be called once. Any subsequent call reverts.
     * - The LP token address is registered immutably on the first call.
     * - The deposited amount must be greater than zero.
     * - The caller must approve this contract before calling.
     *
     * After this call, LP tokens are locked in this contract with no withdrawal path.
     *
     * @param _lpToken  Address of the Uniswap V2 LP token (BLD/ETH pair).
     * @param _amount   Amount of LP tokens to deposit (must be > 0).
     */
    function depositLP(address _lpToken, uint256 _amount) external {
        require(!isDeposited,            "LiquidityVault: LP tokens already deposited");
        require(_lpToken != address(0),  "LiquidityVault: LP token address is zero");
        require(_amount  > 0,            "LiquidityVault: deposit amount must be greater than zero");

        lpToken     = IERC20(_lpToken);
        lpDeposited = _amount;
        isDeposited = true;

        lpToken.safeTransferFrom(msg.sender, address(this), _amount);

        emit LPDeposited(_lpToken, _amount, msg.sender);
    }

    // ═════════════════════════════════════════════════════════════════════
    // BURN
    // ═════════════════════════════════════════════════════════════════════

    /**
     * @notice Send all LP tokens to the dead address, permanently locking liquidity.
     *
     * Can be called by anyone at any time after a deposit has been made.
     * Transfers the entire LP token balance of this contract to 0x000...dEaD.
     * After this call, BLD/ETH liquidity on Uniswap V2 can never be removed.
     */
    function burnLP() external {
        require(isDeposited, "LiquidityVault: no LP tokens have been deposited yet");
        require(!isBurned,   "LiquidityVault: LP tokens have already been burned");

        uint256 balance = lpToken.balanceOf(address(this));
        require(balance > 0, "LiquidityVault: nothing to burn");

        isBurned = true;

        lpToken.safeTransfer(DEAD, balance);

        emit LPBurned(address(lpToken), balance, msg.sender);
    }

    // ═════════════════════════════════════════════════════════════════════
    // VIEW
    // ═════════════════════════════════════════════════════════════════════

    /**
     * @notice Returns the current LP token balance held by this contract.
     * @return balance Current LP balance. Returns 0 if not yet deposited or already burned.
     */
    function lpBalance() external view returns (uint256 balance) {
        if (!isDeposited) return 0;
        return lpToken.balanceOf(address(this));
    }

    /**
     * @notice Returns a full status summary of the vault.
     * @return deposited  True if LP tokens have been deposited.
     * @return burned     True if LP tokens have been burned.
     * @return lp         Address of the LP token (zero if not yet deposited).
     * @return amount     Total LP tokens originally deposited.
     * @return balance    Current LP balance held by this contract.
     */
    function vaultStatus() external view returns (
        bool    deposited,
        bool    burned,
        address lp,
        uint256 amount,
        uint256 balance
    ) {
        deposited = isDeposited;
        burned    = isBurned;
        lp        = address(lpToken);
        amount    = lpDeposited;
        balance   = isDeposited ? lpToken.balanceOf(address(this)) : 0;
    }
}
