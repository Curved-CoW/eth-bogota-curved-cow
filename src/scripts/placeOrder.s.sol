// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity >=0.8.0;

import "forge-std/Script.sol";
import "../CurvedOrders.sol";
import "../interfaces/IERC20.sol";
import "../libraries/CurvedOrder.sol";
import "../libraries/GPv2Order.sol";

contract placeOrder is Script {
    /**
     *   set these constants to the values you want to use for your Curved Order
     */

    address immutable SELL_TOKEN = 0xD0Cd466b34A24fcB2f87676278AF2005Ca8A78c4;
    address immutable BUY_TOKEN = 0xDEf1CA1fb7FBcDC777520aa7f396b4E015F497aB;
    address constant RECEIVER = 0x0000000000000000000000000000000000000002;
    uint256[2] public BUY_AMOUNTS = [0.1 ether, 0.2 ether];
    uint256[2] public SELL_AMOUNTS = [0.1 ether, 0.2 ether];
    uint256 constant VALID_FOR_DAYS = 30;

    /**
     * ^^ end configuration ^^
     */

    address immutable ORDER_FACTORY = 0xcd7A61D023a801Ba1193620b80F7Fe90E6340744;
    bytes32 constant BALANCE_ERC20 = hex"5a28e9363bb942b639270062aa6bb295f434bcdfc42c97267bf003f272060dc9";
    bytes32 constant KIND_SELL = hex"f3b277728b3fee749481eb3e0b3b48980dbbab78658fc419025cb16eee346775";

    function run() external {
        GPv2Order.Data memory gpv2Order = GPv2Order.Data({
            sellToken: IERC20(SELL_TOKEN),
            buyToken: IERC20(BUY_TOKEN),
            receiver: RECEIVER,
            sellAmount: SELL_AMOUNTS[1],
            buyAmount: BUY_AMOUNTS[1],
            validTo: uint32(block.timestamp + VALID_FOR_DAYS * 86400),
            appData: 0,
            feeAmount: 0,
            kind: KIND_SELL,
            partiallyFillable: true,
            sellTokenBalance: BALANCE_ERC20,
            buyTokenBalance: BALANCE_ERC20
        });

        CurvedOrder.Data memory curvedOrder = CurvedOrder.Data({
            sellToken: IERC20(SELL_TOKEN),
            buyToken: IERC20(BUY_TOKEN),
            receiver: RECEIVER,
            sellAmount: _sell_amount(SELL_AMOUNTS),
            buyAmount: _buy_amount(BUY_AMOUNTS),
            validTo: uint32(block.timestamp + VALID_FOR_DAYS * 86400),
            sellTokenBalance: BALANCE_ERC20,
            buyTokenBalance: BALANCE_ERC20
        });

        // signing is currently implemented in another python script, but this signed order can be shared with the solver offline for it to generate a valid signature for the GPv2Trade
        // vm.sign(ownerPrivateKey, abi.encode(curvedOrder));

        IERC20(SELL_TOKEN).approve(ORDER_FACTORY, type(uint256).max);

        (, address instance) =
            CurvedOrders(ORDER_FACTORY).placeOrder(gpv2Order, curvedOrder, bytes32(uint256(block.timestamp)));

        console.log("Submitted a Curved Order @ ", instance);
        vm.stopBroadcast();
    }

    function _sell_amount(uint256[2] memory _sellAmounts) internal pure returns (uint256[] memory) {
        uint256[] memory sellAmounts = new uint256[](2);
        sellAmounts[0] = _sellAmounts[0];
        sellAmounts[1] = _sellAmounts[1];
        return sellAmounts;
    }

    function _buy_amount(uint256[2] memory _buyAmounts) internal pure returns (uint256[] memory) {
        uint256[] memory buyAmounts = new uint256[](2);
        buyAmounts[0] = _buyAmounts[0];
        buyAmounts[1] = _buyAmounts[1];
        return buyAmounts;
    }
}
