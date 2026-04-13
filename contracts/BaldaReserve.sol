// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title  BaldaReserve
 * @author Balda Protocol
 * @notice Eternal reserve contract for the BALDA (BLD) token.
 *
 * This contract holds 6,000 BLD permanently. It has no owner, no functions,
 * no fallback, and no receive hook. Once tokens are sent here at the time
 * the Balda token is deployed, they are locked forever with no mechanism
 * to move, transfer, or interact with them in any way.
 *
 * The source code is intentionally minimal and publicly verifiable on-chain
 * as definitive proof that the reserved supply can never be accessed.
 *
 * @dev Deploy this contract before Balda.sol.
 *      Pass this contract's address to the Balda constructor.
 */
contract BaldaReserve {
    // Intentionally empty.
    // No state variables.
    // No functions.
    // No constructor logic.
    // No fallback.
    // No receive.
    // Tokens deposited here are locked forever.
}
