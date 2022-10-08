// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ICoWSwapSettlement} from "../../interfaces/ICoWSwapSettlement.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {console} from "../utils/Console.sol";

contract MockERC20 is ERC20 {

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) ERC20(_name, _symbol, _decimals) {
      _mint(msg.sender, 1_000_000 * 10 ** _decimals);
    }
}