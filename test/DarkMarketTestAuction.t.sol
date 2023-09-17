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
    MockERC20 erc20Token;
    address payable royaltyRecipient;
    address bidTokenAddress;
    address payable bidderWallet;
    address payable sellerWallet;

    // Fallback function to ensure it doesn't revert
    receive() external payable {}

    function setUp() public {
        console.log("Setting up test environment...");

        royaltyRecipient = payable(address(0x1234567890123456789012345678901234567891)); 
        sellerWallet = payable(address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266));
        bidderWallet = payable(address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8));
        
        console.log("Royalty Recipient:", address(royaltyRecipient));
        console.log("Seller Wallet:", address(sellerWallet));
        console.log("Bidder Wallet:", address(bidderWallet));
        
        auction = new DarkMarketAuction();
        token = new MockERC721("MockToken", "MTK");
        erc20Token = new MockERC20(1000 ether);
        bidTokenAddress = address(erc20Token);
        
        console.log("Auction Contract Address:", address(auction));
        console.log("Mock ERC721 Token Address:", address(token));
        console.log("Mock ERC20 Token Address:", address(erc20Token));
        
        erc20Token.approve(address(auction), 5500 ether);
        console.log("ERC20 approved for auction contract.");

        token.mint(address(sellerWallet), 1);
        console.log("Token minted to:", address(sellerWallet));

        // 1. Mint ERC20 tokens to the bidderWallet
        erc20Token.mint(bidderWallet, 1500 ether); 
        // Minting more than the bid amount for safety
        console.log("ERC20 tokens minted to Bidder Wallet.");
        vm.prank(bidderWallet);
        erc20Token.approve(address(auction), 1500 ether);

        // 2. Mint ERC20 tokens to the sellerWallet
        erc20Token.mint(sellerWallet, 2500 ether); 
        // Minting more than the bid amount for safety
        console.log("ERC20 tokens minted to Seller Wallet.");
        vm.prank(sellerWallet);
        erc20Token.approve(address(auction), 2500 ether);

        // 3. Mint ERC20 tokens to the contractWallet
        erc20Token.mint(address(this), 9500 ether); 
        // Minting more than the bid amount for safety
        console.log("ERC20 tokens minted to CONTRACT Wallet.");
        erc20Token.approve(address(this), 9500 ether);

        // Ensure the token was minted to the sellerWallet
        assertEq(token.ownerOf(1), address(sellerWallet));
        console.log("Token ownership verified for seller.");

        vm.prank(address(sellerWallet));
        token.approve(address(auction), 1);
        console.log("Token approved by:", address(sellerWallet));

        // Ensure the auction contract is approved to transfer the token
        assertEq(token.getApproved(1), address(auction));
        console.log("Token approval verified for auction contract.");
    }

    function testEntireAuction() public {
    console.log("START Entire auction...");
        
        DarkMarketAuction.TokenDetail[] memory tokens = new DarkMarketAuction.TokenDetail[](1);
        tokens[0] = DarkMarketAuction.TokenDetail({
            tokenAddress: address(token),
            tokenId: 1
        });

        uint256 sellerBeforeBid = address(sellerWallet).balance;
        console.log("Seller Wallet Balance before start:", sellerBeforeBid);

        console.log("Starting Auction...");
        vm.prank(address(sellerWallet));
        auction.startAuction(100 ether, 1 hours, tokens, bidTokenAddress);
        console.log("Auction started by:", address(sellerWallet));

        uint256 auctionId = auction.nextAuctionId() - 1; // Get the current auction ID
        console.log("Current Auction ID:", auctionId);
        
        uint256 balanceBeforeBid = address(bidderWallet).balance;
        console.log("Bidder Wallet Balance before bid:", balanceBeforeBid);

        vm.warp(block.timestamp + 10 minutes);
        console.log("Time warped by 10 minutes.");
        
        vm.prank(bidderWallet);
        auction.bid(auctionId, 110 ether, 5 ether);
        console.log("Bid by:", address(bidderWallet));
    
        // Accessing the endTime directly from the public mapping
        uint32 auctionEndTime = auction.getAuctionEndTime(auctionId);

        // Warp the EVM time to the endTime of the auction or slightly after it
        vm.warp(auctionEndTime + 1 minutes); // Adding 1 minute to ensure we're past the endTime
        uint256 contractBeforeBid = address(this).balance;
        console.log("Contract Wallet Balance before bid:", contractBeforeBid);
        console.log("Finalizing auction...");
        auction.finalizeAuction(auctionId);
        console.log("Auction finalized for ID:", auctionId);
    }
}
