//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ISwapper.sol";

contract Swapper is ISwapper {
    address private owner;

    struct SwapPath {
        string ID;
        address router;
        address[] path;
        bool active;
    }

    mapping(address => mapping(address => string[])) public SwapPathIDs;
    mapping(string => SwapPath) public SwapPathVariants;
    
    constructor(
        string[] memory ids, 
        address[][] memory paths, 
        address[] memory routers
    ) {
        require(routers.length == paths.length, "Swapper: Every path must have a router");
        require(ids.length == paths.length, "Swapper: Every path must have an ID");
        owner = msg.sender;
        for (uint256 i = 0; i < paths.length; i++) {
            addPath(ids[i], paths[i], routers[i]);
        }
    }

    modifier onlyOwner {
        require(msg.sender == owner, "Swapper: Only owner can call this function");
        _;
    }

    function addPath(string memory id, address[] memory path, address routerAddress) public override onlyOwner {
        SwapPathVariants[id] = SwapPath(
            id, 
            routerAddress, 
            path, 
            true
        );
        SwapPathIDs[path[0]][path[path.length - 1]].push(id);
    }

    function deletePath(address from, address to, string memory id) public override onlyOwner {
        for (uint256 i = 0; i < SwapPathIDs[from][to].length; i++) {
            if (keccak256(abi.encode(SwapPathIDs[from][to][i])) == keccak256(abi.encode(id))) {
                for (uint256 j = i; j < SwapPathIDs[from][to].length - 1; j++) {
                    SwapPathIDs[from][to][j] = SwapPathIDs[from][to][j + 1];
                }
                SwapPathIDs[from][to].pop();
                SwapPathVariants[id].active = false;
                break;
            }
        }
    }

    function updatePath(string memory id, address[] memory newPath) external override onlyOwner {
        SwapPath storage oldSwapPath = SwapPathVariants[id];
        address oldFrom = oldSwapPath.path[0];
        address oldTo = oldSwapPath.path[oldSwapPath.path.length - 1];
        address newFrom = newPath[0];
        address newTo = newPath[newPath.length - 1];
        if (oldFrom != newFrom || oldTo != newTo) {
            deletePath(oldFrom, oldTo, id);
            addPath(id, newPath, oldSwapPath.router);
        } else {
            SwapPathVariants[id] = SwapPath(
                id, oldSwapPath.router, newPath, oldSwapPath.active
            );
        }
    }

    function getOptimalPathTo(
        address from, 
        address to, 
        uint256 amountIn
    ) public view override returns (string memory bestID, uint256 bestAmountOut) {
        for (uint256 i = 0; i < SwapPathIDs[from][to].length; i++) {
            IUniswapV2Router02 router = IUniswapV2Router02(SwapPathVariants[SwapPathIDs[from][to][i]].router);

            (uint256 reserveIn, uint256 reserveOut) = getReserves(router.factory(), from, to);
            uint256 possibleAmount = router.getAmountOut(amountIn, reserveIn, reserveOut);

            if (possibleAmount > bestAmountOut) {
                bestAmountOut = possibleAmount;
                bestID = SwapPathIDs[from][to][i];
            }
        }
    }

    function getOptimalPathFrom(
        address from,
        address to,
        uint256 amountOut
    ) public view override returns (string memory bestID, uint256 bestAmountIn) {
        for (uint256 i = 0; i < SwapPathIDs[from][to].length; i++) {
            IUniswapV2Router02 router = IUniswapV2Router02(SwapPathVariants[SwapPathIDs[from][to][i]].router);

            (uint256 reserveIn, uint256 reserveOut) = getReserves(router.factory(), from, to);
            uint possibleAmount = router.getAmountIn(amountOut, reserveIn, reserveOut);  

            if (possibleAmount < bestAmountIn) {
                bestAmountIn = possibleAmount;
                bestID = SwapPathIDs[from][to][i];
            }
        } 
    }

    // formerly "SwapByIndex"
    function swapToDirect(
        address routerAddress, 
        address[] memory path, 
        uint256 amountIn
    ) external override returns (uint256 amountOut) {
        require(path.length >= 2, "Swapper: path must have at least 2 tokens");
        IERC20 fromToken = IERC20(path[0]);
        fromToken.transferFrom(msg.sender, address(this), amountIn);
        
        IUniswapV2Router02 router = IUniswapV2Router02(routerAddress);
        (uint256 reserveIn, uint256 reserveOut) = getReserves(router.factory(), path[0], path[path.length - 1]);
        amountOut = router.getAmountOut(amountIn, reserveIn, reserveOut);

        if (fromToken.allowance(address(this), address(router)) < amountIn) {
            fromToken.approve(address(router), type(uint256).max);
        } 
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn, 
            amountOut, 
            path,
            msg.sender,
            block.timestamp
        );
    }

    function swapFromDirect(
        address routerAddress, 
        address[] memory path, 
        uint256 amountOut
    ) external override returns (uint256 amountIn) {
        require(path.length >= 2, "Swapper: path must have at least 2 tokens");

        IUniswapV2Router02 router = IUniswapV2Router02(routerAddress);
        (uint256 reserveIn, uint256 reserveOut) = getReserves(router.factory(), path[0], path[path.length - 1]);
        amountIn = router.getAmountIn(amountOut, reserveIn, reserveOut);  

        IERC20 fromToken = IERC20(path[0]);
        fromToken.transferFrom(msg.sender, address(this), amountIn);
        
        if (fromToken.allowance(address(this), address(router)) < amountIn) {
            fromToken.approve(address(router), type(uint256).max);
        } 
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn, 
            amountOut, 
            path,
            msg.sender,
            block.timestamp
        ); 
    }

    function swapTo(
        address from, 
        address to, 
        uint256 amountIn
    ) external override returns (uint256) {
        IERC20 fromToken = IERC20(from);
        fromToken.transferFrom(msg.sender, address(this), amountIn);
        
        (string memory id, uint256 amountOut) = getOptimalPathTo(from, to, amountIn);
        
        IUniswapV2Router02 chosenRouter = IUniswapV2Router02(SwapPathVariants[id].router); 
        if (fromToken.allowance(address(this), address(chosenRouter)) < amountIn) {
            fromToken.approve(address(chosenRouter), type(uint256).max);
        } 
        chosenRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn, 
            amountOut, 
            SwapPathVariants[id].path, 
            msg.sender,
            block.timestamp
        ); 

        return amountOut;
    }
    
    function swapFrom(
        address from, 
        address to, 
        uint256 amountOut
    ) external override returns (uint256) {
        (string memory id, uint256 amountIn) = getOptimalPathFrom(from, to, amountOut);

        IERC20 fromToken = IERC20(from);
        fromToken.transferFrom(msg.sender, address(this), amountIn);
        
        IUniswapV2Router02 chosenRouter = IUniswapV2Router02(SwapPathVariants[id].router); 
        if (fromToken.allowance(address(this), address(chosenRouter)) < amountIn) {
            fromToken.approve(address(chosenRouter), type(uint256).max);
        } 
        chosenRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn, 
            amountOut, 
            SwapPathVariants[id].path, 
            msg.sender,
            block.timestamp
        ); 

        return amountIn; 
    }

    // fetches and sorts the reserves for a pair
    function getReserves(address factoryAddress, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        IUniswapV2Factory factory = IUniswapV2Factory(factoryAddress);
        IUniswapV2Pair pair = IUniswapV2Pair(factory.getPair(tokenA, tokenB));
        (uint reserve0, uint reserve1,) = pair.getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }
}
