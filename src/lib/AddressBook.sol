// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library AddressBook {
    error ChainNotConfigured(uint256 chainId);

    function accessManager() internal pure returns (address) {
        if (block.chainid == 53935) {
            return address(0);  // replace with deployed AccessManager address
        }
        revert ChainNotConfigured(block.chainid);
    }
}
