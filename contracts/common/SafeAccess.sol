// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

abstract contract SafeAccess {
    modifier isNotContractCall() {
        require(!isContract(msg.sender), "CONTRACT_CALL_NOT_ALLOWED");
        _;
    }

    function isContract(address account) internal view returns (bool) {

        return account.code.length > 0;
    }
}
