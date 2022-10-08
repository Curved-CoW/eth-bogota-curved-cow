// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";

import "../libraries/CurvedOrder.sol";
import "../libraries/GPv2Order.sol";
import "../interfaces/IERC20.sol";

contract ContractTest is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    address constant BUY_TOKEN = address(uint160(0x1337));
    address constant SELL_TOKEN = address(uint160(0x13372));
    address constant VERIFIER = 0x0000000000000000000000000000000000000001;
    address constant RECEIVER = 0x0000000000000000000000000000000000000002;
    bytes32 constant BALANCE_ERC20 =
        hex"5a28e9363bb942b639270062aa6bb295f434bcdfc42c97267bf003f272060dc9";
    bytes32 constant KIND_SELL =
        hex"f3b277728b3fee749481eb3e0b3b48980dbbab78658fc419025cb16eee346775";

    Utilities internal utils;
    address payable[] internal users;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(5);
    }

    function _create_gpv2_order()
        internal
        view
        returns (GPv2Order.Data memory order)
    {
        order = GPv2Order.Data({
            sellToken: IERC20(SELL_TOKEN),
            buyToken: IERC20(BUY_TOKEN),
            receiver: RECEIVER,
            sellAmount: 100,
            buyAmount: 100,
            validTo: 22,
            appData: 0,
            feeAmount: 21,
            kind: KIND_SELL,
            partiallyFillable: true,
            sellTokenBalance: BALANCE_ERC20,
            buyTokenBalance: BALANCE_ERC20
        });
    }

    function _sell_amount() internal pure returns (uint256[] memory) {
        uint256[] memory sellAmount = new uint256[](2);
        sellAmount[0] = 1e18;
        sellAmount[1] = 2e18;
        return sellAmount;
    }

    function _buy_amount() internal pure returns (uint256[] memory) {
        uint256[] memory buyAmount = new uint256[](2);
        buyAmount[0] = 1300e18;
        buyAmount[1] = 2600e18;
        return buyAmount;
    }

    function _create_curved_order()
        internal
        pure
        returns (CurvedOrder.Data memory curvedOrder)
    {
        uint256[] memory sellAmount = new uint256[](2);
        uint256[] memory buyAmount = new uint256[](2);

        sellAmount[0] = 1e18;
        sellAmount[1] = 2e18;
        buyAmount[0] = 1300e18;
        buyAmount[1] = 2600e18;

        curvedOrder = CurvedOrder.Data({
            sellToken: IERC20(SELL_TOKEN),
            buyToken: IERC20(BUY_TOKEN),
            receiver: RECEIVER,
            sellAmount: sellAmount,
            buyAmount: buyAmount,
            validTo: 500,
            feeAmount: 671,
            sellTokenBalance: BALANCE_ERC20,
            buyTokenBalance: BALANCE_ERC20
        });
    }

    function _create_signature_v1()
        internal
        view
        returns (bytes memory signature)
    {
        address verifier = VERIFIER;
        bytes memory encodedOrder = abi.encode(_create_curved_order());
        signature = abi.encodePacked(verifier, encodedOrder);
        console.logBytes(signature);
    }

    function _create_signature_v2()
        internal
        view
        returns (bytes memory signature)
    {
        address verifier = VERIFIER;
        bytes32 curvedOrderSignature;
        bytes memory encodedCurvedOrder = abi.encode(
            _create_gpv2_order(),
            _create_curved_order(),
            curvedOrderSignature
        );
        signature = abi.encodePacked(verifier, encodedCurvedOrder);
    }

    function test_signature_v2_decodes() public {
        bytes memory signature = _create_signature_v2();
        (address verifier, bytes memory encodedSignature) = this
            ._extract_verifier_from_bytes(signature);

        (
            GPv2Order.Data memory gpv2Order,
            CurvedOrder.Data memory curvedOrder,
            bytes32 curvedOrderSignature
        ) = abi.decode(
                encodedSignature,
                (GPv2Order.Data, CurvedOrder.Data, bytes32)
            );

        assertEq(verifier, VERIFIER);
        __assert_curved_order(curvedOrder);
        __assert_gpv2_order(gpv2Order);
        __assert_curved_order_signature(curvedOrderSignature);
    }

    function __assert_curved_order_signature(bytes32 curvedOrderSignature)
        internal
    {
        assertEq(curvedOrderSignature, bytes32(0x0));
    }

    function __assert_curved_order(CurvedOrder.Data memory order) internal {
        assertEq(order.receiver, RECEIVER);
        assertEq(order.sellAmount[0], _sell_amount()[0]);
        assertEq(order.buyAmount[0], _buy_amount()[0]);
        assertEq(order.sellAmount[1], _sell_amount()[1]);
        assertEq(order.buyAmount[1], _buy_amount()[1]);
        assertEq(address(order.sellToken), SELL_TOKEN);
        assertEq(address(order.buyToken), BUY_TOKEN);
    }

    function __assert_gpv2_order(GPv2Order.Data memory order) internal {
        assertEq(order.receiver, RECEIVER);
        assertEq(order.sellAmount, 100);
        assertEq(order.buyAmount, 100);
        assertEq(address(order.sellToken), SELL_TOKEN);
        assertEq(address(order.buyToken), BUY_TOKEN);
    }

    function test_signature_v1_decodes() public {
        bytes memory signature = _create_signature_v1();
        (address verifier, bytes memory encodedSignature) = this
            ._extract_verifier_from_bytes(signature);

        CurvedOrder.Data memory order = abi.decode(
            encodedSignature,
            (CurvedOrder.Data)
        );

        assertEq(verifier, VERIFIER);
        __assert_curved_order(order);
    }

    function _extract_verifier_from_bytes(bytes calldata encodedSignature)
        public
        pure
        returns (address owner, bytes memory signature)
    {
        assembly {
            // owner = address(encodedSignature[0:20])
            owner := shr(96, calldataload(encodedSignature.offset))
        }

        signature = encodedSignature[20:];
    }

    // TODO  double check: feeAmount is additive
    function _create_curved_order_from_amounts(
        uint256[] memory sellAmount,
        uint256[] memory buyAmount
    ) internal pure returns (CurvedOrder.Data memory curvedOrder) {
        curvedOrder = CurvedOrder.Data({
            sellToken: IERC20(SELL_TOKEN),
            buyToken: IERC20(BUY_TOKEN),
            receiver: RECEIVER,
            sellAmount: sellAmount,
            buyAmount: buyAmount,
            validTo: 500,
            feeAmount: 0,
            sellTokenBalance: BALANCE_ERC20,
            buyTokenBalance: BALANCE_ERC20
        });
    }

    function _create_gpv2_order_from_amounts(
        uint256 sellAmount,
        uint256 buyAmount
    ) internal pure returns (GPv2Order.Data memory curvedOrder) {
        curvedOrder = GPv2Order.Data({
            sellToken: IERC20(SELL_TOKEN),
            buyToken: IERC20(BUY_TOKEN),
            receiver: RECEIVER,
            sellAmount: sellAmount,
            buyAmount: buyAmount,
            validTo: 500,
            appData: 0,
            feeAmount: 0,
            kind: KIND_SELL,
            partiallyFillable: true,
            sellTokenBalance: BALANCE_ERC20,
            buyTokenBalance: BALANCE_ERC20
        });
    }

    function test_point_above_line_segment() public {
        assertTrue(
            CurvedOrder.pointAboveLineSegment(
                [uint256(1e18), uint256(1300e18 + 1)],
                [uint256(1e18), uint256(1300e18)],
                [uint256(2e18), uint256(2 * 1300e18)]
            )
        );

        assertTrue(
            CurvedOrder.pointAboveLineSegment(
                [uint256(1e18), uint256(1300e18)],
                [uint256(1e18), uint256(1300e18)],
                [uint256(2e18), uint256(2 * 1300e18)]
            )
        );

        console.log(1);
        assertTrue(
            !CurvedOrder.pointAboveLineSegment(
                [uint256(1e18), uint256(1300e18 - 1)],
                [uint256(1e18), uint256(1300e18)],
                [uint256(2e18), uint256(2 * 1300e18)]
            )
        );

        console.log(2);

        assertTrue(
            !CurvedOrder.pointAboveLineSegment(
                [uint256(1e18 + 1), uint256(1300e18 + 1)],
                [uint256(1e18), uint256(1300e18)],
                [uint256(2e18), uint256(2 * 1300e18 + 1)]
            )
        );

        console.log(3);
        assertTrue(
            CurvedOrder.pointAboveLineSegment(
                [uint256(2e18), uint256(2 * 1300e18 + 1)],
                [uint256(1e18), uint256(1300e18)],
                [uint256(2e18), uint256(2 * 1300e18 + 1)]
            )
        );

        assertTrue(
            CurvedOrder.pointAboveLineSegment(
                [uint256(1e18 + 1), uint256(1300e18 + 1300 + 1)],
                [uint256(1e18), uint256(1300e18)],
                [uint256(2e18), uint256(2 * 1300e18 + 1)]
            )
        );
    }

    function test_executed_above_curve() public {
        uint256[] memory sellAmount = new uint256[](2);
        uint256[] memory buyAmount = new uint256[](2);
        sellAmount[0] = 1e18;
        sellAmount[1] = 2e18;
        buyAmount[0] = 1300e18;
        buyAmount[1] = 2601e18;

        CurvedOrder.Data memory curvedOrder = _create_curved_order_from_amounts(
            sellAmount,
            buyAmount
        );

        assertTrue(
            CurvedOrder.executionAboveCurve(
                _create_gpv2_order_from_amounts(1, 1300),
                curvedOrder
            )
        );

        assertTrue(
            CurvedOrder.executionAboveCurve(
                _create_gpv2_order_from_amounts(1e18 + 1, 1300e18 + 1300 + 1),
                curvedOrder
            )
        );

        assertTrue(
            !CurvedOrder.executionAboveCurve(
                _create_gpv2_order_from_amounts(1e18 + 1, 1300e18 + 1),
                curvedOrder
            )
        );
        assertTrue(
            !CurvedOrder.executionAboveCurve(
                _create_gpv2_order_from_amounts(1e18 + 1, 1300e18 - 1),
                curvedOrder
            )
        );

        assertTrue(
            !CurvedOrder.executionAboveCurve(
                _create_gpv2_order_from_amounts(2e18, 2 * 1300e18),
                curvedOrder
            )
        );

        assertTrue(
            CurvedOrder.executionAboveCurve(
                _create_gpv2_order_from_amounts(2e18, 2 * 1301e18),
                curvedOrder
            )
        );

        assertTrue(
            CurvedOrder.executionAboveCurve(
                _create_gpv2_order_from_amounts(1, 2700e18),
                curvedOrder
            )
        );

        // Not sure what this abomination is but I don't know how to
        // check for a revert otherwise
        try
            CurvedOrder.executionAboveCurve(
                _create_gpv2_order_from_amounts(3e18, 4000e18),
                curvedOrder
            )
        returns (bool) {
            assertTrue(1 == 2);
        } catch {
            assertTrue(1 == 1);
        }
    }
}
