// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface ICoWSwapSettlement {
    function domainSeparator() external view returns (bytes32);
    function vaultRelayer() external view returns (address);
}
