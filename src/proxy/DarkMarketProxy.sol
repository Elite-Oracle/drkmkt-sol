// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import "../lib/AddressBook.sol";

/// @title DarkMarketAuctionProxy
/// @notice This contract acts as a proxy for the DarkMarketAuction contract.
/// It delegates all calls to the current implementation set by the access manager and
/// uses the EliteOracleAccessManager for access control and upgrade authorization.
contract DarkMarketAuctionProxy is UUPSUpgradeable, AccessManagedUpgradeable {

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the proxy with the AccessManager address.
    function initialize() public initializer {
        __UUPSUpgradeable_init();

        // Set up the admin role to the access manager address retrieved from the AddressBook library
        __AccessManaged_init(AddressBook.accessManager());
    }

    /// @notice Ensures that the upgrade is authorized by the AccessManager.
    /// @param newImplementation The address of the new contract implementation.
    function _authorizeUpgrade(address newImplementation) internal override restricted {
    }

    /// @notice Retrieves the current implementation address.
    /// @return The address of the current implementation contract.
    function getImplementation() public view returns (address) {
    return ERC1967Utils.getImplementation();
    }
}
