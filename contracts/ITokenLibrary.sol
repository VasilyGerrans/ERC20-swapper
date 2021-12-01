//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITokenLibrary {
    function addToken(string memory, address) external;
    function getToken(string memory) external view returns(address);
}