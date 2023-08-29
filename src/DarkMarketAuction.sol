// Dark Market Auction Contract v1.1
// @dev Elite Oracle | Kristian Peter
// @date August 2023

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../node_modules/@openzeppelin/contracts/security/Pausable.sol";
import "../node_modules/@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DarkMarketAuction
 * @dev This contract allows users to start and bid on auctions for ERC721 tokens.
 */
contract DarkMarketAuction is Ownable, Pausable, ReentrancyGuard {
    
    // Represents an auction for ERC721 tokens
    struct Auction {
        address payable seller;           // Address of the seller
        uint32 startTime;                 // Start time of the auction
        uint32 endTime;                   // End time of the auction
        address payable highestBidder;    // Address of the current highest bidder
        uint256 highestBid;               // Amount of the current highest bid
        uint256 bidderIncentive;          // Incentive for the bidder
        AuctionStatus status;             // Status of the auction (Open, PreBid, Bid, ExtraTime, Finalized)
        address[] tokenAddresses;         // Array of ERC721 contract addresses
        uint256[] tokenIds;               // Array of token IDs
        address bidTokenAddress;          // ERC20 token address used for bidding
    }

    // Represents the status of an auction
    enum AuctionStatus {
        Open,
        PreBid,
        Bid,
        ExtraTime,
        Finalized
    }

    uint256[] public activeAuctionIds;    // Array to store active auction IDs
    uint256 public nextAuctionId = 1;     // Counter for the next auction ID
    uint32 public feePercentage;          // Fee percentage for the platform
    uint32 public royaltyPercentage;      // Royalty percentage for the creator
    address payable public royaltyRecipient; // Address to receive the royalty

    mapping(uint256 => Auction) public auctions;  // Mapping from auction ID to its details

    // Event emitted when an auction starts
    event AuctionStarted(uint256 auctionId, uint256 startPrice, uint32 endTime);
    // Event emitted when a bid is placed
    event BidPlaced(uint256 auctionId, address bidder, uint256 amount);
    // Event emitted when an auction is finalized
    event AuctionFinalized(uint256 auctionId, address winner, uint256 amount);
    // Event emitted when an auction is cancelled
    event AuctionCancelled(uint256 auctionId);

    /**
     * @dev Sets the auction fee percentage.
     * @param _feePercentage The fee percentage (0% min to 10% max).
     */
    function setFeePercentage(uint32 _feePercentage) public onlyOwner {
        require(_feePercentage <= 1000, "Fee percentage too high");
        feePercentage = _feePercentage;
    }

    /**
     * @dev Sets the royalty fee percentage.
     * @param _royaltyPercentage The royalty percentage (0% min to 10% max).
     */
    function setRoyaltyPercentage(uint32 _royaltyPercentage) public onlyOwner {
        require(_royaltyPercentage <= 1000, "Royalty percentage too high");
        royaltyPercentage = _royaltyPercentage;
    }

    /**
     * @dev Sets the royalty recipient's address.
     * @param _royaltyRecipient The address to receive the royalty.
     */
    function setRoyaltyRecipient(address payable _royaltyRecipient) public onlyOwner {
        royaltyRecipient = _royaltyRecipient;
    }

    /**
     * @dev Starts an auction.
     * @param initialAmount The initial amount for the auction.
     * @param duration The duration of the auction.
     * @param _tokenAddresses The addresses of the ERC721 tokens.
     * @param _tokenIds The IDs of the ERC721 tokens.
     * @param _bidTokenAddress The address of the ERC20 token used for bidding.
     */
    function startAuction(
        uint256 initialAmount, 
        uint32 duration, 
        address[] memory _tokenAddresses, 
        uint256[] memory _tokenIds, 
        address _bidTokenAddress
    ) external whenNotPaused {
        require(duration > 0, "Auction Duration should be greater than zero");
        require(_tokenAddresses.length == _tokenIds.length, "Mismatched token addresses and IDs");
        require(IERC20(_bidTokenAddress).balanceOf(msg.sender) >= initialAmount, "Insufficient bid token balance");

        // Transfer all tokens to the contract
        for (uint i = 0; i < _tokenAddresses.length; i++) {
            IERC721(_tokenAddresses[i]).transferFrom(msg.sender, address(this), _tokenIds[i]);
        }

        // Create a new auction
        auctions[nextAuctionId] = Auction({
            seller: payable(msg.sender),
            startTime: uint32(block.timestamp),
            endTime: uint32(block.timestamp) + duration,
            highestBidder: payable(address(0)),
            highestBid: initialAmount,
            bidderIncentive: 0,
            status: AuctionStatus.Open,
            tokenAddresses: _tokenAddresses,
            tokenIds: _tokenIds,
            bidTokenAddress: _bidTokenAddress
        });

        emit AuctionStarted(nextAuctionId, initialAmount, uint32(block.timestamp) + duration);
        activeAuctionIds.push(nextAuctionId);
        nextAuctionId++;
    }

    /**
     * @dev Allows pre-bidding before the auction officially opens.
     * @param auctionId The ID of the auction.
     * @param bidAmount The bid amount.
     * @param bidderIncentive The incentive for the bidder.
     */
    function preBid(uint256 auctionId, uint256 bidAmount, uint256 bidderIncentive) external payable whenNotPaused {
        Auction storage auction = auctions[auctionId];
        require(auction.status == AuctionStatus.Open, "Auction is already open for bidding");
        require(IERC20(auction.bidTokenAddress).transferFrom(msg.sender, address(this), bidAmount), "Token transfer failed");

        // Refund the previous highest bidder
        if (auction.highestBidder != address(0)) {
            IERC20(auction.bidTokenAddress).transfer(auction.highestBidder, auction.highestBid);
        }

        // Update auction details
        auction.highestBidder = payable(msg.sender);
        auction.highestBid = bidAmount;
        auction.bidderIncentive = bidderIncentive;
        auction.status = AuctionStatus.PreBid;

        emit BidPlaced(auctionId, msg.sender, bidAmount);
    }

    /**
     * @dev Opens the auction for public bidding.
     * @param auctionId The ID of the auction.
     */
    function openAuction(uint256 auctionId) external whenNotPaused {
        Auction storage auction = auctions[auctionId];
        require(block.timestamp >= auction.startTime + 10 minutes, "Auction can't be opened yet");
        require(auction.status == AuctionStatus.Open, "Auction is already open");

        auction.status = AuctionStatus.Open;
    }

    /**
     * @dev Allows users to bid on an open auction.
     * @param auctionId The ID of the auction.
     * @param bidAmount The bid amount.
     * @param bidderIncentive The incentive for the bidder.
     */
    function bid(uint256 auctionId, uint256 bidAmount, uint256 bidderIncentive) external payable whenNotPaused {
        Auction storage auction = auctions[auctionId];
        require(auction.status != AuctionStatus.Finalized, "Auction is Closed");
        require(block.timestamp <= auction.endTime, "Auction has already Ended");
        require(IERC20(auction.bidTokenAddress).transferFrom(msg.sender, address(this), bidAmount), "Token transfer failed");

        uint256 totalPreviousBid = auction.highestBid + auction.bidderIncentive;
        require(bidAmount > totalPreviousBid, "Total bid (including incentive) too low");

        if (block.timestamp < auction.endTime && block.timestamp > auction.endTime - 20 minutes) {
            auction.endTime += 20 minutes;
            auction.status = AuctionStatus.ExtraTime;
        }
        else {
            auction.status = AuctionStatus.Bid;
        }

        // Refund the previous highest bidder
        if (auction.highestBidder != address(0)) {
            IERC20(auction.bidTokenAddress).transfer(auction.highestBidder, auction.highestBid + auction.bidderIncentive);
        }

        // Update auction details
        auction.highestBidder = payable(msg.sender);
        auction.highestBid = bidAmount;
        auction.bidderIncentive = bidderIncentive;

        emit BidPlaced(auctionId, msg.sender, bidAmount);
    }

    /**
     * @dev Allows the seller to cancel the auction if no bids have been placed.
     * @param auctionId The ID of the auction.
     */
    function cancelAuction(uint256 auctionId) public {
        Auction storage auction = auctions[auctionId];
        require(msg.sender == auction.seller || msg.sender == owner(), "Only the seller or contract owner can cancel");
        require(auction.status == AuctionStatus.Open, "Auction has received bids and cannot be canceled");

        // Transfer all tokens back to the seller
        for (uint i = 0; i < auction.tokenAddresses.length; i++) {
            IERC721(auction.tokenAddresses[i]).transferFrom(address(this), auction.seller, auction.tokenIds[i]);
        }

        // Remove auction from active auctions
        for (uint i = 0; i < activeAuctionIds.length; i++) {
            if (activeAuctionIds[i] == auctionId) {
                activeAuctionIds[i] = activeAuctionIds[activeAuctionIds.length - 1];
                activeAuctionIds.pop();
                break;
            }
        }

        delete auctions[auctionId];

        emit AuctionCancelled(auctionId);
    }

    /**
     * @dev Finalizes the auction.
     * @param auctionId The ID of the auction.
     */
    function finalizeAuction(uint256 auctionId) external whenNotPaused nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.status == AuctionStatus.Open || auction.status == AuctionStatus.Bid, "Auction is not open yet");
        require(block.timestamp >= auction.endTime, "Auction has not Ended");
        require(auction.status != AuctionStatus.Finalized, "Auction is already completed and finalized");

        if (auction.highestBid == 0) {
            cancelAuction(auctionId);
            return;
        }

        auction.status = AuctionStatus.Finalized;

        uint256 fee = auction.highestBid * feePercentage / 10000;
        uint256 royalty = auction.highestBid * royaltyPercentage / 10000;
        uint256 sellerAmount = auction.highestBid - fee - royalty;

        payable(owner()).transfer(fee);
        royaltyRecipient.transfer(royalty);
        auction.seller.transfer(sellerAmount);

        // Transfer all tokens to the highest bidder
        for (uint i = 0; i < auction.tokenAddresses.length; i++) {
            IERC721(auction.tokenAddresses[i]).transferFrom(address(this), auction.highestBidder, auction.tokenIds[i]);
        }

        // Remove auction from active auctions
        for (uint i = 0; i < activeAuctionIds.length; i++) {
            if (activeAuctionIds[i] == auctionId) {
                activeAuctionIds[i] = activeAuctionIds[activeAuctionIds.length - 1];
                activeAuctionIds.pop();
                break;
            }
        }

        emit AuctionFinalized(auctionId, auction.highestBidder, auction.highestBid);
    }

    /**
     * @dev Failsafe function to cancel a specific auction by the contract owner.
     * @param auctionId The ID of the auction.
     */
    function cancelSpecificAuction(uint256 auctionId) public onlyOwner {
        Auction storage auction = auctions[auctionId];
        require(auction.seller != address(0), "Auction does not exist");

        if (auction.highestBidder != address(0)) {
            IERC20(auction.bidTokenAddress).transfer(auction.highestBidder, auction.highestBid);
        }

        for (uint i = 0; i < auction.tokenAddresses.length; i++) {
            IERC721(auction.tokenAddresses[i]).transferFrom(address(this), auction.seller, auction.tokenIds[i]);
        }

        // Remove auction from active auctions
        for (uint i = 0; i < activeAuctionIds.length; i++) {
            if (activeAuctionIds[i] == auctionId) {
                activeAuctionIds[i] = activeAuctionIds[activeAuctionIds.length - 1];
                activeAuctionIds.pop();
                break;
            }
        }

        delete auctions[auctionId];

        emit AuctionCancelled(auctionId);
    }

    /**
     * @dev Failsafe function to cancel all auctions.
     */
    function cancelAllAuctions() external onlyOwner {
        for (uint i = 0; i < activeAuctionIds.length; i++) {
            cancelSpecificAuction(activeAuctionIds[i]);
        }
    }

    /**
     * @dev Pauses the contract.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses the contract.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Returns the count of active auctions.
     * @return The count of active auctions.
     */
    function getActiveAuctionCount() external view returns (uint256) {
        return activeAuctionIds.length;
    }
}
