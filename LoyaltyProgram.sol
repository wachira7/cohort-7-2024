// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";

contract LoyaltyProgram is Ownable {
    // Structs
    struct UserProfile {
        uint256 points;
        uint256 totalPointsEarned;
        uint256 totalPointsRedeemed;
        uint256 lastPurchaseBlock;
        uint256 memberSince;
        uint256 tier;  // 0: Basic, 1: Silver, 2: Gold, 3: Platinum
    }

    // State Variables
    mapping(address => UserProfile) private userProfiles;
    uint256 private constant POINTS_PER_PURCHASE = 10;
    uint256 private constant BLOCKS_BETWEEN_POINTS = 100;
    uint256[] private tierThresholds = [0, 100, 500, 1000];  // Points needed for each tier

    // Events
    event PointsAdded(address indexed user, uint256 points, uint256 newTotalPoints, uint256 timestamp);
    event PointsRedeemed(address indexed user, uint256 points, uint256 remainingPoints, uint256 timestamp);
    event TierUpgraded(address indexed user, uint256 oldTier, uint256 newTier, uint256 timestamp);
    event UserRegistered(address indexed user, uint256 timestamp);
    event PointsExpired(address indexed user, uint256 points, uint256 timestamp);

    // Modifiers
    modifier validUser(address user) {
        require(user != address(0), "Invalid user address");
        require(userProfiles[user].memberSince > 0, "User not registered");
        _;
    }

    constructor() Ownable(msg.sender) {}

    // Function to register new user
    function registerUser(address user) external onlyOwner {
        require(user != address(0), "Invalid user address");
        require(userProfiles[user].memberSince == 0, "User already registered");

        userProfiles[user] = UserProfile({
            points: 0,
            totalPointsEarned: 0,
            totalPointsRedeemed: 0,
            lastPurchaseBlock: 0,
            memberSince: block.timestamp,
            tier: 0
        });

        emit UserRegistered(user, block.timestamp);
    }

    function addPoints(address user) external validUser(user) {
        require(
            block.number >= userProfiles[user].lastPurchaseBlock + BLOCKS_BETWEEN_POINTS,
            "Too soon for new points"
        );

        UserProfile storage profile = userProfiles[user];
        profile.points += POINTS_PER_PURCHASE;
        profile.totalPointsEarned += POINTS_PER_PURCHASE;
        profile.lastPurchaseBlock = block.number;

        emit PointsAdded(
            user,
            POINTS_PER_PURCHASE,
            profile.points,
            block.timestamp
        );

        _checkAndUpdateTier(user);
    }

    function redeemPoints(
        address user,
        uint256 points
    ) external validUser(user) {
        UserProfile storage profile = userProfiles[user];
        require(profile.points >= points, "Insufficient points");
        
        profile.points -= points;
        profile.totalPointsRedeemed += points;

        emit PointsRedeemed(
            user,
            points,
            profile.points,
            block.timestamp
        );

        _checkAndUpdateTier(user);
    }

    function _checkAndUpdateTier(address user) internal {
        UserProfile storage profile = userProfiles[user];
        uint256 currentTier = profile.tier;
        uint256 newTier = currentTier;

        // Check if user qualifies for higher tier
        for (uint256 i = currentTier + 1; i < tierThresholds.length; i++) {
            if (profile.points >= tierThresholds[i]) {
                newTier = i;
            }
        }

        // Check if user should be downgraded
        for (uint256 i = currentTier; i > 0; i--) {
            if (profile.points < tierThresholds[i]) {
                newTier = i - 1;
            }
        }

        if (newTier != currentTier) {
            profile.tier = newTier;
            emit TierUpgraded(user, currentTier, newTier, block.timestamp);
        }
    }

    // View Functions
    function getUserProfile(
        address user
    ) external view returns (
        uint256 points,
        uint256 totalEarned,
        uint256 totalRedeemed,
        uint256 memberSince,
        uint256 tier
    ) {
        UserProfile memory profile = userProfiles[user];
        return (
            profile.points,
            profile.totalPointsEarned,
            profile.totalPointsRedeemed,
            profile.memberSince,
            profile.tier
        );
    }

    function getUserPoints(address user) external view returns (uint256) {
        return userProfiles[user].points;
    }

    function getUserTier(address user) external view returns (uint256) {
        return userProfiles[user].tier;
    }

    function getTierThreshold(uint256 tier) external view returns (uint256) {
        require(tier < tierThresholds.length, "Invalid tier");
        return tierThresholds[tier];
    }
}