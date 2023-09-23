// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console2.sol";
import "../src/DarkMarketAuction.sol";
import "./MockERC721.t.sol";
import "./MockERC20.t.sol";

contract DarkMarketAuctionTest is Test, Ownable {
    using console for *; // Reintroduced for enhanced logging

    DarkMarketAuction auction;
    MockERC721 token;
    MockERC721 token2;
    MockERC20 erc20Token;
    address payable royaltyRecipient;
    address bidTokenAddress;
    address payable bidderWallet;
    address payable bidderWallet2;
    address payable sellerWallet;

    // Fallback function to ensure it doesn't revert
    receive() external payable {}

    function setUp() public {
        console.log("SETUP test environment...");

        royaltyRecipient = payable(address(0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf));
        sellerWallet = payable(address(0x2B5AD5c4795c026514f8317c7a215E218DcCD6cF));
        bidderWallet = payable(address(0x6813Eb9362372EEF6200f3b1dbC3f819671cBA69));
        bidderWallet2 = payable(address(0x1efF47bc3a10a45D4B230B5d10E37751FE6AA718));

        auction = new DarkMarketAuction();
        token = new MockERC721("MockToken", "MTK");
        token2 = new MockERC721("MockToken2", "MTK2");
        erc20Token = new MockERC20(1000 ether);
        bidTokenAddress = address(erc20Token);

        console.log("Approving auction contract to spend ERC20 tokens...");
        erc20Token.approve(address(auction), 222500 ether);

        console.log("Minting ERC721 tokens for seller...");
        token.mint(address(sellerWallet), 1); // Mint 3 tokens for testing multiple tokens in an auction

        console.log("Minting and approving ERC20 tokens for bidderWallet...");
        erc20Token.mint(bidderWallet, 1500 ether); 
        vm.prank(bidderWallet);
        erc20Token.approve(address(auction), 1500 ether);
        console.log("Bidder Wallet balance at SetUp:", token.balanceOf(address(bidderWallet)));

        console.log("Minting and approving ERC20 tokens for bidderWallet2...");
        erc20Token.mint(bidderWallet2, 1600 ether); 
        vm.prank(bidderWallet2);
        erc20Token.approve(address(auction), 1600 ether);
        console.log("Bidder2 Wallet2 balance at SetUp:", token.balanceOf(address(bidderWallet2)));

        console.log("Minting and approving ERC20 tokens for sellerWallet...");
        erc20Token.mint(sellerWallet, 2500 ether); 
        vm.prank(sellerWallet);
        erc20Token.approve(address(auction), 2500 ether);
        console.log("Seller Wallet balance at SetUp:", token.balanceOf(address(sellerWallet)));

        console.log("Minting and approving ERC20 tokens for this contract...");
        erc20Token.mint(address(this), 22500 ether); 
        erc20Token.approve(address(this), 22500 ether);
    console.log("CONTRACT Wallet balance at SetUp:", token.balanceOf(address(this)));

        console.log("Approving auction contract to transfer ERC721 tokens...");
        vm.prank(address(sellerWallet));
        token.approve(address(auction), 1);

        // Mint 4 tokens for the seller
        for (uint i = 2; i <= 5; i++) {
            console.log("Minting additional ERC721 tokens for seller...");
            token.mint(address(sellerWallet), i);

            // Transfer ownership of the auction contract to this test contract
            auction.transferOwnership(address(this));
        }

        // Approve the auction contract to transfer all 4 tokens
        for (uint i = 2; i <= 5; i++) {
            console.log("Approving auction contract to transfer additional ERC721 tokens...");
            vm.prank(address(sellerWallet));
            token.approve(address(auction), i);
        }
    }

    function testCal() public {
        uint256 bidAmount = 2000;
        uint256 highestBid = 1000;
        uint256 expectedIncentive = 200; // As per the function logic
        uint256 result = auction.calculateIncentive(bidAmount, highestBid);
        console.log("result =", result);
        assert(result == expectedIncentive); // "Incentive should be 333 when bid amount is double the highest bid")
    }
}
/*

function testCompleteAuctionBidders() public {
    console.log("Starting test: CompleteAuctionBidders...");

    DarkMarketAuction.TokenDetail[] memory tokens = new DarkMarketAuction.TokenDetail[](1);
    tokens[0] = DarkMarketAuction.TokenDetail({
        tokenAddress: address(token),
        tokenId: 1
    });

    DarkMarketAuction.FeeDetail[] memory fees = new DarkMarketAuction.FeeDetail[](1);
    fees[0] = DarkMarketAuction.FeeDetail({
        contractFee: 0,
        royaltyFee: 0,
        royaltyAddress: address(this)
    });

    console.log("Starting auction...");
    vm.prank(address(sellerWallet));
    auction.startAuction(100 ether, 1 hours, tokens, bidTokenAddress, fees);
    uint256 auctionId = auction.nextAuctionId() - 1;

    console.log("Placing initial bid by BidderWallet...");
    vm.prank(bidderWallet);
    auction.bid(auctionId, 110 ether);

    console.log("Advancing time by 10 minutes...");
    vm.warp(block.timestamp + 10 minutes);

    console.log("Placing higher bid by BidderWallet2...");
    vm.prank(bidderWallet2);
    auction.bid(auctionId, 130 ether);

    console.log("Advancing time by 10 minutes...");
    vm.warp(block.timestamp + 10 minutes);

    console.log("Placing another higher bid by BidderWallet...");
    vm.prank(bidderWallet);
    auction.bid(auctionId, 150 ether);

    console.log("Advancing time by 10 minutes...");
    vm.warp(block.timestamp + 10 minutes);

    console.log("Placing the highest bid by BidderWallet2...");
    vm.prank(bidderWallet2);
    auction.bid(auctionId, 170 ether);

    uint32 auctionEndTime = auction.getAuctionEndTime(auctionId);
    console.log("Advancing time past auction end time...");
    vm.warp(auctionEndTime + 1 minutes);

    console.log("Finalizing auction...");
    auction.finalizeAuction(auctionId);
    console.log("AUCTION Completed...");

    // Assertions
    // Ensure the seller has transferred the auctioned tokens
    console.log("Assertion 1 Started...");
    assert(token.ownerOf(1) == address(bidderWallet2));
    console.log("Assertion 1 Completed...");
    // Ensure the seller received the payment from the auction contract
    console.log("Assertion 2 Started...");
    uint256 sellerBalance = erc20Token.balanceOf(address(sellerWallet));
    assert(sellerBalance >= 170 ether);
    console.log("Assertion 2 Completed...");
    }

    function testFinalizeAuctionWithoutBids() public {
        console.log("Starting test: FinalizeAuctionWithoutBids...");

        DarkMarketAuction.TokenDetail[] memory tokens = new DarkMarketAuction.TokenDetail[](1);
        tokens[0] = DarkMarketAuction.TokenDetail({
            tokenAddress: address(token),
            tokenId: 1
        });

        DarkMarketAuction.FeeDetail[] memory fees = new DarkMarketAuction.FeeDetail[](1);
        fees[0] = DarkMarketAuction.FeeDetail({
            contractFee: 0,
            royaltyFee: 1,
            royaltyAddress: address(this)
        });

        console.log("Starting auction...");
        vm.prank(address(sellerWallet));
        auction.startAuction(100 ether, 1 hours, tokens, bidTokenAddress, fees);
        uint256 auctionId = auction.nextAuctionId() - 1;

        uint32 auctionEndTime = auction.getAuctionEndTime(auctionId);
        console.log("Advancing time past auction end time...");
        vm.warp(auctionEndTime + 1 minutes);

        console.log("Finalizing auction without any bids...");
        auction.finalizeAuction(auctionId);
        console.log("AUCTION Finalized without any bids...");
    }

    function testCompleteAuctionWithMultipleBids() public {
        console.log("Starting test: CompleteAuctionWithMultipleBids...");
console.log("Initial contract balance:", address(this).balance);

        DarkMarketAuction.TokenDetail[] memory tokens = new DarkMarketAuction.TokenDetail[](1);
        tokens[0] = DarkMarketAuction.TokenDetail({
            tokenAddress: address(token),
            tokenId: 1
        });

        DarkMarketAuction.FeeDetail[] memory fees = new DarkMarketAuction.FeeDetail[](1);
        fees[0] = DarkMarketAuction.FeeDetail({
            contractFee: 0,
            royaltyFee: 0,
            royaltyAddress: address(this)
        });

        console.log("Starting auction...");
        vm.prank(address(sellerWallet));
        auction.startAuction(100 ether, 1 hours, tokens, bidTokenAddress, fees);
    console.log("Auction starting price:", 100 ether);
        uint256 auctionId = auction.nextAuctionId() - 1;

console.log("Placing bid...");
console.log("Bidder Wallet balance before bid:", token.balanceOf(address(bidderWallet)));

        vm.prank(bidderWallet);
        auction.bid(auctionId, 110 ether);
console.log("ERC20 balance of bidder after bid:", token.balanceOf(address(bidderWallet)));
console.log("Bidder address:", address(bidderWallet));
console.log("Bid amount:", 110 ether);

        console.log("Advancing time by 10 minutes...");
        vm.warp(block.timestamp + 10 minutes);

console.log("Placing bid...");
console.log("Bidder Wallet2 balance before bid:", token.balanceOf(address(bidderWallet2)));

        vm.prank(bidderWallet2);
        auction.bid(auctionId, 130 ether);
console.log("ERC20 balance of bidder after bid:", token.balanceOf(address(bidderWallet2)));
console.log("Bidder2 address:", address(bidderWallet2));
console.log("Bid amount:", 130 ether);

        console.log("Advancing time by 20 minutes...");
        vm.warp(block.timestamp + 20 minutes);

        console.log("Placing second bid by BidderWallet1...");
console.log("Bidder Wallet balance before bid:", token.balanceOf(address(bidderWallet)));

        vm.prank(bidderWallet);
        auction.bid(auctionId, 150 ether);
console.log("ERC20 balance of bidder after bid:", token.balanceOf(address(bidderWallet)));
console.log("Bidder address:", address(bidderWallet));
console.log("Bid amount:", 150 ether);

        uint32 auctionEndTime = auction.getAuctionEndTime(auctionId);
        console.log("Advancing time past auction end time...");
        vm.warp(auctionEndTime + 1 minutes);

        console.log("Finalizing auction...");
        auction.finalizeAuction(auctionId);
        console.log("AUCTION Completed...");
    }

    function testMultipleAuctionCreationAndCancellationByOwner() public {
        console.log("Starting test: MultipleAuctionCreationAndCancellationByOwner...");

        DarkMarketAuction.TokenDetail[] memory tokens = new DarkMarketAuction.TokenDetail[](1);
        tokens[0] = DarkMarketAuction.TokenDetail({
            tokenAddress: address(token),
            tokenId: 1
        });

        DarkMarketAuction.FeeDetail[] memory fees = new DarkMarketAuction.FeeDetail[](1);
        fees[0] = DarkMarketAuction.FeeDetail({
            contractFee: 0,
            royaltyFee: 1,
            royaltyAddress: address(this)
        });

        console.log("Starting multiple auctions...");
        vm.prank(address(sellerWallet));
        auction.startAuction(100 ether, 1 hours, tokens, bidTokenAddress, fees);
        uint256 auctionId1 = auction.nextAuctionId() - 1;

        tokens[0].tokenId = 2;
        auction.startAuction(200 ether, 1 hours, tokens, bidTokenAddress, fees);
        uint256 auctionId2 = auction.nextAuctionId() - 1;

        tokens[0].tokenId = 3;
        auction.startAuction(300 ether, 1 hours, tokens, bidTokenAddress, fees);
        uint256 auctionId3 = auction.nextAuctionId() - 1;

        console.log("Three auctions created...");

        console.log("Cancelling auctions...");
        auction.cancelSpecificAuction(auctionId1);
        console.log("Auction 1 cancelled by owner...");

        auction.cancelSpecificAuction(auctionId2);
        console.log("Auction 2 cancelled by owner...");

        auction.cancelSpecificAuction(auctionId3);
        console.log("Auction 3 cancelled by owner...");
    }
}
*/