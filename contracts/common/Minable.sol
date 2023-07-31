// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

abstract contract Minable is OwnableUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private _minters;

    modifier onlyMinter() {
        require(isMinter(msg.sender), "Minter:NOT_MINTER");
        _;
    }

    function addMinters(address[] memory accounts) public virtual onlyOwner {
        for (uint256 i; i < accounts.length; i++) {
            _minters.add(accounts[i]);
        }
    }

    function addMinter(address account) public virtual onlyOwner {
        _minters.add(account);
    }

    function removeMinters(address[] memory accounts) public virtual onlyOwner {
        for (uint256 i; i < accounts.length; i++) {
            _minters.remove(accounts[i]);
        }
    }

    function getMinters()
        public
        view
        virtual
        returns (address[] memory accounts)
    {
        accounts = new address[](_minters.length());
        for (uint256 i; i < accounts.length; i++) {
            accounts[i] = _minters.at(i);
        }
    }

    function isMinter(address account) public view virtual returns (bool) {
        return _minters.contains(account);
    }
}
