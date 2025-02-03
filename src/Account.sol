// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin/utils/cryptography/ECDSA.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import {WebAuthn} from "./libraries/WebAuthn.sol";
import "./interfaces/IFactory.sol";

contract Account {
    using SafeERC20 for IERC20;

    address public immutable factory;
    uint256 public x;
    uint256 public y;
    address public recoveryWallet;

    uint256 public nonce;

    string public profileUri;

    event Withdraw(address indexed token, uint256 amount);
    event RecoveryWalletChanged(address indexed recoveryWallet);
    event ProfileUriChanged(string profileUri);

    constructor() {
        factory = msg.sender;
    }

    function _authorize(bytes32 signMessage, bytes memory signature) internal view returns (bool) {
        if (msg.sender != recoveryWallet) {
            WebAuthn.WebAuthnAuth memory auth = abi.decode(signature, (WebAuthn.WebAuthnAuth));
            return WebAuthn.verify({challenge: abi.encode(signMessage), requireUV: false, webAuthnAuth: auth, x: x, y: y});
        } else {
            return true;
        }
    }
    
    function initialize(uint256 _x, uint256 _y, address _recoveryWallet, string memory _uri) public {
        x = _x;
        y = _y;
        recoveryWallet = _recoveryWallet;
        profileUri = _uri;
    }

    function withdraw(address token, uint256 amount, bytes memory signature) public {
        bytes32 signMessage = keccak256(abi.encodePacked(msg.sender, token, amount, nonce));
        require(_authorize(signMessage, signature), "Account: invalid signature");
        nonce++;

        uint256 feePercent = IFactory(factory).feePercent();
        address feeReceiver = IFactory(factory).feeReceiver();
        uint256 feeAmount = amount * feePercent / 10000;
        amount -= feeAmount;

        if (token == address(0)) {
            payable(msg.sender).transfer(amount);
            payable(feeReceiver).transfer(feeAmount);
        } else {
            IERC20(token).safeTransfer(msg.sender, amount);
            IERC20(token).safeTransfer(feeReceiver, feeAmount);
        }

        emit Withdraw(token, amount);
    }

    function setRecoveryWallet(address _recoveryWallet, bytes memory signature) public {
        bytes32 signMessage = keccak256(abi.encodePacked(_recoveryWallet, nonce));
        require(_authorize(signMessage, signature), "Account: invalid signature");
        recoveryWallet = _recoveryWallet;
        nonce++;
        emit RecoveryWalletChanged(recoveryWallet);
    }

    function setProfileUri(string memory _profileUri, bytes memory signature) public {
        bytes32 signMessage = keccak256(abi.encodePacked(_profileUri, nonce));
        require(_authorize(signMessage, signature), "Account: invalid signature");
        profileUri = _profileUri;
        nonce++;
        emit ProfileUriChanged(profileUri);
    }

    receive() external payable {}
    fallback() external payable {}
}