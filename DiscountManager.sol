// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./LoyaltyProgram.sol";

contract DiscountManager is Ownable {
    // Structs
    struct Discount {
        uint256 value;
        bool isPercentage;
        uint256 minimumPoints;
        bool isActive;
        uint256 createdAt;
        uint256 expiryDate;
        uint256 usageCount;
        uint256 maxUsage;  // 0 for unlimited
        uint256 minPurchaseAmount;
    }

    struct DiscountUsage {
        uint256 discountId;
        uint256 originalPrice;
        uint256 discountedPrice;
        uint256 timestamp;
    }

    // State Variables
    mapping(uint256 => Discount) public discounts;
    mapping(address => mapping(uint256 => uint256)) public userDiscountUsage;  // user -> discountId -> usage count
    mapping(address => DiscountUsage[]) public userDiscountHistory;
    LoyaltyProgram public loyaltyProgram;
    
    uint256 public totalDiscountsCreated;
    uint256 public totalDiscountsActive;
    uint256 public totalDiscountsClaimed;

    // Events
    event DiscountCreated(uint256 indexed discountId, uint256 value, bool isPercentage, uint256 minimumPoints, uint256 expiryDate, uint256 maxUsage, uint256 timestamp);
    event DiscountUpdated(uint256 indexed discountId, uint256 newValue, uint256 newMinPoints, uint256 newExpiryDate, uint256 timestamp);
    event DiscountDeactivated(uint256 indexed discountId, string reason, uint256 timestamp);
    event DiscountClaimed(uint256 indexed discountId, address indexed user, uint256 originalPrice, uint256 discountedPrice, uint256 pointsUsed, uint256 timestamp);
    event DiscountExpired(uint256 indexed discountId, uint256 timestamp);

    // Modifiers
    modifier validDiscount(uint256 discountId) {
        require(discounts[discountId].value > 0, "Discount does not exist");
        _;
    }

    modifier activeDiscount(uint256 discountId) {
        require(discounts[discountId].isActive, "Discount is not active");
        require(block.timestamp < discounts[discountId].expiryDate, "Discount has expired");
        _;
    }

    constructor(address _loyaltyProgramAddress) Ownable(msg.sender) {
        require(_loyaltyProgramAddress != address(0), "Invalid loyalty program address");
        loyaltyProgram = LoyaltyProgram(_loyaltyProgramAddress);
    }

    function setDiscount(
        uint256 discountId,
        uint256 _value,
        bool _isPercentage,
        uint256 _minimumPoints,
        uint256 _expiryDate,
        uint256 _maxUsage,
        uint256 _minPurchaseAmount
    ) external onlyOwner {
        require(_value > 0, "Discount value must be greater than 0");
        require(_expiryDate > block.timestamp, "Expiry date must be in future");
        
        if (_isPercentage) {
            require(_value <= 100, "Percentage discount cannot exceed 100%");
        }

        discounts[discountId] = Discount({
            value: _value,
            isPercentage: _isPercentage,
            minimumPoints: _minimumPoints,
            isActive: true,
            createdAt: block.timestamp,
            expiryDate: _expiryDate,
            usageCount: 0,
            maxUsage: _maxUsage,
            minPurchaseAmount: _minPurchaseAmount
        });

        totalDiscountsCreated++;
        totalDiscountsActive++;

        emit DiscountCreated(
            discountId,
            _value,
            _isPercentage,
            _minimumPoints,
            _expiryDate,
            _maxUsage,
            block.timestamp
        );
    }

    function updateDiscount(
        uint256 discountId,
        uint256 _newValue,
        uint256 _newMinPoints,
        uint256 _newExpiryDate
    ) external onlyOwner validDiscount(discountId) activeDiscount(discountId) {
        Discount storage discount = discounts[discountId];
        
        if (_newValue > 0) {
            if (discount.isPercentage) {
                require(_newValue <= 100, "Percentage discount cannot exceed 100%");
            }
            discount.value = _newValue;
        }
        
        if (_newMinPoints > 0) {
            discount.minimumPoints = _newMinPoints;
        }
        
        if (_newExpiryDate > block.timestamp) {
            discount.expiryDate = _newExpiryDate;
        }

        emit DiscountUpdated(
            discountId,
            discount.value,
            discount.minimumPoints,
            discount.expiryDate,
            block.timestamp
        );
    }

    function deactivateDiscount(
        uint256 discountId,
        string memory reason
    ) external onlyOwner validDiscount(discountId) {
        require(discounts[discountId].isActive, "Discount already inactive");
        discounts[discountId].isActive = false;
        totalDiscountsActive--;
        
        emit DiscountDeactivated(discountId, reason, block.timestamp);
    }

    function getDiscountedPrice(
        uint256 originalPrice,
        uint256 discountId,
        address user
    ) external view 
      validDiscount(discountId) 
      activeDiscount(discountId) 
      returns (uint256) {
        Discount memory discount = discounts[discountId];
        
        require(originalPrice >= discount.minPurchaseAmount, "Purchase amount too low");
        require(
            discount.maxUsage == 0 || userDiscountUsage[user][discountId] < discount.maxUsage,
            "Discount usage limit reached"
        );

        uint256 userPoints = loyaltyProgram.getUserPoints(user);
        require(userPoints >= discount.minimumPoints, "Insufficient points for discount");

        if (discount.isPercentage) {
            uint256 discountAmount = (originalPrice * discount.value) / 100;
            return originalPrice - discountAmount;
        } else {
            require(
                discount.value <= originalPrice,
                "Fixed discount cannot exceed price"
            );
            return originalPrice - discount.value;
        }
    }

    // New helper functions
    function getActiveDiscounts() external view returns (uint256[] memory) {
        uint256[] memory activeDiscounts = new uint256[](totalDiscountsActive);
        uint256 index = 0;
        
        for (uint256 i = 0; i < totalDiscountsCreated; i++) {
            if (discounts[i].isActive && block.timestamp < discounts[i].expiryDate) {
                activeDiscounts[index] = i;
                index++;
            }
        }
        
        return activeDiscounts;
    }

    function getUserDiscountHistory(
        address user
    ) external view returns (DiscountUsage[] memory) {
        return userDiscountHistory[user];
    }

    function getDiscountDetails(
        uint256 discountId
    ) external view validDiscount(discountId) returns (
        uint256 value,
        bool isPercentage,
        uint256 minimumPoints,
        bool isActive,
        uint256 expiryDate,
        uint256 usageCount,
        uint256 maxUsage,
        uint256 minPurchaseAmount
    ) {
        Discount memory discount = discounts[discountId];
        return (
            discount.value,
            discount.isPercentage,
            discount.minimumPoints,
            discount.isActive,
            discount.expiryDate,
            discount.usageCount,
            discount.maxUsage,
            discount.minPurchaseAmount
        );
    }
}