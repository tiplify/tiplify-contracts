// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin/access/Ownable.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/token/ERC20/extensions/IERC20Permit.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";

contract Tiplify is Ownable {
    using SafeERC20 for IERC20;

    struct Account {
        bool isInitialized;
        uint256 x;
        uint256 y;
        address recoveryWallet;
        uint256 earnings;
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
    event Tip(address indexed supporter, address indexed to, uint256 amount);

    constructor(
        address _receivingToken,
        address _feeReceiver,
        uint256 _feePercent
    ) {
        receivingToken = _receivingToken;
        feeReceiver = _feeReceiver;
        feePercent = _feePercent;
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
        string memory name,
        uint256 x,
        uint256 y,
        address recoveryWallet,
        string memory uri
    ) public returns (address) {
        require(
            !accounts[name].isInitialized,
            "Factory: account already exists"
        );
        Account memory account = Account({
            isInitialized: true,
            x: x,
            y: y,
            recoveryWallet: recoveryWallet,
            earnings: 0,
            uri: uri
        });
        accounts[name] = account;
    }

    function permitAndTip(
        string memory _to,
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

        uint256 feeAmount = (_amount * feePercent) / 10000;
        uint256 tipAmount = _amount - feeAmount;
        IERC20(receivingToken).safeTransferFrom(_msgSender(), address(this), _amount);

        IERC20(receivingToken).safeTransferFrom(
            _msgSender(),
            feeReceiver,
            feeAmount
        );

        

        emit Tip(_msgSender(), _to, _amount);
    }

    function tip(address _to, uint256 _amount) public {
        uint256 feeAmount = (_amount * feePercent) / 10000;
        IERC20(receivingToken).safeTransferFrom(_msgSender(), _to, _amount);
        IERC20(receivingToken).safeTransferFrom(
            _msgSender(),
            feeReceiver,
            feeAmount
        );

        emit Tip(_msgSender(), _to, _amount);
    }

    // for adapter to callback
    function callbackTip(address _supporter, address _to) public {
        uint256 amount = IERC20(receivingToken).balanceOf(address(this));
        require(amount > 0, "Tiplify: no balance");

        uint256 feeAmount = (amount * feePercent) / 10000;
        IERC20(receivingToken).safeTransfer(_to, amount);
        IERC20(receivingToken).safeTransfer(feeReceiver, feeAmount);

        emit Tip(_supporter, _to, amount);
    }
}
