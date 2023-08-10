// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../lib/forge-std/src/Test.sol";
import "../src/DarkMarketAuction.sol";
import "./MockERC721.t.sol";

contract DarkMarketAuctionTest is Test {
    DarkMarketAuction auction;
    MockERC721 token;
    address payable royaltyRecipient;

// Fallback function to ensure it doesn't revert
    receive() external payable {}

    function setUp() public {
        royaltyRecipient = payable(address(0x1234567890123456789012345678901234567890)); // Example address
        auction = new DarkMarketAuction();
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
        uint256 auctionId = auction.nextAuctionId() - 1;
        testBid();
        vm.warp(block.timestamp + 2 hours);
        auction.openAuction(auctionId);
        auction.finalizeAuction(auctionId);
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
    uint256 auctionId = auction.nextAuctionId() - 1;
    testOpenAuction();
    // Retrieve the auction's end time
    (, , uint32 endTime, , , , , , ) = auction.auctions(auctionId);

    // Ensure the current block timestamp is before the auction's end time
    require(block.timestamp < endTime, "Test setup error: Current time is already past the auction's end time");

    // Use the low-level call method to simulate the function call
    (bool success, ) = address(auction).call(abi.encodeWithSignature("finalizeAuction(uint256)", auctionId));

    // Check that the call was unsuccessful (i.e., it reverted)
    require(!success, "Expected the function to revert because the auction hasn't ended yet");
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
    DarkMarketAuction nonOwnerAuction = new DarkMarketAuction();

    // Use the low-level call method to simulate the function call
    (bool success, ) = address(nonOwnerAuction).call(abi.encodeWithSignature("pause()"));

    // Check that the call was unsuccessful (i.e., it reverted)
    require(!success, "Expected the function to revert");
}


    function testFailUnpauseByNonOwner() public {
        DarkMarketAuction nonOwnerAuction = new DarkMarketAuction();
        nonOwnerAuction.unpause();
    }

    function testCancelSpecificAuctionByOwner() public {
        testStartAuction();
        uint256 auctionId = auction.nextAuctionId() - 1; // Assuming nextAuctionId is incremented after starting an auction
        auction.cancelSpecificAuction(auctionId);
        (address payable currentSeller,,,,,,,,) = auction.auctions(auctionId);
        assertEq(currentSeller, address(0), "Auction should be deleted");


    }

    function testFailCancelSpecificAuctionByNonOwner() public {
    testStartAuction();
    uint256 auctionId = auction.nextAuctionId() - 1;

    // Placeholder Ethereum address (not the owner of the contract)
    address someNonOwnerAddress = address(0x1234567890123456789012345678901234567890);

    // Use the low-level call method to simulate the function call
    (bool success, ) = someNonOwnerAddress.call(abi.encodeWithSignature("cancelSpecificAuction(uint256)", auctionId));

    // Check that the call was unsuccessful (i.e., it reverted)
    assertTrue(!success, "Expected the function to revert");
}




    function testCancelAllAuctionsByOwner() public {
    testStartAuction();
    auction.cancelAllAuctions();
    assertEq(auction.getActiveAuctionCount(), 0, "All auctions should be cancelled");
}


    function testFailCancelAllAuctionsByNonOwner() public {
    token.mint(address(this), 2);
    testStartAuction();

    // Placeholder Ethereum address (not the owner of the contract)
    address someNonOwnerAddress = address(0x1234567890123456789012345678901234567890);

    // Use the low-level call method to simulate the function call
    (bool success, ) = someNonOwnerAddress.call(abi.encodeWithSignature("cancelAllAuctions()"));

    // Check that the call was unsuccessful (i.e., it reverted)
    assertTrue(!success, "Expected the function to revert");
}


    function testExtendAuctionTimeOnLateBid() public {
    testStartAuction();
    uint256 auctionId = auction.nextAuctionId() - 1; // Get the current auction ID

    // Use the getter function to retrieve the auction details
    (, uint32 originalStartTime, uint32 originalEndTime, , , , , , ) = auction.auctions(auctionId);
    vm.warp(originalStartTime + 10 minutes);
    auction.openAuction(auctionId); // Open the auction
    // Warp time to just 10 minutes before the auction's end time
    vm.warp(originalEndTime - 10 minutes);
    
    
    // Place a bid
    auction.bid{value: 110 ether}(auctionId, 110 ether, 5 ether);

    // Use the getter function again to retrieve the updated auction details
    (, , uint32 newEndTime, , , , , , ) = auction.auctions(auctionId);

    // Check if the auction's end time has been extended by 20 minutes
    assertEq(newEndTime, originalEndTime + 20 minutes, "Auction end time should be extended by 20 minutes");
}
function testFinalizeAuctionRightAfterEndTime() public {
        testBid();
        uint256 auctionId = auction.nextAuctionId() - 1;
        (, uint32 originalStartTime, uint32 endTime, , , , , , ) = auction.auctions(auctionId);
        vm.warp(originalStartTime + 10 minutes);
        auction.openAuction(auctionId); // Open the auction
        vm.warp(endTime);
        auction.finalizeAuction(auctionId);
    }

}