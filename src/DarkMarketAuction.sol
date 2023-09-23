// Dark Market Auction Contract v1.2
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
import "../lib/drkmkt/LibBinarySearchTree.sol";

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

    // Represents the Contract Fees for every auction
    struct FeeDetail {
        uint256 contractFee; // Fee charged for auction
        uint256 royaltyFee; // Royalty Fee
        address royaltyAddress; // Token Creator
    }

    // Represents an auction for ERC721 tokens
    struct Auction {
        address payable seller;           // Address of the seller
        uint32 startTime;                 // Start time of the auction
        uint32 endTime;                   // End time of the auction
        address highestBidder;            // Address of the current highest bidder
        uint256 highestBid;               // Amount of the current highest bid
        uint256 bidderIncentive;          // Incentive for the bidder
        AuctionStatus status;             // Status of the auction (Open, PreBid, Bid, ExtraTime, Finalized)
        TokenDetail[] tokens;         // Array of ERC721 tokens
        address bidTokenAddress;          // ERC20 token address used for bidding
        uint256 totalIncentives;    // Total incentives paid to bidders who are outbid
        FeeDetail fees;           // Array of fees for contract and royalties
    }

    // Represents the status of an auction
    enum AuctionStatus {
        Open,
        BidReceived,
        ExtraTime,
        Finalized
    }

    LibBinarySearchTree.Tree public activeAuctionIds; // Tree to store active auction IDs
    uint256 public nextAuctionId = 1; // Counter for the next auction ID
    uint32 public feePercentage; // Fee percentage for the platform
    uint32 public royaltyPercentage; // Royalty percentage for the creator
    address payable public royaltyRecipient; // Address to receive the royalty

    // Extra time added to the auction if a bid is placed in the last 20 minutes.
    // This helps prevent auction sniping and gives other participants a chance to place their bids.
    uint32 constant EXTRA_TIME = 20 minutes;

    // The maximum payment paid out of the auction is 10% and this is represented by 10^3.
    uint16 constant MAX_PAYMENT = 1000;

    mapping(uint256 => Auction) public auctions; // Mapping from auction ID to its details

    // Event emitted when an auction starts
    event AuctionStarted(uint256 auctionId, address seller, uint256 startPrice, uint32 endTime);
    // Event emitted when a bid is placed
    event BidPlaced(uint256 auctionId, address bidder, uint256 amount);
    // Event emitted when an auction is finalized
    event AuctionFinalized(uint256 auctionId, address winner, uint256 amount);
    // Event emitted when an auction is cancelled
    event AuctionCancelled(uint256 auctionId);
    // Event emitted when an incentive is given to a bidder
    event IncentiveReceived(address indexed bidder, uint256 amount);
    // Event emitted when extra time is added to the auction due to a bid in the final 20 minutes.
    event ExtraTimeAdded(uint256 auctionId, address bidder, uint32 newEndTime);

    // TEST LOGS
    event Log(string logging);
    event LogInt(string logging, uint256 num);


/**
 * @dev Starts an auction by transferring the ERC721 tokens into the contract.
 * @param startPrice The starting price for the auction.
 * @param duration The duration of the auction in seconds (86,400 = 1 day).
 * @param _tokens The array of TokenDetail containing the ERC721 contract addresses and token IDs.
 * @param ERC20forBidding The address of the ERC20 token used for bidding.
 * @param _fees The fees and address for royalties.
 */
    function startAuction(
        uint256 startPrice,
        uint32 duration,
        TokenDetail[] memory _tokens, 
        address ERC20forBidding,
        FeeDetail[] memory _fees
    ) external whenNotPaused returns (uint256) {
        // The must be at least 1 and less than 30 assets total in the auction.
        require(_tokens.length > 0 && _tokens.length < 30, "At least one token required and less than 30 total assets");
        // The auction must be at least 10 minutes.
        require (duration > 10 minutes, "The auction must be longer than 10 minutes.");

    // Require Fees and Royalties to not exceed 10%
    require(_fees[0].contractFee <= MAX_PAYMENT, "Fee percentage too high");
    require(_fees[0].royaltyFee <= MAX_PAYMENT, "Royalty percentage too high");

    // Transfer each ERC721 token. Originally required Approval check but contract will revert if the tokens are not approved and additional checks require additional Gas, removed for efficiency.
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
    newAuction.fees.contractFee = _fees[0].contractFee;
    newAuction.fees.royaltyFee = _fees[0].royaltyFee;
    newAuction.fees.royaltyAddress = _fees[0].royaltyAddress;


    // Add tokens to the auction
    for (uint i = 0; i < _tokens.length; i++) {
        newAuction.tokens.push(_tokens[i]);
    }

        emit AuctionStarted(nextAuctionId, msg.sender,     startPrice, newAuction.endTime);
        LibBinarySearchTree.insert(activeAuctionIds,       nextAuctionId, nextAuctionId);
        nextAuctionId++;

        // Return the auctionId
        return nextAuctionId - 1;
    }

    /**
    * @dev Calculate the incentive for a bidder based on their bid amount and the current highest bid.
    * @param bidAmount The amount of the new bid.
    * @param highestBid The amount of the current highest bid.
    * @return The incentive amount for the bidder.
    */
    function calculateIncentive(uint256 bidAmount, uint256 highestBid) public returns (uint256) {
    // Ensure the new bid is higher than the current highest bid
    require(bidAmount > highestBid, "Current bid is less than previous bid");
emit LogInt("Calculate Highest Bid = ", highestBid);
emit LogInt("Calc Current Bid = ", bidAmount);
    // Constants scaled up by 10^18 for Solidity Gwei token representation
    uint256 scale = 10**18; // 10^18 for Ether

    // If there's no previous bid, return an 11% incentive of the opening bid
    if (highestBid == 0) {
        return bidAmount * 11 / 100;
    } 

    // Calculate the percentage by which the new bid exceeds the highest bid
    uint256 overbidPercentage = (bidAmount * scale / highestBid) - scale;
emit LogInt("Calculate OverBid = ", overbidPercentage);
    uint256 incentivePercentage;

    // Determine the incentive percentage based on the overbid percentage
    if (overbidPercentage < 20 * scale / 100) {
        incentivePercentage = 2 * scale / 100; // 2%
        emit LogInt("Calculate Less than 2% = ", incentivePercentage);
    } else if (overbidPercentage >= 110 * scale / 100) {
        incentivePercentage = 12 * scale / 100; // 12%
        emit LogInt("Calculate Over 12% = ", incentivePercentage);
    } else {
        // Calculate the base incentive of 2% and add 1% for every 10% overbid starting from 20%
        incentivePercentage = 2 * scale / 100 + ((overbidPercentage - 20 * scale / 100) / (10 * scale / 100));
        emit LogInt("Calculate between 2% to 12% = ", incentivePercentage);
    }

    // Calculate the incentive amount based on the determined incentive percentage
        emit LogInt("Calculate bidAmount = ", bidAmount);
        emit LogInt("Calculate scale = ", scale);
        emit LogInt("Calculate Returning = ", bidAmount * incentivePercentage / scale);
    return bidAmount * incentivePercentage / scale;
    }


    /**
    * @dev Function bid - allow users to Bid on Auction
    * @param auctionId The ID of the auction.
    * @param bidAmount The bid amount.
    */
    function bid(uint256 auctionId, uint256 bidAmount) external nonReentrant whenNotPaused {
        // TEST LOG
emit Log("Starting Bid Function...");

        Auction storage auction = auctions[auctionId];
        require(auction.status != AuctionStatus.Finalized && block.timestamp <= auction.endTime, "Auction has Ended");
        // Ensure the bid amount is greater than the current highest bid
        require(bidAmount > auction.highestBid, "Bid amount must be greater than the current highest bid");

        IERC20 bidToken = IERC20(auction.bidTokenAddress); // the token used to bid on this auction
        uint32 warmUpTime = 10 minutes; // the time required to elapse before incentives are rewarded to bidders

    // Transfer the bid amount from the bidder to the contract
    require(bidToken.transferFrom(msg.sender, address(this), bidAmount), "Token transfer failed");

    // Calculate the Incentive for the current Bidder
    uint256 incentive = calculateIncentive(bidAmount, auction.highestBid);

    // Extra Time to Bid if a bid is placed in the final 20 minutes before the auction ends
    if (block.timestamp > auction.endTime - EXTRA_TIME) {
        auction.endTime += EXTRA_TIME;
        auction.status = AuctionStatus.ExtraTime;
        emit ExtraTimeAdded(auctionId, msg.sender, auction.endTime);
    } else {auction.status = AuctionStatus.BidReceived;}

    // If there is a Previous Bidder, refund the previous bidder and pay the incentive if the auction has been started for at least 10 minutes. The 10 minute 'warmUpTime' is to reduce botting and ensure fair bidding for all bidders
    if (auction.highestBidder != address(0) && block.timestamp >= auction.startTime + warmUpTime) {
        IERC20(auction.bidTokenAddress).transfer(auction.highestBidder, auction.highestBid + auction.bidderIncentive);
        auction.totalIncentives += incentive;
        emit IncentiveReceived(auction.highestBidder, incentive);
    } else if (auction.highestBidder != address(0)) {
        IERC20(auction.bidTokenAddress).transfer(auction.highestBidder, auction.highestBid);
    }

    // Update auction details
    auction.highestBidder = msg.sender;
    auction.highestBid = bidAmount;
    auction.bidderIncentive = incentive;

//emit LogInt("BIDDING Contract Balance = ", bidToken.balanceOf(address(this)));
//emit LogInt("BIDDING Total Incentives = ", auction.totalIncentives);
//emit LogInt("BIDDING Highest Bid = ", auction.highestBid);

    emit BidPlaced(auctionId, msg.sender, bidAmount);
    }

    /**
     * @dev Allows the Seller to cancel the auction if no bids have been placed.
     * @param auctionId The ID of the auction.
     */
    function cancelAuction(uint256 auctionId) public {
        Auction storage auction = auctions[auctionId];
        require(msg.sender == auction.seller || msg.sender == owner() || msg.sender == address(this), "Auctions can only be Cancelled by the Seller");
        require(auction.status == AuctionStatus.Open, "Auction has received bids and cannot be canceled");

        // Transfer all tokens back to the seller
        for (uint i = 0; i < auction.tokens.length; i++) {
            IERC721(auction.tokens[i].tokenAddress).transferFrom(
                address(this),
                auction.seller,
                auction.tokens[i].tokenId
            );
        }

        // Remove auction from active auctions
        LibBinarySearchTree.remove(activeAuctionIds, auctionId, auctionId);

        delete auctions[auctionId];

        emit AuctionCancelled(auctionId);
    }

    /*
    * @dev Finalizes the auction and transfers the ERC721 tokens to the highest bidder. Calculates the transfers for Fees, Royalties, and Seller minus the Incentives paid out. 
    * @param auctionId The ID of the auction.
    */
    function finalizeAuction(uint256 auctionId) external whenNotPaused nonReentrant {
    Auction storage auction = auctions[auctionId];
    require(auction.status == AuctionStatus.Open || auction.status == AuctionStatus.BidReceived || auction.status == AuctionStatus.ExtraTime, "Auction Status not approved to End");
    require(block.timestamp >= auction.endTime, "Auction has not Ended");
    require(auction.status != AuctionStatus.Finalized, "Auction is already completed and finalized");
       IERC20 bidToken = IERC20(auction.bidTokenAddress);
       uint256 contractBalance = bidToken.balanceOf(address(this));
       require(
           contractBalance >= auction.highestBid - auction.totalIncentives,
           "Contract doesn't have enough funds to finalize the auction MANNNN"
       );
emit LogInt("Checked contract balance for:", auction.highestBid);

    uint256 initialBalance = bidToken.balanceOf(address(this));
    emit LogInt("Initial Contract Balance", initialBalance);


        // TEST LOG
emit LogInt("FINAL Auction Highest Bid = ", auction.highestBid);
emit LogInt("FINAL Contract Balance = ", bidToken.balanceOf(address(this)));
emit LogInt("FINAL Total Incentives = ", auction.totalIncentives);

    // If there are No Bids, cancel the auction
    if (auction.highestBid == 0) {
        cancelAuction(auctionId);
        return;
    }

    // Update Auction Status to Finalized
    auction.status = AuctionStatus.Finalized;

    // Transfer Fees and Royalties
    uint256 fee = auction.highestBid * (auction.fees.contractFee / 10000);
    uint256 royalty = auction.highestBid * (auction.fees.royaltyFee / 10000);
    uint256 sellerAmount = auction.highestBid - fee - royalty - auction.totalIncentives;

emit LogInt("Calculated Fee", fee);
emit LogInt("Calculated Royalty", royalty);
emit LogInt("Calculated Seller Amount", sellerAmount);

    if (fee > 0) {
        bidToken.transfer(owner(), fee);
    }

    if (royalty > 0) {
        bidToken.transfer(royaltyRecipient, royalty);
    }
    // Transfer winning bid to Seller minus incentives and fees
    bidToken.transfer(auction.seller, sellerAmount);

    // Transfer all auctioned tokens to the highest bidder
    for (uint i = 0; i < auction.tokens.length; i++) {
        IERC721(auction.tokens[i].tokenAddress).safeTransferFrom(address(this), auction.highestBidder, auction.tokens[i].tokenId);
    }

    // Remove auction from active auctions
    LibBinarySearchTree.remove(activeAuctionIds, auctionId, auctionId);

    delete auctions[auctionId];

uint256 finalBalance = bidToken.balanceOf(address(this));
emit LogInt("Final Contract Balance", finalBalance);

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
        IERC721(auction.tokens[i].tokenAddress).safeTransferFrom(address(this), auction.seller, auction.tokens[i].tokenId);
    }

    // Remove auction from active auctions
    LibBinarySearchTree.remove(activeAuctionIds, auctionId, auctionId);

    delete auctions[auctionId];

    emit AuctionCancelled(auctionId);
    }

    /**
    * @dev Failsafe function to cancel all auctions.
    */
    function cancelAllAuctions(uint256 limit) external onlyOwner {
        for (uint i = 0; i < limit; i++) {
        // Get the first auctionId from the activeAuctionIds tree.
            (, uint auctionId) = LibBinarySearchTree.keyValueAtRank(activeAuctionIds, 0);
            if (auctionId == 0) {
            break;  // No more auctions to cancel
            }
            cancelSpecificAuction(auctionId);
        }
    }


    /**
    * @dev Get auctions that are still active.
    */
    function getActiveAuctions(uint256 start, uint256 limit) external view returns (Auction[] memory) {
    // Ensure the limit doesn't exceed the number of active auctions.
        uint256 activeAuctionCount = LibBinarySearchTree.count(activeAuctionIds);

        if (start + limit > activeAuctionCount) {
        limit = activeAuctionCount - start;
        }

        require(limit > 0, "No active auctions");

        Auction[] memory activeAuctions = new Auction[](limit);

    // Get the first auctionId from the activeAuctionIds tree starting at start.
        (uint value, uint auctionId) = LibBinarySearchTree.keyValueAtRank(activeAuctionIds, start);
        activeAuctions[0] = auctions[auctionId];

    // Start from i = 1 since the first auction is already fetched.
        for (uint256 i = 1; i < limit; i++) {
            auctionId = LibBinarySearchTree.next(activeAuctionIds, auctionId, value);  // Update the auctionId for the next iteration
            activeAuctions[i] = auctions[auctionId];
        }

        return activeAuctions;
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
        return LibBinarySearchTree.count(activeAuctionIds);
    }

    /**
    * @dev Returns the end time of the auction.
    * @return The end time of the current auction.
    */
    function getAuctionEndTime(uint256 auctionId) external view returns (uint32) {
    return auctions[auctionId].endTime;
    }

    /** This function gets executed if a transaction with invalid data is sent to the contract or just ether without data. We revert the send in both cases.
    */
    fallback() external payable {
        revert("DarkMarketAuction: Invalid or unexpected call");
    }
    // Function to receive Ether. msg.data must be empty
    receive() external payable {
        revert("DarkMarketAuction: Ether not accepted");
    }

}
