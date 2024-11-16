// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.2; 
//Book Store
//Books - cat_name, price, author, title, isbn, available
// - string, unit, int, bool
// uint8 (137) - unit256 (878687678678687876) 2*8 2*256
// mapping -used to store items with their unique id
// array - two type - dynamic, fixed size unit256[] and unit256[4]
// event - notify about new addition or act as audit trail
// variables - global, state, local

//functions - setters and getter
//addBooks() - setter...for setting data
//buyBooks() - getter - getting data
//getTotalBooks


contract BookStore {
    address payable public owner;  //  owner is the one made payable to receive payments

    struct Book {
        string title;
        string author;
        uint256 price;
        uint256 stock;
        bool isAvailable;
        uint256 totalSold;
        bool isCreated;
    }

    mapping(uint256 => Book) public books;
    uint256[] public bookIds;
    uint256 public totalBooksSold;

    event BookAdded(uint256 indexed bookId, string title, string author, uint256 price, uint256 stock);
    event BookPurchased(uint256 indexed bookId, address indexed buyer, uint256 quantity);
    event BookRemoved(uint256 indexed bookId);

    constructor() {
        owner = payable(msg.sender);  
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

   function addBook(
        uint256 _bookId,
        string memory _title,
        string memory _author,
        uint256 _price,
        uint256 _stock
    ) public onlyOwner {
        require(!books[_bookId].isCreated, "the book does not exist");
        require(books[_bookId].price == 0, "Book already exists with this ID.");
        require(_price > 0, "Price must be greater than 0");
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_author).length > 0, "Author cannot be empty");

        books[_bookId] = Book({
            title: _title,
            author: _author,
            price: _price,
            stock: _stock,
            isAvailable: _stock > 0,
            totalSold: 0,
            isCreated: true
        });
        
        bookIds.push(_bookId);
        emit BookAdded(_bookId, _title, _author, _price, _stock);
    }

    function removeBook(uint256 _bookId) public onlyOwner {
        require(books[_bookId].price > 0, "Book does not exist");
        
        
        for (uint256 i = 0; i < bookIds.length; i++) {
            if (bookIds[i] == _bookId) {
                // Move the last element to the position we want to remove
                bookIds[i] = bookIds[bookIds.length - 1];
                // Remove the last element
                bookIds.pop();
                break;
            }
        }

        // for deleting the book from the mapping
        delete books[_bookId];
        emit BookRemoved(_bookId);
    }

    function getBook(uint256 _bookId) public view returns (
        string memory title,
        string memory author,
        uint256 price,
        uint256 stock,
        bool isAvailable,
        uint256 totalSold
    ) {
        Book memory book = books[_bookId];
        return (book.title, book.author, book.price, book.stock, book.isAvailable, book.totalSold);
    }

    function buyBook(uint256 _bookId, uint256 _quantity,uint256 _amount) public payable {
        Book storage book = books[_bookId];
        require(books[_bookId].price > 0, "Book does not exist");
        require(books[_bookId].isAvailable, "This book is not available");
        require(books[_bookId].stock >= _quantity, "Not enough stock available");
        require(_quantity > 0, "quantity must be greater thatn zero");
        require(_amount == book.price * _quantity, "Incorrect payment amount.");

        books[_bookId].stock -= _quantity;
        books[_bookId].isAvailable = book.stock > 0;
        books[_bookId].totalSold += _quantity;
        totalBooksSold += _quantity;

       // Transfer payment to the owner - paybale == transfer(from, to, amount)

        payable(owner).transfer(msg.value);
        
        emit BookPurchased(_bookId, msg.sender, _quantity);
    }

    function getTotalBooks() public view returns (uint256) {
        return bookIds.length;
    }

    function getTotalBooksSold() public view returns (uint256) {
        return totalBooksSold;
    }

    function getBookSales(uint256 _bookId) public view returns (uint256) {
        require(books[_bookId].price > 0, "Book does not exist");
        return books[_bookId].totalSold;
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getOwnerBalance() public view returns (uint256) {
        return owner.balance;
    }

    function updateBookPrice(uint256 _bookId, uint256 _newPrice) public onlyOwner {
        require(books[_bookId].price > 0, "Book does not exist");
        require(_newPrice > 0, "Price must be greater than 0");
        books[_bookId].price = _newPrice;
    }
}