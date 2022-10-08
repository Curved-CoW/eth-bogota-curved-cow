// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity >=0.8.0;

import "./interfaces/ERC1271.sol";
import "./libraries/CurvedOrder.sol";
import "./libraries/GPv2Order.sol";
import "./interfaces/IERC20.sol";
import {GPv2EIP1271} from "./interfaces/ERC1271.sol";
import "./interfaces/ICoWSwapSettlement.sol";

contract CurvedOrderInstance is EIP1271Verifier {
    ICoWSwapSettlement public immutable settlement;

    address public immutable owner;
    IERC20 public immutable sellToken;
    CurvedOrder.Data public curvedOrder;

    bytes32 public _curvedOrderHash;

    constructor(address owner_, IERC20 _sellToken, ICoWSwapSettlement _settlement)  {
        owner = owner_;
        sellToken = _sellToken;
        settlement = _settlement;
        _sellToken.approve(_settlement.vaultRelayer(), type(uint256).max);
    }

    /**
     * @notice isValidSignature returns whether the provider signature and hash are valid. This method is called by GPv2 settlement contract when validating an order for execution
     * @param _hash bytes32 hash of the GPv2Order.Data struct
     * @param _payload encoded payload with metadata including `GPv2Order`, `CurvedOrder`, and `signature`. This is usually referred to as a signature in the EIP, but we're calling it payload here to differentiate between cryptographic signatures which have different meaning. This payload is encoded as follows abi.encoded(GPv2Order,CurvedOrder,bytes32). The bytes32 represents the signature of a signed curved order to verify the order was infact submitted by the LP.
     */
    function isValidSignature(bytes32 _hash, bytes calldata _payload) external view returns (bytes4 magicValue) {
        _hash;
        _payload;
        return GPv2EIP1271.MAGICVALUE;
    }

    function decode(bytes calldata _payload)
        public
        pure
        returns (GPv2Order.Data memory _gpv2Order, CurvedOrder.Data memory _curvedOrder, bytes memory _curvedOrderSignature)
    {
        (_gpv2Order, _curvedOrder, _curvedOrderSignature) =
            abi.decode(_payload, (GPv2Order.Data, CurvedOrder.Data, bytes));
    }

    /**
     * @notice generateSignature is a helper method used by solver to generate a signature to attach to GPv2Trade
     * @param _gpv2Order GPv2Order.Data created by solver
     * @param _curvedOrder CurvedOrder.Data created by LP / Curved order submitter / owner
     * @param _curvedOrderSignature signature of signed curvedOrder
     */
    function generateSignature(
        GPv2Order.Data calldata _gpv2Order,
        CurvedOrder.Data calldata _curvedOrder,
        bytes calldata _curvedOrderSignature
    ) external view returns (bytes memory signature) {
        bytes memory encodedCurvedOrder = abi.encode(_gpv2Order, _curvedOrder, _curvedOrderSignature);
        signature = abi.encodePacked(address(this), encodedCurvedOrder);
    }
}
