// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {OutgoingTransferSupportV1} from "../OutgoingTransferSupport/V1/OutgoingTransferSupportV1.sol";
import {MulticallReentrancyGuard} from "./MulticallReentrancyGuard.sol";

/// @title Multicall
/// @notice allowing call multiple methods in a single call to the contract
/// @dev inspired by mds1'smulticall3 and Uniswap-V3-periphery's multicall
///   https://github.com/mds1/multicall/blob/d7b62458c99c650ce1efa7464ffad69d2059ad56/src/Multicall3.sol
///   https://github.com/Uniswap/v3-periphery/blob/697c2474757ea89fec12a4e6db16a574fe259610/contracts/base/Multicall.sol
abstract contract Multicall is OutgoingTransferSupportV1, MulticallReentrancyGuard {
    struct Call {
        bool allowFailure;
        bytes callData;
    }

    struct Result {
        bool success;
        bytes returnData;
    }

    /// @notice Aggregate calls, ensuring each returns success if required
    /// @dev The `msg.value` should not be trusted for any method callable from multicall.
    /// @param calls An array of Call structs
    /// @return returnData An array of Result structs
    function aggregate(Call[] calldata calls) public payable nonReentrantMulticall returns (Result[] memory returnData) {
        uint256 length = calls.length;
        returnData = new Result[](length);
        Call calldata calli;
        for (uint256 i = 0; i < length; ) {
            Result memory result = returnData[i];
            calli = calls[i];
            (result.success, result.returnData) = address(this).delegatecall(calli.callData);
            assembly {
                // Revert if the call fails and failure is not allowed
                // `allowFailure := calldataload(add(calli, 0x20))` and `success := mload(result)`
                if iszero(or(calldataload(calli), mload(result))) {
                    // set "Error(string)" signature: bytes32(bytes4(keccak256("Error(string)")))
                    mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                    // set data offset
                    mstore(0x04, 0x0000000000000000000000000000000000000000000000000000000000000020)
                    // set length of revert string
                    mstore(0x24, 0x0000000000000000000000000000000000000000000000000000000000000016)
                    // set revert string: bytes32(abi.encodePacked("Multicall: call failed"))
                    mstore(0x44, 0x4d756c746963616c6c3a2063616c6c206661696c656400000000000000000000)
                    revert(0x00, 0x64)
                }
            }
            unchecked {
                ++i;
            }
        }

        // Refund any excess Ether
        _handleOutgoingTransfer(msg.sender, address(this).balance, address(0), 50000);
    }
}
