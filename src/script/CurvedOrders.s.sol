// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity >=0.8.0;

import "forge-std/Script.sol";
import "../CurvedOrders.sol";

contract MyScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address goerliSettlementAddr = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;
        CurvedOrders curvedOrders = new CurvedOrders(ICoWSwapSettlement(goerliSettlementAddr));

        address popTokenAddr;
        address cowTokenAddr;

        uint256[] memory buyAmounts = new uint256[](2);
        uint256[] memory sellAmounts = new uint256[](2);

        (bytes memory orderUid, address orderInstance) = orders.placeOrder(
            _gpv2_order(sellAmounts[1], buyAmounts[1]),
            _curved_order_from_amounts(sellAmounts, buyAmounts),
            keccak256(bytes("another salt"))
        );

        vm.stopBroadcast();
    }
}
