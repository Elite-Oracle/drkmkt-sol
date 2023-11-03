// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// EXTERNAL IMPORTS
import {ERC1155HolderUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import {ERC721HolderUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// INTERNAL IMPORTS
import {IDarkMarketAuction} from "./interfaces/IDarkMarketAuction.sol";
import {AddressBook} from "./lib/AddressBook.sol";

/// @title DarkMarketAuction
/// @author Elite Oracle | Kristian Peter
/// @notice This contract allows users to start, bid, and finalize auctions for a variety of ERC tokens (digital assets)
/// @custom:version 1.4.1
/// @custom:release November 2023
contract DarkMarketAuction is
    IDarkMarketAuction,
    Initializable,
    ERC1155HolderUpgradeable,
    ERC721HolderUpgradeable,
    AccessManagedUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    // =========================== //
    // STATE VARIABLES             //
    // All Inheritied By Interface //
    // =========================== //

    /*******************
     * Auction-related *
     *******************/

    uint256 public nextAuctionId;
    mapping(uint256 => Auction) internal auctions;

    /**
     * @notice Custom 'getter' function to return the Auction Details
     * @param auctionId The ID of the auction to get details for
     * @return seller The address of the seller
     * @return startTime The start time of the auction
     * @return endTime The end time of the auction
     * @return highestBidder The address of the highest bidder
     * @return highestBid The highest bid amount
     * @return bidderIncentive The incentive for the bidder
     * @return status The status of the auction
     * @return bidTokenAddress The address of the bid token
     * @return totalIncentives The total incentives for the auction
     */
    function getAuctionDetails(uint256 auctionId) external view override returns (
        address seller,
        uint32 startTime,
        uint32 endTime,
        address highestBidder,
        uint256 highestBid,
        uint256 bidderIncentive,
        AuctionStatus status,
        address bidTokenAddress,
        uint256 totalIncentives
    ) {
        Auction storage auction = auctions[auctionId];
        return (
            auction.seller,
            auction.startTime,
            auction.endTime,
            auction.highestBidder,
            auction.highestBid,
            auction.bidderIncentive,
            auction.status,
            auction.bidTokenAddress,
            auction.totalIncentives
        );
    }

    /**
     * @notice Custom 'getter' function to return the Token Details for a given auction
     * @param auctionId The ID of the auction to get token details for
     * @param tokenIndex The index of the token in the auction's token array
     * @return The details of the token at the given index
     */
    function getAuctionTokens(uint256 auctionId, uint256 tokenIndex) external view override returns (TokenDetail memory) {
        require(tokenIndex < auctions[auctionId].tokens.length, "Token index out of bounds");
        return auctions[auctionId].tokens[tokenIndex];
    }

    /*********************
     * Parameter-related *
     *********************/

    address public treasuryAddress; // Initialized in Address Book

    uint256 public minAuctionDuration;
    uint256 public maxAuctionDuration;
    uint256 public warmUpTime;
    uint32  public extraTime;
    uint256 public maxIncentive;
    uint256 public maxPayment;
    uint256 public maxAssets;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() initializer public {
        __ERC721Holder_init();
        __ERC1155Holder_init();
        __Pausable_init();
        __AccessManaged_init(AddressBook.accessManager());
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        // Set up Treasury
        treasuryAddress = AddressBook.treasury();

        nextAuctionId = 1;
        minAuctionDuration = 1 minutes;
        maxAuctionDuration = 12 weeks;
        warmUpTime = 0 minutes;
        extraTime = 0 minutes;
        maxIncentive = 12;
        maxPayment = 1000;
        maxAssets = 20;
    }

    // ============================
    // AUCTION FUNCTIONS
    // ============================

    /// @inheritdoc IDarkMarketAuction
    function startAuction(
        uint256 startPrice,
        uint32 duration,
        TokenDetail[] memory _tokens,
        address ERC20forBidding,
        FeeDetail memory _fees
    ) external whenNotPaused returns (uint256) {
        if (_tokens.length == 0 || _tokens.length > maxAssets)
            revert InvalidAAssetCount(_tokens.length, maxAssets);
        if (duration < minAuctionDuration || duration > maxAuctionDuration)
            revert InvalidAuctionDuration(
                duration,
                minAuctionDuration,
                maxAuctionDuration
            );
        if (_fees.contractFee > maxPayment)
            revert InvalidAuctionFeePercentage(_fees.contractFee, maxPayment);
        if (_fees.royaltyFee > maxPayment)
            revert InvalidAuctionFeePercentage(_fees.royaltyFee, maxPayment);

        // Initialize a new auction
        Auction storage newAuction = auctions[nextAuctionId];
        newAuction.seller = payable(msg.sender);
        newAuction.startTime = uint32(block.timestamp);
        newAuction.endTime = uint32(block.timestamp + duration);
        newAuction.highestBid = startPrice;
        newAuction.status = AuctionStatus.Open;
        newAuction.bidTokenAddress = ERC20forBidding;
        newAuction.fees = _fees;

        // Transfer each ERC721 or ERC1155 token to the contract
        for (uint i = 0; i < _tokens.length; i++) {
            if (_tokens[i].tokenType == TokenType.ERC721) {
        IERC721(_tokens[i].tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            _tokens[i].tokenId
        );
    } else if (_tokens[i].tokenType == TokenType.ERC1155) {
        IERC1155(_tokens[i].tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            _tokens[i].tokenId,
            _tokens[i].tokenQuantity,
            ""
        );
    }
        newAuction.tokens.push(_tokens[i]);
    }

        emit AuctionStarted(
            nextAuctionId,
            msg.sender,
            startPrice,
            newAuction.endTime
        );
        nextAuctionId++;

        return nextAuctionId - 1;
    }

    /// @inheritdoc IDarkMarketAuction
    function bid(
        uint256 auctionId,
        uint256 bidAmount,
        uint256 incentiveAmount
    ) external nonReentrant whenNotPaused {
        Auction storage auction = auctions[auctionId];

        if (block.timestamp > auction.endTime)
            revert AuctionEnded(block.timestamp, auction.endTime);
        if (bidAmount <= auction.highestBid)
            revert BidTooLow(bidAmount, auction.highestBid);
        if (incentiveAmount > (maxIncentive * bidAmount) / 100)
            revert IncentiveTooHigh(incentiveAmount, maxIncentive);

        IERC20 bidToken = IERC20(auction.bidTokenAddress);
        bidToken.transferFrom(msg.sender, address(this), bidAmount);

        // Check for extra time condition
        if (block.timestamp > auction.endTime - extraTime) {
            auction.endTime += extraTime;
            auction.status = AuctionStatus.ExtraTime;
        } else {
            auction.status = AuctionStatus.BidReceived;
        }

        // Refund previous bidder if applicable
        if (
            auction.highestBidder != address(0) &&
            block.timestamp >= auction.startTime + warmUpTime
        ) {
            uint256 refundAmount = auction.highestBid + auction.bidderIncentive;
            bidToken.transfer(auction.highestBidder, refundAmount);
            auction.totalIncentives += incentiveAmount;
            emit IncentiveReceived(
                auction.highestBidder,
                auction.bidderIncentive
            );
        } else if (auction.highestBidder != address(0)) {
            bidToken.transfer(auction.highestBidder, auction.highestBid);
        }

        // Update auction details
        auction.highestBidder = msg.sender;
        auction.highestBid = bidAmount;
        auction.bidderIncentive = incentiveAmount;

        emit BidPlaced(
            auctionId,
            auction.highestBidder,
            auction.highestBid,
            auction.bidderIncentive,
            auction.endTime
        );
    }

    /// @inheritdoc IDarkMarketAuction
    function finalizeAuction(
        uint256 auctionId ) external nonReentrant whenNotPaused {
        Auction storage auction = auctions[auctionId];
        if (block.timestamp < auction.endTime)
            revert AuctionNotEnded(block.timestamp, auction.endTime);

        // If there are no bids, cancel the auction.
        if (auction.highestBidder == address(0)) {
            cancelAuction(auctionId);
        }

        IERC20 bidToken = IERC20(auction.bidTokenAddress);
        uint256 auctionFee = auction.highestBid *
                (auction.fees.contractFee / 10000);
        uint256 auctionRoyalty = auction.highestBid *
                (auction.fees.royaltyFee / 10000);
        uint256 sellerAmount = auction.highestBid - auctionFee - auctionRoyalty - auction.totalIncentives;

        // If the caller is the seller
        if (msg.sender == auction.seller) {
            // Safely transfer winning bid to Seller minus incentives and fees
            safeTransfer(bidToken, auction.seller, sellerAmount);

            emit SellerFinalized(auctionId, auction.seller, sellerAmount);
        }

        // If the caller is the highest bidder
        if (msg.sender == auction.highestBidder) {
            // Safely transfer all auctioned tokens to the highest bidder
            for (uint i = 0; i < auction.tokens.length; i++) {
                if (auction.tokens[i].tokenType == TokenType.ERC721) {
                IERC721(auction.tokens[i].tokenAddress).safeTransferFrom(
                address(this),
                auction.highestBidder,
                auction.tokens[i].tokenId
                );
            } else if (auction.tokens[i].tokenType     == TokenType.ERC1155) {
            IERC1155(auction.tokens[i].tokenAddress).safeTransferFrom(
            address(this),
            auction.highestBidder,
            auction.tokens[i].tokenId,
            auction.tokens[i].tokenQuantity,
            ""
            );
            }
        }
            emit BidderFinalized(
                auctionId,
                auction.highestBidder,
                auction.highestBid
            );
        }

        // Safely transfer Fees to Treasury
        if (auctionFee > 0) {
            safeTransfer(bidToken, treasuryAddress, auctionFee);
        }

        // Safely transfer Royalty Fees to Creator
        if (auctionRoyalty > 0) {          
            safeTransfer(bidToken, auction.fees.royaltyAddress, auctionRoyalty);
        }
    }

    /// @inheritdoc IDarkMarketAuction
    function cancelSpecificAuction(uint256 auctionId) external restricted {
        if (auctionId >= nextAuctionId) revert InvalidAuction(auctionId);
        Auction storage auction = auctions[auctionId];

        if (auction.highestBidder != address(0)) {
            IERC20(auction.bidTokenAddress).transfer(
                auction.highestBidder,
                auction.highestBid - auction.totalIncentives
            );
        }

        for (uint i = 0; i < auction.tokens.length; i++) {
            IERC721(auction.tokens[i].tokenAddress).safeTransferFrom(
                address(this),
                auction.seller,
                auction.tokens[i].tokenId
            );
        }

        auction.status = AuctionStatus.Cancelled;

        emit AuctionCancelled(auctionId);
    }

    /// @inheritdoc IDarkMarketAuction
    function setMinAuctionDuration(uint32 _duration) external restricted {
        if (_duration < 1 minutes)
            revert InvalidAuctionDuration(
                _duration,
                1 minutes,
                maxAuctionDuration
            );
        minAuctionDuration = _duration;
        emit MinAuctionDurationUpdated(_duration);
    }

    /// @inheritdoc IDarkMarketAuction
    function setMaxAuctionDuration(uint32 _duration) external restricted {
        if (_duration > 52 weeks)
            revert InvalidAuctionDuration(
                _duration,
                maxAuctionDuration,
                52 weeks
            );
        maxAuctionDuration = _duration;
        emit MaxAuctionDurationUpdated(_duration);
    }

    /// @inheritdoc IDarkMarketAuction
    function setMaxAssets(uint16 _assets) external restricted {
        if (_assets > 100) revert InvalidAAssetCount(_assets, 100);
        maxAssets = _assets;
        emit MaxAssetsUpdated(_assets);
    }

    /// @inheritdoc IDarkMarketAuction
    function setMaxIncentive(uint16 _incentive) external restricted {
        if (_incentive >= 100) revert IncentiveTooHigh(_incentive, 99);
        maxIncentive = _incentive;
        emit MaxIncentiveUpdated(_incentive);
    }

    /// @inheritdoc IDarkMarketAuction
    function setWarmUpTime(uint32 _warmUp) external restricted {
        warmUpTime = _warmUp;
        emit WarmUpTimeUpdated(_warmUp);
    }

    /// @inheritdoc IDarkMarketAuction
    function setExtraTime(uint32 _extTime) external restricted {
        if (_extTime > 12 hours) revert InvalidExtraTime(_extTime, 12 hours);

        extraTime = _extTime;
        emit ExtraTimeUpdated(extraTime);
    }

    /// @inheritdoc IDarkMarketAuction
    function setMaxPayment(uint16 _maxPmt) external restricted {
        require(_maxPmt <= 1000, "Fees must be below 10%");
        maxPayment = _maxPmt;
        emit MaxPaymentUpdated(_maxPmt);
    }

    /// @inheritdoc IDarkMarketAuction
    function getAuctionStatus(
        uint256 auctionId
    ) external view returns (AuctionStatus) {
        return auctions[auctionId].status;
    }

    /// @inheritdoc IDarkMarketAuction
    function getAuctionEndTime(
        uint256 auctionId
    ) external view returns (uint32) {
        return auctions[auctionId].endTime;
    }

    /// @inheritdoc IDarkMarketAuction
    function cancelAuction(uint256 auctionId) public {
        Auction storage auction = auctions[auctionId];
        if (msg.sender != auction.seller)
            revert NotAuctionSeller(auction.seller, msg.sender);
        if (
            auction.status == AuctionStatus.Cancelled ||
            auction.status == AuctionStatus.Closed
        ) revert AuctionEnded(block.timestamp, auction.endTime);
        if (auction.status != AuctionStatus.Open) revert AuctionHasBids();

        // Transfer all tokens back to the seller
        for (uint i = 0; i < auction.tokens.length; i++) {
            IERC721(auction.tokens[i].tokenAddress).transferFrom(
                address(this),
                auction.seller,
                auction.tokens[i].tokenId
            );
        }

        auction.status = AuctionStatus.Cancelled;

        emit AuctionCancelled(auctionId);
    }


    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        try token.transfer(to, amount) {
            // Transfer successful
        } catch {
            // If transfer fails, revert to allow new attempted transfer to occur
            revert();
        }
    }

    // @dev Pause the contract
    function pause() external restricted {
        _pause();
    }

    // @dev UnPause (resume) the contract
    function unpause() external restricted {
        _unpause();
    }

    // @dev Authorize Updagrade Implementation
    function _authorizeUpgrade(
        address newImplementation
    ) internal override restricted {}

}
