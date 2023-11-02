// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../src/DarkMarketAuction.sol";
import "../test/MockERC721.t.sol";
import "../test/MockERC20.t.sol";

contract DarkMarketAuctionFuzzTest {
    DarkMarketAuction auction;
    MockERC721 token;
    MockERC20 erc20Token;

    constructor() {
        auction = new DarkMarketAuction();
        token = new MockERC721("MockToken", "MTK");
        erc20Token = new MockERC20(1000 ether);
    }

    function randomUint(uint256 upper) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % upper;
    }

    function randomUint32(uint32 upper) internal view returns (uint32) {
        return uint32(randomUint(upper));
    }

    function fuzzStartAuction() public {
        uint256 startPrice = randomUint(1000 ether);
        uint32 duration = randomUint32(2 * 60 * 60); // 2 hours in seconds
        DarkMarketAuction.TokenDetail[] memory tokens = new DarkMarketAuction.TokenDetail[](1);
        tokens[0] = DarkMarketAuction.TokenDetail({
            tokenAddress: address(token),
            tokenId: randomUint(100)
        });
        auction.startAuction(startPrice, duration, tokens, address(erc20Token));
    }

    function fuzzBid() public {
        uint256 auctionId = randomUint(auction.nextAuctionId());
        uint256 bidAmount = randomUint(1000 ether);
        uint256 minIncrement = randomUint(50 ether);
        auction.bid(auctionId, bidAmount, minIncrement);
    }

}
