// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// =============== INTERFACES ===============

interface IAdrianTraitsCore {
    function getAvailableSupply(uint256 assetId) external view returns (uint256);
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function mintFromExtension(address to, uint256 id, uint256 amount) external;
    function burnFromExtension(address from, uint256 id, uint256 amount) external;
    function canEquipAsset(uint256 assetId) external view returns (bool);
    function getCategory(uint256 assetId) external view returns (string memory);
    function getCategoryList() external view returns (string[] memory);
    function treasuryWallet() external view returns (address);
    function authorizedExtensions(address extension) external view returns (bool);
    function exists(uint256 tokenId) external view returns (bool);
}

interface IAdrianLabCore {
    function ownerOf(uint256 tokenId) external view returns (address);
}

interface IAdrianHistory {
    function recordEvent(
        uint256 tokenId,
        bytes32 eventType,
        address actor,
        bytes calldata eventData,
        uint256 blockNumber
    ) external;
}

/**
 * @title AdrianTraitsExtensions
 * @dev Extensions contract for trait management, inventory and permanent application (burn-and-apply)
 */
contract AdrianTraitsExtensions is Ownable, ReentrancyGuard {

    // =============== STATE VARIABLES ===============
    
    // Core references
    address public adrianLabCoreContract;
    address public treasury;
    IERC20 public paymentToken;
    IAdrianTraitsCore public immutable traitsCore;
    IAdrianHistory public historyContract;                // ← NUEVO

    // Token trait management
    mapping(uint256 => mapping(string => uint256)) public equippedTrait;
    mapping(uint256 => string[]) public tokenCategories;
    mapping(uint256 => mapping(string => bool)) public tokenHasCategory;

    // Token inventories
    mapping(uint256 => mapping(uint256 => uint256[])) public tokenInventory;

    // =============== EVENTS ===============
    
    event TraitEquipped(uint256 indexed tokenId, string category, uint256 traitId);
    event TraitUnequipped(uint256 indexed tokenId, string category, uint256 traitId);
    event TraitApplied(uint256 indexed tokenId, string category, uint256 traitId);      // ← NUEVO
    event TraitsAppliedBatch(uint256 indexed tokenId, uint256[] traitIds, string[] categories);
    event AssetAddedToInventory(uint256 indexed tokenId, uint256 indexed assetId, uint256 amount);
    event AssetRemovedFromInventory(uint256 indexed tokenId, uint256 indexed assetId, uint256 amount);
    event CoreContractCallReceived(address indexed core, uint256 timestamp);

    // =============== MODIFIERS ===============
    
    modifier onlyTokenOwner(uint256 tokenId) {
        require(IAdrianLabCore(adrianLabCoreContract).ownerOf(tokenId) == msg.sender, "Not token owner");
        _;
    }

    // =============== CONSTRUCTOR ===============
    
    constructor(address _traitsCore) Ownable(msg.sender) {
        require(_traitsCore != address(0), "Invalid traits core");
        traitsCore = IAdrianTraitsCore(_traitsCore);
    }

    // =============== TRAIT MANAGEMENT (APPLY) ===============
    
    function applyTrait(uint256 tokenId, uint256 traitId) external onlyTokenOwner(tokenId) nonReentrant {
        require(traitsCore.canEquipAsset(traitId), "Cannot apply this asset");
        require(traitsCore.balanceOf(msg.sender, traitId) >= 1, "No trait tokens to apply");

        // Burn the token from the caller - TODOS los traits se queman al aplicarlos
        traitsCore.burnFromExtension(msg.sender, traitId, 1);
        
        string memory category = traitsCore.getCategory(traitId);
        require(bytes(category).length > 0, "Invalid category");
        
        // Record the trait as equipped permanently
        equippedTrait[tokenId][category] = traitId;
        
        if (!tokenHasCategory[tokenId][category]) {
            tokenCategories[tokenId].push(category);
            tokenHasCategory[tokenId][category] = true;
        }
        
        emit TraitApplied(tokenId, category, traitId);

        // Record in history if available
        if (address(historyContract) != address(0)) {
            try historyContract.recordEvent(
                tokenId,
                keccak256("TRAIT_APPLIED"),
                msg.sender,
                abi.encode(traitId, category),
                block.number
            ) {} catch {}
        }
    }

    function getTrait(uint256 tokenId, string memory category) public view returns (uint256) {
        return equippedTrait[tokenId][category];
    }

    function applyTraitMultiple(uint256 tokenId, uint256[] calldata traitIds) 
        external 
        onlyTokenOwner(tokenId) 
        nonReentrant 
    {
        require(traitIds.length > 0, "No traits provided");
        require(traitIds.length <= 10, "Too many traits in single transaction"); // Límite de gas
        
        // ✅ PASO 1: Validar todos los traits y recopilar categorías
        string[] memory categories = new string[](traitIds.length);
        
        for (uint256 i = 0; i < traitIds.length; i++) {
            uint256 traitId = traitIds[i];
            
            // Validaciones básicas (igual que applyTrait)
            require(traitsCore.canEquipAsset(traitId), "Cannot apply this asset");
            require(traitsCore.balanceOf(msg.sender, traitId) >= 1, "Insufficient trait balance");
            
            string memory category = traitsCore.getCategory(traitId);
            require(bytes(category).length > 0, "Invalid category");
            
            categories[i] = category;
        }
        
        // ✅ PASO 2: Verificar no hay duplicados de categoría EN EL BATCH
        for (uint256 i = 0; i < categories.length; i++) {
            for (uint256 j = i + 1; j < categories.length; j++) {
                require(
                    keccak256(bytes(categories[i])) != keccak256(bytes(categories[j])),
                    string(abi.encodePacked("Duplicate category in batch: ", categories[i]))
                );
            }
        }
        
        // ✅ PASO 3: Si llegamos aquí, todo está bien - aplicar todos los traits
        for (uint256 i = 0; i < traitIds.length; i++) {
            uint256 traitId = traitIds[i];
            string memory category = categories[i];
            
            // Quemar el trait
            traitsCore.burnFromExtension(msg.sender, traitId, 1);
            
            // Aplicar el trait
            equippedTrait[tokenId][category] = traitId;
            
            // Tracking de categorías
            if (!tokenHasCategory[tokenId][category]) {
                tokenCategories[tokenId].push(category);
                tokenHasCategory[tokenId][category] = true;
            }
            
            emit TraitApplied(tokenId, category, traitId);
        }
        
        // ✅ PASO 4: Record en history (batch)
        if (address(historyContract) != address(0)) {
            try historyContract.recordEvent(
                tokenId,
                keccak256("TRAITS_APPLIED_BATCH"),
                msg.sender,
                abi.encode(traitIds, categories),
                block.number
            ) {} catch {}
        }
        
        emit TraitsAppliedBatch(tokenId, traitIds, categories);
    }

    // =============== INVENTORY MANAGEMENT ===============
    
    function addAssetToInventory(uint256 tokenId, uint256 assetId, uint256 amount) external onlyTokenOwner(tokenId) nonReentrant {
        require(amount > 0, "Invalid amount");
        
        // Update inventory first
        for (uint256 i = 0; i < amount; i++) {
            tokenInventory[tokenId][assetId].push(block.timestamp);
        }

        // Transfer after updating inventory
        IERC1155(address(traitsCore)).safeTransferFrom(
            msg.sender,
            address(this),
            assetId,
            amount,
            ""
        );
        
        emit AssetAddedToInventory(tokenId, assetId, amount);
    }

    function removeAssetFromInventory(uint256 tokenId, uint256 assetId, uint256 amount) external onlyTokenOwner(tokenId) nonReentrant {
        require(amount > 0, "Invalid amount");
        
        uint256 inventoryBalance = tokenInventory[tokenId][assetId].length;
        require(inventoryBalance >= amount, "Insufficient inventory balance");

        // Remove from inventory
        for (uint256 i = 0; i < amount; i++) {
            tokenInventory[tokenId][assetId].pop();
        }

        IERC1155(address(traitsCore)).safeTransferFrom(
            address(this),
            msg.sender,
            assetId,
            amount,
            ""
        );
        
        emit AssetRemovedFromInventory(tokenId, assetId, amount);
    }

    function getInventoryBalance(uint256 tokenId, uint256 assetId) external view returns (uint256) {
        return tokenInventory[tokenId][assetId].length;
    }

    // =============== CONTRACT MANAGEMENT ===============
    
    function setAdrianLabCoreContract(address _contract) external onlyOwner {
        require(_contract != address(0), "Invalid address");
        adrianLabCoreContract = _contract;
    }

    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Invalid address");
        treasury = _treasury;
    }

    function setPaymentToken(address _paymentToken) external onlyOwner {
        require(_paymentToken != address(0), "Invalid address");
        paymentToken = IERC20(_paymentToken);
    }

    /** @dev Configura (o desactiva pasando address(0)) el registrador de historial on-chain */
    function setHistoryContract(address _historyContract) external onlyOwner {
        historyContract = IAdrianHistory(_historyContract);
    }

    /**
     * @dev Dummy function required by AdrianLabCore.setExtensionsContract()
     * @notice This function exists only to prevent LabCore from failing when setting extensions
     * @notice Real configuration must be done manually using setAdrianLabCoreContract()
     * @param _core The core contract address (logged but not stored automatically)
     */
    function setCoreContract(address _core) external {
        // No-op: This function exists only so that LabCore doesn't fail
        // Real setup is done manually with setAdrianLabCoreContract()
        emit CoreContractCallReceived(_core, block.timestamp);
    }

    // =============== VIEW FUNCTIONS ===============
    
    function isTraitAvailable(uint256 traitId, uint256 requiredAmount) external view returns (bool available, string memory reason) {
        if (!traitsCore.canEquipAsset(traitId)) {
            return (false, "Cannot equip this asset type");
        }
        
        uint256 availableSupply = traitsCore.getAvailableSupply(traitId);
        if (availableSupply < requiredAmount) {
            return (false, "Insufficient global supply");
        }
        
        return (true, "Trait available");
    }

    function canUserAccessTrait(address user, uint256 traitId, uint256 requiredAmount) external view returns (bool canAccess, string memory reason) {
        (bool available, string memory availabilityReason) = this.isTraitAvailable(traitId, requiredAmount);
        if (!available) {
            return (false, availabilityReason);
        }
        
        uint256 userBalance = traitsCore.balanceOf(user, traitId);
        if (userBalance < requiredAmount) {
            return (false, "Insufficient user balance");
        }
        
        return (true, "User can access trait");
    }

    function getAllEquippedTraits(uint256 tokenId)
        public
        view
        returns (string[] memory categories, uint256[] memory traitIds)
    {
        string[] memory tokenCats = tokenCategories[tokenId];
        uint256 equippedCount = 0;
        
        // Count equipped traits
        for (uint256 i = 0; i < tokenCats.length; i++) {
            if (equippedTrait[tokenId][tokenCats[i]] != 0) {
                equippedCount++;
            }
        }

        categories = new string[](equippedCount);
        traitIds = new uint256[](equippedCount);

        uint256 index = 0;
        for (uint256 i = 0; i < tokenCats.length; i++) {
            uint256 traitId = equippedTrait[tokenId][tokenCats[i]];
            if (traitId != 0) {
                categories[index] = tokenCats[i];
                traitIds[index] = traitId;
                index++;
            }
        }
    }

    function getCategories() public view returns (string[] memory) {
        return traitsCore.getCategoryList();
    }

    // =============== ERC1155 RECEIVER FUNCTIONS ===============
    
    function onERC1155Received(address, address, uint256, uint256, bytes memory) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory) public virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}
