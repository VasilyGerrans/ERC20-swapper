//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ISwapper.sol";
import "./ITokenLibrary.sol";

contract Swapper is ISwapper, Ownable {
    /**
        @notice The Polygon network is often undercollateralised. For cheaper swaps,
        we route our swaps through pools that have more liquidity. At the moment,
        we do this with an array of middle tokens through which a swap can be routed.
        @dev This array shouldn't store more than 256 tokens because all for-loops use uint8 indexes.
     */
    string[] public middleTokens;

    /**
        @notice Routers through which we will view prices and swap ERC20 tokens.
     */
    IUniswapV2Router02 public quickSwap;
    IUniswapV2Router02 public sushiSwap;

    /** 
        @notice Library contract of mappings from strings to addresses of ERC20 tokens on Polygon.
     */ 
    ITokenLibrary public tokenLibrary;

    constructor(address _library) {
        tokenLibrary = ITokenLibrary(_library);

        // Inlcude two most common middle tokens for QuickSwap
        middleTokens.push("WETH");
        middleTokens.push("USDC");

        quickSwap = IUniswapV2Router02(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff); 
        sushiSwap = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
    }

    function addMiddleToken(string memory _name, address _address) public onlyOwner {
        require(middleTokens.length < 255, "Swapper: Max middleTokens size exceeded");
        for (uint8 i = 0; i < middleTokens.length; i++) {
            require(sameStrings(middleTokens[i], _name) == false, "Swapper: Token already included");
        }
        if (tokenLibrary.getToken(_name) == address(0)) {
            tokenLibrary.addToken(_name, _address);
        }
        middleTokens.push(_name);
    }

    function removeMiddleToken(string memory _name) public onlyOwner {
        for (uint8 i = 0; i < middleTokens.length; i++) {
            if (sameStrings(middleTokens[i], _name)) {
                for (uint8 j = i; j < middleTokens.length - 1; j++) {
                    middleTokens[j] = middleTokens[j + 1];
                }
                middleTokens.pop();
                break;
            }
        }
    }

    /**
        @notice Finds optimal way to swap two ERC20s using our existing middleTokens and 
        routers.
        @param from is the string symbol of the input ERC20.
        @param to is the string symbol for the output ERC20.
        @param amountIn is the amount of input ERC20 supplied.
        @return middleToken is address(0) if direct swap is optimal and ERC20 of token
        through which we build the path.
     */
    function priceTo(
        string memory from,
        string memory to,
        uint256 amountIn
    ) public view override returns (
        address middleToken, 
        IUniswapV2Router02 router, 
        uint256 bestAmountOut
    ) {
        address fromToken = tokenLibrary.getToken(from);
        address toToken = tokenLibrary.getToken(to);

        address[] memory path = new address[](2);
        path[0] = fromToken;
        path[1] = toToken;
        
        // Setting SushiSwap direct default
        uint256[] memory amountsOut = sushiSwap.getAmountsOut(amountIn, path);
        bestAmountOut = amountsOut[amountsOut.length - 1];
        router = sushiSwap;

        // Checking QuickSwap direct
        amountsOut = quickSwap.getAmountsOut(amountIn, path);
        uint256 newAmountOut = amountsOut[amountsOut.length - 1]; 
        if (newAmountOut > bestAmountOut) {
            bestAmountOut = newAmountOut;
            router = quickSwap;
        }
        
        // Checking indirect
        for (uint8 i = 0; i < middleTokens.length; i++) {
            if (sameStrings(middleTokens[i], from) == false && sameStrings(middleTokens[i], to) == false) {
                path = new address[](3);
                path[0] = fromToken;
                path[1] = tokenLibrary.getToken(middleTokens[i]);
                path[2] = toToken;

                amountsOut = sushiSwap.getAmountsOut(amountIn, path);
                newAmountOut = amountsOut[amountsOut.length - 1]; 
                if (newAmountOut > bestAmountOut) {
                    bestAmountOut = newAmountOut;
                    middleToken = tokenLibrary.getToken(middleTokens[i]);
                    router = sushiSwap;
                }

                amountsOut = quickSwap.getAmountsOut(amountIn, path);
                newAmountOut = amountsOut[amountsOut.length - 1]; 
                if (newAmountOut > bestAmountOut) {
                    bestAmountOut = newAmountOut;
                    middleToken = tokenLibrary.getToken(middleTokens[i]);
                    router = quickSwap;
                }
            }
        }
    }

    /**
        @notice Finds optimal way to swap two ERC20s using our existing middleTokens and 
        routers.
        @param from is the string symbol of the input ERC20.
        @param to is the string symbol for the output ERC20.
        @param amountOut is the amount of output ERC20 desired.
        @return middleToken is address(0) if direct swap is optimal and ERC20 of token
        through which we build the path.
     */
    function priceFrom(
        string memory from,
        string memory to,
        uint256 amountOut
    ) public view override returns (
        address middleToken,
        IUniswapV2Router02 router,
        uint256 bestAmountIn
    ) {
        address fromToken = tokenLibrary.getToken(from);
        address toToken = tokenLibrary.getToken(to);

        address[] memory path = new address[](2);
        path[0] = fromToken;
        path[1] = toToken;

        // Making the default unreasonably large, so we can only decrease it
        bestAmountIn = type(uint256).max;      

        // Checking SushiSwap direct
        try sushiSwap.getAmountsIn(amountOut, path) returns(uint256[] memory amountsIn) {
            bestAmountIn = amountsIn[0];
            router = sushiSwap;
        } catch {}

        // Checking QuickSwap direct
        try quickSwap.getAmountsIn(amountOut, path) returns(uint256[] memory amountsIn) {
            uint256 newAmountOut = amountsIn[0]; 
            if (newAmountOut < bestAmountIn) {
                bestAmountIn = newAmountOut;
                router = quickSwap;
            }
        } catch {}

        // Checking indirect
        for (uint8 i = 0; i < middleTokens.length; i++) {
            if (sameStrings(middleTokens[i], from) == false && sameStrings(middleTokens[i], to) == false) {
                path = new address[](3);
                path[0] = fromToken;
                path[1] = tokenLibrary.getToken(middleTokens[i]);
                path[2] = toToken;

                try sushiSwap.getAmountsIn(amountOut, path) returns(uint256[] memory amountsIn) {
                    uint256 newAmountOut = amountsIn[0]; 
                    if (newAmountOut < bestAmountIn) {
                        bestAmountIn = newAmountOut;
                        middleToken = tokenLibrary.getToken(middleTokens[i]);
                        router = sushiSwap;
                    }
                } catch {}

                try quickSwap.getAmountsIn(amountOut, path) returns(uint256[] memory amountsIn) {
                    uint256 newAmountOut = amountsIn[0]; 
                    if (newAmountOut < bestAmountIn) {
                        bestAmountIn = newAmountOut;
                        middleToken = tokenLibrary.getToken(middleTokens[i]);
                        router = quickSwap;
                    }
                } catch {}
            }
        } 

        require(bestAmountIn < type(uint256).max, "Swapper: no option with sufficient liquidity found");
    }

    /**
        @param from must be approved before calling this function.
     */
    function swapTo(
        string memory from,
        string memory to,
        uint256 amountIn
    ) public override returns(uint256) {
        address fromToken = tokenLibrary.getToken(from);
        address toToken = tokenLibrary.getToken(to);

        (address middleToken, IUniswapV2Router02 router, uint256 bestAmountOut) = priceTo(from, to, amountIn);
        
        IERC20 inputToken = IERC20(fromToken);
        inputToken.transferFrom(msg.sender, address(this), amountIn);

        if (inputToken.allowance(address(this), address(router)) < amountIn) {
            inputToken.approve(address(router), type(uint256).max);
        }
       
        // Direct swap
        if (middleToken == address(0)) {
            address[] memory path = new address[](2);
            path[0] = fromToken;
            path[1] = toToken;
            router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                amountIn, 
                bestAmountOut, 
                path,
                msg.sender,
                block.timestamp
            );
        }
        // Indirect swap
        else {
            address[] memory path = new address[](3);
            path[0] = fromToken;
            path[1] = middleToken;
            path[2] = toToken;
            router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                amountIn, 
                bestAmountOut, 
                path,
                msg.sender,
                block.timestamp
            );
        }

        return bestAmountOut;
    }

    /**
        @param from must be approved before calling this function.
     */
    function swapFrom(
        string memory from,
        string memory to, 
        uint256 amountOut
    ) external override returns (uint256) {
        address fromToken = tokenLibrary.getToken(from);
        address toToken = tokenLibrary.getToken(to);

        (address middleToken, IUniswapV2Router02 router, uint256 bestAmountIn) = priceFrom(from, to, amountOut);

        IERC20 inputToken = IERC20(fromToken);
        inputToken.transferFrom(msg.sender, address(this), bestAmountIn); 

        if (inputToken.allowance(address(this), address(router)) < bestAmountIn) {
            inputToken.approve(address(router), type(uint256).max);
        } 

        // Direct swap
        if (middleToken == address(0)) {
            address[] memory path = new address[](2);
            path[0] = fromToken;
            path[1] = toToken;
            router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                bestAmountIn, 
                amountOut, 
                path,
                msg.sender,
                block.timestamp
            );
        }
        // Indirect swap
        else {
            address[] memory path = new address[](3);
            path[0] = fromToken;
            path[1] = middleToken;
            path[2] = toToken;
            router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                bestAmountIn, 
                amountOut, 
                path,
                msg.sender,
                block.timestamp
            );
        } 

        return bestAmountIn;
    }

    /**
        @dev Utility function to perform equality check on storage string and memory string.
        Read more about this design choice here:
        https://ethereum.stackexchange.com/questions/4559/operator-not-compatible-with-type-string-storage-ref-and-literal-string
     */
    function sameStrings(string storage stringA, string memory stringB) internal pure returns(bool) {
        return keccak256(abi.encode(stringA)) == keccak256(abi.encode(stringB));
    }
}
