// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import "./interfaces/ERC1271.sol";
import "./libraries/CurvedOrder.sol";
import "./libraries/GPv2Order.sol";

contract Verifier is EIP1271Verifier {
    function isValidSignature(bytes32 _hash, bytes memory _signature) external view returns (bytes4 magicValue) {
        _hash;
        _signature;
        return 0x1626ba7e;
    }

    /**
     * @notice generateSignature is a helper method used by solver to generate a signature to attach to GPv2Trade
     * @param gpv2Order GPv2Order.Data created by solver
     * @param curvedOrder CurvedOrder.Data created by LP / Curved order submitter
     * @param curvedOrderSignature signature of signed curvedOrder
     */
    function generateSignature(
        GPv2Order.Data calldata gpv2Order,
        CurvedOrder.Data calldata curvedOrder,
        bytes32 curvedOrderSignature
    ) external view returns (bytes memory signature) {
        bytes memory encodedCurvedOrder = abi.encode(gpv2Order, curvedOrder, curvedOrderSignature);
        signature = abi.encodePacked(address(this), encodedCurvedOrder);
    }
}
