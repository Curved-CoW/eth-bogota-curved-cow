// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity >=0.8.0;

import "../interfaces/IERC20.sol";
import {GPv2Order} from "../libraries/GPv2Order.sol";

library CurvedOrder {
    struct Data {
        IERC20 sellToken;
        IERC20 buyToken;
        address receiver;
        uint256[] sellAmount;
        uint256[] buyAmount;
        uint32 validTo;
        bytes32 sellTokenBalance;
        bytes32 buyTokenBalance;
    }

    function findMinIndexGT(uint256[] calldata arr, uint256 tgt) public pure returns (uint256 index) {
        bool found = false;
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] >= tgt) {
                index = i;
                found = true;
                break;
            }
        }
        require(found, "executed order size too large");
    }

    function pointAboveLineSegment(
        uint256[2] memory executedPoint,
        uint256[2] memory leftBreakpoint,
        uint256[2] memory rightBreakpoint
    ) public pure returns (bool) {
        // (x'-x)(b-y) >= (a-x)(y'-y)
        // TODO Safemath??
        if (executedPoint[1] < leftBreakpoint[1]) {
            return false;
        }

        return (rightBreakpoint[0] - leftBreakpoint[0]) * (executedPoint[1] - leftBreakpoint[1])
            >= (executedPoint[0] - leftBreakpoint[0]) * (rightBreakpoint[1] - leftBreakpoint[1]);
    }

    // Note: we assume that the list of breakpoints is ordered
    function executionAboveCurve(GPv2Order.Data calldata executedOrder, CurvedOrder.Data calldata curvedOrder)
        public
        pure
        returns (bool aboveCurve)
    {
        // find first index with curve sell amount >= executed sell amount (if any)
        uint256 rightIndex = findMinIndexGT(curvedOrder.sellAmount, executedOrder.sellAmount);
        uint256[2] memory rightBreakpoint = [curvedOrder.sellAmount[rightIndex], curvedOrder.buyAmount[rightIndex]];

        // DESIGN CHOICE?
        // The point [0,0] is included by convention (could be thought of as occuping index -1)
        uint256[2] memory leftBreakpoint = [uint256(0), uint256(0)];
        if (rightIndex > 0) {
            leftBreakpoint = [curvedOrder.sellAmount[rightIndex - 1], curvedOrder.buyAmount[rightIndex - 1]];
        }

        uint256[2] memory executedPoint = [executedOrder.sellAmount, executedOrder.buyAmount];

        aboveCurve = pointAboveLineSegment(executedPoint, leftBreakpoint, rightBreakpoint);
    }

}
