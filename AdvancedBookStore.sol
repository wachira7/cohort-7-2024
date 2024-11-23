// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.2;

import "./BookStore.sol";

contract AdvancedBookStore is BookStore {
    // Structs
    struct BestsellerInfo {
        bool isBestseller;
        uint256 markedDate;
        uint256 salesCount;
        uint256 lastUpdateTime;
    }

    // State variables
    mapping(uint256 => BestsellerInfo) public bestsellerDetails;
    uint256 public bestsellerThreshold;
    uint256[] public bestsellerList;

    // Events
    event BookMarkedAsBestseller(uint256 indexed bookId, address indexed markedBy, uint256 salesCount, uint256 timestamp);
    event BookRemovedFromBestsellers(uint256 indexed bookId, address indexed removedBy, string reason, uint256 timestamp);
    event BookRemoved(uint256 indexed bookId, address indexed removedBy, uint256 timestamp);
    event BestsellerThresholdUpdated(uint256 oldThreshold, uint256 newThreshold, uint256 timestamp);
    event BestsellerStatusAutoUpdated(uint256 indexed bookId, bool newStatus, uint256 currentSales, uint256 timestamp);

    // Constructor
    constructor(
        address _owner,
        uint256 _initialBestsellerThreshold
    ) BookStore(_owner) {
        bestsellerThreshold = _initialBestsellerThreshold;
    }

    // Modifiers
    modifier validBookId(uint256 _bookId) {
        require(books[_bookId].price != 0, "Book does not exist");
        _;
    }

    // Functions
    function markAsBestseller(
        uint256 _bookId
    ) public onlyOwner validBookId(_bookId) {
        require(!bestsellerDetails[_bookId].isBestseller, "Already a bestseller");
        
        bestsellerDetails[_bookId] = BestsellerInfo({
            isBestseller: true,
            markedDate: block.timestamp,
            salesCount: books[_bookId].totalSold,
            lastUpdateTime: block.timestamp
        });
        
        bestsellerList.push(_bookId);
        
        emit BookMarkedAsBestseller(
            _bookId,
            msg.sender,
            books[_bookId].totalSold,
            block.timestamp
        );
    }

    function removeFromBestsellers(
        uint256 _bookId,
        string memory reason
    ) public onlyOwner validBookId(_bookId) {
        require(bestsellerDetails[_bookId].isBestseller, "Not a bestseller");
        
        delete bestsellerDetails[_bookId];
        
        // Remove from bestsellerList
        for (uint256 i = 0; i < bestsellerList.length; i++) {
            if (bestsellerList[i] == _bookId) {
                bestsellerList[i] = bestsellerList[bestsellerList.length - 1];
                bestsellerList.pop();
                break;
            }
        }
        
        emit BookRemovedFromBestsellers(
            _bookId,
            msg.sender,
            reason,
            block.timestamp
        );
    }

    function removeBook(
        uint256 _bookId
    ) public onlyOwner validBookId(_bookId) {
        // Remove from bestsellers if applicable
        if (bestsellerDetails[_bookId].isBestseller) {
            removeFromBestsellers(_bookId, "Book removed from store");
        }

        // Remove from main book storage
        delete books[_bookId];

        // Remove from bookIds array
        for (uint256 i = 0; i < bookIds.length; i++) {
            if (bookIds[i] == _bookId) {
                bookIds[i] = bookIds[bookIds.length - 1];
                bookIds.pop();
                break;
            }
        }

        emit BookRemoved(_bookId, msg.sender, block.timestamp);
    }

    function updateBestsellerThreshold(
        uint256 _newThreshold
    ) public onlyOwner {
        require(_newThreshold > 0, "Threshold must be greater than 0");
        uint256 oldThreshold = bestsellerThreshold;
        bestsellerThreshold = _newThreshold;
        
        emit BestsellerThresholdUpdated(
            oldThreshold,
            _newThreshold,
            block.timestamp
        );

        // Check all books against new threshold
        updateBestsellerStatuses();
    }

    function updateBestsellerStatuses() public {
        for (uint256 i = 0; i < bookIds.length; i++) {
            uint256 bookId = bookIds[i];
            uint256 sales = books[bookId].totalSold;
            
            // Should be bestseller but isn't
            if (sales >= bestsellerThreshold && !bestsellerDetails[bookId].isBestseller) {
                bestsellerDetails[bookId] = BestsellerInfo({
                    isBestseller: true,
                    markedDate: block.timestamp,
                    salesCount: sales,
                    lastUpdateTime: block.timestamp
                });
                bestsellerList.push(bookId);
                
                emit BestsellerStatusAutoUpdated(
                    bookId,
                    true,
                    sales,
                    block.timestamp
                );
            }
            // Shouldn't be bestseller but is
            else if (sales < bestsellerThreshold && bestsellerDetails[bookId].isBestseller) {
                removeFromBestsellers(bookId, "Sales below threshold");
                
                emit BestsellerStatusAutoUpdated(
                    bookId,
                    false,
                    sales,
                    block.timestamp
                );
            }
        }
    }

    // View functions
    function isBestseller(
        uint256 _bookId
    ) public view returns (bool) {
        return bestsellerDetails[_bookId].isBestseller;
    }

    function getBestsellerInfo(
        uint256 _bookId
    ) public view returns (
        bool isBookBestseller,
        uint256 markedDate,
        uint256 salesCount,
        uint256 lastUpdateTime
    ) {
        BestsellerInfo memory info = bestsellerDetails[_bookId];
        return (
            info.isBestseller,
            info.markedDate,
            info.salesCount,
            info.lastUpdateTime
        );
    }

    function getAllBestsellers() public view returns (uint256[] memory) {
        return bestsellerList;
    }

    // Override buyBook to update bestseller status
    function buyBook(
        uint256 _bookId,
        uint256 _quantity
    ) public payable override {
        // Call parent buyBook first
        super.buyBook(_bookId, _quantity);
        
        // Check if this purchase makes the book a bestseller
        uint256 totalSales = books[_bookId].totalSold;
        if (totalSales >= bestsellerThreshold && !bestsellerDetails[_bookId].isBestseller) {
            bestsellerDetails[_bookId] = BestsellerInfo({
                isBestseller: true,
                markedDate: block.timestamp,
                salesCount: totalSales,
                lastUpdateTime: block.timestamp
            });
            bestsellerList.push(_bookId);
            
            emit BestsellerStatusAutoUpdated(
                _bookId,
                true,
                totalSales,
                block.timestamp
            );
        }
    }
}