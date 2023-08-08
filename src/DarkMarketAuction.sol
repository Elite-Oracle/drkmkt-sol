// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

// Importing required libraries and contracts from OpenZeppelin
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// DarkMarketAuction contract definition
contract DarkMarketAuction is Ownable {
    using SafeMath for uint256; // Using SafeMath library to prevent integer overflow/underflow

    // Struct definition for an auction
    struct Auction {
        address payable seller;         // Address of the seller
        uint256 startPrice;             // Starting price of the auction
        uint256 endTime;                // End time of the auction
        address highestBidder;          // Address of the current highest bidder
        uint256 highestBid;             // Amount of the current highest bid
        bool finalized;                 // Flag to check if the auction has been finalized
    }

    // Reference to the ERC721 token contract
    DarkMarketToken public token;

    // Fee percentage for the platform; e.g., for 1% fee, set it as 100 for 1/100
    uint256 public feePercentage;

    // Mapping from token ID to its auction details
    mapping(uint256 => Auction) public auctions;

    // Events to log significant actions for frontend integration
    event AuctionStarted(uint256 tokenId, uint256 startPrice, uint256 endTime);
    event BidPlaced(uint256 tokenId, address bidder, uint256 amount);
    event AuctionFinalized(uint256 tokenId, address winner, uint256 amount);
    event AuctionCancelled(uint256 tokenId);

    // Constructor to initialize the contract with the token address and fee percentage
    constructor(address _tokenAddress, uint256 _feePercentage) {
        token = DarkMarketToken(_tokenAddress); // Setting the token contract address
        setFeePercentage(_feePercentage);      // Setting the fee percentage
    }

    // Function to set the fee percentage, only callable by the contract owner
    function setFeePercentage(uint256 _feePercentage) public onlyOwner {
        require(_feePercentage >= 0 && _feePercentage <= 1000, "Fee must be between 0% and 10%");
        feePercentage = _feePercentage;
    }

    // Function to start an auction
    function startAuction(uint256 tokenId, uint256 startPrice, uint256 duration) external {
        require(token.ownerOf(tokenId) == msg.sender, "Not the owner"); // Ensure the caller owns the token
        // Initializing the auction
        auctions[tokenId] = Auction(payable(msg.sender), startPrice, block.timestamp.add(duration), address(0), 0, false);
        token.transferFrom(msg.sender, address(this), tokenId); // Transferring the token to the contract

        emit AuctionStarted(tokenId, startPrice, block.timestamp.add(duration)); // Emitting event
    }

    // Function to place a bid
    function bid(uint256 tokenId) external payable {
        Auction storage auction = auctions[tokenId]; // Reference to the auction
        require(block.timestamp <= auction.endTime, "Auction ended"); // Ensure the auction is still active
        require(msg.value > auction.highestBid, "Bid too low"); // Ensure the new bid is higher than the current highest bid

        // Refund previous highest bidder
        if (auction.highestBidder != address(0)) {
            uint256 refundAmount = auction.highestBid;
            auction.highestBidder.transfer(refundAmount);
        }

        // Updating auction with new highest bid details
        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;

        // Extend auction time if bid is made in the last 20 minutes
        if (block.timestamp > auction.endTime.sub(20 minutes)) {
            auction.endTime = auction.endTime.add(20 minutes);
        }

        emit BidPlaced(tokenId, msg.sender, msg.value); // Emitting event
    }

    // Function to finalize an auction
    function finalizeAuction(uint256 tokenId) external {
        Auction storage auction = auctions[tokenId]; // Reference to the auction
        require(block.timestamp > auction.endTime, "Auction not yet ended"); // Ensure the auction has ended
        require(!auction.finalized, "Already finalized"); // Ensure the auction hasn't been finalized already

        auction.finalized = true; // Marking the auction as finalized

        // Calculating fee and royalty
        uint256 fee = auction.highestBid.mul(feePercentage).div(10000);
        uint256 royalty = auction.highestBid.mul(token.royalties(tokenId).value).div(10000);
        uint256 sellerAmount = auction.highestBid.sub(fee).sub(royalty);

        // Transferring fee, royalty, and seller amount
        payable(owner()).transfer(fee);
        token.royalties(tokenId).recipient.transfer(royalty);
        auction.seller.transfer(sellerAmount);

        // Transferring the token to the highest bidder
        token.transferFrom(address(this), auction.highestBidder, tokenId);

        emit AuctionFinalized(tokenId, auction.highestBidder, auction.highestBid); // Emitting event
    }

    // Function to cancel an auction
    function cancelAuction(uint256 tokenId) external {
        Auction storage auction = auctions[tokenId]; // Reference to the auction
        require(msg.sender == auction.seller, "Only the seller can cancel the auction"); // Ensure only the seller can cancel
        require(auction.highestBid == 0, "Auction has bids and cannot be canceled"); // Ensure there are no bids

        token.transferFrom(address(this), auction.seller, tokenId); // Returning the token to the seller
        delete auctions[tokenId]; // Deleting the auction

        emit AuctionCancelled(tokenId); // Emitting event
    }

    // Function to update auction parameters
    function updateAuction(uint256 tokenId, uint256 newStartPrice, uint256 additionalDuration) external {
        Auction storage auction = auctions[tokenId]; // Reference to the auction
        require(msg.sender == auction.seller, "Only the seller can update the auction"); // Ensure only the seller can update
        require(auction.highestBid == 0, "Auction has bids and cannot be updated"); // Ensure there are no bids

        // Updating auction details
        auction.startPrice = newStartPrice;
        auction.endTime = auction.endTime.add(additionalDuration);
    }

    // Function to allow the contract owner to withdraw funds
    function withdrawFunds(uint256 amount) external onlyOwner {
        payable(owner()).transfer(amount);
    }
}
