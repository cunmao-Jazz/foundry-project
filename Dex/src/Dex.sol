// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";

interface IDex {
    function sellETH(address buyToken, uint256 minBuyAmount) external payable;
    function buyETH(address sellToken, uint256 sellAmount, uint256 minBuyAmount) external;
}

contract MyDex is IDex {
    // Uniswap V2 Factory合约地址
    address public immutable factory;
    // WETH合约地址
    address public immutable WETH;
    
    // 记录已创建的交易对
    mapping(address => address) public tokenToPair;
    
    event PairCreated(address indexed token, address pair);
    event LiquidityAdded(address indexed token, uint256 ethAmount, uint256 tokenAmount);

    constructor(address _factory, address _WETH) {
        factory = _factory;
        WETH = _WETH;
    }

    /**
     * @dev 创建新的交易对
     * @param token 要与ETH配对的代币地址
     */
    function createPair(address token) external returns (address pair) {
        require(token != address(0), "Invalid token address");
        require(tokenToPair[token] == address(0), "Pair already exists");
        
        // 使用factory创建新的交易对
        pair = IUniswapV2Factory(factory).createPair(WETH, token);
        tokenToPair[token] = pair;
        
        emit PairCreated(token, pair);
        return pair;
    }

    /**
     * @dev 向交易对添加流动性
     * @param token 代币地址
     * @param tokenAmount 添加的代币数量
     * @param minTokenAmount 最小代币数量（滑点保护）
     * @param minEthAmount 最小ETH数量（滑点保护）
     */
    function addLiquidity(
        address token,
        uint256 tokenAmount,
        uint256 minTokenAmount,
        uint256 minEthAmount
    ) external payable {
        require(msg.value > 0, "Insufficient ETH");
        require(tokenAmount > 0, "Insufficient token amount");
        
        address pair = tokenToPair[token];
        require(pair != address(0), "Pair does not exist");
        
        // 将ETH转换为WETH
        IWETH(WETH).deposit{value: msg.value}();
        
        // 将用户的代币转入合约
        IERC20(token).transferFrom(msg.sender, address(this), tokenAmount);
        
        // 授权交易对合约使用token
        IERC20(token).approve(pair, tokenAmount);
        IERC20(WETH).approve(pair, msg.value);
        
        // 获取当前储备量
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(pair).getReserves();
        
        // 确保添加的流动性比例合适
        if (reserve0 > 0 && reserve1 > 0) {
            require(reserve0 * tokenAmount / reserve1 >= minEthAmount, "Insufficient ETH amount");
            require(reserve1 * msg.value / reserve0 >= minTokenAmount, "Insufficient token amount");
        }
        
        // 添加流动性
        IUniswapV2Pair(pair).mint(msg.sender);
        
        emit LiquidityAdded(token, msg.value, tokenAmount);
    }

    /**
     * @dev 获取交易对地址
     */
    function getPair(address token) public view returns (address) {
        return tokenToPair[token];
    }

    /**
     * @dev 卖出ETH，兑换成 buyToken
     */
    function sellETH(address buyToken, uint256 minBuyAmount) external payable override {
        require(msg.value > 0, "Insufficient ETH amount");
        
        address pair = tokenToPair[buyToken];
        require(pair != address(0), "Pair does not exist");
        
        // 将ETH转换为WETH
        IWETH(WETH).deposit{value: msg.value}();

        // 获取当前交易对中的储备量
        (uint reserve0, uint reserve1,) = IUniswapV2Pair(pair).getReserves();
        
        // 确保储备量的顺序与token地址的顺序一致
        (uint reserveIn, uint reserveOut) = WETH < buyToken 
            ? (reserve0, reserve1) 
            : (reserve1, reserve0);

        // 计算能获得的代币数量
        uint amountOut = getAmountOut(msg.value, reserveIn, reserveOut);
        require(amountOut >= minBuyAmount, "Insufficient output amount");

        // 将WETH发送到交易对合约
        IERC20(WETH).transfer(pair, msg.value);
        
        // 执行swap
        if (WETH < buyToken) {
            IUniswapV2Pair(pair).swap(0, amountOut, msg.sender, new bytes(0));
        } else {
            IUniswapV2Pair(pair).swap(amountOut, 0, msg.sender, new bytes(0));
        }
    }

    /**
     * @dev 买入ETH，用 sellToken 兑换
     */
    function buyETH(address sellToken, uint256 sellAmount, uint256 minBuyAmount) external override {
        require(sellAmount > 0, "Insufficient sell amount");

        address pair = tokenToPair[sellToken];
        require(pair != address(0), "Pair does not exist");

        // 将用户的代币转入合约
        IERC20(sellToken).transferFrom(msg.sender, address(this), sellAmount);
        
        // 获取当前交易对中的储备量
        (uint reserve0, uint reserve1,) = IUniswapV2Pair(pair).getReserves();
        
        // 确保储备量的顺序与token地址的顺序一致
        (uint reserveIn, uint reserveOut) = sellToken < WETH 
            ? (reserve0, reserve1) 
            : (reserve1, reserve0);

        // 计算能获得的ETH数量
        uint amountOut = getAmountOut(sellAmount, reserveIn, reserveOut);
        require(amountOut >= minBuyAmount, "Insufficient output amount");

        // 将代币发送到交易对合约
        IERC20(sellToken).transfer(pair, sellAmount);
        
        // 执行swap
        if (sellToken < WETH) {
            IUniswapV2Pair(pair).swap(0, amountOut, address(this), new bytes(0));
        } else {
            IUniswapV2Pair(pair).swap(amountOut, 0, address(this), new bytes(0));
        }

        // 将WETH转换回ETH并发送给用户
        IWETH(WETH).withdraw(amountOut);
        payable(msg.sender).transfer(amountOut);
    }

    // 计算swap后能获得的代币数量
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, "Insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");
        
        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    // 接收ETH的回调函数
    receive() external payable {}
}