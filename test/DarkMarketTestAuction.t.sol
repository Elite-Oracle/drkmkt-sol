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
        
        erc20Token.approve(address(auction), 5500 ether);

        token.mint(address(sellerWallet), 1); // Mint 3 tokens for testing multiple tokens in an auction

        erc20Token.mint(bidderWallet, 1500 ether); 
        vm.prank(bidderWallet);
        erc20Token.approve(address(auction), 1500 ether);

        erc20Token.mint(bidderWallet2, 1600 ether); 
        vm.prank(bidderWallet2);
        erc20Token.approve(address(auction), 1600 ether);

        erc20Token.mint(sellerWallet, 2500 ether); 
        vm.prank(sellerWallet);
        erc20Token.approve(address(auction), 2500 ether);

        erc20Token.mint(address(this), 9500 ether); 
        erc20Token.approve(address(this), 9500 ether);

        vm.prank(address(sellerWallet));
            token.approve(address(auction), 1);

        // Mint 4 tokens for the seller
        for (uint i = 2; i <= 5; i++) {
        token.mint(address(sellerWallet), i);
        }

        // Approve the auction contract to transfer all 4 tokens
        for (uint i = 2; i <= 5; i++) {
        vm.prank(address(sellerWallet));
        token.approve(address(auction), i);
        }
        
    }

    function testSingleTokenAuction() public {
        console.log("SingleTokenAuction...");

        DarkMarketAuction.TokenDetail[] memory tokens = new DarkMarketAuction.TokenDetail[](1);
        tokens[0] = DarkMarketAuction.TokenDetail({
            tokenAddress: address(token),
            tokenId: 1
        });

        vm.prank(address(sellerWallet));
        auction.startAuction(100 ether, 1 hours, tokens, bidTokenAddress);

        uint256 auctionId = auction.nextAuctionId() - 1;

        vm.prank(bidderWallet);
        auction.preBid(auctionId, 110 ether, 5 ether);
        console.log("PREBID Completed...");

        vm.warp(block.timestamp + 10 minutes);
        
        vm.prank(bidderWallet2);
        auction.bid(auctionId, 130 ether, 6 ether);
        console.log("BID Completed...");

        uint32 auctionEndTime = auction.getAuctionEndTime(auctionId);
        vm.warp(auctionEndTime + 1 minutes);

        auction.finalizeAuction(auctionId);
        console.log("AUCTION Completed...");

        // Log the balances of the four wallets
        console.log("Royalty Recipient ERC20 Balance:", erc20Token.balanceOf(address(royaltyRecipient)));
        console.log("Seller Wallet ERC20 Balance:", erc20Token.balanceOf(address(sellerWallet)));
        console.log("Bidder Wallet ERC20 Balance:", erc20Token.balanceOf(address(bidderWallet)));
        console.log("Bidder Wallet2 ERC20 Balance:", erc20Token.balanceOf(address(bidderWallet2)));

    console.log("Royalty Recipient ERC721 Token ID:", token.ownerOf(1) == address(royaltyRecipient) ? 1 : 0);
    console.log("Seller Wallet ERC721 Token ID:", token.ownerOf(1) == address(sellerWallet) ? 1 : 0);
    console.log("Bidder Wallet ERC721 Token ID:", token.ownerOf(1) == address(bidderWallet) ? 1 : 0);
    console.log("Bidder Wallet2 ERC721 Token ID:", token.ownerOf(1) == address(bidderWallet2) ? 1 : 0);

    }

    function testMultipleTokensAuction() public {
    console.log("MultipleTokensAuction...");

    uint256 numTokens = 4;
    DarkMarketAuction.TokenDetail[] memory tokens = new DarkMarketAuction.TokenDetail[](numTokens);
    for (uint i = 0; i < numTokens; i++) {
        tokens[i] = DarkMarketAuction.TokenDetail({
            tokenAddress: address(token),
            tokenId: i + 2 // Starting from token ID 2 to 5
        });
    }

    vm.prank(address(sellerWallet));
    auction.startAuction(300 ether, 1 hours, tokens, bidTokenAddress);

    uint256 auctionId = auction.nextAuctionId() - 1;

    vm.prank(bidderWallet);
    auction.preBid(auctionId, 330 ether, 15 ether);
    console.log("PREBID Completed...");

    vm.warp(block.timestamp + 10 minutes);
    
    vm.prank(bidderWallet2);
    auction.bid(auctionId, 440 ether, 22 ether);
    console.log("BID Completed...");

    uint32 auctionEndTime = auction.getAuctionEndTime(auctionId);
    vm.warp(auctionEndTime + 1 minutes);

    auction.finalizeAuction(auctionId);
    console.log("AUCTION Completed...");

    // Log the balances of the four wallets
    console.log("Royalty Recipient ERC20 Balance:", erc20Token.balanceOf(address(royaltyRecipient)));
    console.log("Seller Wallet ERC20 Balance:", erc20Token.balanceOf(address(sellerWallet)));
    console.log("Bidder Wallet ERC20 Balance:", erc20Token.balanceOf(address(bidderWallet)));
    console.log("Bidder Wallet2 ERC20 Balance:", erc20Token.balanceOf(address(bidderWallet2)));

    // Loop through the ERC721 tokens and log their ownership
    for (uint i = 2; i <= 5; i++) {
        if (token.ownerOf(i) == address(royaltyRecipient)) {
            console.log("Royalty Recipient owns ERC721 Token ID:", i);
        } else if (token.ownerOf(i) == address(sellerWallet)) {
            console.log("Seller Wallet owns ERC721 Token ID:", i);
        } else if (token.ownerOf(i) == address(bidderWallet)) {
            console.log("Bidder Wallet owns ERC721 Token ID:", i);
        } else if (token.ownerOf(i) == address(bidderWallet2)) {
            console.log("Bidder Wallet2 owns ERC721 Token ID:", i);
        } else {
            console.log("Unknown owner for ERC721 Token ID:", i);
        }
    }
}


}
