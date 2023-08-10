// Dark Market Auction

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../node_modules/@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../node_modules/@openzeppelin/contracts/security/Pausable.sol";

contract DarkMarketAuction is Ownable, Pausable {
    // Auction Struct
    struct Auction {
        address payable seller;        // Address of the seller
        uint32 startTime;              // Start time of the auction
        uint32 endTime;                // End time of the auction
        address payable highestBidder; // Address of the current highest bidder
        uint256 highestBid;             // Amount of the current highest bid
        uint256 bidderIncentive;        // Incentive for the bidder
        bool finalized;                // Whether the auction has been finalized
        bool isOpen;                   // Whether the auction is open for bidding
        bool hasReceivedBids;          // Whether the auction has received any bids
        address[] tokenAddresses;      // Array of ERC721 contract addresses
        uint256[] tokenIds;            // Array of token IDs
    }

    uint256[] public activeAuctionIds; // Total Active Auctions
    uint256 public nextAuctionId = 1; // New state variable for incremental auction IDs
    uint32 public feePercentage;       // Fee percentage for the platform
    uint32 public royaltyPercentage;   // Royalty percentage for the creator
    address payable public royaltyRecipient; // Address to receive the royalty

    mapping(uint256 => Auction) public auctions; // Mapping from auction ID to its details

// Add these events at the top of your DarkMarketAuction contract
event DebugUint(string message, uint256 value);
event DebugAddress(string message, address addr);
event DebugString(string message);

    event AuctionStarted(uint256 auctionId, uint256 startPrice, uint32 endTime);
    event BidPlaced(uint256 auctionId, address bidder, uint256 amount);
    event AuctionFinalized(uint256 auctionId, address winner, uint256 amount);
    event AuctionCancelled(uint256 auctionId);

 //   constructor(uint32 _feePercentage, uint32 _royaltyPercentage, address payable _royaltyRecipient) {
 //       require(_feePercentage <= 1000, "Fee percentage too high"); // Max 10%
 //       require(_royaltyPercentage <= 1000, "Royalty percentage too high"); // Max 10%
 //       feePercentage = _feePercentage;
 //       royaltyPercentage = _royaltyPercentage;
 //       royaltyRecipient = _royaltyRecipient;
 //   }

    // Set the Auction Fee Percentage (0% min to 10% max)
    function setFeePercentage(uint32 _feePercentage) public onlyOwner {
        require(_feePercentage <= 1000, "Fee percentage too high"); // Max 10%
        feePercentage = _feePercentage;
    }

    // Set the Royalty Fee Percentage (0% min to 10% max)
    function setRoyaltyPercentage(uint32 _royaltyPercentage) public onlyOwner {
        require(_royaltyPercentage <= 1000, "Royalty percentage too high"); // Max 10%
        royaltyPercentage = _royaltyPercentage;
    }

    // Set the royalty recipient's address
    function setRoyaltyRecipient(address payable _royaltyRecipient) public onlyOwner {
        royaltyRecipient = _royaltyRecipient;
    }

    // Start An Auction
    // Multiple ERC721 Tokens can be auctioned
    function startAuction(uint256 initialAmount, uint32 duration, address[] memory _tokenAddresses, uint256[] memory _tokenIds) external whenNotPaused {
        require(duration > 0, "Auction Duration should be greater than zero");
        require(_tokenAddresses.length == _tokenIds.length, "Mismatched token addresses and IDs");

        // Transfer all tokens to the contract
        for (uint i = 0; i < _tokenAddresses.length; i++) {
            ERC721(_tokenAddresses[i]).transferFrom(msg.sender, address(this), _tokenIds[i]);
        }

        // Create a new auction
        auctions[nextAuctionId] = Auction({
            seller: payable(msg.sender),
            startTime: uint32(block.timestamp),
            endTime: uint32(block.timestamp) + duration,
            highestBidder: payable(address(0)),
            highestBid: initialAmount,
            bidderIncentive: 0,
            finalized: false,
            isOpen: false,
            hasReceivedBids: false,
            tokenAddresses: _tokenAddresses,
            tokenIds: _tokenIds
        });

        emit AuctionStarted(nextAuctionId, initialAmount, uint32(block.timestamp) + duration);
        nextAuctionId++; // Increment the Auction ID for the next auction
        activeAuctionIds.push(nextAuctionId); // Active auctions ++
    }

    // Pre-bid function to allow users to bid before the auction officially opens
    // This fuctionality deters Bots from listening for new auctions and front-running actual bidders
    function preBid(uint256 auctionId, uint256 bidAmount, uint256 bidderIncentive) external payable whenNotPaused {
        Auction storage auction = auctions[auctionId];
        require(!auction.isOpen, "Auction is already open for bidding");
        require(msg.value == bidAmount, "ETH sent does not match the bid");

        // If there's a previous bidder, refund them (without incentive since it's pre-bid)
        if (auction.highestBidder != address(0)) {
            auction.highestBidder.transfer(auction.highestBid);
        }

        // Update auction details
        auction.highestBidder = payable(msg.sender);
        auction.highestBid = bidAmount;
        auction.bidderIncentive = bidderIncentive;
        auction.hasReceivedBids = true;

        emit BidPlaced(auctionId, msg.sender, bidAmount);
    }

    // Open the auction for public bidding
    function openAuction(uint256 auctionId) external whenNotPaused {
        //DebugAddressemit DebugUint("Current Timestamp:", block.timestamp);
    emit DebugUint("Auction End Time:", auctions[auctionId].endTime);

        Auction storage auction = auctions[auctionId];
        require(block.timestamp >= auction.startTime + 10 minutes, "Auction can't be opened yet");
        require(!auction.isOpen, "Auction is already open");

        auction.isOpen = true;
    }

// Bid function to allow users to bid on an open auction
function bid(uint256 auctionId, uint256 bidAmount, uint256 bidderIncentive) external payable whenNotPaused {
    Auction storage auction = auctions[auctionId];
    
    // Debugging information
    emit DebugUint("Bid Amount Received:", msg.value);
    emit DebugUint("Expected Bid Amount:", bidAmount);
    emit DebugUint("Previous Highest Bid:", auction.highestBid);
    emit DebugUint("Previous Bidder Incentive:", auction.bidderIncentive);
    
    require(auction.isOpen, "Auction is not open yet");
    require(msg.value == bidAmount, "ETH sent does not match Bid");
    
    // Ensure the new bid amount is strictly greater than the sum of the previous highest bid and the bidder incentive
    uint256 totalPreviousBid = auction.highestBid + auction.bidderIncentive;
    require(bidAmount > totalPreviousBid, "Total bid (including incentive) too low");

    // Debugging information for endTime extension
    emit DebugUint("Current Timestamp:", block.timestamp);
    emit DebugUint("Auction End Time Before Check:", auction.endTime);

    // Check if the bid is made within the last 20 minutes of the auction
    if (block.timestamp < auction.endTime && block.timestamp > auction.endTime - 20 minutes) {
        auction.endTime += 20 minutes; // Extend the auction by 20 minutes
        emit DebugUint("Auction End Time Extended To:", auction.endTime);
    } else {
        emit DebugString("Auction End Time Not Extended");
    }

    // Refund the previous highest bidder with their bid and incentive
    if (auction.highestBidder != address(0)) {
        require(auction.highestBid + auction.bidderIncentive > auction.highestBid, "Potential overflow in refund");
        auction.highestBidder.transfer(auction.highestBid + auction.bidderIncentive);
    }

    // Update auction details
    auction.highestBidder = payable(msg.sender);
    auction.highestBid = bidAmount;
    auction.bidderIncentive = bidderIncentive;

    emit BidPlaced(auctionId, msg.sender, bidAmount);
}



    // Allow the seller to cancel the auction if no bids have been placed
    function cancelAuction(uint256 auctionId) public {
        Auction storage auction = auctions[auctionId];
        require(msg.sender == auction.seller || msg.sender == owner(), "Only the seller or contract owner can cancel");

        require(!auction.hasReceivedBids, "Auction has received bids and cannot be canceled");

        // Transfer all tokens back to the seller
        for (uint i = 0; i < auction.tokenAddresses.length; i++) {
            ERC721(auction.tokenAddresses[i]).transferFrom(address(this), auction.seller, auction.tokenIds[i]);
        }

        delete auctions[auctionId];

        _removeAuctionId(auctionId);

        emit AuctionCancelled(auctionId);
    }

function _removeAuctionId(uint256 auctionId) internal {
    for (uint i = 0; i < activeAuctionIds.length; i++) {
        if (activeAuctionIds[i] == auctionId) {
            activeAuctionIds[i] = activeAuctionIds[activeAuctionIds.length - 1];
            activeAuctionIds.pop();
            break;
        }
    }
}

    // Finalize the auction, transferring the tokens to the highest bidder and funds to the seller
function finalizeAuction(uint256 auctionId) external whenNotPaused {
    Auction storage auction = auctions[auctionId];

    emit DebugString("Entering finalizeAuction");
    emit DebugUint("Auction ID:", auctionId);
    emit DebugUint("Current block timestamp:", block.timestamp);
    emit DebugUint("Auction end time:", auction.endTime);

    require(auction.isOpen, "Auction is not open yet");
    require(block.timestamp >= auction.endTime, "Auction not yet ended");
    require(!auction.finalized, "Auction already completed and finalized");

    if (auction.highestBid == 0) {
        emit DebugString("No bids received. Cancelling auction.");
        // If no bids were received, cancel the auction
        cancelAuction(auctionId);
        return;
    }

    auction.finalized = true;

    uint256 fee = auction.highestBid * feePercentage / 10000;
    uint256 royalty = auction.highestBid * royaltyPercentage / 10000;
    uint256 sellerAmount = auction.highestBid - fee - royalty;

    emit DebugUint("Calculated fee:", fee);
    emit DebugUint("Calculated royalty:", royalty);
    emit DebugUint("Calculated sellerAmount:", sellerAmount);

    payable(owner()).transfer(fee);
    royaltyRecipient.transfer(royalty);
    auction.seller.transfer(sellerAmount);

    emit DebugString("Transferred ETH amounts");

    // Transfer all tokens to the highest bidder
    for (uint i = 0; i < auction.tokenAddresses.length; i++) {
        emit DebugAddress("Transferring token from contract to highest bidder. Token address:", auction.tokenAddresses[i]);
        ERC721(auction.tokenAddresses[i]).transferFrom(address(this), auction.highestBidder, auction.tokenIds[i]);
    }

    _removeAuctionId(auctionId);
    
    emit AuctionFinalized(auctionId, auction.highestBidder, auction.highestBid);
}
    
    // FAILSAFE (Owner Only): Cancel a specific auction by the contract owner and return all tokens to the bidder / seller
    function cancelSpecificAuction(uint256 auctionId) external onlyOwner {
        Auction storage auction = auctions[auctionId];
        require(auction.seller != address(0), "Auction does not exist");

        // If there's an outstanding bid, refund the highest bidder
        if (auction.highestBidder != address(0)) {
            auction.highestBidder.transfer(auction.highestBid);
        }

        // Transfer all tokens back to the seller
        for (uint i = 0; i < auction.tokenAddresses.length; i++) {
            ERC721(auction.tokenAddresses[i]).transferFrom(address(this), auction.seller, auction.tokenIds[i]);
        }

        delete auctions[auctionId];
        _removeAuctionId(auctionId);
        emit AuctionCancelled(auctionId);
    }

    // FAILSAFE (Owner Only): Cancel ALL AUCTIONS and return all tokens to the bidders / sellers
    function cancelAllAuctions() external onlyOwner {
    for (uint i = 0; i < activeAuctionIds.length; i++) {
        uint256 auctionId = activeAuctionIds[i];
        Auction storage auction = auctions[auctionId];
        
        // If there's an outstanding bid, refund the highest bidder
        if (auction.highestBidder != address(0)) {
            auction.highestBidder.transfer(auction.highestBid);
        }

        // Transfer all tokens back to the seller
        for (uint j = 0; j < auction.tokenAddresses.length; j++) {
            ERC721(auction.tokenAddresses[j]).transferFrom(address(this), auction.seller, auction.tokenIds[j]);
        }

        delete auctions[auctionId];
        emit AuctionCancelled(auctionId);
        }
    delete activeAuctionIds; // Clear the array
    }

    // Owner can PAUSE contract if an iregularity is identified - Openzepplin Fuction 
    function pause() external onlyOwner {
    _pause();
    }

    // Owner can UNPAUSE contract when paused - Openzepplin Fuction
    function unpause() external onlyOwner {
    _unpause();
    }

    function getActiveAuctionCount() external view returns (uint256) {
    return activeAuctionIds.length;
}

}
