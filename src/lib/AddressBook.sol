// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library AddressBook {
    error ChainNotConfigured(uint256 chainId);
    error TreasuryNotConfigured(uint256 chainId);

    // Existing function for Access Manager
    function accessManager() internal view returns (address) {
        if (block.chainid == 335) {
            return address(0xE1809d966D96BEf678f808329336962944Ffb106);
        }
        revert ChainNotConfigured(block.chainid);
    }

    // New function for Treasury Address
    function treasury() internal view returns (address) {
        if (block.chainid == 335) {
            return address(0x419C3657532aaD16955291AF7942fea9A1b6d010); // Treasury address
        }
        revert TreasuryNotConfigured(block.chainid);
    }
}

