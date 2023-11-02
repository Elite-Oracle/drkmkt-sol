// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// EXTERNAL IMPORTS
import {ERC1155HolderUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import {ERC721HolderUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {AccessManagerUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
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
    AccessManagerUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    // Access Manager for Contract //
    AccessManagerUpgradeable private accessManager;

    // =========================== //
    // STATE VARIABLES             //
    // All Inheritied By Interface //
    // =========================== //

    /*******************
     * Auction-related *
     *******************/

    uint256 private _nextAuctionId;
    /// @inheritdoc IDarkMarketAuction
    function nextAuctionId() external view override returns (uint256) {
        return _nextAuctionId;
    }

    mapping(uint256 => Auction) private _auctions;

    function auctions(
        uint256 auctionId
    ) external view override returns (Auction memory) {
        return _auctions[auctionId];
    }

    /*********************
     * Parameter-related *
     *********************/

    address private treasuryAddress; // Initialized in Address Book

    uint256 private _minAuctionDuration;
    /// @inheritdoc IDarkMarketAuction
    function minAuctionDuration() external view override returns (uint256) {
        return _minAuctionDuration;
    }

    uint256 private _maxAuctionDuration;

    function maxAuctionDuration() external view override returns (uint256) {
        return _maxAuctionDuration;
    }

    uint256 private _warmUpTime;

    function warmUpTime() external view override returns (uint256) {
        return _warmUpTime;
    }

    uint32 private _extraTime;

    function extraTime() external view override returns (uint32) {
        return _extraTime;
    }

    uint256 private _maxIncentive;

    function maxIncentive() external view override returns (uint256) {
        return _maxIncentive;
    }

    uint256 private _maxPayment;

    function maxPayment() external view override returns (uint256) {
        return _maxPayment;
    }

    uint256 private _maxAssets;

    function maxAssets() external view override returns (uint256) {
        return _maxAssets;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
        accessManager = AccessManagerUpgradeable(AddressBook.accessManager());
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

        _nextAuctionId = 1;
        _minAuctionDuration = 1 minutes;
        _maxAuctionDuration = 12 weeks;
        _warmUpTime = 0 minutes;
        _extraTime = 0 minutes;
        _maxIncentive = 12;
        _maxPayment = 1000;
        _maxAssets = 20;
    }

    function isAdmin() public view returns (bool) {
    // Assuming ADMIN_ROLE is a constant in AccessManagerUpgradeable and you want to check for the current contract
    (bool immediate,) = accessManager.canCall(msg.sender, address(this), this.isAdmin.selector);
    return immediate;
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
        if (_tokens.length == 0 || _tokens.length > _maxAssets)
            revert InvalidAAssetCount(_tokens.length, _maxAssets);
        if (duration < _minAuctionDuration || duration > _maxAuctionDuration)
            revert InvalidAuctionDuration(
                duration,
                _minAuctionDuration,
                _maxAuctionDuration
            );
        if (_fees.contractFee > _maxPayment)
            revert InvalidAuctionFeePercentage(_fees.contractFee, _maxPayment);
        if (_fees.royaltyFee > _maxPayment)
            revert InvalidAuctionFeePercentage(_fees.royaltyFee, _maxPayment);

        // Initialize a new auction
        Auction storage newAuction = _auctions[_nextAuctionId];
        newAuction.seller = payable(msg.sender);
        newAuction.startTime = uint32(block.timestamp);
        newAuction.endTime = uint32(block.timestamp + duration);
        newAuction.highestBid = startPrice;
        newAuction.status = AuctionStatus.Open;
        newAuction.bidTokenAddress = ERC20forBidding;
        newAuction.fees = _fees;

        // Transfer each ERC721 token to the contract
        for (uint i = 0; i < _tokens.length; i++) {
            IERC721(_tokens[i].tokenAddress).safeTransferFrom(
                msg.sender,
                address(this),
                _tokens[i].tokenId
            );
            newAuction.tokens.push(_tokens[i]);
        }

        emit AuctionStarted(
            _nextAuctionId,
            msg.sender,
            startPrice,
            newAuction.endTime
        );
        _nextAuctionId++;

        return _nextAuctionId - 1;
    }

    /// @inheritdoc IDarkMarketAuction
    function bid(
        uint256 auctionId,
        uint256 bidAmount,
        uint256 incentiveAmount
    ) external nonReentrant whenNotPaused {
        Auction storage auction = _auctions[auctionId];

        if (block.timestamp > auction.endTime)
            revert AuctionEnded(block.timestamp, auction.endTime);
        if (bidAmount <= auction.highestBid)
            revert BidTooLow(bidAmount, auction.highestBid);
        if (incentiveAmount > (_maxIncentive * bidAmount) / 100)
            revert IncentiveTooHigh(incentiveAmount, _maxIncentive);

        IERC20 bidToken = IERC20(auction.bidTokenAddress);
        bidToken.transferFrom(msg.sender, address(this), bidAmount);

        // Check for extra time condition
        if (block.timestamp > auction.endTime - _extraTime) {
            auction.endTime += _extraTime;
            auction.status = AuctionStatus.ExtraTime;
        } else {
            auction.status = AuctionStatus.BidReceived;
        }

        // Refund previous bidder if applicable
        if (
            auction.highestBidder != address(0) &&
            block.timestamp >= auction.startTime + _warmUpTime
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
        uint256 auctionId
    ) external nonReentrant whenNotPaused {
        Auction storage auction = _auctions[auctionId];
        if (block.timestamp < auction.endTime)
            revert AuctionNotEnded(block.timestamp, auction.endTime);

        // If there are no bids, cancel the auction.
        if (auction.highestBidder == address(0)) {
            cancelAuction(auctionId);
        }

        IERC20 bidToken = IERC20(auction.bidTokenAddress);

        // If the caller is the seller
        if (msg.sender == auction.seller) {
            uint256 fee = auction.highestBid *
                (auction.fees.contractFee / 10000);
            uint256 royalty = auction.highestBid *
                (auction.fees.royaltyFee / 10000);
            uint256 sellerAmount = auction.highestBid -
                fee -
                royalty -
                auction.totalIncentives;

            // Safely transfer winning bid to Seller minus incentives and fees
            safeTransfer(bidToken, auction.seller, sellerAmount);

            emit SellerFinalized(auctionId, auction.seller, sellerAmount);
        }

        // If the caller is the highest bidder
        if (msg.sender == auction.highestBidder) {
            // Safely transfer all auctioned tokens to the highest bidder
            for (uint i = 0; i < auction.tokens.length; i++) {
                IERC721(auction.tokens[i].tokenAddress).safeTransferFrom(
                    address(this),
                    auction.highestBidder,
                    auction.tokens[i].tokenId
                );
            }

            emit BidderFinalized(
                auctionId,
                auction.highestBidder,
                auction.highestBid
            );
        }

        // If the caller is the ADMIN
        if (isAdmin()) {
            uint256 fee = auction.highestBid *
                (auction.fees.contractFee / 10000);
            uint256 royalty = auction.highestBid *
                (auction.fees.royaltyFee / 10000);

            // Safely transfer Fees to Treasury
            safeTransfer(bidToken, treasuryAddress, fee);

            // Safely transfer Royalty Fees to Creator
            safeTransfer(bidToken, auction.fees.royaltyAddress, royalty);

            emit AuctionFinalized(
                auctionId,
                fee,
                auction.fees.royaltyAddress,
                royalty
            );
        }
    }

    /// @inheritdoc IDarkMarketAuction
    function cancelSpecificAuction(uint256 auctionId) external restricted {
        if (auctionId >= _nextAuctionId) revert InvalidAuction(auctionId);
        Auction storage auction = _auctions[auctionId];

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
                _maxAuctionDuration
            );
        _minAuctionDuration = _duration;
        emit MinAuctionDurationUpdated(_duration);
    }

    /// @inheritdoc IDarkMarketAuction
    function setMaxAuctionDuration(uint32 _duration) external restricted {
        if (_duration > 52 weeks)
            revert InvalidAuctionDuration(
                _duration,
                _minAuctionDuration,
                52 weeks
            );
        _maxAuctionDuration = _duration;
        emit MaxAuctionDurationUpdated(_duration);
    }

    /// @inheritdoc IDarkMarketAuction
    function setMaxAssets(uint16 _assets) external restricted {
        if (_assets > 100) revert InvalidAAssetCount(_assets, 100);
        _maxAssets = _assets;
        emit MaxAssetsUpdated(_assets);
    }

    /// @inheritdoc IDarkMarketAuction
    function setMaxIncentive(uint16 _incentive) external restricted {
        if (_incentive >= 100) revert IncentiveTooHigh(_incentive, 99);
        _maxIncentive = _incentive;
        emit MaxIncentiveUpdated(_incentive);
    }

    /// @inheritdoc IDarkMarketAuction
    function setWarmUpTime(uint32 _warmUp) external restricted {
        _warmUpTime = _warmUp;
        emit WarmUpTimeUpdated(_warmUp);
    }

    /// @inheritdoc IDarkMarketAuction
    function setExtraTime(uint32 _extTime) external restricted {
        if (_extTime > 12 hours) revert InvalidExtraTime(_extTime, 12 hours);

        _extraTime = _extTime;
        emit ExtraTimeUpdated(_extraTime);
    }

    /// @inheritdoc IDarkMarketAuction
    function setMaxPayment(uint16 _maxPmt) external restricted {
        require(_maxPmt <= 1000, "Fees must be below 10%");
        _maxPayment = _maxPmt;
        emit MaxPaymentUpdated(_maxPmt);
    }

    /// @inheritdoc IDarkMarketAuction
    function getAuctionStatus(
        uint256 auctionId
    ) external view returns (AuctionStatus) {
        return _auctions[auctionId].status;
    }

    /// @inheritdoc IDarkMarketAuction
    function getAuctionEndTime(
        uint256 auctionId
    ) external view returns (uint32) {
        return _auctions[auctionId].endTime;
    }

    /// @inheritdoc IDarkMarketAuction
    function cancelAuction(uint256 auctionId) public {
        Auction storage auction = _auctions[auctionId];
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
