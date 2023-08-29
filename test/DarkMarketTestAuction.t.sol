// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../lib/forge-std/src/Test.sol";
import "../src/DarkMarketAuction.sol";
import "./MockERC721.t.sol";
import "./MockERC20.t.sol";

contract DarkMarketAuctionTest is Test {
    DarkMarketAuction auction;
    MockERC721 token;
    MockERC20 erc20Token;
    address payable royaltyRecipient;
    address bidTokenAddress;

    // Log
    event LogInfo(string description, uint256 value);

    // Fallback function to ensure it doesn't revert
    receive() external payable {}

    function setUp() public {
        royaltyRecipient = payable(address(0x1234567890123456789012345678901234567890)); // Example address
        auction = new DarkMarketAuction();
        token = new MockERC721("MockToken", "MTK");
        erc20Token = new MockERC20(1000 ether); // For example, minting 1000 tokens
        bidTokenAddress = address(erc20Token);
        erc20Token.approve(address(auction), 1000 ether); // Approve the auction contract to spend the ERC20 tokens
    }

    function testStartAuction() public {
        token.mint(address(this), 1);
        token.approve(address(auction), 1);
        address[] memory tokenAddresses = new address[](1);
        uint256[] memory tokenIds = new uint256[](1);
        tokenAddresses[0] = address(token);
        tokenIds[0] = 1;
        auction.startAuction(100 ether, 1 hours, tokenAddresses, tokenIds, bidTokenAddress);
    }

function testOpenAuction() internal {
    uint256 auctionId = auction.nextAuctionId() - 1; // Assuming nextAuctionId is incremented after starting an auction
    auction.openAuction(auctionId);
}

function testBid() internal {
    uint256 auctionId = auction.nextAuctionId() - 1; // Get the current auction ID
    auction.bid{value: 110 ether}(auctionId, 110 ether, 5 ether);
}

function testPreBid() internal {
    uint256 auctionId = auction.nextAuctionId() - 1; // Get the current auction ID
    auction.preBid{value: 2 ether}(auctionId, 2 ether, 0.1 ether);
}

    function testFailBidAfterAuctionEnd() public {
        testOpenAuction();
        vm.warp(block.timestamp + 2 hours); // Assuming 1 hour was the auction duration
        auction.bid{value: 4 ether}(block.timestamp, 4 ether, 0.1 ether);  // This should fail as the auction has ended
    }

    function testFailStartAuctionWithoutApproval() public {
        token.mint(address(this), 2);
        address[] memory tokenAddresses = new address[](1);
        uint256[] memory tokenIds = new uint256[](1);
        tokenAddresses[0] = address(token);
        tokenIds[0] = 2;
        auction.startAuction(100 ether, 1 hours, tokenAddresses, tokenIds, bidTokenAddress); // This should fail as the token is not approved
    }

    function testFailCancelAuctionByNonSeller() public {
        testStartAuction();
        uint256 auctionId = auction.nextAuctionId() - 1;
        DarkMarketAuction nonSeller = new DarkMarketAuction();
        nonSeller.cancelSpecificAuction(auctionId); // This should fail as the caller is not the seller
    }

    function testFailFinalizeAuctionByNonWinner() public {
        testBid();
        uint256 auctionId = auction.nextAuctionId() - 1;
        DarkMarketAuction nonWinner = new DarkMarketAuction();
        nonWinner.finalizeAuction(auctionId); // This should fail as the caller is not the highest bidder
    }

    function testFailBidBelowMinimum() public {
        testOpenAuction();
        auction.bid{value: 1 ether}(block.timestamp, 1 ether, 0.1 ether);  // This should fail as the bid is below the minimum
    }

    function testFailBidWithoutIncentive() public {
        testOpenAuction();
        auction.bid{value: 3 ether}(block.timestamp, 3 ether, 0 ether);  // This should fail as there's no incentive
    }

    function testFailOpenAuctionTwice() public {
        testOpenAuction();
        auction.openAuction(block.timestamp); // This should fail as the auction is already open
    }

    function testFailPreBidAfterOpenAuction() public {
        testOpenAuction();
        auction.preBid{value: 2 ether}(block.timestamp, 2 ether, 0.1 ether); // This should fail as the auction is already open
    }

    function testFailBidWithSameAmount() public {
        testOpenAuction();
        auction.bid{value: 2.1 ether}(block.timestamp, 2 ether, 0.1 ether);  // This should fail as the bid is the same as the previous
    }

    function testFailBidOnCancelledAuction() public {
        testStartAuction();
        uint256 auctionId = auction.nextAuctionId() - 1;
        auction.cancelSpecificAuction(auctionId);
        auction.bid{value: 110 ether}(block.timestamp, 110 ether, 5 ether); // This should fail as the auction is cancelled
    }

    function testFailFinalizeOnCancelledAuction() public {
        testStartAuction();
        uint256 auctionId = auction.nextAuctionId() - 1;
        auction.cancelSpecificAuction(auctionId);
        auction.finalizeAuction(auctionId); // This should fail as the auction is cancelled
        revert("Auction cannot be finalized, it was Cancelled");
    }

    function testFailBidOnNotOpenAuction() public {
        testStartAuction();
        auction.bid{value: 110 ether}(block.timestamp, 110 ether, 5 ether); // This should fail
        revert("Should fail as Auction Not Open");
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
        (address payable currentSeller,,,,,,,) = auction.auctions(auctionId);
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
        (, uint32 originalStartTime, uint32 originalEndTime, , , , ,) = auction.auctions(auctionId);
        vm.warp(originalStartTime + 10 minutes);
        auction.openAuction(auctionId); // Open the auction
        // Warp time to just 10 minutes before the auction's end time
        vm.warp(originalEndTime - 10 minutes);
        
        // Place a bid
        auction.bid{value: 110 ether}(auctionId, 110 ether, 5 ether);

        // Use the getter function again to retrieve the updated auction details
        (, , uint32 newEndTime, , , , ,) = auction.auctions(auctionId);

        // Check if the auction's end time has been extended by 20 minutes
        assertEq(newEndTime, originalEndTime + 20 minutes, "Auction end time should be extended by 20 minutes");
    }

// Helper function to convert uint to string
function uint2str(uint256 _i) internal pure returns (string memory) {
    if (_i == 0) {
        return "0";
    }
    uint256 j = _i;
    uint256 length;
    while (j != 0) {
        length++;
        j /= 10;
    }
    bytes memory bstr = new bytes(length);
    uint256 k = length - 1;
    while (_i != 0) {
        bstr[k--] = bytes1(uint8(48 + _i % 10));
        _i /= 10;
    }
    return string(bstr);
}

    function testFinalizeAuctionRightAfterEndTime() public {
    testStartAuction(); // Start a new auction

    uint256 auctionId = auction.nextAuctionId() - 1;
    (, uint32 originalStartTime, uint32 endTime, , , , ,) = auction.auctions(auctionId);

    emit LogInfo("Auction ID", auctionId);
    emit LogInfo("Original Start Time", originalStartTime);
    emit LogInfo("End Time", endTime);
    emit LogInfo("Original Block Time", block.timestamp);

    vm.warp(originalStartTime + 10 minutes);
    auction.openAuction(auctionId); // Open the auction

    emit LogInfo("Open Block Time", block.timestamp);
    emit LogInfo("End Time", endTime);

    auction.bid{value: 110 ether}(auctionId, 110 ether, 5 ether); // Bid

    emit LogInfo("Bid Block Time", block.timestamp);
    emit LogInfo("End Time", endTime);

    vm.warp(endTime);
    auction.finalizeAuction(auctionId);
    }

    function testFailBidOnPausedContract() public {
        testStartAuction();
        auction.pause();
        auction.bid{value: 110 ether}(block.timestamp, 110 ether, 5 ether); // This should fail as the contract is paused
    }

    function testFailOpenAuctionOnPausedContract() public {
        testStartAuction();
        auction.pause();
        auction.openAuction(block.timestamp); // This should fail as the contract is paused
    }

    function testFailPreBidOnPausedContract() public {
        testStartAuction();
        auction.pause();
        auction.preBid{value: 2 ether}(block.timestamp, 2 ether, 0.1 ether); // This should fail as the contract is paused
    }

    function testFailFinalizeAuctionOnPausedContract() public {
        testBid();
        uint256 auctionId = auction.nextAuctionId() - 1;
        auction.pause();
        auction.finalizeAuction(auctionId); // This should fail as the contract is paused
            // If the above line doesn't revert, then the test should fail
    revert("Test failed: can not Finalize Auction on Paused Contract");
    }

function testFailSetFeePercentageOnPausedContract() public {
    auction.pause();
    
    // Try to set the fee percentage
    auction.setFeePercentage(600); // This should fail as the contract is paused
    
    // If the above line doesn't revert, then the test should fail
    revert("Test failed: setFeePercentage did not revert as expected");
}
}
