// SPDX-License-Identifier: UNLICENSED

// Deploy the Dark Market

pragma solidity ^0.8.20;

import {Script} from "../lib/forge-std/src/Script.sol";
import {DarkMarketAuction} from "../src/DarkMarketAuction.sol";

contract DeployDM is Script {

    function run() external returns (DarkMarketAuction) {
        vm.startBroadcast();

        DarkMarketAuction darkMarketAuction = new DarkMarketAuction();

        vm.stopBroadcast();
        return darkMarketAuction;
    }
}
