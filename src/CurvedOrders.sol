// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity >=0.8.0;

import "./interfaces/ERC1271.sol";
import "./libraries/CurvedOrder.sol";
import "./libraries/GPv2Order.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ICowSwapOnChainOrders.sol";
import "./interfaces/ICoWSwapSettlement.sol";

contract CurvedOrders  {
  ICoWSwapSettlement public immutable settlement;
  bytes32 public immutable domainSeparator;

  constructor(ICoWSwapSettlement settlement_) {
    settlement = settlement_;
    domainSeparator = settlement_.domainSeparator();
  }

  function placeOrder() external {
    
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
