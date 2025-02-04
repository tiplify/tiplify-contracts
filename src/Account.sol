// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin/utils/cryptography/ECDSA.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin/proxy/utils/Initializable.sol";

import {WebAuthn} from "./libraries/WebAuthn.sol";

contract Account is Initializable {
    using SafeERC20 for IERC20;

    uint256 public x;
    uint256 public y;
    address public recoveryWallet;

    uint256 public nonce;

    string public profileUri;

    event Withdraw(address indexed token, uint256 amount);
    event RecoveryWalletChanged(address indexed recoveryWallet);
    event ProfileUriChanged(string profileUri);

    constructor() {
    }

    function _authorize(bytes32 signMessage, bytes memory signature) internal view returns (bool) {
        if (msg.sender != recoveryWallet) {
            WebAuthn.WebAuthnAuth memory auth = abi.decode(signature, (WebAuthn.WebAuthnAuth));
            return WebAuthn.verify({challenge: abi.encode(signMessage), requireUV: false, webAuthnAuth: auth, x: x, y: y});
        } else {
            return true;
        }
    }
    
    function initialize(uint256 _x, uint256 _y, address _recoveryWallet, string memory _uri) public initializer {
        x = _x;
        y = _y;
        recoveryWallet = _recoveryWallet;
        profileUri = _uri;
    }

    function withdraw(address token, address to, uint256 amount, bytes memory signature) public {
        bytes32 signMessage = keccak256(abi.encodePacked(msg.sender, token, amount, nonce));
        require(_authorize(signMessage, signature), "Account: invalid signature");
        nonce++;

        if (token == address(0)) {
            payable(to).transfer(amount);
        } else {
            IERC20(token).safeTransfer(to, amount);
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