// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.10;

import "forge-std/Script.sol";
import "../CurvedOrderInstance.sol";

contract approve is Script {
    address constant ORDER_INSTANCE = 0x5F73f4413eF1cc7f0FDF92c060f5Ff50a0606BE5;
    address constant TOKEN = 0xD0Cd466b34A24fcB2f87676278AF2005Ca8A78c4;

    function run() public {
        vm.startBroadcast();
        CurvedOrderInstance(address(ORDER_INSTANCE)).approve(IERC20(TOKEN), type(uint256).max);
        vm.stopBroadcast();
    }
}
