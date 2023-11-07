// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/ContextUpgradable, Initializable)

pragma solidity ^0.8.20;

import {ContextUpgradeable} from  "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {IDarkMarketAuctionStructures} from  "./interfaces/IDarkMarketAuctionStructures.sol";

/**
 * @dev Abstract Contract to store State Variables
 */
abstract contract DarkMarketAuctionStorage is Initializable, ContextUpgradeable {
    /// @custom:storage-location erc7201:openzeppelin.storage.DarkMarketAuction
    struct DMAStorage {
        uint256 _nextAuctionId;
        uint256 _minAuctionDuration;
        uint256 _maxAuctionDuration;
        uint256 _warmUpTime;
        uint256 _maxIncentive;
        uint256 _maxPayment;
        uint256 _maxAssets;
        uint256 _extraTime;
        address _treasury;
        mapping(uint256 => IDarkMarketAuctionStructures.Auction) _auctions;
    }

    // keccak256(abi.encode(uint256(keccak256("elite-oracle.storage.DarkMarketAuction")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant DMAStorageLocation = 0x27b49f3b53a795769950b1f0d5678148bbca7c47eb1e64956b2aa849760b9a00;

    function _getDMAStorage() private pure returns (DMAStorage storage $) {
        assembly {
            $.slot := DMAStorageLocation
        }
    }

    /**
     * @dev Initializes the contract storage.
     */
    function __DMAStorage_init() internal onlyInitializing {
        DMAStorage storage $ = _getDMAStorage();
        $._nextAuctionId = 1;
        $._minAuctionDuration = 1 minutes;
        $._maxAuctionDuration = 12 weeks;
        $._warmUpTime = 0 minutes;
        $._extraTime = 0 minutes;
        $._maxIncentive = 12;
        $._maxPayment = 1000;
        $._maxAssets = 20;
        $._treasury = 0x419C3657532aaD16955291AF7942fea9A1b6d010;
    }

    /**
     * @notice Custom 'getter' function to return the Token Details for a given auction
     * @param auctionId_ The ID of the auction to get token details for
     * @return The details of the token at the given index
     */
    function getAuction(uint256 auctionId_) public view returns (IDarkMarketAuctionStructures.Auction memory) {
        DMAStorage storage $ = _getDMAStorage();
        return $._auctions[auctionId_];
    }

    function nextAuctionId() public view returns (uint256) {
        DMAStorage storage $ = _getDMAStorage();
        return $._nextAuctionId;
    }

    function minAuctionDuration() public view returns (uint256) {
        DMAStorage storage $ = _getDMAStorage();
        return $._minAuctionDuration;
    }

    function maxAuctionDuration() public view returns (uint256) {
        DMAStorage storage $ = _getDMAStorage();
        return $._maxAuctionDuration;
    }

    function warmUpTime() public view returns (uint256) {
        DMAStorage storage $ = _getDMAStorage();
        return $._warmUpTime;
    }

    function maxIncentive() public view returns (uint256) {
        DMAStorage storage $ = _getDMAStorage();
        return $._maxIncentive;
    }

    function maxPayment() public view returns (uint256) {
        DMAStorage storage $ = _getDMAStorage();
        return $._maxPayment;
    }

    function maxAssets() public view returns (uint256) {
        DMAStorage storage $ = _getDMAStorage();
        return $._maxAssets;
    }

    function extraTime() public view returns (uint256) {
        DMAStorage storage $ = _getDMAStorage();
        return $._extraTime;
    }

    function treasury() public view returns (address) {
        DMAStorage storage $ = _getDMAStorage();
        return $._treasury;
    }

    function _setTreasury(address treasury_) internal {
        DMAStorage storage $ = _getDMAStorage();
        $._treasury = treasury_;
    }

    function _setNextAuctionId(uint256 nextAuctionId_) internal {
        DMAStorage storage $ = _getDMAStorage();
        $._nextAuctionId = nextAuctionId_;
    }

    function _setMinAuctionDuration(uint256 minAuctionDuration_) internal {
        DMAStorage storage $ = _getDMAStorage();
        $._minAuctionDuration = minAuctionDuration_;
    }

    function _setMaxAuctionDuration(uint256 maxAuctionDuration_) internal {
        DMAStorage storage $ = _getDMAStorage();
        $._maxAuctionDuration = maxAuctionDuration_;
    }

    function _setWarmUpTime(uint256 warmUpTime_) internal {
        DMAStorage storage $ = _getDMAStorage();
        $._warmUpTime = warmUpTime_;
    }

    function _setMaxIncentive(uint256 maxIncentive_) internal {
        DMAStorage storage $ = _getDMAStorage();
        $._maxIncentive = maxIncentive_;
    }

    function _setMaxPayment(uint256 maxPayment_) internal {
        DMAStorage storage $ = _getDMAStorage();
        $._maxPayment = maxPayment_;
    }

    function _setMaxAssets(uint256 maxAssets_) internal {
        DMAStorage storage $ = _getDMAStorage();
        $._maxAssets = maxAssets_;
    }

    function _setExtraTime(uint256 extraTime_) internal {
        DMAStorage storage $ = _getDMAStorage();
        $._extraTime = extraTime_;
    }

    function _getNextAuctionId() internal returns (uint256) {
        DMAStorage storage $ = _getDMAStorage();
        uint256 nextAuctionId_ = $._nextAuctionId;
        $._nextAuctionId = nextAuctionId_++;
        return nextAuctionId_;
    }

    function _getAuction(uint256 auctionId_) internal view returns (IDarkMarketAuctionStructures.Auction storage) {
        DMAStorage storage $ = _getDMAStorage();
        return $._auctions[auctionId_];
    }

}
