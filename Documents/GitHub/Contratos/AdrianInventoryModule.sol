// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// =============== CONSTANTES DE RANGOS FASE 2 ===============
uint256 constant TRAIT_ID_MAX = 99_999;        // Actualizado desde 999_999
uint256 constant PACK_ID_MIN = 100_000;        // Actualizado desde 1_000_000  
uint256 constant PACK_ID_MAX = 109_999;        // Actualizado desde 1_999_999
uint256 constant SERUM_ID_MIN = 110_000;       // NUEVO rango para serums

// =============== Funciones de Validación de Rangos ===============
library InventoryValidation {
    function isValidTraitId(uint256 id) internal pure returns (bool) {
        return id > 0 && id <= TRAIT_ID_MAX;
    }
    
    function isValidPackId(uint256 id) internal pure returns (bool) {
        return id >= PACK_ID_MIN && id <= PACK_ID_MAX;
    }
    
    function isValidSerumId(uint256 id) internal pure returns (bool) {
        return id >= SERUM_ID_MIN;
    }
    
    function isValidInventoryAsset(uint256 id) internal pure returns (bool) {
        return isValidTraitId(id) || isValidPackId(id) || isValidSerumId(id); // Todos los tipos válidos para inventario
    }
    
    function getAssetType(uint256 id) internal pure returns (string memory) {
        if (isValidTraitId(id)) return "TRAIT";
        if (isValidPackId(id)) return "PACK";  
        if (isValidSerumId(id)) return "SERUM";
        return "UNKNOWN";
    }
    
    // ✅ HELPER: Funciones específicas para validación directa
    function isTraitAsset(uint256 id) internal pure returns (bool) {
        return isValidTraitId(id);
    }
    
    function isPackAsset(uint256 id) internal pure returns (bool) {
        return isValidPackId(id);
    }
    
    function isSerumAsset(uint256 id) internal pure returns (bool) {
        return isValidSerumId(id);
    }
}

// =============== INTERFACES SINCRONIZADAS FASE 2 ===============

interface IAdrianTraitsCore {
    function burn(address from, uint256 id, uint256 amount) external;
    function mint(address to, uint256 id, uint256 amount) external;
    function owner() external view returns (address);
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function getCategory(uint256 assetId) external view returns (string memory);
    function getName(uint256 assetId) external view returns (string memory);
    function isTemporary(uint256 assetId) external view returns (bool);
    function getTraitInfo(uint256 assetId) external view returns (string memory category, bool isTemp);
    function getCategoryList() external view returns (string[] memory);
}

interface IAdrianLabCore {
    function ownerOf(uint256 tokenId) external view returns (address);
    function exists(uint256 tokenId) external view returns (bool);
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

contract AdrianInventoryModule is Ownable, ReentrancyGuard {
    
    // =============== State Variables ===============
    
    address public traitsCore;
    address public labCore;
    address public historyContract;

    // Inventory tracking - tokenId => category => traitId[]
    mapping(uint256 => mapping(string => uint256[])) public tokenInventoryByCategory;
    
    // Equipped traits - tokenId => category => traitId (solo uno equipado por categoría)
    mapping(uint256 => mapping(string => uint256)) public equippedTrait;
    
    // Reverse lookup - tokenId => traitId => equipped
    mapping(uint256 => mapping(uint256 => bool)) public isTraitEquipped;
    
    // Categories that each token has
    mapping(uint256 => string[]) public tokenCategories;
    mapping(uint256 => mapping(string => bool)) public tokenHasCategory;
    
    // Global inventory - tokenId => traitId[]  
    mapping(uint256 => uint256[]) public tokenGlobalInventory;
    mapping(uint256 => mapping(uint256 => uint256)) public tokenTraitCount; // tokenId => traitId => count
    
    // Trait usage tracking
    mapping(uint256 => mapping(uint256 => uint256)) public traitUsageCount; // tokenId => traitId => timesUsed
    mapping(uint256 => uint256[]) public usedTraitsHistory; // tokenId => traitId[] (history)

    // System settings
    bool public inventorySystemEnabled = true;
    mapping(string => bool) public categoryEnabled;
    mapping(uint256 => bool) public traitBanned;

    // =============== Events ===============
    
    event TraitEquipped(uint256 indexed tokenId, string category, uint256 indexed traitId);
    event TraitUnequipped(uint256 indexed tokenId, string category, uint256 indexed traitId);
    event TraitAddedToInventory(uint256 indexed tokenId, uint256 indexed traitId, uint256 amount);
    event TraitRemovedFromInventory(uint256 indexed tokenId, uint256 indexed traitId, uint256 amount);
    event TraitBurned(uint256 indexed tokenId, uint256 indexed traitId, uint256 amount, address user);
    event TraitTransformed(uint256 indexed tokenId, uint256 indexed burnedTraitId, uint256 indexed newTraitId, address user);
    event TraitEvolved(uint256 indexed tokenId, uint256[] burnedTraitIds, uint256 indexed evolvedTraitId, address user);
    event TraitUsed(uint256 indexed tokenId, uint256 indexed traitId, address user);
    event InventorySystemStatusChanged(bool enabled);
    event CategoryStatusChanged(string category, bool enabled);
    event TraitBannedStatusChanged(uint256 indexed traitId, bool banned);
    event ContractUpdated(string contractName, address oldAddress, address newAddress);

    // =============== Modifiers ===============

    modifier onlyCoreOwner() {
        require(msg.sender == IAdrianTraitsCore(traitsCore).owner(), "Not core owner");
        _;
    }

    modifier onlyTokenOwner(uint256 tokenId) {
        require(IAdrianLabCore(labCore).ownerOf(tokenId) == msg.sender, "Not token owner");
        _;
    }

    modifier systemEnabled() {
        require(inventorySystemEnabled, "Inventory system disabled");
        _;
    }

    modifier validToken(uint256 tokenId) {
        require(IAdrianLabCore(labCore).exists(tokenId), "Token does not exist");
        _;
    }

    modifier notBannedTrait(uint256 traitId) {
        require(!traitBanned[traitId], "Trait is banned");
        _;
    }

    modifier validInventoryAsset(uint256 assetId) {
        require(InventoryValidation.isValidInventoryAsset(assetId), "Invalid asset for inventory");
        _;
    }

    // =============== Constructor ===============
    
    constructor(address _traitsCore, address _labCore) Ownable(msg.sender) {
        require(_traitsCore != address(0) && _traitsCore.code.length > 0, "Invalid traits core");
        require(_labCore != address(0) && _labCore.code.length > 0, "Invalid lab core");
        
        traitsCore = _traitsCore;
        labCore = _labCore;
        
        // Enable common categories by default
        categoryEnabled["BACKGROUND"] = true;
        categoryEnabled["BASE"] = true;
        categoryEnabled["BODY"] = true;
        categoryEnabled["CLOTHING"] = true;
        categoryEnabled["EYES"] = true;
        categoryEnabled["MOUTH"] = true;
        categoryEnabled["HEAD"] = true;
        categoryEnabled["ACCESSORIES"] = true;
    }

    // =============== REQUIRED FUNCTIONS FOR AdrianLabView ===============

    /**
     * @dev Get equipped traits for a token (REQUIRED by AdrianLabView)
     */
    function getEquippedTraits(uint256 tokenId) external view validToken(tokenId) returns (uint256[] memory) {
        string[] memory categories = tokenCategories[tokenId];
        uint256 count = 0;
        
        // Count equipped traits
        for (uint256 i = 0; i < categories.length; i++) {
            if (equippedTrait[tokenId][categories[i]] != 0) {
                count++;
            }
        }
        
        // Build result array
        uint256[] memory equipped = new uint256[](count);
        uint256 index = 0;
        
        for (uint256 i = 0; i < categories.length; i++) {
            uint256 traitId = equippedTrait[tokenId][categories[i]];
            if (traitId != 0) {
                equipped[index] = traitId;
                index++;
            }
        }
        
        return equipped;
    }

    /**
     * @dev Get inventory items for a token (REQUIRED by AdrianLabView)
     */
    function getInventoryItems(uint256 tokenId) external view validToken(tokenId) returns (
        uint256[] memory traitIds,
        uint256[] memory amounts
    ) {
        uint256[] memory inventory = tokenGlobalInventory[tokenId];
        amounts = new uint256[](inventory.length);
        
        for (uint256 i = 0; i < inventory.length; i++) {
            amounts[i] = tokenTraitCount[tokenId][inventory[i]];
        }
        
        return (inventory, amounts);
    }

    // =============== Inventory Management ===============

    /**
     * @dev Add trait to token inventory
     */
    function addTraitToInventory(
        uint256 tokenId, 
        uint256 traitId, 
        uint256 amount
    ) external onlyTokenOwner(tokenId) systemEnabled notBannedTrait(traitId) validInventoryAsset(traitId) nonReentrant {
        require(amount > 0, "Invalid amount");
        require(IAdrianTraitsCore(traitsCore).balanceOf(msg.sender, traitId) >= amount, "Insufficient balance");

        // ✅ FASE 2: Validación específica de tipo de asset
        require(InventoryValidation.isValidInventoryAsset(traitId), "Invalid asset type for inventory");

        // Transfer traits to this contract for escrow
        IAdrianTraitsCore(traitsCore).burn(msg.sender, traitId, amount);

        string memory category = IAdrianTraitsCore(traitsCore).getCategory(traitId);
        require(categoryEnabled[category], "Category disabled");

        // Add to category inventory
        if (!tokenHasCategory[tokenId][category]) {
            tokenCategories[tokenId].push(category);
            tokenHasCategory[tokenId][category] = true;
        }
        
        // Add to category-specific inventory
        tokenInventoryByCategory[tokenId][category].push(traitId);
        
        // Add to global inventory if not already present
        if (tokenTraitCount[tokenId][traitId] == 0) {
            tokenGlobalInventory[tokenId].push(traitId);
        }
        
        // Update count
        tokenTraitCount[tokenId][traitId] += amount;

        // Record in history
        _recordHistory(tokenId, "TRAIT_ADDED_TO_INVENTORY", abi.encode(traitId, amount, category));

        emit TraitAddedToInventory(tokenId, traitId, amount);
    }

    /**
     * @dev Remove trait from token inventory
     */
    function removeTraitFromInventory(
        uint256 tokenId, 
        uint256 traitId, 
        uint256 amount
    ) external onlyTokenOwner(tokenId) systemEnabled validInventoryAsset(traitId) nonReentrant {
        require(amount > 0, "Invalid amount");
        require(tokenTraitCount[tokenId][traitId] >= amount, "Insufficient inventory");

        // Update count
        tokenTraitCount[tokenId][traitId] -= amount;

        // Remove from global inventory if count reaches 0
        if (tokenTraitCount[tokenId][traitId] == 0) {
            _removeFromGlobalInventory(tokenId, traitId);
            
            // Remove from category inventory
            string memory category = IAdrianTraitsCore(traitsCore).getCategory(traitId);
            _removeFromCategoryInventory(tokenId, category, traitId);
        }

        // Return traits to user
        IAdrianTraitsCore(traitsCore).mint(msg.sender, traitId, amount);

        // Record in history
        _recordHistory(tokenId, "TRAIT_REMOVED_FROM_INVENTORY", abi.encode(traitId, amount));

        emit TraitRemovedFromInventory(tokenId, traitId, amount);
    }

    /**
     * @dev Equip trait to token
     */
    function equipTrait(
        uint256 tokenId, 
        uint256 traitId
    ) external onlyTokenOwner(tokenId) systemEnabled notBannedTrait(traitId) validInventoryAsset(traitId) nonReentrant {
        require(tokenTraitCount[tokenId][traitId] > 0, "Trait not in inventory");
        
        // ✅ FASE 2: Solo traits pueden ser equipados (no packs ni serums directamente)
        require(InventoryValidation.isTraitAsset(traitId), "Only traits can be equipped");
        
        string memory category = IAdrianTraitsCore(traitsCore).getCategory(traitId);
        require(categoryEnabled[category], "Category disabled");

        // Unequip current trait if any
        uint256 currentEquipped = equippedTrait[tokenId][category];
        if (currentEquipped != 0) {
            isTraitEquipped[tokenId][currentEquipped] = false;
            emit TraitUnequipped(tokenId, category, currentEquipped);
        }

        // Equip new trait
        equippedTrait[tokenId][category] = traitId;
        isTraitEquipped[tokenId][traitId] = true;

        // Handle temporary traits
        if (IAdrianTraitsCore(traitsCore).isTemporary(traitId)) {
            // Remove from inventory for temporary traits
            tokenTraitCount[tokenId][traitId]--;
            if (tokenTraitCount[tokenId][traitId] == 0) {
                _removeFromGlobalInventory(tokenId, traitId);
                _removeFromCategoryInventory(tokenId, category, traitId);
            }
        }

        // Record in history
        _recordHistory(tokenId, "TRAIT_EQUIPPED", abi.encode(traitId, category));

        emit TraitEquipped(tokenId, category, traitId);
    }

    /**
     * @dev Unequip trait from token
     */
    function unequipTrait(
        uint256 tokenId, 
        string calldata category
    ) external onlyTokenOwner(tokenId) systemEnabled nonReentrant {
        uint256 traitId = equippedTrait[tokenId][category];
        require(traitId != 0, "No trait equipped in category");

        // Unequip
        equippedTrait[tokenId][category] = 0;
        isTraitEquipped[tokenId][traitId] = false;

        // Record in history
        _recordHistory(tokenId, "TRAIT_UNEQUIPPED", abi.encode(traitId, category));

        emit TraitUnequipped(tokenId, category, traitId);
    }

    // =============== Trait Operations (Original Logic) ===============

    /**
     * @dev Burn trait from inventory
     */
    function burnTrait(
        uint256 tokenId, 
        uint256 traitId, 
        uint256 amount
    ) external onlyTokenOwner(tokenId) systemEnabled validInventoryAsset(traitId) nonReentrant {
        require(tokenTraitCount[tokenId][traitId] >= amount, "Insufficient inventory");

        // Update inventory
        tokenTraitCount[tokenId][traitId] -= amount;
        if (tokenTraitCount[tokenId][traitId] == 0) {
            _removeFromGlobalInventory(tokenId, traitId);
            string memory category = IAdrianTraitsCore(traitsCore).getCategory(traitId);
            _removeFromCategoryInventory(tokenId, category, traitId);
        }

        // Record in history
        _recordHistory(tokenId, "TRAIT_BURNED", abi.encode(traitId, amount));

        emit TraitBurned(tokenId, traitId, amount, msg.sender);
    }

    /**
     * @dev Transform trait: burn A, get B
     */
    function transformTrait(
        uint256 tokenId,
        uint256 burnTraitId, 
        uint256 burnAmount, 
        uint256 newTraitId, 
        uint256 newAmount
    ) external onlyCoreOwner systemEnabled {
        // ✅ FASE 2: Validar ambos assets
        require(InventoryValidation.isValidInventoryAsset(burnTraitId), "Invalid burn asset");
        require(InventoryValidation.isValidInventoryAsset(newTraitId), "Invalid new asset");
        
        address tokenOwner = IAdrianLabCore(labCore).ownerOf(tokenId);
        require(tokenTraitCount[tokenId][burnTraitId] >= burnAmount, "Insufficient burn trait");

        // Remove burned trait from inventory
        tokenTraitCount[tokenId][burnTraitId] -= burnAmount;
        if (tokenTraitCount[tokenId][burnTraitId] == 0) {
            _removeFromGlobalInventory(tokenId, burnTraitId);
            string memory burnCategory = IAdrianTraitsCore(traitsCore).getCategory(burnTraitId);
            _removeFromCategoryInventory(tokenId, burnCategory, burnTraitId);
        }

        // Add new trait to inventory
        string memory newCategory = IAdrianTraitsCore(traitsCore).getCategory(newTraitId);
        if (!tokenHasCategory[tokenId][newCategory]) {
            tokenCategories[tokenId].push(newCategory);
            tokenHasCategory[tokenId][newCategory] = true;
        }
        
        if (tokenTraitCount[tokenId][newTraitId] == 0) {
            tokenGlobalInventory[tokenId].push(newTraitId);
            tokenInventoryByCategory[tokenId][newCategory].push(newTraitId);
        }
        tokenTraitCount[tokenId][newTraitId] += newAmount;

        // Mint new trait to owner
        IAdrianTraitsCore(traitsCore).mint(tokenOwner, newTraitId, newAmount);

        // Record in history
        _recordHistory(tokenId, "TRAIT_TRANSFORMED", abi.encode(burnTraitId, newTraitId, burnAmount, newAmount));

        emit TraitTransformed(tokenId, burnTraitId, newTraitId, msg.sender);
    }

    /**
     * @dev Evolve traits: burn multiple, get evolved one
     */
    function evolveTraits(
        uint256 tokenId,
        uint256[] calldata burnTraitIds,
        uint256[] calldata burnAmounts,
        uint256 evolvedTraitId
    ) external onlyCoreOwner systemEnabled {
        require(burnTraitIds.length == burnAmounts.length, "Arrays length mismatch");
        
        // ✅ FASE 2: Validar todos los assets
        for (uint256 i = 0; i < burnTraitIds.length; i++) {
            require(InventoryValidation.isValidInventoryAsset(burnTraitIds[i]), "Invalid burn asset");
        }
        require(InventoryValidation.isValidInventoryAsset(evolvedTraitId), "Invalid evolved asset");
        
        address tokenOwner = IAdrianLabCore(labCore).ownerOf(tokenId);

        // Burn all required traits
        for (uint256 i = 0; i < burnTraitIds.length; i++) {
            uint256 traitId = burnTraitIds[i];
            uint256 amount = burnAmounts[i];
            
            require(tokenTraitCount[tokenId][traitId] >= amount, "Insufficient trait for evolution");
            
            tokenTraitCount[tokenId][traitId] -= amount;
            if (tokenTraitCount[tokenId][traitId] == 0) {
                _removeFromGlobalInventory(tokenId, traitId);
                string memory category = IAdrianTraitsCore(traitsCore).getCategory(traitId);
                _removeFromCategoryInventory(tokenId, category, traitId);
            }
        }

        // Add evolved trait to inventory
        string memory evolvedCategory = IAdrianTraitsCore(traitsCore).getCategory(evolvedTraitId);
        if (!tokenHasCategory[tokenId][evolvedCategory]) {
            tokenCategories[tokenId].push(evolvedCategory);
            tokenHasCategory[tokenId][evolvedCategory] = true;
        }
        
        if (tokenTraitCount[tokenId][evolvedTraitId] == 0) {
            tokenGlobalInventory[tokenId].push(evolvedTraitId);
            tokenInventoryByCategory[tokenId][evolvedCategory].push(evolvedTraitId);
        }
        tokenTraitCount[tokenId][evolvedTraitId] += 1;

        // Mint evolved trait to owner
        IAdrianTraitsCore(traitsCore).mint(tokenOwner, evolvedTraitId, 1);

        // Record in history
        _recordHistory(tokenId, "TRAIT_EVOLVED", abi.encode(burnTraitIds, evolvedTraitId));

        emit TraitEvolved(tokenId, burnTraitIds, evolvedTraitId, msg.sender);
    }

    /**
     * @dev Use trait (consume from inventory)
     */
    function useTrait(
        uint256 tokenId, 
        uint256 traitId
    ) external onlyTokenOwner(tokenId) systemEnabled validInventoryAsset(traitId) nonReentrant {
        require(tokenTraitCount[tokenId][traitId] > 0, "Trait not in inventory");

        // Remove from inventory
        tokenTraitCount[tokenId][traitId]--;
        if (tokenTraitCount[tokenId][traitId] == 0) {
            _removeFromGlobalInventory(tokenId, traitId);
            string memory category = IAdrianTraitsCore(traitsCore).getCategory(traitId);
            _removeFromCategoryInventory(tokenId, category, traitId);
        }

        // Track usage
        traitUsageCount[tokenId][traitId]++;
        usedTraitsHistory[tokenId].push(traitId);

        // Record in history
        _recordHistory(tokenId, "TRAIT_USED", abi.encode(traitId, traitUsageCount[tokenId][traitId]));

        emit TraitUsed(tokenId, traitId, msg.sender);
    }

    // =============== FASE 2: Funciones de Validación y Utilidad ===============

    /**
     * @dev Validate asset for inventory operations
     */
    function validateInventoryAsset(uint256 assetId) external pure returns (bool isValid, string memory assetType, string memory reason) {
        if (InventoryValidation.isTraitAsset(assetId)) {
            return (true, "TRAIT", "Valid trait asset");
        } else if (InventoryValidation.isPackAsset(assetId)) {
            return (true, "PACK", "Valid pack asset");
        } else if (InventoryValidation.isSerumAsset(assetId)) {
            return (true, "SERUM", "Valid serum asset");
        }
        return (false, "INVALID", "Invalid asset ID range");
    }

    /**
     * @dev Check if asset can be equipped
     */
    function canEquipAsset(uint256 assetId) external pure returns (bool canEquip, string memory reason) {
        if (InventoryValidation.isTraitAsset(assetId)) {
            return (true, "Traits can be equipped");
        } else if (InventoryValidation.isPackAsset(assetId)) {
            return (false, "Packs cannot be equipped directly");
        } else if (InventoryValidation.isSerumAsset(assetId)) {
            return (false, "Serums cannot be equipped directly");
        }
        return (false, "Invalid asset ID range");
    }

    /**
     * @dev Get supported asset ranges for inventory
     */
    function getInventoryRanges() external pure returns (
        uint256 traitMax,
        uint256 packMin,
        uint256 packMax,
        uint256 serumMin,
        string memory info
    ) {
        return (
            TRAIT_ID_MAX, 
            PACK_ID_MIN,
            PACK_ID_MAX,
            SERUM_ID_MIN, 
            "All asset types supported in inventory"
        );
    }

    /**
     * @dev Get asset type by ID
     */
    function getAssetType(uint256 assetId) external pure returns (string memory) {
        return InventoryValidation.getAssetType(assetId);
    }

    /**
     * @dev Check if asset ID is valid for inventory
     */
    function isValidInventoryAsset(uint256 assetId) external pure returns (bool) {
        return InventoryValidation.isValidInventoryAsset(assetId);
    }

    /**
     * @dev Get range info for debugging
     */
    function getRangeInfo() external pure returns (
        uint256 traitMax,
        uint256 packMin,
        uint256 packMax,
        uint256 serumMin
    ) {
        return (TRAIT_ID_MAX, PACK_ID_MIN, PACK_ID_MAX, SERUM_ID_MIN);
    }

    /**
     * @dev Get detailed inventory status for a token
     */
    function getDetailedInventoryStatus(uint256 tokenId) external view validToken(tokenId) returns (
        uint256 totalAssets,
        uint256 equippedCount,
        string[] memory categories,
        uint256[] memory categoryTotals
    ) {
        totalAssets = tokenGlobalInventory[tokenId].length;
        categories = tokenCategories[tokenId];
        categoryTotals = new uint256[](categories.length);
        equippedCount = 0;
        
        for (uint256 i = 0; i < categories.length; i++) {
            categoryTotals[i] = tokenInventoryByCategory[tokenId][categories[i]].length;
            if (equippedTrait[tokenId][categories[i]] != 0) {
                equippedCount++;
            }
        }
        
        return (totalAssets, equippedCount, categories, categoryTotals);
    }

    /**
     * @dev Get assets by type in inventory
     */
    function getAssetsByType(uint256 tokenId, string calldata assetType) external view validToken(tokenId) returns (
        uint256[] memory assetIds,
        uint256[] memory amounts
    ) {
        uint256[] memory allAssets = tokenGlobalInventory[tokenId];
        uint256 count = 0;
        
        // Count assets of specified type
        for (uint256 i = 0; i < allAssets.length; i++) {
            string memory currentType = InventoryValidation.getAssetType(allAssets[i]);
            if (keccak256(abi.encodePacked(currentType)) == keccak256(abi.encodePacked(assetType))) {
                count++;
            }
        }
        
        // Build result arrays
        assetIds = new uint256[](count);
        amounts = new uint256[](count);
        uint256 index = 0;
        
        for (uint256 i = 0; i < allAssets.length; i++) {
            string memory currentType = InventoryValidation.getAssetType(allAssets[i]);
            if (keccak256(abi.encodePacked(currentType)) == keccak256(abi.encodePacked(assetType))) {
                assetIds[index] = allAssets[i];
                amounts[index] = tokenTraitCount[tokenId][allAssets[i]];
                index++;
            }
        }
        
        return (assetIds, amounts);
    }

    // =============== View Functions ===============

    function getTokenInventoryByCategory(uint256 tokenId, string calldata category) external view returns (uint256[] memory) {
        return tokenInventoryByCategory[tokenId][category];
    }

    function getTokenCategories(uint256 tokenId) external view returns (string[] memory) {
        return tokenCategories[tokenId];
    }

    function getEquippedTraitInCategory(uint256 tokenId, string calldata category) external view returns (uint256) {
        return equippedTrait[tokenId][category];
    }

    function getTraitCount(uint256 tokenId, uint256 traitId) external view returns (uint256) {
        return tokenTraitCount[tokenId][traitId];
    }

    function getTraitUsageCount(uint256 tokenId, uint256 traitId) external view returns (uint256) {
        return traitUsageCount[tokenId][traitId];
    }

    function getUsedTraitsHistory(uint256 tokenId) external view returns (uint256[] memory) {
        return usedTraitsHistory[tokenId];
    }

    function isTraitInInventory(uint256 tokenId, uint256 traitId) external view returns (bool) {
        return tokenTraitCount[tokenId][traitId] > 0;
    }

    // =============== Admin Functions ===============

    function setHistoryContract(address _historyContract) external onlyOwner {
        require(_historyContract != address(0) && _historyContract.code.length > 0, "Invalid contract");
        historyContract = _historyContract;
    }

    function setInventorySystemEnabled(bool _enabled) external onlyOwner {
        inventorySystemEnabled = _enabled;
        emit InventorySystemStatusChanged(_enabled);
    }

    function setCategoryEnabled(string calldata category, bool _enabled) external onlyOwner {
        categoryEnabled[category] = _enabled;
        emit CategoryStatusChanged(category, _enabled);
    }

    function setTraitBanned(uint256 traitId, bool _banned) external onlyOwner {
        traitBanned[traitId] = _banned;
        emit TraitBannedStatusChanged(traitId, _banned);
    }

    // ✅ SETTERS PARA ACTUALIZACIONES DE CONTRATOS
    
    /**
     * @dev Actualiza la dirección del contrato AdrianTraitsCore
     */
    function setTraitsCore(address _traitsCore) external onlyOwner {
        require(_traitsCore != address(0) && _traitsCore.code.length > 0, "Invalid traits core");
        address oldCore = traitsCore;
        traitsCore = _traitsCore;
        emit ContractUpdated("TraitsCore", oldCore, _traitsCore);
    }
    
    /**
     * @dev Actualiza la dirección del contrato AdrianLabCore
     */
    function setLabCore(address _labCore) external onlyOwner {
        require(_labCore != address(0) && _labCore.code.length > 0, "Invalid lab core");
        address oldCore = labCore;
        labCore = _labCore;
        emit ContractUpdated("LabCore", oldCore, _labCore);
    }

    // =============== Internal Functions ===============

    function _removeFromGlobalInventory(uint256 tokenId, uint256 traitId) internal {
        uint256[] storage inventory = tokenGlobalInventory[tokenId];
        for (uint256 i = 0; i < inventory.length; i++) {
            if (inventory[i] == traitId) {
                inventory[i] = inventory[inventory.length - 1];
                inventory.pop();
                break;
            }
        }
    }

    function _removeFromCategoryInventory(uint256 tokenId, string memory category, uint256 traitId) internal {
        uint256[] storage categoryInventory = tokenInventoryByCategory[tokenId][category];
        for (uint256 i = 0; i < categoryInventory.length; i++) {
            if (categoryInventory[i] == traitId) {
                categoryInventory[i] = categoryInventory[categoryInventory.length - 1];
                categoryInventory.pop();
                break;
            }
        }
    }

    function _recordHistory(uint256 tokenId, string memory eventType, bytes memory data) internal {
        if (historyContract != address(0)) {
            IAdrianHistory(historyContract).recordEvent(
                tokenId,
                keccak256(abi.encodePacked(eventType)),
                msg.sender,
                data,
                block.number
            );
        }
    }
}