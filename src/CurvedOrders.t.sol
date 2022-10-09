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
import "./mock/MockERC20.sol";
import {GPv2EIP1271} from "../interfaces/ERC1271.sol";

contract CurvedOrdersTest is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    address immutable BUY_TOKEN;
    address immutable SELL_TOKEN;
    address constant VERIFIER = 0x0000000000000000000000000000000000000001;
    address constant RECEIVER = 0x0000000000000000000000000000000000000002;
    bytes32 constant BALANCE_ERC20 =
        hex"5a28e9363bb942b639270062aa6bb295f434bcdfc42c97267bf003f272060dc9";
    bytes32 constant KIND_SELL =
        hex"f3b277728b3fee749481eb3e0b3b48980dbbab78658fc419025cb16eee346775";

    address constant SETTLEMENT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;

    address constant LP_ADDRESS = 0x7B2419E0Ee0BD034F7Bf24874C12512AcAC6e21C;

    Utilities internal utils;
    address payable[] internal users;

    CurvedOrders orders;

    ERC20 sellToken;
    ERC20 buyToken;

    event OrderPlacement(
        address indexed sender, GPv2Order.Data order, ICoWSwapOnchainOrders.OnchainSignature signature, bytes data
    );

    constructor() {
        sellToken = new MockERC20("Sell Token", "ST", 18);
        buyToken = new MockERC20("Buy Token", "ST", 18);
        BUY_TOKEN = address(buyToken);
        SELL_TOKEN = address(sellToken);
    }

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(5);
        ICoWSwapSettlement settlement = new MockCowSwapSettlement();
        orders = new CurvedOrders(settlement);

        sellToken.transfer(OWNER, 500_000 ether);
        vm.prank(OWNER);
        sellToken.approve(address(orders), type(uint256).max);
    }

    function test_balances_of_msg_sender() public {
        assertEq(IERC20(SELL_TOKEN).balanceOf(address(this)), 500_000 * 10 ** 18);
        assertEq(IERC20(BUY_TOKEN).balanceOf(address(this)), 1_000_000 * 10 ** 18);
    }

    function test_constructor() public {
        assertEq(address(orders), address(orders));
    }

    function test_generate_payload_v2() public {
        (, address orderInstanceAddress) = _new_curved_order();

        CurvedOrderInstance orderInstance = CurvedOrderInstance(orderInstanceAddress);

        (GPv2Order.Data memory gpv2Order, CurvedOrder.Data memory curvedOrder, bytes memory curvedOrderSignature) =
            orderInstance.decode(truncated_signature);

        orderInstance.generateSignature(gpv2Order, curvedOrder, curvedOrderSignature);

        (
            GPv2Order.Data memory gpv2OrderDecoded,
            CurvedOrder.Data memory curvedOrderDecoded,
            bytes memory curvedOrderSignatureDecoded
        ) = abi.decode(truncated_signature, (GPv2Order.Data, CurvedOrder.Data, bytes));

        console.log(address(gpv2OrderDecoded.sellToken));

        assertEq(uint256(keccak256(abi.encode(gpv2Order))), uint256(keccak256(abi.encode(gpv2Order))));
        assertEq(uint256(keccak256(abi.encode(curvedOrder))), uint256(keccak256(abi.encode(curvedOrderDecoded))));
        assertEq(
            uint256(keccak256(abi.encode(curvedOrderSignature))),
            uint256(keccak256(abi.encode(curvedOrderSignatureDecoded)))
        );
    }

    function test_creates_curved_order() public {
        (bytes memory orderUid, address orderInstance) = _new_curved_order();
        assertEq(orderUid.length, 56);
        assertEq(abi.encodePacked(address(orderInstance)).length, 20);
    }

    function _new_curved_order() public returns (bytes memory, address) {
        uint256[] memory sellAmounts = _sell_amount();
        uint256[] memory buyAmounts = _buy_amount();

        vm.prank(0xd19772540a685424DD127f9aE6AE38DBC3cf56FB);
        (bytes memory orderUid, address orderInstance) = orders.placeOrder(
            _gpv2_order(sellAmounts[1], buyAmounts[1]),
            _curved_order_from_amounts(sellAmounts, buyAmounts),
            keccak256(bytes("this is a salt"))
        );

        return (orderUid, orderInstance);
    }

    function _curved_order_from_amounts(uint256[] memory sellAmount, uint256[] memory buyAmount)
        internal
        view
        returns (CurvedOrder.Data memory curvedOrder)
    {
        curvedOrder = CurvedOrder.Data({
            sellToken: IERC20(SELL_TOKEN),
            buyToken: IERC20(BUY_TOKEN),
            receiver: RECEIVER,
            sellAmount: sellAmount,
            buyAmount: buyAmount,
            validTo: 500,
            sellTokenBalance: BALANCE_ERC20,
            buyTokenBalance: BALANCE_ERC20
        });
    }

    function _gpv2_order(uint256 sellAmount, uint256 buyAmount) internal view returns (GPv2Order.Data memory) {
        return GPv2Order.Data({
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

    function test_decode_payload() public {
        (, address orderInstanceAddress) = _new_curved_order();
        CurvedOrderInstance orderInstance = CurvedOrderInstance(orderInstanceAddress);
        orderInstance.decode(truncated_signature);
    }

    function _strip_address_from_signature(bytes calldata signature) public pure returns (bytes calldata) {
        return signature[20:];
    }

    //below or to the side of the curve. No longer valid. Fees amount is greater than 0.

    /// @dev We use a custom SigUtils contract to help create a CurvedOrder hash.
    contract SigUtils {
    bytes32 internal DOMAIN_SEPARATOR;

    constructor(bytes32 _DOMAIN_SEPARATOR) {
      DOMAIN_SEPARATOR = _DOMAIN_SEPARATOR;

    // keccak256("CurveOrderHash(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant CurvedOrderHash =
            0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    }
    struct CurvedOrder {
        IERC20 sellToken;
        IERC20 buyToken;
        address receiver;
        uint256[] sellAmount;
        uint256[] buyAmount;
        uint32 validTo;
        bytes32 sellTokenBalance;
        bytes32 buyTokenBalance;
    }

    // computes the hash of the CurvedOrder
    function getCurvedOrderHash(CurvedOrder memory curvedOrderHash)
        internal
        pure
        returns (bytes32)
      {
        return
          keccak256(
            abi.encode(
            )
          )
      }

    // computes the hash of the fully encoded EIP-1271 message for the domain, which can be used to recover the signer

    function test_gpv2Order_fees_equals_zero() public {
        uint256[] memory sellAmounts = _sell_amount();
        uint256[] memory buyAmounts = _buy_amount();
        GPv2Order.Data memory cowOrder = _gpv2_order(
            sellAmounts[1],
            buyAmounts[1]
        );
        bytes32 order_hash = GPv2Order.hash(cowOrder, domainSeperator);
        (, address orderInstanceAddress) = _new_curved_order();
        CurvedOrderInstance orderInstance = CurvedOrderInstance(
            orderInstanceAddress
        );



        bytes curvedOrderSignature = // Like permit example but for CurvedOrder
        bytes signature = abi.encode(cowOrder, orderInstance, curverOrderSignature);
        bytes4 result = orderInstance.isValidSignature(order_hash, signature);
        assertEq(result, GPv2EIP1271.MAGICVALUE); //should be able to asserteq MAGICVALUE in the happy case.
    }

    function _strip_address_from_signature(bytes calldata signature)
        public
        pure
        returns (bytes calldata)
    {
        return signature[20:];
    }

    function test_is_valid_signature() public {
        assertTrue(false);
    }

    //ecrecover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) returns (address)
    //recover the address associated with the public key from
    //elliptic curve signature or return zero on error. The function parameters
    //correspond to ECDSA values of the signature:
    //r = first 32 bytes of signature
    //s = second 32 bytes of signature
    //v = final 1 byte of signature
    //ecrecover returns an address, and not an address payable

    function test_placing_order_emits_event() public {
        uint256[] memory sellAmounts = _sell_amount();
        uint256[] memory buyAmounts = _buy_amount();

        // checks topic 2, topic 3 and data are the same as the following emitted event. It does not check topic 1.
        vm.expectEmit(false, true, true, true);

        emit OrderPlacement(
        OWNER,
        _gpv2_order(sellAmounts[1], buyAmounts[1]),
        ICoWSwapOnchainOrders.OnchainSignature({
            scheme: ICoWSwapOnchainOrders.OnchainSigningScheme.Eip1271,
            data: hex""
        }),
        abi.encode(_curved_order_from_amounts(sellAmounts, buyAmounts))
        );

    _new_curved_order();
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

    bytes public truncated_signature =
        hex"000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000009008d19f58aabd9ed0d60971565aa8510560ab410000000000000000000000000000000000000000000000001bc16d674ec8000000000000000000000000000000000000000000000000008d0020474fb7000000000000000000000000000000000000000000000000000000000000006341fc0a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002f3b277728b3fee749481eb3e0b3b48980dbbab78658fc419025cb16eee34677500000000000000000000000000000000000000000000000000000000000000005a28e9363bb942b639270062aa6bb295f434bcdfc42c97267bf003f272060dc95a28e9363bb942b639270062aa6bb295f434bcdfc42c97267bf003f272060dc900000000000000000000000000000000000000000000000000000000000001c00000000000000000000000000000000000000000000000000000000000000380000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000009008d19f58aabd9ed0d60971565aa8510560ab4100000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000006341fc0a5a28e9363bb942b639270062aa6bb295f434bcdfc42c97267bf003f272060dc95a28e9363bb942b639270062aa6bb295f434bcdfc42c97267bf003f272060dc900000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000de0b6b3a76400000000000000000000000000000000000000000000000000001bc16d674ec800000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000046791fc84e07d0000000000000000000000000000000000000000000000000008d0020474fb70000000000000000000000000000000000000000000000000000000000000000000041488ff08f8e1573afb7361367ee69302bf66c837ed5282808e7c039a65bfb1b536fcc8d9158656d54e9860d01d950aaf0f67034f1c1f205e252913993c0668ba31b00000000000000000000000000000000000000000000000000000000000000";
}
