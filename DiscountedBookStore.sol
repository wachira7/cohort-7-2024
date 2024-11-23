// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.2;

import "./BookStore.sol";
import "./LoyaltyProgram.sol";
import "./DiscountManager.sol";

interface IDiscountedBookStore {
    function buyBookWithDiscount(
        uint256 bookId,
        uint256 quantity,
        uint256 discountId
    ) external payable;
}

contract DiscountedBookStore is BookStore, IDiscountedBookStore {
    LoyaltyProgram public loyaltyProgram;
    DiscountManager public discountManager;

    struct PurchaseHistory {
        uint256 bookId;
        uint256 quantity;
        uint256 originalPrice;
        uint256 discountedPrice;
        uint256 discountId;
        uint256 pointsEarned;
        uint256 timestamp;
    }

    mapping(address => PurchaseHistory[]) private userPurchaseHistory;
    uint256 public totalDiscountedSales;
    uint256 public totalDiscountAmount;

    // Events
    event DiscountedPurchase(uint256 indexed bookId, address indexed buyer, uint256 quantity, uint256 originalPrice, uint256 discountedPrice, uint256 pointsEarned, uint256 timestamp);
    event DiscountPurchaseFailed(address indexed buyer, uint256 indexed bookId, string reason, uint256 timestamp);

    constructor(
        address _owner,
        address _loyaltyProgram,
        address _discountManager
    ) BookStore(_owner) {
        require(_loyaltyProgram != address(0), "Invalid loyalty program address");
        require(_discountManager != address(0), "Invalid discount manager address");
        loyaltyProgram = LoyaltyProgram(_loyaltyProgram);
        discountManager = DiscountManager(_discountManager);
    }

    function buyBookWithDiscount(
        uint256 bookId,
        uint256 quantity,
        uint256 discountId
    ) external payable override {
        Book storage book = books[bookId];
        require(book.isAvailable, "This book is not available");
        require(book.stock >= quantity, "Not enough stock available");

        uint256 originalPrice = book.price * quantity;
        uint256 discountedPrice = discountManager.getDiscountedPrice(
            originalPrice,
            discountId,
            msg.sender
        );

        require(msg.value == discountedPrice, "Incorrect payment amount");

        // Update book stock
        book.stock -= quantity;
        if (book.stock == 0) {
            book.isAvailable = false;
        }

        // Calculate points earned (based on discounted price)
        uint256 pointsEarned = discountedPrice / 100; // 1 point per 100 units spent

        // Add loyalty points
        loyaltyProgram.addPoints(msg.sender);

        // Store purchase history
        userPurchaseHistory[msg.sender].push(PurchaseHistory({
            bookId: bookId,
            quantity: quantity,
            originalPrice: originalPrice,
            discountedPrice: discountedPrice,
            discountId: discountId,
            pointsEarned: pointsEarned,
            timestamp: block.timestamp
        }));

        // Update statistics
        totalDiscountedSales++;
        totalDiscountAmount += (originalPrice - discountedPrice);

        // Transfer payment to owner
        payable(owner).transfer(msg.value);

        // Emit event from parent contract
        super.buyBook(bookId, quantity); // This will emit the BookPurchased event

        // Emit discounted purchase event
        emit DiscountedPurchase(
            bookId,
            msg.sender,
            quantity,
            originalPrice,
            discountedPrice,
            pointsEarned,
            block.timestamp
        );
    }

    function getAvailableDiscountPrice(
        uint256 bookId,
        uint256 quantity,
        uint256 discountId
    ) external view returns (uint256 originalPrice, uint256 discountedPrice) {
        Book memory book = books[bookId];
        require(book.isAvailable, "Book not available");
        
        originalPrice = book.price * quantity;
        discountedPrice = discountManager.getDiscountedPrice(
            originalPrice,
            discountId,
            msg.sender
        );
    }

    // New helper functions
    function getUserPurchaseHistory(
        address user
    ) external view returns (PurchaseHistory[] memory) {
        return userPurchaseHistory[user];
    }

    function getDiscountStatistics() external view returns (
        uint256 totalSales,
        uint256 totalDiscount,
        uint256 averageDiscount
    ) {
        return (
            totalDiscountedSales,
            totalDiscountAmount,
            totalDiscountedSales > 0 ? totalDiscountAmount / totalDiscountedSales : 0
        );
    }
}