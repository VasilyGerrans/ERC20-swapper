//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IOracle.sol";

contract Swapper {
    address private owner;

    // We assume that we will use SimpleSLPTWAP0OracleV1 and SimpleSLPTWAP1OracleV1
    IUniswapV2Factory private sushiFactory;
    IOracle private sushiOracle; 

    struct SwapPath {
        string ID;
        address router;
        address[] path;
        bool active;
    }

    mapping(address => mapping(address => string[])) public SwapPathIDs;
    mapping(string => SwapPath) public SwapPathVariants;
    
    constructor(
        address factoryAddress,  
        address oracleAddress, 
        string[] memory ids, 
        address[][] memory paths, 
        address[] memory routers
    ) {
        require(routers.length == paths.length, "Swapper: Every path must have a router");
        require(ids.length == paths.length, "Swapper: Every path must have an ID");
        owner = msg.sender;
        sushiFactory = IUniswapV2Factory(factoryAddress);
        sushiOracle = IOracle(oracleAddress);
        for (uint256 i = 0; i < paths.length; i++) {
            addPath(ids[i], paths[i], routers[i]);
        }
    }

    modifier onlyOwner {
        require(msg.sender == owner, "Swapper: Only owner can call this function");
        _;
    }

    function addPath(string memory id, address[] memory path, address routerAddress) public onlyOwner {
        SwapPathVariants[id] = SwapPath(
            id, 
            routerAddress, 
            path, 
            true
        );
        SwapPathIDs[path[0]][path[path.length - 1]].push(id);
    }

    function deletePath(address from, address to, string memory id) public onlyOwner {
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

    function updatePath(string memory id, address[] memory newPath) external onlyOwner {
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

    function findOptimalPath(address from, address to, uint256 amountIn) internal view returns(string memory bestPath, uint256 bestAmount) {
        for (uint256 i = 0; i < SwapPathIDs[from][to].length; i++) {
            IUniswapV2Router02 router = IUniswapV2Router02(SwapPathVariants[SwapPathIDs[from][to][i]].router);

            uint256[] memory amountsOut = router.getAmountsOut(amountIn, SwapPathVariants[SwapPathIDs[from][to][i]].path);
            uint256 possibleAmount = amountsOut[amountsOut.length - 1];

            if (possibleAmount > bestAmount) {
                bestAmount = possibleAmount;
                bestPath = SwapPathIDs[from][to][i];
            }
        }
    }


    function fetchOraclePrice(address from, address to) public view returns (uint256) {
        IUniswapV2Pair uniPair = IUniswapV2Pair(sushiFactory.getPair(from, to));

        // get price of to in terms of from
        uint256 price = from == uniPair.token0() ? uniPair.price0CumulativeLast() : uniPair.price1CumulativeLast();

        // (bool success, uint256 price) = IOracle(sushiOracle).peek(data);
        return price;
    }

    function swap(
        address from,
        address to,
        uint256 amountIn,
        uint256 maxSlippage
    ) external returns(uint256) {
        (uint256 oraclePrice) = fetchOraclePrice(from, to);
        (string memory id, uint256 amountOut) = findOptimalPath(from, to, amountIn);

        uint256 amountOutMin = amountIn * oraclePrice * (10000 - maxSlippage) / 10000;
        require(amountOut >= amountOutMin, "Swapper: slippage exceeded");

        IERC20 fromToken = IERC20(from);
        IUniswapV2Router02 chosenRouter = IUniswapV2Router02(SwapPathVariants[id].router); 
        
        fromToken.transferFrom(msg.sender, address(this), amountIn);
        fromToken.approve(address(chosenRouter), amountIn);
        chosenRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn, 
            amountOutMin, 
            SwapPathVariants[id].path, 
            msg.sender,
            block.timestamp
        );

        return amountOut;
    }
}
