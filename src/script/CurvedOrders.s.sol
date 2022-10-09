// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity >=0.8.0;

import "forge-std/Script.sol";
import "../CurvedOrders.sol";
import "../interfaces/IERC20.sol";
import "../libraries/CurvedOrder.sol";
import "../libraries/GPv2Order.sol";

contract MyScript is Script {
    bytes32 constant BALANCE_ERC20 = hex"5a28e9363bb942b639270062aa6bb295f434bcdfc42c97267bf003f272060dc9";
    bytes32 constant KIND_SELL = hex"f3b277728b3fee749481eb3e0b3b48980dbbab78658fc419025cb16eee346775";
    address constant RECEIVER = 0x0000000000000000000000000000000000000002;

    address immutable deployedOrdersAddr = 0xcd7A61D023a801Ba1193620b80F7Fe90E6340744;
    address immutable popTokenAddr = 0xD0Cd466b34A24fcB2f87676278AF2005Ca8A78c4;
    address immutable cowTokenAddr = 0xDEf1CA1fb7FBcDC777520aa7f396b4E015F497aB;

    function run() external {
        uint256[] memory buyAmounts = [0.1 ether, 0.2 ether];
        uint256[] memory sellAmounts = [0.3 ether, 0.4 ether];

        GPv2Order.Data memory _gpv2Order = GPv2Order.Data({
            sellToken: IERC20(popTokenAddr),
            buyToken: IERC20(cowTokenAddr),
            receiver: RECEIVER,
            sellAmount: sellAmounts[1],
            buyAmount: buyAmounts[1],
            validTo: 500,
            appData: 0,
            feeAmount: 0,
            kind: KIND_SELL,
            partiallyFillable: true,
            sellTokenBalance: BALANCE_ERC20,
            buyTokenBalance: BALANCE_ERC20
        });

        CurvedOrder.Data memory curvedOrder = CurvedOrder.Data({
            sellToken: IERC20(popTokenAddr),
            buyToken: IERC20(cowTokenAddr),
            receiver: RECEIVER,
            sellAmount: sellAmounts[1],
            buyAmount: buyAmounts[1],
            validTo: 500,
            sellTokenBalance: BALANCE_ERC20,
            buyTokenBalance: BALANCE_ERC20
        });

        (bytes memory orderUid, address orderInstance) = CurvedOrders(deployedOrdersAddr).placeOrder(
            _gpv2Order(sellAmounts[1], buyAmounts[1]),
            curvedOrder(sellAmounts, buyAmounts),
            keccak256(bytes("another salt"))
        );

        vm.stopBroadcast();
    }
}
