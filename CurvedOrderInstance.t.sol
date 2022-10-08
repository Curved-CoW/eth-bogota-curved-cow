// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";

import "../libraries/CurvedOrder.sol";
import "../libraries/GPv2Order.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/ICoWSwapSettlement.sol";
import "../CurvedOrders.sol";
import "./mock/MockCowSwapSettlement.sol";

contract CurvedOrderInstanceTest is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    address constant BUY_TOKEN = address(uint160(0x1337));
    address constant SELL_TOKEN = address(uint160(0x13372));
    address constant VERIFIER = 0x0000000000000000000000000000000000000001;
    address constant RECEIVER = 0x0000000000000000000000000000000000000002;
    bytes32 constant BALANCE_ERC20 =
        hex"5a28e9363bb942b639270062aa6bb295f434bcdfc42c97267bf003f272060dc9";
    bytes32 constant KIND_SELL =
        hex"f3b277728b3fee749481eb3e0b3b48980dbbab78658fc419025cb16eee346775";

    address constant SETTLEMENT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;

    Utilities internal utils;
    address payable[] internal users;

    //CurvedOrders orders;

    function setUp() public {}

    function test_constructor() public {
        assertEq(address(), address());
    }

    function test_isValidSignature() public {
        assertEq(address(orders), address(orders));
    }

    function test_decode() public {}
}
