// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity >=0.8.0;

import "./interfaces/ERC1271.sol";
import "./libraries/CurvedOrder.sol";
import "./libraries/GPv2Order.sol";
import "./interfaces/IERC20.sol";
import {ICoWSwapOnchainOrders} from "./interfaces/ICoWSwapOnChainOrders.sol";
import "./CurvedOrderInstance.sol";
import "./interfaces/ICoWSwapSettlement.sol";
import {console} from "./test/utils/Console.sol";

contract CurvedOrders is ICoWSwapOnchainOrders {
    using GPv2Order for *;

    ICoWSwapSettlement public immutable settlement;
    bytes32 public immutable domainSeparator;

    constructor(ICoWSwapSettlement settlement_) {
        settlement = settlement_;
        domainSeparator = settlement_.domainSeparator();
    }

    function placeOrder(GPv2Order.Data calldata gpv2Order, CurvedOrder.Data calldata curvedOrder, bytes32 salt)
        external
        returns (bytes memory orderUid, address)
    {
        // todo validate orders have matching fields

        bytes32 gpv2OrderHash = gpv2Order.hash(domainSeparator);

        CurvedOrderInstance instance = new CurvedOrderInstance{salt: salt}(
            msg.sender,
            curvedOrder.sellToken,
            settlement
        );

        curvedOrder.sellToken.transferFrom(msg.sender, address(instance), gpv2Order.sellAmount + gpv2Order.feeAmount);

        OnchainSignature memory signature =
            OnchainSignature({scheme: ICoWSwapOnchainOrders.OnchainSigningScheme.Eip1271, data: hex""});

        emit OrderPlacement(address(instance), gpv2Order, signature, abi.encode(curvedOrder));

        orderUid = new bytes(GPv2Order.UID_LENGTH);

        orderUid.packOrderUidParams(gpv2OrderHash, address(instance), gpv2Order.validTo);

        return (orderUid, address(instance));
    }

    /**
     * @notice generateSignature is a helper method used by solver to generate a signature to attach to GPv2Trade
     * @param gpv2Order GPv2Order.Data created by solver
     * @param curvedOrder CurvedOrder.Data created by LP / Curved order submitter
     * @param curvedOrderSignature signature of signed curvedOrder
     */
    function generateSignature(
        address owner,
        GPv2Order.Data calldata gpv2Order,
        CurvedOrder.Data calldata curvedOrder,
        bytes32 curvedOrderSignature
    ) external pure returns (bytes memory signature) {
        bytes memory encodedOrder = abi.encode(gpv2Order, curvedOrder, curvedOrderSignature);
        signature = abi.encodePacked(owner, encodedOrder);
        return signature;
    }
}
