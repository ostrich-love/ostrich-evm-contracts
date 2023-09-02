// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../swap/ISwapPair.sol";
import "../swap/libraries/SwapLibrary.sol";
import "../swap/IWETH.sol";

interface IVault {
    function batchDeposit(address token, address[] memory accounts, uint256[] memory weights) external payable;
}

contract Orich is ERC20Upgradeable, OwnableUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 public constant feeDenominator = 10000;
    struct FeeConfig {
        uint256 burnRate;
        uint256 earn1Rate;
        uint256 earn2Rate;
        uint256 earn3Rate;
        uint256 earn4Rate;
        uint256 earn5Rate;
        uint256 tdRate;
        uint256 liquidityRate;
        uint256 fundRate;
        uint256 devRate;
        uint256 totalRate;
    }

    struct Recipients {
        address burn;
        address earn1;
        address earn2;
        address earn3;
        address earn4;
        address earn5;
        address td;
        address lp;
        address fund;
        address dev;
    }

    address public WETH;
    address public wethPair;
    FeeConfig public feeConfig;
    Recipients public recipients;
    EnumerableSet.AddressSet private _feeExceptions;
    address public depositVault;

    fallback() external payable {}

    receive() external payable {}

    function initialize(
        string memory name_,
        string memory symbol_,
        address weth_,
        address depositVault_
    ) public initializer {
        __Ownable_init();
        __ERC20_init(name_, symbol_);
        WETH = weth_;
        depositVault = depositVault_;
    }

    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }

    function queryFeeExceptions() public view virtual returns (address[] memory items) {
        items = new address[](_feeExceptions.length());
        for (uint256 i; i < items.length; i++) {
            items[i] = _feeExceptions.at(i);
        }
    }

    function addFeeExceptions(address[] memory items) public onlyOwner {
        for (uint256 i; i < items.length; i++) {
            _feeExceptions.add(items[i]);
        }
    }

    function removeFeeExceptions(address[] memory items) public onlyOwner {
        for (uint256 i; i < items.length; i++) {
            _feeExceptions.remove(items[i]);
        }
    }

    function setRecipients(Recipients memory v) public onlyOwner {
        recipients = v;
    }

    function setFeeConfig(FeeConfig memory v) public onlyOwner {
        feeConfig = v;
    }

    function setDepositVault(address v) public onlyOwner {
        depositVault = v;
    }

    function setWethPair(address v) public onlyOwner {
        wethPair = v;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        transferSupportingFee(msg.sender, from, to, amount);
        return true;
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        transferSupportingFee(msg.sender, msg.sender, to, amount);
        return true;
    }

    function transferSupportingFee(address sender, address from, address to, uint256 amount) internal virtual {
        _transfer(from, to, amount - _takeFee(sender, from, to, amount));
    }

    function _takeFee(address sender, address from, address to, uint256 amount) private returns (uint256 fee) {
        bool isFromContract = _isContract(from);
        bool isToContract = _isContract(to);
        if (_feeExceptions.contains(sender) || _feeExceptions.contains(from) || _feeExceptions.contains(to)) return 0;
        if ((isFromContract && isToContract) || (!isFromContract && !isToContract)) return 0;
        FeeConfig memory config = feeConfig;
        if (config.totalRate == 0 || config.totalRate >= feeDenominator) return 0;
        fee = (amount * config.totalRate) / feeDenominator;
        _transfer(from, address(this), fee);
        _distributeFee(config);
    }

    function _distributeToDepositVault(FeeConfig memory config, uint256 fee) private {
        address[] memory accounts = new address[](5);
        accounts[0] = recipients.earn1;
        accounts[1] = recipients.earn2;
        accounts[2] = recipients.earn3;
        accounts[3] = recipients.earn4;
        accounts[4] = recipients.earn5;
        uint256[] memory weights = new uint256[](5);
        weights[0] = config.earn1Rate;
        weights[1] = config.earn2Rate;
        weights[2] = config.earn3Rate;
        weights[3] = config.earn4Rate;
        weights[4] = config.earn5Rate;

        _transfer(
            address(this),
            depositVault,
            (fee * (config.earn1Rate + config.earn2Rate + config.earn3Rate + config.earn4Rate + config.earn5Rate)) /
                config.totalRate
        );

        IVault(depositVault).batchDeposit(address(this), accounts, weights);
    }

    function _distributeFee(FeeConfig memory config) public {
        uint256 fee = balanceOf(address(this));
        _transfer(address(this), recipients.burn, (fee * config.burnRate) / config.totalRate);
        _distributeToDepositVault(config, fee);
        uint256 tdFee = (fee * config.tdRate) / config.totalRate;
        uint256 liquidityFee = (fee * config.liquidityRate) / config.totalRate;
        uint256 fundFee = (fee * config.fundRate) / config.totalRate;
        uint256 devFee = (fee * config.devRate) / config.totalRate;
        uint256 amountIn = tdFee + liquidityFee / 2 + fundFee + devFee;
        _swapToWETH(amountIn);
        uint256 wethBalance = IWETH(WETH).balanceOf(address(this));

        uint feeAmount = tdFee + fundFee + devFee;
        uint256 ethAmount = (feeAmount * wethBalance) / amountIn;
        IWETH(WETH).withdraw(ethAmount);
        uint256 tdFeeAmount = (ethAmount * tdFee) / feeAmount;
        uint256 fundFeeAmount = (ethAmount * fundFee) / feeAmount;
        uint256 devFeeAmount = ethAmount - tdFeeAmount - fundFeeAmount;
        _sendETH(recipients.td, tdFeeAmount);
        _sendETH(recipients.fund, fundFeeAmount);
        _sendETH(recipients.dev, devFeeAmount);
        _addLiquidity(address(this), WETH, balanceOf(address(this)), wethBalance - ethAmount, recipients.lp);
    }

    function _swapToWETH(uint256 amountIn) private {
        _transfer(address(this), wethPair, amountIn);
        uint256 amountOut = _getAmountOut(wethPair, address(this), WETH, amountIn);
        (uint256 amount0Out, uint256 amount1Out) = address(this) < WETH
            ? (uint256(0), amountOut)
            : (amountOut, uint256(0));
        ISwapPair(wethPair).swap(amount0Out, amount1Out, address(this), new bytes(0));
    }

    function _getAmountOut(
        address pairAddress,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) private view returns (uint256 amountOut) {
        (uint256 reserveIn, uint256 reserveOut) = _getReserves(pairAddress, tokenIn, tokenOut);
        return SwapLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function _sendETH(address to, uint256 amount) private {
        (bool sent, ) = payable(to).call{ value: amount }("");
        require(sent, "Orich,SEND_ETH_FAILED");
    }

    function _isContract(address account) private view returns (bool) {
        return account.code.length > 0;
    }

    function _getReserves(
        address pair,
        address token0,
        address token1
    ) private view returns (uint256 reserve0, uint256 reserve1) {
        (uint112 _reserve0, uint112 _reserve1, ) = ISwapPair(pair).getReserves();
        if (token0 == address(0)) token0 = WETH;
        if (token1 == address(0)) token1 = WETH;
        (reserve0, reserve1) = token0 < token1
            ? (uint256(_reserve0), uint256(_reserve1))
            : (uint256(_reserve1), uint256(_reserve0));
    }

    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired
    ) internal virtual returns (uint256 amountA, uint256 amountB) {
        (uint256 reserveA, uint256 reserveB) = _getReserves(wethPair, tokenA, tokenB);
        uint256 amountBOptimal = SwapLibrary.quote(amountADesired, reserveA, reserveB);
        if (amountBOptimal <= amountBDesired) {
            (amountA, amountB) = (amountADesired, amountBOptimal);
        } else {
            uint256 amountAOptimal = SwapLibrary.quote(amountBDesired, reserveB, reserveA);
            assert(amountAOptimal <= amountADesired);
            (amountA, amountB) = (amountAOptimal, amountBDesired);
        }
    }

    function _addLiquidity(
        address token,
        address weth,
        uint256 tokenAmount,
        uint256 wethAmount,
        address to
    ) private returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        (amountA, amountB) = _addLiquidity(token, weth, tokenAmount, wethAmount);
        _transfer(address(this), wethPair, tokenAmount);
        _safeTransferFrom(weth, address(this), wethPair, wethAmount);
        liquidity = ISwapPair(wethPair).mint(to);
    }

    function _safeTransferFrom(address token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Orich: TRANSFER_FROM_FAILED");
    }
}
