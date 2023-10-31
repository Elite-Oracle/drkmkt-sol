// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console2.sol";
import "../src/DarkMarketAuction.sol";
import "./MockERC721.t.sol";
import "./MockERC20.t.sol";

contract DarkMarketAuctionTest is Test {
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

    struct FeeDetail {
        uint256 contractFee;
        uint256 royaltyFee;
        address payable royaltyAddress;
    }

    struct TokenDetail {
        address tokenAddress;
        uint256 tokenId;
    }

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

        erc20Token.approve(address(auction), 222500 ether);

        token.mint(address(sellerWallet), 1); // Mint 3 tokens for testing multiple tokens in an auction
        vm.prank(sellerWallet);
        token.approve(address(auction), 1);
        token2.mint(address(sellerWallet), 1); // Mint 3 tokens for testing multiple tokens in an auction
        vm.prank(sellerWallet);
        token2.approve(address(auction), 1);

        erc20Token.mint(bidderWallet, 1500 ether); 
        vm.prank(bidderWallet);
        erc20Token.approve(address(auction), 1500 ether);
        console.log("Bidder Wallet balance at SetUp:", token.balanceOf(address(bidderWallet)));

        erc20Token.mint(bidderWallet2, 1600 ether); 
        vm.prank(bidderWallet2);
        erc20Token.approve(address(auction), 1600 ether);
        console.log("Bidder2 Wallet2 balance at SetUp:", token.balanceOf(address(bidderWallet2)));

        erc20Token.mint(sellerWallet, 2500 ether); 
        vm.prank(sellerWallet);
        erc20Token.approve(address(auction), 2500 ether);
        console.log("Seller Wallet balance at SetUp:", token.balanceOf(address(sellerWallet)));

        erc20Token.mint(address(this), 22500 ether); 
        erc20Token.approve(address(this), 22500 ether);
    console.log("CONTRACT Wallet balance at SetUp:", token.balanceOf(address(this)));

        vm.prank(address(sellerWallet));
        token.approve(address(auction), 1);

        // Mint 4 tokens for the seller
        for (uint i = 2; i <= 5; i++) {
            token.mint(address(sellerWallet), i);

            // Transfer ownership of the auction contract to this test contract
            auction.transferOwnership(address(this));
        }

        // Approve the auction contract to transfer all 4 tokens
        for (uint i = 2; i <= 5; i++) {
            vm.prank(address(sellerWallet));
            token.approve(address(auction), i);
        }

        // Mint 5 tokens for the seller
     for (uint i = 6; i <= 10; i++) {
        token.mint(address(sellerWallet), i);
     }

    // Approve the auction contract to transfer all 5 tokens
     for (uint i = 6; i <= 10; i++) {
         vm.prank(address(sellerWallet));
         token.approve(address(auction), i);
     }

    }

/***
function testStartMajorAuction() public {
    console.log("Starting test: StartMajorAuction...");

    DarkMarketAuction.TokenDetail[] memory tokens = new DarkMarketAuction.TokenDetail[](2);
    tokens[0] = DarkMarketAuction.TokenDetail({
        tokenAddress: address(token),
        tokenId: 1
    });
    tokens[1] = DarkMarketAuction.TokenDetail({
        tokenAddress: address(token2),
        tokenId: 1
    });

    DarkMarketAuction.FeeDetail[] memory fees = new DarkMarketAuction.FeeDetail[](1);
    fees[0] = DarkMarketAuction.FeeDetail({
        contractFee: 100,
        royaltyFee: 200,
        royaltyAddress: royaltyRecipient
    });

    vm.prank(address(sellerWallet));
    uint256 auctionId = auction.startAuction(100 ether, 1 hours, tokens, bidTokenAddress, fees[0]);
    console.log("Auction started with multiple tokens...");

    vm.warp(block.timestamp + 10 minutes);

// Placing bids

        vm.prank(bidderWallet);
        auction.bid(auctionId, 110 ether, 1 ether);
        console.log("Bid placed by BidderWallet1:");
        vm.prank(bidderWallet2);
        auction.bid(auctionId, 120 ether, 2 ether); 
        console.log("Bid placed by BidderWallet2:");

    // Warp time to end of auction
    uint32 auctionEndTime = auction.getAuctionEndTime(auctionId);

    vm.warp(auctionEndTime + 1 minutes);

    console.log("Time advanced past auction end time...");

    // Finalizing auction
    vm.prank(address(sellerWallet));
    auction.finalizeAuction(auctionId);
        console.log("Auction SELLER finalized...");
        vm.prank(address(bidderWallet2));
        auction.finalizeAuction(auctionId);
            console.log("Auction BIDDER2 finalized...");
        vm.prank(auction.owner());
            auction.finalizeAuction(auctionId);
    console.log("Auction COMPLETELY finalized...");

    // Assertions
    // Ensure the seller has transferred the auctioned tokens
    assert(token.ownerOf(1) == address(bidderWallet2));
    assert(token2.ownerOf(1) == address(bidderWallet2));
    console.log("Tokens ownership confirmed for BidderWallet2...");

    // Ensure the seller received the payment from the auction contract
    uint256 sellerBalance = erc20Token.balanceOf(address(sellerWallet));
    assert(sellerBalance >= 140 ether);
    console.log("Payment confirmed for SellerWallet...");

    // Ensure the auction contract has no remaining tokens
    assert(token.balanceOf(address(auction)) == 0);
    assert(token2.balanceOf(address(auction)) == 0);
    console.log("Auction contract has no remaining tokens...");
}

}

 * 
 * 
    function testGetActiveAuctionCount() public {
        console.log("STARTING 25 new auctions...");

        uint256 startPrice = 1 ether;
        uint32 duration = 7 days;

        DarkMarketAuction.FeeDetail memory fees = DarkMarketAuction.FeeDetail({
            contractFee: 5,
            royaltyFee: 5,
            royaltyAddress: royaltyRecipient
        });

        for (uint i = 1; i <= 25; i++) {
            DarkMarketAuction.TokenDetail[] memory tokens = new DarkMarketAuction.TokenDetail[](1);
            tokens[0] = DarkMarketAuction.TokenDetail({
                tokenAddress: address(token),
                tokenId: i
            });

            vm.prank(address(sellerWallet));
            auction.startAuction(startPrice, duration, tokens, bidTokenAddress, fees);
        }

        uint256 activeAuctionCount = auction.getActiveAuctionCount();
        console.log("Active Auction Count =", activeAuctionCount);

        assertEq(activeAuctionCount, 25, "Expected 25 active auctions");
    }

function testCancelAuctionBySeller() public {
        console.log("Starting test: CancelAuctionBySeller...");

        DarkMarketAuction.TokenDetail[] memory tokens = new DarkMarketAuction.TokenDetail[](1);
        tokens[0] = DarkMarketAuction.TokenDetail({
            tokenAddress: address(token),
            tokenId: 4
        });

        DarkMarketAuction.FeeDetail[] memory fees = new DarkMarketAuction.FeeDetail[](1);
        fees[0] = DarkMarketAuction.FeeDetail({
            contractFee: 0,
            royaltyFee: 1,
            royaltyAddress: address(this)
        });

        console.log("Starting auction...");
        vm.prank(address(sellerWallet));
        auction.startAuction(400 ether, 1 hours, tokens, bidTokenAddress, fees[0]);
        uint256 auctionId = auction.nextAuctionId() - 1;

        console.log("Cancelling auction by seller...");
        vm.prank(address(sellerWallet));
        auction.cancelAuction(auctionId);
        console.log("Auction cancelled by seller...");
    }

    function testBidOnAuction() public {
        console.log("Starting test: BidOnAuction...");

        DarkMarketAuction.TokenDetail[] memory tokens = new DarkMarketAuction.TokenDetail[](1);
        tokens[0] = DarkMarketAuction.TokenDetail({
            tokenAddress: address(token),
            tokenId: 5
        });

        DarkMarketAuction.FeeDetail[] memory fees = new DarkMarketAuction.FeeDetail[](1);
        fees[0] = DarkMarketAuction.FeeDetail({
            contractFee: 0,
            royaltyFee: 1,
            royaltyAddress: address(this)
        });

        console.log("Starting auction...");
        vm.prank(address(sellerWallet));
        auction.startAuction(500 ether, 1 hours, tokens, bidTokenAddress, fees[0]);
        uint256 auctionId = auction.nextAuctionId() - 1;

        console.log("Placing bid...");
        vm.prank(bidderWallet);
        auction.bid(auctionId, 550 ether, 1 ether);
        console.log("Bid placed...");
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
*/
}
