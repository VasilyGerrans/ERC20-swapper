//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Swapper {
    address private parent;
    IUniswapV2Router02 private router;

    constructor(address _parentAddress, address _routerAddress) {
        parent = _parentAddress;
        router = IUniswapV2Router02(_routerAddress);
    }

    function swap(
        address _tokenIn, 
        address _tokenOut,
        uint256 _amountIn,
        uint256 _amountOutMin
    ) external returns(uint256 amountOut) {
        require(msg.sender == parent, "Swapper: Only parent can call this contract!");
        IERC20(_tokenIn).transferFrom(msg.sender, address(this), _amountIn);
        IERC20(_tokenIn).approve(address(router), _amountIn);

        // use direct path
        address[] memory path;
        path = new address[](2);
        path[0] = _tokenIn;
        path[1] = _tokenOut;

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _amountIn, 
            _amountOutMin, 
            path, 
            address(this),
            block.timestamp + 10 // valid for only 10 seconds
        );

        amountOut = IERC20(_tokenOut).balanceOf(address(this));
        IERC20(_tokenOut).transfer(msg.sender, amountOut);
    }
}
