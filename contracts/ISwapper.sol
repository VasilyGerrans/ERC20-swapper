//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

interface ISwapper {
    function priceTo(
        string memory from, 
        string memory to, 
        uint256 amountIn
    ) external returns (
        address middleToken, 
        IUniswapV2Router02 router, 
        uint256 bestAmountOut
    );
    function priceFrom(
        string memory from,
        string memory to,
        uint256 amountOut
    ) external returns (
        address middleToken,
        IUniswapV2Router02 router,
        uint256 bestAmountIn
    );
    function swapTo(
        string memory from, 
        string memory to, 
        uint256 amountIn
    ) external returns (uint256 amountOut);
    function swapFrom(
        string memory from,
        string memory to, 
        uint256 amountOut
    ) external returns (uint256 amountIn);
}
