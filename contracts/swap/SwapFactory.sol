// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ISwapFactory.sol";
import "./SwapPair.sol";

contract SwapFactory is Ownable, ISwapFactory {
    address public override feeTo;
    address public override migrator;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    constructor() Ownable() {}


    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, "Swap: IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "Swap: ZERO_ADDRESS");
        bytes memory bytecode = type(SwapPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        SwapPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external override onlyOwner {
        feeTo = _feeTo;
    }

    function setMigrator(address _migrator) external override onlyOwner {
        migrator = _migrator;
    }

    function setWhiteContracts(address pair, address contractAddress, bool enabled) external onlyOwner {
        ISwapPair(pair).setWhiteContracts(contractAddress, enabled);
    }

    function setOnlyWhiteContract(address pair, bool enabled) external onlyOwner {
        ISwapPair(pair).setOnlyWhiteContract(enabled);
    }

    function allPairsLength() external view override returns (uint) {
        return allPairs.length;
    }
}
