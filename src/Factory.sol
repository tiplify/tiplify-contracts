// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin/access/Ownable.sol";
import "openzeppelin/proxy/Clones.sol";

import "./interfaces/IFactory.sol";
import "./Account.sol";

contract Factory is IFactory, Ownable {
    address public accountImplementation;
    address public feeReceiver;
    uint256 public feePercent;

    mapping(bytes32 => address) public accounts;

    event FeeReceiverChanged(address feeReceiver);
    event FeePercentChanged(uint256 feePercent);

    constructor() {
        accountImplementation = address(new Account());
    }

    function setFeeReceiver(address _feeReceiver) public onlyOwner {
        feeReceiver = _feeReceiver;
        emit FeeReceiverChanged(feeReceiver);
    }

    function setFeePercent(uint256 _feePercent) public onlyOwner {
        feePercent = _feePercent;
        emit FeePercentChanged(feePercent);
    }

    function createAccount(bytes32 name, uint256 x, uint256 y, address recoveryWallet, string memory uri) public returns (address) {
        address clone = Clones.cloneDeterministic(accountImplementation, name);
        Account(payable(clone)).initialize(x, y, recoveryWallet, uri);
        accounts[name] = clone;
        return clone;
    }
}