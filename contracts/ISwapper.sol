//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface ISwapper {
    function addPath(string memory id, address[] memory path, address routerAddress) external;
    function deletePath(address from, address to, string memory id) external;
    function updatePath(string memory id, address[] memory newPath) external;
    function getOptimalPathTo(
        address from, 
        address to, 
        uint256 amountIn
    ) external returns (string memory bestID, uint256 bestAmountOut);
    function getOptimalPathFrom(
        address from,
        address to,
        uint256 amountOut
    ) external view returns (string memory bestID, uint256 bestAmountIn);
    function swapToDirect(address router, address[] memory path, uint256 amountIn) external returns (uint256 amountOut);
    function swapFromDirect(address router, address[] memory path, uint256 amountOut) external returns (uint256 amountIn);
    function swapTo(address from, address to, uint256 amountIn) external returns (uint256 amountOut);
    function swapFrom(address from, address to, uint256 amountOut) external returns (uint256 amountIn);
}