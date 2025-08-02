// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAdrianTraitsCore} from "./AdrianTraitsCore.sol";

/**
 * @title AdrianLabMarketplace
 * @dev Marketplace for trading AdrianLab traits and assets
 */
contract AdrianLabMarketplace is Ownable, ReentrancyGuard {
    // =============== Type Definitions ===============
    
    struct MarketplaceListing {
        address seller;
        uint256 assetId;
        uint256 amount;
        uint256 pricePerUnit;
        uint256 expiration;
        bool active;
    }

    // =============== State Variables ===============
    
    address public coreContract;
    IAdrianTraitsCore public immutable traitsCore;
    
    // Marketplace configuration
    mapping(uint256 => MarketplaceListing) public listings;
    mapping(address => uint256[]) public userListings;
    uint256 public nextListingId = 1;
    uint256 public marketplaceFee = 250; // 2.5%
    address public marketplaceFeeRecipient;
    
    // Emergency features
    bool public emergencyMode = false;
    mapping(bytes4 => bool) public pausedFunctions;

    // =============== Events ===============
    
    event MarketplaceListingCreated(uint256 indexed listingId, address indexed seller, uint256 assetId, uint256 amount, uint256 pricePerUnit);
    event MarketplaceListingCanceled(uint256 indexed listingId);
    event MarketplaceSale(uint256 indexed listingId, address indexed buyer, uint256 amount, uint256 totalPrice);
    event EmergencyModeSet(bool enabled);
    event FunctionPauseToggled(bytes4 functionSelector, bool paused);

    // =============== Modifiers ===============
    
    modifier notPaused(bytes4 selector) {
        require(!emergencyMode || !pausedFunctions[selector], "Function paused in emergency mode");
        _;
    }

    // =============== Constructor ===============
    
    constructor(
        address _coreContract,
        IAdrianTraitsCore _traitsCore
    ) Ownable(msg.sender) {
        coreContract = _coreContract;
        traitsCore = _traitsCore;
        marketplaceFeeRecipient = msg.sender;
    }

    // =============== Marketplace Functions ===============
    
    /**
     * @dev Create marketplace listing
     */
    function createListing(
        uint256 assetId,
        uint256 amount,
        uint256 pricePerUnit,
        uint256 duration
    ) external nonReentrant notPaused(this.createListing.selector) {
        // Inline asset validation
        string memory name = traitsCore.getName(assetId);
        require(bytes(name).length > 0, "Invalid asset");
        
        require(IERC1155(coreContract).balanceOf(msg.sender, assetId) >= amount, "Insufficient balance");
        require(amount > 0 && pricePerUnit > 0, "Invalid amount or price");
        require(duration > 0 && duration <= 30 days, "Invalid duration");
        
        uint256 listingId = nextListingId++;
        
        listings[listingId] = MarketplaceListing({
            seller: msg.sender,
            assetId: assetId,
            amount: amount,
            pricePerUnit: pricePerUnit,
            expiration: block.timestamp + duration,
            active: true
        });
        
        userListings[msg.sender].push(listingId);
        
        // Transfer assets to escrow
        IERC1155(coreContract).safeTransferFrom(
            msg.sender,
            address(this),
            assetId,
            amount,
            ""
        );
        
        emit MarketplaceListingCreated(listingId, msg.sender, assetId, amount, pricePerUnit);
    }

    /**
     * @dev Cancel marketplace listing
     */
    function cancelListing(uint256 listingId) external nonReentrant {
        MarketplaceListing storage listing = listings[listingId];
        require(listing.seller == msg.sender, "Not listing owner");
        require(listing.active, "Listing not active");
        
        listing.active = false;
        
        // Return assets to seller
        IERC1155(coreContract).safeTransferFrom(
            address(this),
            msg.sender,
            listing.assetId,
            listing.amount,
            ""
        );
        
        emit MarketplaceListingCanceled(listingId);
    }

    /**
     * @dev Purchase from marketplace listing
     */
    function purchaseFromListing(
        uint256 listingId,
        uint256 amount
    ) external nonReentrant notPaused(this.purchaseFromListing.selector) {
        MarketplaceListing storage listing = listings[listingId];
        require(listing.active, "Listing not active");
        require(block.timestamp <= listing.expiration, "Listing expired");
        require(amount <= listing.amount, "Insufficient amount available");
        require(listing.seller != msg.sender, "Cannot buy from yourself");
        
        uint256 totalPrice = amount * listing.pricePerUnit;
        uint256 fee = (totalPrice * marketplaceFee) / 10000;
        uint256 sellerAmount = totalPrice - fee;
        
        // Get payment token from core contract
        IERC20 paymentToken = IAdrianTraitsCore(coreContract).paymentToken();
        
        // Transfer payment
        require(
            paymentToken.transferFrom(msg.sender, listing.seller, sellerAmount),
            "Payment to seller failed"
        );
        
        if (fee > 0) {
            require(
                paymentToken.transferFrom(msg.sender, marketplaceFeeRecipient, fee),
                "Fee payment failed"
            );
        }
        
        // Transfer assets to buyer
        IERC1155(coreContract).safeTransferFrom(
            address(this),
            msg.sender,
            listing.assetId,
            amount,
            ""
        );
        
        // Update listing
        listing.amount -= amount;
        if (listing.amount == 0) {
            listing.active = false;
        }
        
        emit MarketplaceSale(listingId, msg.sender, amount, totalPrice);
    }

    // =============== View Functions ===============
    
    /**
     * @dev Get user listings
     */
    function getUserListings(address user) external view returns (uint256[] memory) {
        return userListings[user];
    }

    /**
     * @dev Get listing details
     */
    function getListingDetails(uint256 listingId) external view returns (
        address seller,
        uint256 assetId,
        uint256 amount,
        uint256 pricePerUnit,
        uint256 expiration,
        bool active
    ) {
        MarketplaceListing storage listing = listings[listingId];
        return (
            listing.seller,
            listing.assetId,
            listing.amount,
            listing.pricePerUnit,
            listing.expiration,
            listing.active
        );
    }

    // =============== Emergency Functions ===============
    
    /**
     * @dev Set emergency mode
     */
    function setEmergencyMode(bool enabled) external onlyOwner {
        emergencyMode = enabled;
        emit EmergencyModeSet(enabled);
    }

    /**
     * @dev Set function pause status
     */
    function setFunctionPaused(bytes4 functionSelector, bool paused) external onlyOwner {
        pausedFunctions[functionSelector] = paused;
        emit FunctionPauseToggled(functionSelector, paused);
    }

    // =============== Admin Functions ===============
    
    /**
     * @dev Set core contract
     */
    function setCoreContract(address _coreContract) external onlyOwner {
        require(_coreContract != address(0) && _coreContract.code.length > 0, "Invalid contract");
        coreContract = _coreContract;
    }

    /**
     * @dev Set marketplace fee
     */
    function setMarketplaceFee(uint256 _fee) external onlyOwner {
        require(_fee <= 1000, "Fee too high"); // Max 10%
        marketplaceFee = _fee;
    }

    /**
     * @dev Set marketplace fee recipient
     */
    function setMarketplaceFeeRecipient(address _recipient) external onlyOwner {
        require(_recipient != address(0), "Invalid recipient");
        marketplaceFeeRecipient = _recipient;
    }

    // =============== ERC1155 Receiver ===============
    
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}
