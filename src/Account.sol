// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Account {
    address public immutable factory;

    constructor() {
    }
    
    function initialize() public {
    }

    function withdraw(uint256 amount) public {
        payable(msg.sender).transfer(amount);
    }

    receive() external payable {}
    fallback() external payable {}
}