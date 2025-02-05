// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin/access/Ownable.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/token/ERC20/extensions/IERC20Permit.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {WebAuthn} from "./libraries/WebAuthn.sol";

contract Tiplify is Ownable {
    using SafeERC20 for IERC20;

    struct Account {
        bool isInitialized;
        uint256 x;
        uint256 y;
        address recoveryWallet;
        uint256 balance;
        uint256 nonce;
        string uri;
    }

    address public receivingToken;
    address public feeReceiver;
    uint256 public feePercent;

    mapping(string => Account) public accounts;

    event ReceivingTokenChanged(address receivingToken);
    event FeeReceiverChanged(address feeReceiver);
    event FeePercentChanged(uint256 feePercent);
    event AccountCreated(bytes32 indexed name, address indexed account);
    event Tip(string supporter, string to, string message, uint256 amount);

    constructor(
        address _receivingToken,
        address _feeReceiver,
        uint256 _feePercent
    ) {
        receivingToken = _receivingToken;
        feeReceiver = _feeReceiver;
        feePercent = _feePercent;
    }

    function _executeTip(
        string memory _supporter,
        string memory _to,
        string memory _message,
        uint256 _amount
    ) internal {
        IERC20(receivingToken).safeTransferFrom(
            _msgSender(),
            address(this),
            _amount
        );
        uint256 feeAmount = (_amount * feePercent) / 10000;
        IERC20(receivingToken).safeTransfer(feeReceiver, feeAmount);

        accounts[_to].balance += (_amount - feeAmount);

        emit Tip(_supporter, _to, _message, _amount);
    }

    function _executeTipByBalance(
        string memory _supporter,
        string memory _to,
        string memory _message,
        uint256 _amount
    ) internal {
        uint256 feeAmount = (_amount * feePercent) / 10000;
        IERC20(receivingToken).safeTransfer(feeReceiver, feeAmount);

        accounts[_supporter].balance -= _amount;
        accounts[_to].balance += (_amount - feeAmount);

        emit Tip(_supporter, _to, _message, _amount);
    }

    function _authorize(
        string memory _name,
        bytes32 _signMessage,
        bytes memory _signature
    ) internal view returns (bool) {
        Account memory account = accounts[_name];
        if (_msgSender() != account.recoveryWallet) {
            WebAuthn.WebAuthnAuth memory auth = abi.decode(
                _signature,
                (WebAuthn.WebAuthnAuth)
            );
            return
                WebAuthn.verify({
                    challenge: abi.encode(_signMessage),
                    requireUV: false,
                    webAuthnAuth: auth,
                    x: account.x,
                    y: account.y
                });
        } else {
            return true;
        }
    }

    function setReceivingToken(address _receivingToken) public onlyOwner {
        receivingToken = _receivingToken;
        emit ReceivingTokenChanged(receivingToken);
    }

    function setFeeReceiver(address _feeReceiver) public onlyOwner {
        feeReceiver = _feeReceiver;
        emit FeeReceiverChanged(feeReceiver);
    }

    function setFeePercent(uint256 _feePercent) public onlyOwner {
        require(_feePercent <= 10000, "Factory: fee percent too high");
        feePercent = _feePercent;
        emit FeePercentChanged(feePercent);
    }

    function createAccount(
        string memory _name,
        uint256 _x,
        uint256 _y,
        address _recoveryWallet,
        string memory _uri
    ) public {
        require(
            !accounts[_name].isInitialized,
            "Factory: account already exists"
        );
        Account memory account = Account({
            isInitialized: true,
            x: _x,
            y: _y,
            recoveryWallet: _recoveryWallet,
            balance: 0,
            nonce: 0,
            uri: _uri
        });
        accounts[_name] = account;
    }

    function permitAndTip(
        string memory _supporter,
        string memory _to,
        string memory _message,
        uint256 _amount,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public {
        IERC20Permit(receivingToken).permit(
            _msgSender(),
            address(this),
            _amount,
            _deadline,
            _v,
            _r,
            _s
        );

        _executeTip(_supporter, _to, _message, _amount);
    }

    function tip(
        string memory _supporter,
        string memory _to,
        string memory _message,
        uint256 _amount
    ) public {
        _executeTip(_supporter, _to, _message, _amount);
    }

    function tipByBalance(
        string memory _supporter,
        string memory _to,
        string memory _message,
        uint256 _amount,
        bytes memory _signature
    ) public {
        Account storage account = accounts[_supporter];
        bytes32 signMessage = keccak256(
            abi.encodePacked("TipByBalance", _to, _amount, account.nonce)
        );
        require(
            _authorize(_supporter, signMessage, _signature),
            "Factory: only owner can tip"
        );
        _executeTipByBalance(_supporter, _to, _message, _amount);
    }

    function withdraw(
        string memory _name,
        uint256 _amount,
        bytes memory _signature
    ) public {
        Account storage account = accounts[_name];
        bytes32 signMessage = keccak256(
            abi.encodePacked("Withdraw", _amount, account.nonce)
        );
        require(
            _authorize(_name, signMessage, _signature),
            "Factory: only owner can withdraw"
        );
        require(
            account.balance >= _amount,
            "Factory: insufficient balance to withdraw"
        );
        account.balance -= _amount;
        IERC20(receivingToken).safeTransfer(_msgSender(), _amount);
    }

    function setRecoveryAddress(
        string memory _name,
        address _recoveryWallet,
        bytes memory _signature
    ) public {
        Account storage account = accounts[_name];
        bytes32 signMessage = keccak256(
            abi.encodePacked("SetRecoveryAddress", _recoveryWallet, account.nonce)
        );
        require(
            _authorize(_name, signMessage, _signature),
            "Factory: only owner can set recovery address"
        );
        account.recoveryWallet = _recoveryWallet;
    }

    function setProfileUri(
        string memory _name,
        string memory _uri,
        bytes memory _signature
    ) public {
        Account storage account = accounts[_name];
        bytes32 signMessage = keccak256(
            abi.encodePacked("SetProfileUri", _uri, account.nonce)
        );
        require(
            _authorize(_name, signMessage, _signature),
            "Factory: only owner can set profile uri"
        );
        account.uri = _uri;
    }
}
