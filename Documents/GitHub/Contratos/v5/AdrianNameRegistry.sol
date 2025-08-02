// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// =============== INTERFACES ===============

interface IAdrianLabCore {
    function ownerOf(uint256 tokenId) external view returns (address);
    function exists(uint256 tokenId) external view returns (bool);
}

/**
 * @title AdrianNameRegistry - ERC20 Payment System
 * @dev Simple name registry with ERC20 payment instead of token burning
 * @notice Users pay ERC20 to set names, owner can modify any name for free
 */
contract AdrianNameRegistry is Ownable, ReentrancyGuard {
    
    // =============== STATE VARIABLES ===============
    
    IAdrianLabCore private coreContract;
    IERC20 private paymentToken;
    address private treasury;
    
    // Name storage and pricing
    mapping(uint256 => string) public tokenNames;
    uint256 public namePrice; // Price in payment token wei
    
    // Name history tracking (optional but useful)
    struct NameChange {
        string name;
        address changer;
        uint256 timestamp;
        bool paidChange; // false if owner override
    }
    
    mapping(uint256 => NameChange[]) public tokenNameHistory;

    // =============== EVENTS ===============
    
    event NameSet(
        uint256 indexed tokenId, 
        string indexed newName, 
        address indexed setter, 
        bool paid,
        uint256 price
    );
    
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);
    event TreasuryUpdated(address oldTreasury, address newTreasury);

    // =============== CONSTRUCTOR ===============
    
    constructor(
        address _coreContract,
        address _paymentToken,
        address _treasury,
        uint256 _initialPrice
    ) Ownable(msg.sender) {
        require(_coreContract != address(0) && _coreContract.code.length > 0, "Invalid core contract");
        require(_paymentToken != address(0) && _paymentToken.code.length > 0, "Invalid payment token");
        require(_treasury != address(0), "Invalid treasury");
        
        coreContract = IAdrianLabCore(_coreContract);
        paymentToken = IERC20(_paymentToken);
        treasury = _treasury;
        namePrice = _initialPrice;
    }

    // =============== CORE FUNCTIONS ===============

    /**
     * @dev Set token name (paid version for users)
     * @param tokenId Token to name
     * @param name New name for the token
     */
    function setTokenName(uint256 tokenId, string calldata name) external nonReentrant {
        // Basic validations
        require(coreContract.exists(tokenId), "Token does not exist");
        require(coreContract.ownerOf(tokenId) == msg.sender, "Not token owner");
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(name).length <= 32, "Name too long");
        
        // Process payment if price > 0
        if (namePrice > 0) {
            require(
                paymentToken.transferFrom(msg.sender, treasury, namePrice),
                "Payment failed"
            );
        }
        
        // Set the name
        tokenNames[tokenId] = name;
        
        // Record in history
        tokenNameHistory[tokenId].push(NameChange({
            name: name,
            changer: msg.sender,
            timestamp: block.timestamp,
            paidChange: true
        }));
        
        emit NameSet(tokenId, name, msg.sender, true, namePrice);
    }

    /**
     * @dev Set token name (owner override - no payment required)
     * @param tokenId Token to name
     * @param name New name for the token
     */
    function setTokenNameOwner(uint256 tokenId, string calldata name) external onlyOwner {
        require(coreContract.exists(tokenId), "Token does not exist");
        require(bytes(name).length <= 32, "Name too long");
        
        // Set the name (no payment required)
        tokenNames[tokenId] = name;
        
        // Record in history
        tokenNameHistory[tokenId].push(NameChange({
            name: name,
            changer: msg.sender,
            timestamp: block.timestamp,
            paidChange: false
        }));
        
        emit NameSet(tokenId, name, msg.sender, false, 0);
    }

    // =============== VIEW FUNCTIONS ===============

    /**
     * @dev Get token name
     * @param tokenId Token to query
     * @return name Current name of the token
     */
    function getTokenName(uint256 tokenId) external view returns (string memory) {
        return tokenNames[tokenId];
    }

    /**
     * @dev Get token name history
     * @param tokenId Token to query
     * @return history Array of all name changes
     */
    function getTokenNameHistory(uint256 tokenId) external view returns (NameChange[] memory) {
        return tokenNameHistory[tokenId];
    }

    /**
     * @dev Get count of name changes for a token
     * @param tokenId Token to query
     * @return count Number of name changes
     */
    function getTokenNameChangeCount(uint256 tokenId) external view returns (uint256) {
        return tokenNameHistory[tokenId].length;
    }

    /**
     * @dev Get specific name change by index
     * @param tokenId Token to query
     * @param index Change index (0-based)
     * @return change Name change details
     */
    function getTokenNameChange(uint256 tokenId, uint256 index) external view returns (NameChange memory) {
        require(index < tokenNameHistory[tokenId].length, "Index out of bounds");
        return tokenNameHistory[tokenId][index];
    }

    /**
     * @dev Check if user can set name for token
     * @param user User address
     * @param tokenId Token ID
     * @return canSet True if user can set name
     * @return reason Reason if cannot set
     */
    function canSetName(address user, uint256 tokenId) external view returns (bool canSet, string memory reason) {
        if (!coreContract.exists(tokenId)) return (false, "Token does not exist");
        if (coreContract.ownerOf(tokenId) != user) return (false, "Not token owner");
        if (namePrice > 0 && paymentToken.balanceOf(user) < namePrice) return (false, "Insufficient balance");
        if (namePrice > 0 && paymentToken.allowance(user, address(this)) < namePrice) return (false, "Insufficient allowance");
        
        return (true, "Can set name");
    }

    // =============== ADMIN FUNCTIONS ===============

    /**
     * @dev Set price for name changes
     * @param newPrice New price in payment token wei
     */
    function setNamePrice(uint256 newPrice) external onlyOwner {
        uint256 oldPrice = namePrice;
        namePrice = newPrice;
        emit PriceUpdated(oldPrice, newPrice);
    }

    /**
     * @dev Set treasury wallet
     * @param newTreasury New treasury address
     */
    function setTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Invalid treasury");
        address oldTreasury = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(oldTreasury, newTreasury);
    }

    /**
     * @dev Set core contract
     * @param _coreContract New core contract address
     */
    function setCoreContract(address _coreContract) external onlyOwner {
        require(_coreContract != address(0) && _coreContract.code.length > 0, "Invalid core contract");
        coreContract = IAdrianLabCore(_coreContract);
    }

    /**
     * @dev Set payment token
     * @param _paymentToken New payment token address
     */
    function setPaymentToken(address _paymentToken) external onlyOwner {
        require(_paymentToken != address(0) && _paymentToken.code.length > 0, "Invalid payment token");
        paymentToken = IERC20(_paymentToken);
    }

    /**
     * @dev Emergency withdraw of payment tokens (if any get stuck)
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(uint256 amount) external onlyOwner {
        require(paymentToken.transfer(owner(), amount), "Withdrawal failed");
    }

    // =============== GETTERS FOR CONTRACT ADDRESSES ===============

    /**
     * @dev Get current core contract address
     * @return address Core contract address
     */
    function getCoreContract() external view returns (address) {
        return address(coreContract);
    }

    /**
     * @dev Get current payment token address
     * @return address Payment token address
     */
    function getPaymentToken() external view returns (address) {
        return address(paymentToken);
    }

    /**
     * @dev Get current treasury address
     * @return address Treasury address
     */
    function getTreasury() external view returns (address) {
        return treasury;
    }
}