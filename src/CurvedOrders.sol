// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity >=0.8.0;

import "./interfaces/ERC1271.sol";
import "./libraries/CurvedOrder.sol";
import "./libraries/GPv2Order.sol";
import "./interfaces/IERC20.sol";
import { GPv2EIP1271 } from "./interfaces/ERC1271.sol";
import "./interfaces/ICowSwapOnChainOrders.sol";
import "./interfaces/ICoWSwapSettlement.sol";

contract CurvedOrders is EIP1271Verifier {
  ICoWSwapSettlement public immutable settlement;
  bytes32 public immutable domainSeparator;

  constructor(ICoWSwapSettlement settlement_) {
    settlement = settlement_;
    domainSeparator = settlement_.domainSeparator();
  }

  /**
   * @notice isValidSignature returns whether the provider signature and hash are valid. This method is called by GPv2 settlement contract when validating an order for execution
   * @param _hash bytes32 hash of the GPv2Order.Data struct
   * @param _payload encoded payload with metadata including `GPv2Order`, `CurvedOrder`, and `signature`. This is usually referred to as a signature in the EIP, but we're calling it payload here to differentiate between cryptographic signatures which have different meaning. This payload is encoded as follows abi.encoded(GPv2Order,CurvedOrder,bytes32). The bytes32 represents the signature of a signed curved order to verify the order was infact submitted by the LP.
   */
  function isValidSignature(bytes32 _hash, bytes calldata _payload)
    external
    view
    returns (bytes4 magicValue)
  {
    _hash;
    _payload;
    return GPv2EIP1271.MAGICVALUE;
  }

  function decode(bytes calldata _payload)
    internal
    pure
    returns (
      GPv2Order.Data memory gpv2Order,
      CurvedOrder.Data memory curvedOrder,
      bytes32 curvedOrderSignature
    )
  {
    (gpv2Order, curvedOrder, curvedOrderSignature) = abi.decode(
      _payload[20:],
      (GPv2Order.Data, CurvedOrder.Data, bytes32)
    );
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
    bytes memory encodedCurvedOrder = abi.encode(
      gpv2Order,
      curvedOrder,
      curvedOrderSignature
    );
    signature = abi.encodePacked(address(this), encodedCurvedOrder);
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
    bytes memory encodedOrder = abi.encode(
      gpv2Order,
      curvedOrder,
      curvedOrderSignature
    );
    signature = abi.encodePacked(owner, encodedOrder);
  }
}
