//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ISwapper.sol";
import "./TokenLibrary.sol";

/**
    @dev Demo contract the function for Swapper.sol. (WIP)
 */
contract ParentContract is Ownable {
    ISwapper public swapper;

    function changeAddress(address _newAddress) external onlyOwner {
        swapper = ISwapper(_newAddress);
    }
}