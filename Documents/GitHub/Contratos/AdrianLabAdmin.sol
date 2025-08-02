// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

// =============== INTERFACES ORGANIZADAS ===============

interface IAdrianLabCore {
    function setSerumModule(address _module) external;
    function setAdrianLabExtensions(address _extensions) external;
    function setBaseURI(string calldata newURI) external;
    function setFunctionImplementation(bytes32 key, address implementation) external;
    function setRandomSkin(bool enabled) external;
    function setTokenModified(uint256 tokenId, bool modified) external;
    function setTokenDuplicated(uint256 tokenId, bool duplicated) external;
    function setTokenMutatedBySerum(uint256 tokenId, bool mutated) external;
    function setTokenMutationLevel(uint256 tokenId, uint8 level) external;
    function setAdminContract(address admin) external;
    function ownerOf(uint256 tokenId) external view returns (address);
    function exists(uint256 tokenId) external view returns (bool);
    function owner() external view returns (address);
}

interface IAdrianLabExtensions {
    function tokenHistory(uint256) external view returns (uint256[] memory);
    function resetTokenHistory(uint256 tokenId) external;
    function getTraits(uint256 tokenId) external view returns (uint256, uint256, string memory);
    function setCoreContract(address _core) external;
    function onTokenMinted(uint256 tokenId, address to) external;
}

interface IAdrianTraitsCore {
    function getTraitInfo(uint256 assetId) external view returns (string memory, bool);
    function getName(uint256 assetId) external view returns (string memory);
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function owner() external view returns (address);
    
    // ✅ NEW: Functions for administrative management
    function assets(uint256 assetId) external view returns (
        string memory name,
        string memory category,
        string memory ipfsPath,
        bool tempFlag,
        uint256 maxSupply,
        uint8 assetType,
        string memory metadata
    );
    function totalMintedPerAsset(uint256 assetId) external view returns (uint256);
    function packConfigs(uint256 packId) external view returns (
        uint256 id,
        uint256 price,
        uint256 maxSupply,
        uint256 minted,
        uint256 itemsPerPack,
        uint256 maxPerWallet,
        bool active,
        bool requiresAllowlist,
        bytes32 merkleRoot,
        string memory uri
    );
}

interface IAdrianSerumModule {
    function getSerumData(uint256 serumId) external view returns (string memory, uint256);
    function setCoreContract(address _core) external;
    function simulateUse(uint256 serumId, uint256 tokenId) external view returns (bool);
}

interface IAdrianInventoryModule {
    function getEquippedTraits(uint256 tokenId) external view returns (uint256[] memory);
    function getInventoryItems(uint256 tokenId) external view returns (uint256[] memory, uint256[] memory);
}

interface IAdrianHistory {
    struct HistoricalEvent {
        uint256 timestamp;
        bytes32 eventType;
        address actorAddress;
        bytes eventData;
        uint256 blockNumber;
    }
    
    function getHistory(uint256 tokenId) external view returns (HistoricalEvent[] memory);
    function getHistoryCount(uint256 tokenId) external view returns (uint256);
    function resetTokenHistory(uint256 tokenId) external;
    function recordEvent(
        uint256 tokenId,
        bytes32 eventType,
        address actor,
        bytes calldata eventData,
        uint256 blockNumber
    ) external;
}

interface IAdrianDuplicatorModule {
    function hasBeenDuplicated(uint256 tokenId) external view returns (bool);
    function duplicateAdrian(uint256 originalTokenId, address recipient) external returns (uint256);
}

interface IAdrianMintModule {
    function getMintStatus(uint256 tokenId) external view returns (bool);
    function getCurrentBatchInfo() external view returns (
        uint256 batchId, string memory name, uint256 price, uint256 minted,
        uint256 maxSupply, bool active, uint256 startTime, uint256 endTime, bool useMerkleWhitelist
    );
}

interface IAdrianLabCrafting {
    function nextRecipeId() external view returns (uint256);
    function craftingRecipes(uint256 recipeId) external view returns (
        uint256 id, uint256[] memory ingredientIds, uint256[] memory ingredientAmounts,
        uint256 resultId, uint256 resultAmount, bool consumeIngredients, bool active,
        uint256 minLevel, bool requiresAllowlist
    );
}

interface IAdrianLabMarketplace {
    function nextListingId() external view returns (uint256);
    function getListingDetails(uint256 listingId) external view returns (
        address seller, uint256 assetId, uint256 amount, uint256 pricePerUnit,
        uint256 expiration, bool active
    );
}

/**
 * @title AdrianLabAdmin
 * @dev Contrato administrativo centralizado para gestión del ecosistema AdrianLab
 * @notice UPGRADED - FASE 1: Incluye MaxSupply Dinámico + Sistema de Precios Progresivos
 */
contract AdrianLabAdmin is Ownable {
    // =============== Type Definitions ===============
    
    // ✅ NEW: Sistema de Precios Progresivos (movido desde AdrianTraitsCore)
    struct PackPricing {
        uint256 freeMints;          // Cuántos packs gratis por wallet
        uint256 paidPrice;          // Precio para packs adicionales
        bool useProgressivePricing; // Si usa precios progresivos
    }

    // =============== State Variables ===============
    
    address public core;
    address public extensionsContract;
    address public traitsContract;
    address public serumModule;
    address public inventoryModule;
    address public historyContract;
    address public duplicatorModule;
    address public mintModule;
    address public craftingContract;
    address public marketplaceContract;

    // Emergency features
    bool public emergencyMode = false;
    mapping(address => bool) public emergencyAdmins;

    // ✅ NEW: Sistema de Precios Progresivos (movido desde AdrianTraitsCore)
    mapping(uint256 => PackPricing) public packPricing;          // packId → pricing config
    mapping(address => mapping(uint256 => uint256)) public freeMintsUsed;  // wallet → packId → used

    // =============== Events ===============
    
    event CoreContractUpdated(address indexed newContract);
    event ExtensionsContractUpdated(address indexed newContract);
    event TraitsContractUpdated(address indexed newContract);
    event SerumModuleUpdated(address indexed newModule);
    event InventoryModuleUpdated(address indexed newModule);
    event HistoryContractUpdated(address indexed newContract);
    event DuplicatorModuleUpdated(address indexed newModule);
    event MintModuleUpdated(address indexed newModule);
    event CraftingContractUpdated(address indexed newContract);
    event MarketplaceContractUpdated(address indexed newContract);
    event TokenHistoryReset(uint256 indexed tokenId);
    event EmergencyModeToggled(bool enabled);
    event EmergencyAdminUpdated(address indexed admin, bool status);
    event BatchAdminAction(string indexed actionType, uint256 count, bool success);

    // ✅ NEW: Eventos para nuevas features administrativas
    event AssetMaxSupplyUpdated(uint256 indexed assetId, uint256 oldMaxSupply, uint256 newMaxSupply);
    event PackPricingSet(uint256 indexed packId, uint256 freeMints, uint256 paidPrice, bool useProgressive);
    event FreePackClaimed(address indexed user, uint256 indexed packId, uint256 freeMintsRemaining);
    event PaidPackPurchased(address indexed user, uint256 indexed packId, uint256 quantity, uint256 totalCost);

    // =============== Modifiers ===============
    
    modifier onlyOwnerOrEmergency() {
        require(
            msg.sender == owner() || 
            (emergencyMode && emergencyAdmins[msg.sender]), 
            "Not authorized"
        );
        _;
    }

    modifier validContract(address _contract) {
        require(_contract != address(0) && _contract.code.length > 0, "Invalid contract");
        _;
    }

    modifier coreExists() {
        require(core != address(0), "Core contract not set");
        _;
    }

    modifier traitsExists() {
        require(traitsContract != address(0), "Traits contract not set");
        _;
    }

    modifier validAsset(uint256 assetId) {
        if (traitsContract != address(0)) {
            require(bytes(IAdrianTraitsCore(traitsContract).getName(assetId)).length > 0, "Asset does not exist");
        }
        _;
    }

    // =============== Constructor ===============
    
    constructor() Ownable(msg.sender) {
        // No validamos el core aquí, se hará después del deploy
    }

    // =============== Core Contract Management ===============
    
    /**
     * @dev Update core contract with full validation
     */
    function setCoreContract(address _contract) external onlyOwner validContract(_contract) {
        _setCoreContract(_contract);
    }

    function _setCoreContract(address _contract) internal {
        // Validate contract by calling a view function
        try IAdrianLabCore(_contract).owner() returns (address coreOwner) {
            require(coreOwner != address(0), "Invalid core contract");
            core = _contract;
            
            // Set bidirectional reference
            try IAdrianLabCore(_contract).setAdminContract(address(this)) {
                emit CoreContractUpdated(_contract);
            } catch {
                revert("Core contract rejected admin");
            }
        } catch {
            revert("Invalid core contract interface");
        }
    }

    /**
     * @dev Update core contract (emergency override)
     */
    function updateCore(address _newCore) external onlyOwnerOrEmergency validContract(_newCore) {
        _setCoreContract(_newCore);
    }

    // =============== NEW: MaxSupply Dinámico (Moved from AdrianTraitsCore) ===============

    /**
     * @dev Modifica el maxSupply de un asset existente
     * @param assetId ID del asset a modificar
     * @param newMaxSupply Nuevo maxSupply (debe ser >= totalMintedPerAsset)
     */
    function updateAssetMaxSupply(uint256 assetId, uint256 newMaxSupply) external onlyOwner traitsExists validAsset(assetId) {
        // Get current asset data from traits contract
        (,,,, uint256 currentMaxSupply,,) = IAdrianTraitsCore(traitsContract).assets(assetId);
        uint256 totalMinted = IAdrianTraitsCore(traitsContract).totalMintedPerAsset(assetId);
        
        // Validación: no permitir reducir por debajo de lo ya minteado
        require(newMaxSupply >= totalMinted, "Cannot reduce below minted amount");
        
        // Para maxSupply ilimitado, permitir 0
        if (newMaxSupply == 0) {
            require(currentMaxSupply > 0, "Asset already has unlimited supply");
        }
        
        // NOTE: This function assumes traits contract has an admin function to update maxSupply
        // The actual implementation would need to be added to AdrianTraitsCore
        
        emit AssetMaxSupplyUpdated(assetId, currentMaxSupply, newMaxSupply);
    }

    /**
     * @dev Batch update de maxSupply para múltiples assets
     */
    function batchUpdateAssetMaxSupply(
        uint256[] calldata assetIds,
        uint256[] calldata newMaxSupplies
    ) external onlyOwner traitsExists {
        require(assetIds.length == newMaxSupplies.length, "Arrays length mismatch");
        require(assetIds.length <= 50, "Batch too large"); // Prevent gas issues
        
        uint256 successCount = 0;
        
        for (uint256 i = 0; i < assetIds.length; i++) {
            try this.updateAssetMaxSupply(assetIds[i], newMaxSupplies[i]) {
                successCount++;
            } catch {
                // Continue with next asset
            }
        }
        
        emit BatchAdminAction("UPDATE_MAX_SUPPLY", successCount, successCount == assetIds.length);
    }

    // =============== NEW: Sistema de Precios Progresivos (Moved from AdrianTraitsCore) ===============

    /**
     * @dev Configura precios progresivos para un pack
     * @param packId ID del pack
     * @param freeMints Cantidad de packs gratis por wallet
     * @param paidPrice Precio para packs adicionales (después de usar freeMints)
     */
    function setPackPricing(uint256 packId, uint256 freeMints, uint256 paidPrice) external onlyOwner traitsExists {
        // Validate pack exists
        (uint256 id,,,,,,,,,) = IAdrianTraitsCore(traitsContract).packConfigs(packId);
        require(id == packId, "Pack does not exist");
        
        packPricing[packId] = PackPricing({
            freeMints: freeMints,
            paidPrice: paidPrice,
            useProgressivePricing: true
        });
        
        emit PackPricingSet(packId, freeMints, paidPrice, true);
    }

    /**
     * @dev Batch configuración de precios progresivos
     */
    function batchSetPackPricing(
        uint256[] calldata packIds,
        uint256[] calldata freeMints,
        uint256[] calldata paidPrices
    ) external onlyOwner traitsExists {
        require(packIds.length == freeMints.length && packIds.length == paidPrices.length, "Arrays length mismatch");
        require(packIds.length <= 50, "Batch too large");
        
        uint256 successCount = 0;
        
        for (uint256 i = 0; i < packIds.length; i++) {
            try this.setPackPricing(packIds[i], freeMints[i], paidPrices[i]) {
                successCount++;
            } catch {
                // Continue with next pack
            }
        }
        
        emit BatchAdminAction("SET_PACK_PRICING", successCount, successCount == packIds.length);
    }

    /**
     * @dev Desactiva precios progresivos para un pack (vuelve a precio fijo)
     */
    function disableProgressivePricing(uint256 packId) external onlyOwner traitsExists {
        // Validate pack exists
        (uint256 id,,,,,,,,,) = IAdrianTraitsCore(traitsContract).packConfigs(packId);
        require(id == packId, "Pack does not exist");
        
        packPricing[packId].useProgressivePricing = false;
        
        emit PackPricingSet(packId, 0, 0, false);
    }

    /**
     * @dev Calcula el precio actual para un usuario específico
     * @param packId ID del pack
     * @param user Dirección del usuario
     * @param quantity Cantidad que quiere comprar
     * @return totalCost Costo total a pagar
     * @return freeCount Cantidad que será gratis
     * @return paidCount Cantidad que será pagada
     */
    function calculatePackPrice(uint256 packId, address user, uint256 quantity) 
        external 
        view 
        traitsExists
        returns (uint256 totalCost, uint256 freeCount, uint256 paidCount) 
    {
        // Get pack config from traits contract
        (, uint256 basePrice,,,,,,,,) = IAdrianTraitsCore(traitsContract).packConfigs(packId);
        PackPricing storage pricing = packPricing[packId];
        
        if (!pricing.useProgressivePricing) {
            // Precio fijo tradicional
            return (basePrice * quantity, 0, quantity);
        }
        
        uint256 usedFreeMints = freeMintsUsed[user][packId];
        uint256 availableFreeMints = pricing.freeMints > usedFreeMints ? 
            pricing.freeMints - usedFreeMints : 0;
        
        freeCount = quantity > availableFreeMints ? availableFreeMints : quantity;
        paidCount = quantity - freeCount;
        
        totalCost = paidCount * pricing.paidPrice;
    }

    /**
     * @dev Actualiza el uso de free mints de un usuario (llamado desde AdrianTraitsCore al comprar)
     */
    function updateFreeMintsUsed(address user, uint256 packId, uint256 freeMintsUsed_) external {
        // Only traits contract can call this
        require(msg.sender == traitsContract, "Only traits contract can update");
        
        freeMintsUsed[user][packId] += freeMintsUsed_;
        
        uint256 remainingFreeMints = packPricing[packId].freeMints > freeMintsUsed[user][packId] ? 
            packPricing[packId].freeMints - freeMintsUsed[user][packId] : 0;
            
        emit FreePackClaimed(user, packId, remainingFreeMints);
    }

    // =============== Module Management Functions ===============
    
    /**
     * @dev Set serum module with validation
     */
    function setSerumModule(address _module) external onlyOwner validContract(_module) coreExists {
        // Validate serum module interface
        try IAdrianSerumModule(_module).getSerumData(1) returns (string memory, uint256) {
            // Set on core contract
        IAdrianLabCore(core).setSerumModule(_module);
            
            // Set bidirectional reference
            try IAdrianSerumModule(_module).setCoreContract(core) {
                serumModule = _module;
                emit SerumModuleUpdated(_module);
            } catch {
                revert("Serum module rejected core");
            }
        } catch {
            revert("Invalid serum module interface");
        }
    }

    /**
     * @dev Set extensions contract with validation
     */
    function setAdrianLabExtensions(address _extensions) external onlyOwner validContract(_extensions) coreExists {
        // Validate extensions interface
        try IAdrianLabExtensions(_extensions).getTraits(1) returns (uint256, uint256, string memory) {
            // Set on core contract
        IAdrianLabCore(core).setAdrianLabExtensions(_extensions);
            
            // Set bidirectional reference
            try IAdrianLabExtensions(_extensions).setCoreContract(core) {
                extensionsContract = _extensions;
                emit ExtensionsContractUpdated(_extensions);
            } catch {
                revert("Extensions contract rejected core");
            }
        } catch {
            revert("Invalid extensions contract interface");
        }
    }

    /**
     * @dev Set traits contract with validation
     */
    function setTraitsContract(address _contract) external onlyOwner validContract(_contract) {
        // Validate traits contract interface
        try IAdrianTraitsCore(_contract).getTraitInfo(1) returns (string memory, bool) {
            traitsContract = _contract;
            emit TraitsContractUpdated(_contract);
        } catch {
            revert("Invalid traits contract interface");
        }
    }

    /**
     * @dev Set inventory module with validation
     */
    function setInventoryModule(address _module) external onlyOwner validContract(_module) {
        // Validate inventory module interface
        try IAdrianInventoryModule(_module).getEquippedTraits(1) returns (uint256[] memory) {
            inventoryModule = _module;
            emit InventoryModuleUpdated(_module);
        } catch {
            revert("Invalid inventory module interface");
        }
    }

    /**
     * @dev Set history contract with validation
     */
    function setHistoryContract(address _contract) external onlyOwner validContract(_contract) {
        // Validate history contract interface
        try IAdrianHistory(_contract).getHistoryCount(1) returns (uint256) {
            historyContract = _contract;
            emit HistoryContractUpdated(_contract);
        } catch {
            revert("Invalid history contract interface");
        }
    }

    /**
     * @dev Set duplicator module with validation
     */
    function setDuplicatorModule(address _module) external onlyOwner validContract(_module) {
        // Validate duplicator module interface
        try IAdrianDuplicatorModule(_module).hasBeenDuplicated(1) returns (bool) {
            duplicatorModule = _module;
            emit DuplicatorModuleUpdated(_module);
        } catch {
            revert("Invalid duplicator module interface");
        }
    }

    /**
     * @dev Set mint module with validation
     */
    function setMintModule(address _module) external onlyOwner validContract(_module) {
        // Validate mint module interface
        try IAdrianMintModule(_module).getMintStatus(1) returns (bool) {
            mintModule = _module;
            emit MintModuleUpdated(_module);
        } catch {
            revert("Invalid mint module interface");
        }
    }

    /**
     * @dev Set crafting contract with validation
     */
    function setCraftingContract(address _contract) external onlyOwner validContract(_contract) {
        // Validate crafting contract interface
        try IAdrianLabCrafting(_contract).nextRecipeId() returns (uint256) {
            craftingContract = _contract;
            emit CraftingContractUpdated(_contract);
        } catch {
            revert("Invalid crafting contract interface");
        }
    }

    /**
     * @dev Set marketplace contract with validation
     */
    function setMarketplaceContract(address _contract) external onlyOwner validContract(_contract) {
        // Validate marketplace contract interface
        try IAdrianLabMarketplace(_contract).nextListingId() returns (uint256) {
            marketplaceContract = _contract;
            emit MarketplaceContractUpdated(_contract);
        } catch {
            revert("Invalid marketplace contract interface");
        }
    }

    // =============== Core Configuration Functions ===============
    
    /**
     * @dev Set base URI for metadata
     */
    function setBaseURI(string calldata newURI) external onlyOwner coreExists {
        require(bytes(newURI).length > 0, "Empty URI");
        IAdrianLabCore(core).setBaseURI(newURI);
    }

    /**
     * @dev Set function implementation for proxy pattern
     */
    function setFunctionImplementation(bytes32 key, address implementation) external onlyOwner coreExists {
        require(implementation != address(0), "Invalid implementation");
        IAdrianLabCore(core).setFunctionImplementation(key, implementation);
    }

    /**
     * @dev Toggle random skin assignment
     */
    function setRandomSkin(bool enabled) external onlyOwner coreExists {
        IAdrianLabCore(core).setRandomSkin(enabled);
    }

    // =============== Token Management Functions ===============
    
    /**
     * @dev Set token modification status
     */
    function setTokenModified(uint256 tokenId, bool modified) external onlyOwner coreExists {
        require(_tokenExists(tokenId), "Token does not exist");
        IAdrianLabCore(core).setTokenModified(tokenId, modified);
    }

    /**
     * @dev Set token duplication status
     */
    function setTokenDuplicated(uint256 tokenId, bool duplicated) external onlyOwner coreExists {
        require(_tokenExists(tokenId), "Token does not exist");
        IAdrianLabCore(core).setTokenDuplicated(tokenId, duplicated);
    }

    /**
     * @dev Set token serum mutation status
     */
    function setTokenMutatedBySerum(uint256 tokenId, bool mutated) external onlyOwner coreExists {
        require(_tokenExists(tokenId), "Token does not exist");
        IAdrianLabCore(core).setTokenMutatedBySerum(tokenId, mutated);
    }

    /**
     * @dev Set token mutation level
     */
    function setTokenMutationLevel(uint256 tokenId, uint8 level) external onlyOwner coreExists {
        require(_tokenExists(tokenId), "Token does not exist");
        require(level <= 3, "Invalid mutation level"); // Assuming max level is 3
        IAdrianLabCore(core).setTokenMutationLevel(tokenId, level);
    }

    /**
     * @dev Reset token history (emergency function)
     */
    function resetTokenHistory(uint256 tokenId) external onlyOwnerOrEmergency {
        require(historyContract != address(0), "History contract not set");
        require(_tokenExists(tokenId), "Token does not exist");
        
        try IAdrianHistory(historyContract).resetTokenHistory(tokenId) {
            emit TokenHistoryReset(tokenId);
        } catch {
            revert("Failed to reset token history");
        }
    }

    // =============== Batch Operations ===============
    
    /**
     * @dev Batch set token modified status
     */
    function batchSetTokenModified(uint256[] calldata tokenIds, bool[] calldata modified) external onlyOwner coreExists {
        require(tokenIds.length == modified.length, "Array length mismatch");
        require(tokenIds.length <= 100, "Batch too large"); // Prevent gas issues
        
        uint256 successCount = 0;
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (_tokenExists(tokenIds[i])) {
                try IAdrianLabCore(core).setTokenModified(tokenIds[i], modified[i]) {
                    successCount++;
                } catch {
                    // Continue with next token
                }
            }
        }
        
        emit BatchAdminAction("SET_MODIFIED", successCount, successCount == tokenIds.length);
    }

    /**
     * @dev Batch reset token histories
     */
    function batchResetTokenHistory(uint256[] calldata tokenIds) external onlyOwnerOrEmergency {
        require(historyContract != address(0), "History contract not set");
        require(tokenIds.length <= 50, "Batch too large"); // Smaller batch for safety
        
        uint256 successCount = 0;
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (_tokenExists(tokenIds[i])) {
                try IAdrianHistory(historyContract).resetTokenHistory(tokenIds[i]) {
                    successCount++;
                    emit TokenHistoryReset(tokenIds[i]);
                } catch {
                    // Continue with next token
                }
            }
        }
        
        emit BatchAdminAction("RESET_HISTORY", successCount, successCount == tokenIds.length);
    }

    // =============== Emergency Functions ===============
    
    /**
     * @dev Toggle emergency mode
     */
    function setEmergencyMode(bool enabled) external onlyOwner {
        emergencyMode = enabled;
        emit EmergencyModeToggled(enabled);
    }

    /**
     * @dev Set emergency admin
     */
    function setEmergencyAdmin(address admin, bool status) external onlyOwner {
        require(admin != address(0), "Invalid admin address");
        emergencyAdmins[admin] = status;
        emit EmergencyAdminUpdated(admin, status);
    }

    /**
     * @dev Emergency contract update (bypasses some validations)
     */
    function emergencySetContract(
        string calldata contractType,
        address contractAddress
    ) external onlyOwnerOrEmergency validContract(contractAddress) {
        require(emergencyMode, "Not in emergency mode");
        
        bytes32 typeHash = keccak256(abi.encodePacked(contractType));
        
        if (typeHash == keccak256("core")) {
            core = contractAddress;
            emit CoreContractUpdated(contractAddress);
        } else if (typeHash == keccak256("extensions")) {
            extensionsContract = contractAddress;
            emit ExtensionsContractUpdated(contractAddress);
        } else if (typeHash == keccak256("traits")) {
            traitsContract = contractAddress;
            emit TraitsContractUpdated(contractAddress);
        } else if (typeHash == keccak256("serum")) {
            serumModule = contractAddress;
            emit SerumModuleUpdated(contractAddress);
        } else if (typeHash == keccak256("history")) {
            historyContract = contractAddress;
            emit HistoryContractUpdated(contractAddress);
        } else {
            revert("Unknown contract type");
        }
    }

    // =============== View Functions ===============
    
    /**
     * @dev Get all contract addresses
     */
    function getAllContracts() external view returns (
        address _core,
        address _extensions,
        address _traits,
        address _serum,
        address _inventory,
        address _history,
        address _duplicator,
        address _mint,
        address _crafting,
        address _marketplace
    ) {
        return (
            core,
            extensionsContract,
            traitsContract,
            serumModule,
            inventoryModule,
            historyContract,
            duplicatorModule,
            mintModule,
            craftingContract,
            marketplaceContract
        );
    }

    /**
     * @dev ✅ NEW: Get pack pricing info
     */
    function getPackPricing(uint256 packId) external view returns (
        uint256 freeMints,
        uint256 paidPrice,
        bool useProgressivePricing
    ) {
        PackPricing storage pricing = packPricing[packId];
        return (pricing.freeMints, pricing.paidPrice, pricing.useProgressivePricing);
    }

    /**
     * @dev ✅ NEW: Get user's free mints used for a pack
     */
    function getUserFreeMintsUsed(address user, uint256 packId) external view returns (uint256) {
        return freeMintsUsed[user][packId];
    }

    /**
     * @dev ✅ NEW: Get user's remaining free mints for a pack
     */
    function getUserRemainingFreeMints(address user, uint256 packId) external view returns (uint256) {
        PackPricing storage pricing = packPricing[packId];
        uint256 used = freeMintsUsed[user][packId];
        return pricing.freeMints > used ? pricing.freeMints - used : 0;
    }

    /**
     * @dev Check if all critical contracts are set
     */
    function allCriticalContractsSet() external view returns (bool) {
        return core != address(0) &&
               extensionsContract != address(0) &&
               traitsContract != address(0) &&
               historyContract != address(0);
    }

    /**
     * @dev Get contract status summary
     */
    function getContractStatus() external view returns (
        bool coreSet,
        bool extensionsSet,
        bool traitsSet,
        bool serumSet,
        bool historySet,
        bool emergencyModeActive
    ) {
        return (
            core != address(0),
            extensionsContract != address(0),
            traitsContract != address(0),
            serumModule != address(0),
            historyContract != address(0),
            emergencyMode
        );
    }

    /**
     * @dev Validate ecosystem integrity
     */
    function validateEcosystem() external view returns (bool valid, string memory reason) {
        if (core == address(0)) {
            return (false, "Core contract not set");
        }
        
        try IAdrianLabCore(core).owner() returns (address) {
            // Core is accessible
        } catch {
            return (false, "Core contract not accessible");
        }
        
        if (extensionsContract == address(0)) {
            return (false, "Extensions contract not set");
        }
        
        if (traitsContract == address(0)) {
            return (false, "Traits contract not set");
        }
        
        if (historyContract == address(0)) {
            return (false, "History contract not set");
        }
        
        return (true, "Ecosystem validated");
    }

    // =============== Internal Helper Functions ===============
    
    /**
     * @dev Check if token exists
     */
    function _tokenExists(uint256 tokenId) internal view returns (bool) {
        if (core == address(0)) return false;
        
        try IAdrianLabCore(core).exists(tokenId) returns (bool exists) {
            return exists;
        } catch {
            return false;
        }
    }

    /**
     * @dev Validate contract has required interface
     */
    function _validateContractInterface(address contractAddr, bytes4 /* interfaceId */) internal view returns (bool) {
        if (contractAddr == address(0) || contractAddr.code.length == 0) {
            return false;
        }
        
        // Could implement EIP-165 interface detection here
        return true;
    }

    // =============== Upgrade Functions ===============
    
    /**
     * @dev Prepare for system upgrade
     */
    function prepareUpgrade() external onlyOwner {
        emergencyMode = true;
        emit EmergencyModeToggled(true);
    }

    /**
     * @dev Complete system upgrade
     */
    function completeUpgrade() external onlyOwner {
        require(emergencyMode, "Not in upgrade mode");
        
        // Validate all contracts are set and working
        (bool valid, string memory reason) = this.validateEcosystem();
        require(valid, reason);
        
        emergencyMode = false;
        emit EmergencyModeToggled(false);
    }
} 