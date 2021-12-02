//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ITokenLibrary.sol";

/**
    Contract for getting ERC20 token addresses by symbol string.
    @notice This contract does not store information about token decimals.
 */
contract TokenLibrary is ITokenLibrary, Ownable {
    mapping(string => address) internal tokenAddresses;
    
    /**
        @dev Limits who can call addToken.
     */
    mapping(address => bool) public editors;

    constructor() {
        editors[msg.sender] = true;

        tokenAddresses["WETH"] = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
        tokenAddresses["USDC"] = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
        tokenAddresses["DAI"] = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
        tokenAddresses["WMATIC"] = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
        tokenAddresses["WBTC"] = 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6;
    }

    function setEditor(address _editor, bool _access) external onlyOwner {
        editors[_editor] = _access;
    }

    /** 
        @dev Overwriting previous addresses is allowed because editor
        is expected to be responsible.
    */
    function addToken(string memory _name, address _address) external override {
        require(editors[msg.sender] == true, "TokenLibrary: Only editor can access this function");
        tokenAddresses[_name] = _address;
    }

    function getToken(string memory _name) external view override returns(address) {
        return tokenAddresses[_name];
    }
}