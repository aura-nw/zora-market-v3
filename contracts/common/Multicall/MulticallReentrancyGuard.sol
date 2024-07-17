// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Gas optimized reentrancy protection for multicall contracts.
/// @author Modified (https://github.com/transmissions11/solmate/blob/34d20fc027fe8d50da71428687024a29dc01748b/src/utils/ReentrancyGuard.sol)
abstract contract MulticallReentrancyGuard {
    uint256 private multicallReentrancyStatus = 1;

    modifier nonReentrantMulticall() {
        require(multicallReentrancyStatus == 1, "REENTRANCY");

        multicallReentrancyStatus = 2;

        _;

        multicallReentrancyStatus = 1;
    }
}
