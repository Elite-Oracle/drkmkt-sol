// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../src/DarkMarketAuction.sol";
import "./MockERC721.t.sol";

contract DarkMarketAuctionTest {
    DarkMarketAuction auction;
    MockERC721 testToken;

    // Setup before each test
    function setUp() public {
        testToken = new MockERC721("TestToken", "TT");
        auction = new DarkMarketAuction(address(testToken), 500); // 5% fee
    }

    // Test starting an auction
function testStartAuction() public {
    testToken.mint(address(this), 1);  // Mint token to this contract
    testToken.approve(address(auction), 1);
    auction.startAuction(1, 1 ether, 1 days);
}

// Test placing a bid
function testBid() public {
    testToken.mint(address(this), 2);  // Mint token to this contract
    testToken.approve(address(auction), 2);
    auction.startAuction(2, 1 ether, 1 days);
    auction.bid{value: 2 ether}(2, 2 ether, 0.1 ether); // Assuming a bid incentive of 0.1 ether
}

// Test outbidding and ensuring the initial bidder receives their bid with the incentive
function testOutbidWithIncentive() public {
    uint256 tokenId = 3;
    uint256 initialAmount = 0.1 ether;
    uint256 initialBid = 1 ether;
    uint256 initialBidIncentive = 0.1 ether;
    uint256 newBid = 1.2 ether; // Increased the new bid
    uint256 newBidIncentive = 0.1 ether;

    // Mint token and start auction
    testToken.mint(address(this), tokenId);
    testToken.approve(address(auction), tokenId);
    auction.startAuction(tokenId, initialAmount, 1 days);

    // Initial bid
    auction.bid{value: initialBid + initialBidIncentive}(tokenId, initialBid, initialBidIncentive);

    // Check initial bidder balance before outbidding
    uint256 initialBidderBalanceBefore = address(this).balance;

    // Outbid the initial bidder
    auction.bid{value: newBid + newBidIncentive}(tokenId, newBid, newBidIncentive);

    // Check initial bidder balance after being outbid
    uint256 initialBidderBalanceAfter = address(this).balance;

    // Confirm that the initial bidder received their bid back plus the incentive
    assert(initialBidderBalanceAfter == initialBidderBalanceBefore + initialBid + initialBidIncentive);
}

}