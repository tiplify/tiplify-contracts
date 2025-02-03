// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IFactory {
    function createAccount(bytes32 name, uint256 x, uint256 y, address recoveryWallet, string memory uri) external returns (address);
    function feeReceiver() external view returns (address);
    function feePercent() external view returns (uint256);
}