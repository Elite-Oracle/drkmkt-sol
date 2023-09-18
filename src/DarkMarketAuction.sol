// Dark Market Auction Contract v1.1
// @dev Elite Oracle | Kristian Peter
// @date September 2023

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../node_modules/@openzeppelin/contracts/security/Pausable.sol";
import "../node_modules/@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DarkMarketAuction
 * @dev This contract allows users to start and bid on auctions for ERC721 tokens.
 */
contract DarkMarketAuction is ERC721Holder, Ownable, Pausable, ReentrancyGuard {
    
    // Represents the Contract Address and Token ID for every ERC721 token
    struct TokenDetail {
        address tokenAddress;
        uint256 tokenId;
    }

    // Represents an auction for ERC721 tokens
    struct Auction {
        address payable seller;           // Address of the seller
        uint32 startTime;                 // Start time of the auction
        uint32 endTime;                   // End time of the auction
        address payable highestBidder;    // Address of the current highest bidder
        uint256 highestBid;               // Amount of the current highest bid
        uint256 bidderIncentive;          // Incentive for the bidder
        AuctionStatus status;             // Status of the auction (Open, PreBid, Bid, ExtraTime, Finalized)
        TokenDetail[] tokens;         // Array of ERC721 tokens
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
    uint256 public totalIncentives; // Total incentives paid to bidders

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
 * @dev Starts an auction by transferring the ERC721 tokens into the contract.
 * @param startPrice The starting price for the auction.
 * @param duration The duration of the auction in seconds (86,400 = 1 day).
 * @param _tokens The array of TokenDetail containing the ERC721 contract addresses and token IDs.
 * @param ERC20forBidding The address of the ERC20 token used for bidding.
 */
function startAuction(
    uint256 startPrice,
    uint32 duration,
    TokenDetail[] memory _tokens, 
    address ERC20forBidding
) external whenNotPaused {
    require(_tokens.length > 0, "At least one token required");

    // Ensure the contract is approved to transfer each ERC721 token
    for (uint i = 0; i < _tokens.length; i++) {
        require(
            IERC721(_tokens[i].tokenAddress).getApproved(_tokens[i].tokenId) == address(this) || 
            IERC721(_tokens[i].tokenAddress).isApprovedForAll(msg.sender, address(this)),
            "Contract not approved to transfer this token"
        );
    }

    // Transfer all tokens to the contract
    for (uint i = 0; i < _tokens.length; i++) {
        IERC721(_tokens[i].tokenAddress).safeTransferFrom(msg.sender, address(this), _tokens[i].tokenId);
    }

    // Create a new auction
    Auction storage newAuction = auctions[nextAuctionId];
    newAuction.seller = payable(msg.sender);
    newAuction.startTime = uint32(block.timestamp);
    newAuction.endTime = uint32(block.timestamp + duration);
    newAuction.highestBid = startPrice;
    newAuction.status = AuctionStatus.Open;
    newAuction.bidTokenAddress = ERC20forBidding;

    // Add tokens to the auction
    for (uint i = 0; i < _tokens.length; i++) {
        newAuction.tokens.push(_tokens[i]);
    }

    emit AuctionStarted(nextAuctionId, startPrice, newAuction.endTime);
    activeAuctionIds.push(nextAuctionId);
    nextAuctionId++;
}


    /**
     * @dev Allows pre-bidding before the auction officially opens. This function was created to discourage 'Botting' so that no auction can be front-run in order to generate outbid incentives until after 10 minutes have elapsed.
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
        require(block.timestamp >= auction.startTime + 10 minutes, "Auction must wait 10 minutes prior to being opened");
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
            totalIncentives += auction.bidderIncentive;
        }

        // Update auction details
        auction.highestBidder = payable(msg.sender);
        auction.highestBid = bidAmount;
        auction.bidderIncentive = bidderIncentive;

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
        for (uint i = 0; i < auction.tokens.length; i++) {
            IERC721(auction.tokens[i].tokenAddress).transferFrom(address(this), auction.seller, auction.tokens[i].tokenId);
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

    /*
    * @dev Finalizes the auction and transfers the ERC721 tokens to the highest bidder. Calculates the transfers for Fees, Royalties, and Seller minus the Incentives paid out. 
    * @param auctionId The ID of the auction.
    */
    function finalizeAuction(uint256 auctionId) external whenNotPaused nonReentrant {
    Auction storage auction = auctions[auctionId];
    require(auction.status == AuctionStatus.Open || auction.status == AuctionStatus.Bid, "Auction is not open yet");
    require(block.timestamp >= auction.endTime, "Auction has not Ended");
    require(auction.status != AuctionStatus.Finalized, "Auction is already completed and finalized");

    IERC20 bidToken = IERC20(auction.bidTokenAddress);
    uint256 contractBalance = bidToken.balanceOf(address(this));
    require(contractBalance >= auction.highestBid - totalIncentives, "Contract doesn't have enough funds to finalize the auction");

    if (auction.highestBid == 0) {
        cancelAuction(auctionId);
        return;
    }

    auction.status = AuctionStatus.Finalized;
    uint256 fee = auction.highestBid * feePercentage / 10000;
    uint256 royalty = auction.highestBid * royaltyPercentage / 10000;
    uint256 sellerAmount = auction.highestBid - fee - royalty - totalIncentives;

    if (fee > 0) {
        payable(owner()).transfer(fee);
    }

    if (royalty > 0) {
        royaltyRecipient.transfer(royalty);
    }

    bidToken.transfer(auction.seller, sellerAmount);

    // Transfer all auctioned tokens to the highest bidder
    for (uint i = 0; i < auction.tokens.length; i++) {
        IERC721(auction.tokens[i].tokenAddress).safeTransferFrom(address(this), auction.highestBidder, auction.tokens[i].tokenId);
    }

    // Remove the auctionId from the activeAuctionIds array
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

        for (uint i = 0; i < auction.tokens.length; i++) {
            IERC721(auction.tokens[i].tokenAddress).safeTransferFrom(address(this), auction.highestBidder, auction.tokens[i].tokenId);
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

// TESTING
    function getAuctionEndTime(uint256 auctionId) external view returns (uint32) {
    return auctions[auctionId].endTime;
    }

}
