// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity >=0.8.0;

import "../interfaces/IERC20.sol";

library CurvedOrder {
    struct Data {
        IERC20 sellToken;
        IERC20 buyToken;
        address receiver;
        uint256[] sellAmount;
        uint256[] buyAmount;
        uint32 validTo;
        uint256 feeAmount;
        bytes32 sellTokenBalance;
        bytes32 buyTokenBalance;
    }
}
