// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Importing required libraries and contracts from OpenZeppelin
import "../node_modules/@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";

// DarkMarketAuction contract definition
contract DarkMarketAuction is Ownable {
    using SafeMath for uint256;

    // Struct definition for an auction
    struct Auction {
        address payable seller;
        uint256 endTime;
        address payable highestBidder;
        uint256 highestBid;
        uint256 bidderIncentive;
        bool finalized;
    }

    // Reference to the ERC721 token contract
    ERC721 public token;

    // Fee percentage for the platform
    uint256 public feePercentage;

    // Mapping from token ID to its auction details
    mapping(uint256 => Auction) public auctions;

    // Events
    event AuctionStarted(uint256 tokenId, uint256 startPrice, uint256 endTime);
    event BidPlaced(uint256 tokenId, address bidder, uint256 amount);
    event AuctionFinalized(uint256 tokenId, address winner, uint256 amount);
    event AuctionCancelled(uint256 tokenId);

    // Constructor
    constructor(address _tokenAddress, uint256 _feePercentage) {
        token = ERC721(_tokenAddress);
        setFeePercentage(_feePercentage);
    }

    // Set the Auction Fee Percentage (0% min to 10% max)
    function setFeePercentage(uint256 _feePercentage) public onlyOwner {
        require(_feePercentage >= 0 && _feePercentage <= 1000, "Fee must be between 0% and 10%");
        feePercentage = _feePercentage;
    }

    // Start an auction
    function startAuction(uint256 tokenId, uint256 initialAmount, uint256 duration) external {
        require(token.ownerOf(tokenId) == msg.sender, "Not the owner");
        auctions[tokenId] = Auction(payable(msg.sender), block.timestamp.add(duration), payable(address(0)), initialAmount, 0, false);
        token.transferFrom(msg.sender, address(this), tokenId);
        emit AuctionStarted(tokenId, initialAmount, block.timestamp.add(duration));
    }

    // Place a Bid with an incentive if the Bidder is oubide
    function bid(uint256 tokenId, uint256 bidAmount, uint256 bidderIncentive) external payable {
        Auction storage auction = auctions[tokenId];
        require(block.timestamp <= auction.endTime, "Auction ended");
        require(bidAmount > auction.highestBid.add(bidderIncentive), "Total New Bid does not cover the Previous Bid plus Incentive");

        // Refund the previous highest bidder with the incentive
        if (auction.highestBidder != address(0)) {
            auction.highestBidder.transfer(auction.highestBid.add(bidderIncentive));
        }

        // Update the auction with the new highest bid
        auction.highestBidder = payable(msg.sender);
        auction.highestBid = bidAmount;

        // Extend the auction if a bid is made in the last 20 minutes
        if (block.timestamp > auction.endTime.sub(20 minutes)) {
            auction.endTime = auction.endTime.add(20 minutes);
        }

        emit BidPlaced(tokenId, msg.sender, msg.value);
    }

    // Finalize an auction
    function finalizeAuction(uint256 tokenId) external {
        Auction storage auction = auctions[tokenId];
        require(block.timestamp > auction.endTime, "Auction not yet ended");
        require(!auction.finalized, "Already finalized");

        auction.finalized = true;

        uint256 fee = auction.highestBid.mul(feePercentage).div(10000);
        uint256 sellerAmount = auction.highestBid.sub(fee);

        payable(owner()).transfer(fee);
        auction.seller.transfer(sellerAmount);

        token.transferFrom(address(this), auction.highestBidder, tokenId);

        emit AuctionFinalized(tokenId, auction.highestBidder, auction.highestBid);
    }

    // Cancel an auction
    function cancelAuction(uint256 tokenId) external {
        Auction storage auction = auctions[tokenId];
        require(msg.sender == auction.seller, "Only the seller can cancel");
        require(auction.highestBid == 0, "Auction has bids and cannot be canceled");

        token.transferFrom(address(this), auction.seller, tokenId);
        delete auctions[tokenId];

        emit AuctionCancelled(tokenId);
    }

    // Update auction parameters
    function updateAuction(uint256 tokenId, uint256 newStartPrice, uint256 additionalDuration) external {
        Auction storage auction = auctions[tokenId];
        require(msg.sender == auction.seller, "Only the seller can update");
        require(auction.highestBid == 0, "Auction has bids and cannot be updated");

        auction.highestBid = newStartPrice;
        auction.endTime = auction.endTime.add(additionalDuration);
    }

    // Withdraw funds
    function withdrawFunds(uint256 amount) external onlyOwner {
        payable(owner()).transfer(amount);
    }
}
