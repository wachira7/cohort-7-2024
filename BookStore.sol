// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.2;

// Book Store - we have an owner
// Books - cat_name, price, author, title, isbn, available
// - string, uint, int, bool
// uint8 (137) - unit256 (878687678678687876) 2*8 2*256
// int8 - int255

// struct - grouping items
// mapping - used to store items with thier unique id
// array - two type - dynamic, fixed size unit256[] and unit256[4]
// event - notify about new addition or act as audit trail
// variables - global, state, local

// functions - setters and getters
// addBooks() - event BookAdded setter - setting data
// getBook() - getter - getting data
// buyBook() - event
// getTotalBooks() -

// inheritance -

// more than 2 contracts
// index contract - entry point for all your other contracts
// interface contracts - abstracts functions that are reusable  - IERC20
// modifer contracts - require statements thats reusable
// opezzenplin contracts -

// ABI - Application Binary Interface - xml, json, graphql - bridge between la backend python, php, javascript - react or next or reactNative

// example - assignment
// create a loyaltyProgram - contract for the bookstore - two addPoint to user address, getUserPoints
// use the opezepplin contract for ownable
// create a discount contract - two functions - setDiscount(either fixed or percentage), getDiscountedPrice
// use the points for the discount -


contract BookStore {
    address public owner;
    uint256 private constant LOW_STOCK_THRESHOLD = 5;

    struct Book {
        string title;
        string author;
        uint256 price;
        uint256 stock;
        bool isAvailable;
        uint256 totalSold;
        uint256 lastRestockTime;
    }

    mapping(uint256 => Book) public books;
    uint256[] public bookIds;
    
    // Enhanced Events
   
    event BookAdded(uint256 indexed bookId, string title, string author, uint256 price, uint256 stock, address indexed addedBy, uint256 timestamp);
    event BookUpdated(uint256 indexed bookId, uint256 newPrice, uint256 newStock, bool isAvailable, address indexed updatedBy, uint256 timestamp);
    event BookSold(uint256 indexed bookId, address indexed buyer, uint256 quantity, uint256 totalAmount, uint256 timestamp);   
    event PurchaseInitiated(uint256 indexed bookId, address indexed buyer, uint256 quantity, uint256 totalAmount, uint256 timestamp);  // Added this event
    event PurchaseConfirmed(uint256 indexed bookId, address indexed buyer, uint256 quantity, uint256 totalAmount, uint256 timestamp);
    event PurchaseFailed(uint256 indexed bookId, address indexed buyer, uint256 quantity, string reason, uint256 timestamp);  // Fixed parameter order
    event LowStockAlert(uint256 indexed bookId, uint256 currentStock, uint256 timestamp);
    event StockReplenished(uint256 indexed bookId, uint256 addedStock, uint256 newTotalStock, uint256 timestamp);

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action.");
        _;
    }

    modifier bookExists(uint256 _bookId) {
        require(books[_bookId].price != 0, "Book does not exist.");
        _;
    }

    constructor(address _owner) {
        owner = _owner;
    }

    function addBook(
        uint256 _bookId, 
        string memory _title, 
        string memory _author, 
        uint256 _price, 
        uint256 _stock
    ) public onlyOwner {
        require(books[_bookId].price == 0, "Book already exists with this ID.");
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_author).length > 0, "Author cannot be empty");
        require(_price > 0, "Price must be greater than 0");
        
        books[_bookId] = Book({
            title: _title,
            author: _author,
            price: _price,
            stock: _stock,
            isAvailable: _stock > 0,
            totalSold: 0,
            lastRestockTime: block.timestamp
        });
        
        bookIds.push(_bookId);
        
        emit BookAdded(
            _bookId, 
            _title, 
            _author, 
            _price, 
            _stock,
            msg.sender,
            block.timestamp
        );

        if (_stock <= LOW_STOCK_THRESHOLD) {
            emit LowStockAlert(_bookId, _stock, block.timestamp);
        }
    }

    function updateBook( uint256 _bookId, uint256 _newPrice, uint256 _additionalStock) 
      public onlyOwner bookExists(_bookId) {
        Book storage book = books[_bookId];
        
        if (_newPrice > 0) {
            book.price = _newPrice;
        }
        
        if (_additionalStock > 0) {
            book.stock += _additionalStock;
            book.isAvailable = true;
            book.lastRestockTime = block.timestamp;
            
            emit StockReplenished(
                _bookId,
                _additionalStock,
                book.stock,
                block.timestamp
            );
        }

        emit BookUpdated(
            _bookId,
            book.price,
            book.stock,
            book.isAvailable,
            msg.sender,
            block.timestamp
        );
    }

    function getBook(uint256 _bookId) 
        public 
        view 
        bookExists(_bookId) 
        returns (
            string memory,
            string memory,
            uint256,
            uint256,
            bool,
            uint256
        ) 
    {
        Book memory book = books[_bookId];
        return (
            book.title,
            book.author,
            book.price,
            book.stock,
            book.isAvailable,
            book.totalSold
        );
    }

    function getAllBooks() public view returns (uint256[] memory) {
        return bookIds;
    }

    function purchaseBook(
        uint256 _bookId, 
        uint256 _quantity
        // payable - payment is needed
    ) public virtual payable bookExists(_bookId) {
        Book storage book = books[_bookId];
        uint256 totalAmount = book.price * _quantity;

        emit PurchaseInitiated(
            _bookId,
            msg.sender,
            _quantity,
            totalAmount,
            block.timestamp
        );

        // Validations
        if (!book.isAvailable) {
            emit PurchaseFailed(_bookId, msg.sender, _quantity, "Book not available", block.timestamp);
            revert("This book is not available.");
        }
        
        if (book.stock < _quantity) {
            emit PurchaseFailed(_bookId, msg.sender, _quantity, "Insufficient stock", block.timestamp);
            revert("Not enough stock available.");
        }
        
        if (msg.value != totalAmount) {
            emit PurchaseFailed(_bookId, msg.sender, _quantity, "Incorrect payment", block.timestamp);
            revert("Incorrect payment amount.");
        }

        // Update book data
        book.stock -= _quantity;
        book.totalSold += _quantity;
        
        if (book.stock == 0) {
            book.isAvailable = false;
        }

        // Check for low stock after purchase
        if (book.stock <= LOW_STOCK_THRESHOLD) {
            emit LowStockAlert(_bookId, book.stock, block.timestamp);
        }

        // Transfer payment
        payable(owner).transfer(msg.value);

        emit PurchaseConfirmed(
            _bookId,
            msg.sender,
            _quantity,
            totalAmount,
            block.timestamp
        );
    }

    // New helper functions
    function getBooksCount() public view returns (uint256) {
        return bookIds.length;
    }

    function getBookSales(uint256 _bookId) 
        public 
        view 
        bookExists(_bookId) 
        returns (uint256) 
    {
        return books[_bookId].totalSold;
    }

    function getLowStockBooks() public view returns (uint256[] memory) {
        uint256[] memory lowStockBooks = new uint256[](bookIds.length);
        uint256 count = 0;
        
        for (uint256 i = 0; i < bookIds.length; i++) {
            if (books[bookIds[i]].stock <= LOW_STOCK_THRESHOLD) {
                lowStockBooks[count] = bookIds[i];
                count++;
            }
        }
        
        // Resize array to actual count
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = lowStockBooks[i];
        }
        
        return result;
    }
}