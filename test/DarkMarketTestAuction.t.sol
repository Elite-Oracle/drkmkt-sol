// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../lib/forge-std/src/Test.sol";
import "../src/DarkMarketAuction.sol";
import "./MockERC721.t.sol";

contract DarkMarketAuctionTest is Test {
    DarkMarketAuction auction;
    MockERC721 token;
    address payable royaltyRecipient;

    function setUp() public {
        royaltyRecipient = payable(address(0x1234567890123456789012345678901234567890)); // Example address
        auction = new DarkMarketAuction(500, 500, royaltyRecipient); // 5% fee, 5% royalty
        token = new MockERC721("MockToken", "MTK");
    }

    function testStartAuction() public {
        token.mint(address(this), 1);
        token.approve(address(auction), 1);
        address[] memory tokenAddresses = new address[](1);
        uint256[] memory tokenIds = new uint256[](1);
        tokenAddresses[0] = address(token);
        tokenIds[0] = 1;
        auction.startAuction(100 ether, 1 hours, tokenAddresses, tokenIds);
    }

    function testFailBidWithoutPreBid() public {
        testStartAuction();
        auction.bid{value: 110 ether}(block.timestamp, 110 ether, 5 ether);
    }

    function testPreBid() public {
        testStartAuction();
        auction.preBid{value: 2 ether}(block.timestamp, 2 ether, 0.1 ether);
    }

    function testOpenAuction() public {
        testPreBid();
        vm.warp(block.timestamp + 50 minutes);
        auction.openAuction(block.timestamp);
    }

    function testBid() public {
        testOpenAuction();
        auction.bid{value: 3 ether}(block.timestamp, 3 ether, 0.1 ether);  // Ensure the sum of bid and incentive matches the ether sent
    }

    function testFinalizeAuction() public {
        testBid();
        vm.warp(block.timestamp + 2 hours);
        auction.finalizeAuction(block.timestamp);
    }

    function testFailCancelAuctionAfterBid() public {
        testPreBid();
        auction.cancelAuction(block.timestamp);
    }

    function testCancelAuctionBeforeBid() public {
        testStartAuction();
        auction.cancelAuction(block.timestamp);
    }

    function testSetFeePercentage() public {
        auction.setFeePercentage(600); // Setting to 6%
        assertEq(auction.feePercentage(), 600);
    }

    function testFailSetFeePercentageAboveLimit() public {
        auction.setFeePercentage(1100); // Should fail as it's above 10%
    }

    function testSetRoyaltyPercentage() public {
        auction.setRoyaltyPercentage(600); // Setting to 6%
        assertEq(auction.royaltyPercentage(), 600);
    }

    function testFailSetRoyaltyPercentageAboveLimit() public {
        auction.setRoyaltyPercentage(1100); // Should fail as it's above 10%
    }

    function testSetRoyaltyRecipient() public {
        address payable newRecipient = payable(address(0x0987654321098765432109876543210987654321)); // Example address
        auction.setRoyaltyRecipient(newRecipient);
        assertEq(auction.royaltyRecipient(), newRecipient);
    }

    // New tests based on the mentioned cases

    function testFailStartAuctionWithMismatchedTokenAddressesAndIDs() public {
        token.mint(address(this), 1);
        token.approve(address(auction), 1);
        address[] memory tokenAddresses = new address[](2);
        uint256[] memory tokenIds = new uint256[](1);
        tokenAddresses[0] = address(token);
        tokenAddresses[1] = address(token);
        tokenIds[0] = 1;
        auction.startAuction(100 ether, 1 hours, tokenAddresses, tokenIds); // This should fail
    }

    function testFailStartAuctionWithZeroDuration() public {
        token.mint(address(this), 1);
        token.approve(address(auction), 1);
        address[] memory tokenAddresses = new address[](1);
        uint256[] memory tokenIds = new uint256[](1);
        tokenAddresses[0] = address(token);
        tokenIds[0] = 1;
        auction.startAuction(100 ether, 0, tokenAddresses, tokenIds); // This should fail
    }

    function testFailPreBidWithDifferentAmount() public {
        testStartAuction();
        auction.preBid{value: 3 ether}(block.timestamp, 2 ether, 0.1 ether); // This should fail
    }

    function testFailPreBidOnOpenAuction() public {
        testOpenAuction();
        auction.preBid{value: 2 ether}(block.timestamp, 2 ether, 0.1 ether); // This should fail
    }

    function testFailBidWithLowerAmount() public {
    testOpenAuction();
    auction.bid{value: 2 ether + 0.1 ether}(block.timestamp, 2 ether, 0.1 ether);  // This should fail as it's equal to the highest bid + incentive
}

    function testFailFinalizeAuctionBeforeEndTime() public {
        testBid();
        auction.finalizeAuction(block.timestamp); // This should fail
    }

    function testFailBidOnNotOpenAuction() public {
        testStartAuction();
        auction.bid{value: 110 ether}(block.timestamp, 110 ether, 5 ether); // This should fail
    }

    function testFailOpenAuctionBefore10Minutes() public {
        testPreBid();
        vm.warp(block.timestamp + 5 minutes);
        auction.openAuction(block.timestamp); // This should fail
    }

    function testFailOpenAlreadyOpenAuction() public {
        testOpenAuction();
        auction.openAuction(block.timestamp); // This should fail
    }

    function testPauseAndUnpauseByOwner() public {
        auction.pause();
        assertTrue(auction.paused(), "Contract should be paused");

        auction.unpause();
        assertFalse(auction.paused(), "Contract should be unpaused");
    }

    function testFailPauseByNonOwner() public {
        DarkMarketAuction nonOwnerAuction = new DarkMarketAuction(500, 500, royaltyRecipient);
        nonOwnerAuction.pause();
    }

    function testFailUnpauseByNonOwner() public {
        DarkMarketAuction nonOwnerAuction = new DarkMarketAuction(500, 500, royaltyRecipient);
        nonOwnerAuction.unpause();
    }

    function testCancelSpecificAuctionByOwner() public {
        testStartAuction();
        uint256 auctionId = auction.nextAuctionId() - 1; // Assuming nextAuctionId is incremented after starting an auction
        auction.cancelSpecificAuction(auctionId);
        assertEq(auction.auctions(auctionId).seller, address(0), "Auction should be deleted");
    }

    function testFailCancelSpecificAuctionByNonOwner() public {
        testStartAuction();
        uint256 auctionId = auction.nextAuctionId() - 1;
        DarkMarketAuction nonOwnerAuction = new DarkMarketAuction(500, 500, royaltyRecipient);
        nonOwnerAuction.cancelSpecificAuction(auctionId);
    }

    function testCancelAllAuctionsByOwner() public {
        testStartAuction();
        testStartAuction();
        auction.cancelAllAuctions();
        assertEq(auction.activeAuctionIds.length, 0, "All auctions should be cancelled");
    }

    function testFailCancelAllAuctionsByNonOwner() public {
        testStartAuction();
        DarkMarketAuction nonOwnerAuction = new DarkMarketAuction(500, 500, royaltyRecipient);
        nonOwnerAuction.cancelAllAuctions();
    }
}
