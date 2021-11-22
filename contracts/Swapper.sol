//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Swapper {
    address private parent;

    IUniswapV2Router02[] public routers;
    mapping(address => address[]) public routerPaths;

    constructor(address _parentAddress, address[] memory _routerAddresses, address[][] memory _defaultPaths) {
        require(_routerAddresses.length == _defaultPaths.length, "Swapper: Every router must have a path");
        parent = _parentAddress;
        for (uint256 i = 0; i < _routerAddresses.length; i++) {
            addRouter(_routerAddresses[i], _defaultPaths[i]);
        }
    }

    modifier onlyParent {
        require(msg.sender == parent, "Swapper: Only parent can call this function");
        _;
    }

    function addRouter(address routerAddress, address[] memory defaultPath) public onlyParent {
        routers.push(IUniswapV2Router02(routerAddress));
        routerPaths[routerAddress] = defaultPath;
    }

    function deleteRouter(address routerAddress) external onlyParent {
        for (uint256 i = 0; i < routers.length; i++) {
            if (routers[i] == IUniswapV2Router02(routerAddress)) {
                for (uint256 j = i; j < routers.length - 1; j++) {
                    routers[i] = routers[j + 1];
                }
                routers.pop();
            }
        }
    }

    function updatePath(address routerAddress, address[] memory newPath) external onlyParent {
        routerPaths[routerAddress] = newPath;
    }

    function findOptimalRouter(uint256 amountIn) public view returns(IUniswapV2Router02, uint256, address[] memory) {
        IUniswapV2Router02 bestRouter;
        uint256 bestAmountOut;
        for (uint256 i = 0; i < routers.length; i++) {
            if (i == 0) {
                bestRouter = routers[i];
                uint256[] memory amounts = bestRouter.getAmountsOut(amountIn, routerPaths[address(routers[i])]);
                bestAmountOut = amounts[amounts.length - 1];
            } else {
                uint256[] memory amountOut = routers[i].getAmountsOut(amountIn, routerPaths[address(routers[i])]);
                uint256 possibleAmount = amountOut[amountOut.length - 1];
                if (possibleAmount > bestAmountOut) {
                    bestRouter = routers[i];
                    bestAmountOut = possibleAmount;
                }
            }
        }
        return (bestRouter, bestAmountOut, routerPaths[address(bestRouter)]);
    }

    function swap(
        uint256 _amountIn,
        uint256 _amountOutMin
    ) external onlyParent returns(uint256) {
        (IUniswapV2Router02 router, uint256 amountOut, address[] memory path) = findOptimalRouter(_amountIn);
        
        IERC20(path[0]).transferFrom(msg.sender, address(this), _amountIn);
        IERC20(path[0]).approve(address(router), _amountIn);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _amountIn, 
            _amountOutMin, 
            path, 
            parent, // send funds directly to parent; parent must calculate amountOut itself
            block.timestamp
        );

        return amountOut;
    }
}
