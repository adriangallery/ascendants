// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// =============== CONSTANTES DE RANGOS FASE 2 ===============
uint256 constant TRAIT_ID_MAX = 99_999;        // Actualizado desde 999_999
uint256 constant PACK_ID_MIN = 100_000;        // Actualizado desde 1_000_000  
uint256 constant PACK_ID_MAX = 109_999;        // Actualizado desde 1_999_999
uint256 constant SERUM_ID_MIN = 110_000;       // NUEVO rango para serums

// =============== Funciones de Validación de Rangos ===============
library ViewValidation {
    function isValidTraitId(uint256 id) internal pure returns (bool) {
        return id > 0 && id <= TRAIT_ID_MAX;
    }
    
    function isValidPackId(uint256 id) internal pure returns (bool) {
        return id >= PACK_ID_MIN && id <= PACK_ID_MAX;
    }
    
    function isValidSerumId(uint256 id) internal pure returns (bool) {
        return id >= SERUM_ID_MIN;
    }
    
    function getAssetType(uint256 id) internal pure returns (string memory) {
        if (isValidTraitId(id)) return "TRAIT";
        if (isValidPackId(id)) return "PACK";  
        if (isValidSerumId(id)) return "SERUM";
        return "UNKNOWN";
    }
}

// =============== Interfaces actualizadas ===============

interface IAdrianLabCore {
    function ownerOf(uint256 tokenId) external view returns (address);
    function getTraits(uint256 tokenId) external view returns (uint256 generation, uint256, string memory mutation);
    function tokenCounter() external view returns (uint256);
    function exists(uint256 tokenId) external view returns (bool);
    function hasBeenDuplicated(uint256 tokenId) external view returns (bool);
    function mutationLevel(uint256 tokenId) external view returns (uint8);
    function canDuplicate(uint256 tokenId) external view returns (bool);
    
    // ✅ FASE 2: Funciones de skins de FASE 1
    function getTokenSkin(uint256 tokenId) external view returns (uint256 skinId, string memory name);
    function getSkin(uint256 skinId) external view returns (string memory name, uint256 rarity, bool active);
    function getSkinRarityPercentage(uint256 skinId) external view returns (uint256);
    function getAllSkins() external view returns (uint256[] memory skinIds, string[] memory names);
    function getTokenData(uint256 tokenId) external view returns (uint256 generation, uint8 mutationType, bool hasBeenModified);
}

// ✅ FASE 2: Interfaz para AdrianLabAdmin (maxSupply dinámico y precios progresivos)
interface IAdrianLabAdmin {
    function getAssetMaxSupply(uint256 assetId) external view returns (uint256);
    function getPackPricing(uint256 packId) external view returns (uint256 basePrice, uint256 maxPrice, bool enabled);
    function getUserFreeMintsUsed(address user, uint256 packId) external view returns (uint256);
    function getPackPricingTier(uint256 packId, uint256 currentMints) external view returns (uint256 currentPrice);
}

interface IAdrianLabExtensions {
    struct TokenTraitInfo {
        string category;
        uint256 traitId;
    }

    function getEquippedTraits(uint256 tokenId) external view returns (TokenTraitInfo[] memory);
}

interface IAdrianTraitsCore {
    function balanceOf(address account, uint256 id) external view returns (uint256);
}

interface IAdrianHistory {
    struct HistoricalEvent {
        bytes32 eventType;
        uint256 timestamp;
        address actor;
        bytes data;
        uint256 blockNumber;
    }

    function getEventsForToken(uint256 tokenId) external view returns (HistoricalEvent[] memory);
}

interface IAdrianInventoryModule {
    function getEquippedTraits(uint256 tokenId) external view returns (uint256[] memory);
    function getInventoryItems(uint256 tokenId) external view returns (uint256[] memory, uint256[] memory);
}

contract AdrianLabView {
    address public labCore;
    address public labExtensions;
    address public traitsCore;
    address public historyContract;
    address public inventoryModule;
    address public adminContract;  // ✅ FASE 2: Agregado para precios progresivos
    IAdrianLabCore public lab;

    // ✅ EVENTOS PARA SETTERS
    event ContractUpdated(string contractName, address oldAddress, address newAddress);

    constructor(
        address _core,
        address _ext,
        address _traits,
        address _history,
        address _inventory,
        address _admin  // ✅ FASE 2: Agregado admin contract
    ) {
        labCore = _core;
        labExtensions = _ext;
        traitsCore = _traits;
        historyContract = _history;
        inventoryModule = _inventory;
        adminContract = _admin;
        lab = IAdrianLabCore(_core);
    }

    struct TokenView {
        address owner;
        uint256 generation;
        string mutation;
        IAdrianLabExtensions.TokenTraitInfo[] equippedTraits;
        uint256[] inventoryTraitIds;
        uint256[] inventoryBalances;
        IAdrianHistory.HistoricalEvent[] history;
        // ✅ FASE 2: Agregado info de skins
        uint256 skinId;
        string skinName;
        uint256 skinRarity;
    }

    // =============== FASE 2: Nuevas Funciones View para Sistema de Skins ===============

    /**
     * @dev Get complete token skin information
     */
    function getTokenSkinInfo(uint256 tokenId) external view returns (
        uint256 skinId,
        string memory skinName,
        uint256 skinRarity,
        uint256 skinRarityPercentage,
        bool skinActive
    ) {
        (skinId, skinName) = lab.getTokenSkin(tokenId);
        
        if (skinId > 0) {
            (string memory name, uint256 rarity, bool active) = lab.getSkin(skinId);
            uint256 rarityPercentage = lab.getSkinRarityPercentage(skinId);
            return (skinId, name, rarity, rarityPercentage, active);
        }
        
        return (0, "BareAdrian", 0, 0, true);
    }

    /**
     * @dev Get all available skins
     */
    function getAllSkinsInfo() external view returns (
        uint256[] memory skinIds,
        string[] memory names,
        uint256[] memory rarities,
        uint256[] memory percentages
    ) {
        (skinIds, names) = lab.getAllSkins();
        rarities = new uint256[](skinIds.length);
        percentages = new uint256[](skinIds.length);
        
        for (uint256 i = 0; i < skinIds.length; i++) {
            (, rarities[i],) = lab.getSkin(skinIds[i]);
            percentages[i] = lab.getSkinRarityPercentage(skinIds[i]);
        }
        
        return (skinIds, names, rarities, percentages);
    }

    // =============== FASE 2: Funciones View para Precios Progresivos ===============

    /**
     * @dev Get pack pricing information with current pricing tier
     */
    function getPackPricingInfo(uint256 packId) external view returns (
        uint256 basePrice,
        uint256 maxPrice,
        bool enabled,
        uint256 currentPrice,
        uint256 currentMints
    ) {
        require(ViewValidation.isValidPackId(packId), "Invalid pack ID range");
        require(adminContract != address(0), "Admin contract not set");
        
        (basePrice, maxPrice, enabled) = IAdrianLabAdmin(adminContract).getPackPricing(packId);
        
        if (enabled) {
            // Necesitaríamos el currentMints del pack - esto requeriría una función adicional en admin
            currentMints = 0; // Placeholder - se necesita implementar en admin
            currentPrice = IAdrianLabAdmin(adminContract).getPackPricingTier(packId, currentMints);
        } else {
            currentPrice = basePrice;
            currentMints = 0;
        }
        
        return (basePrice, maxPrice, enabled, currentPrice, currentMints);
    }

    /**
     * @dev Get user's free mints status for a pack
     */
    function getUserFreeMintStatus(address user, uint256 packId) external view returns (
        uint256 freeMintUsed,
        bool canUseFreeInt,
        string memory packType
    ) {
        require(ViewValidation.isValidPackId(packId), "Invalid pack ID range");
        require(adminContract != address(0), "Admin contract not set");
        
        freeMintUsed = IAdrianLabAdmin(adminContract).getUserFreeMintsUsed(user, packId);
        canUseFreeInt = freeMintUsed == 0; // Assuming 1 free mint per pack per user
        packType = ViewValidation.getAssetType(packId);
        
        return (freeMintUsed, canUseFreeInt, packType);
    }

    // =============== FASE 2: Funciones View para Validación de Assets ===============

    /**
     * @dev Get asset range and type information
     */
    function getAssetRangeInfo(uint256 assetId) external pure returns (
        bool isValid,
        string memory assetType,
        string memory rangeInfo
    ) {
        if (ViewValidation.isValidTraitId(assetId)) {
            return (true, "TRAIT", "Range: 1-99,999");
        } else if (ViewValidation.isValidPackId(assetId)) {
            return (true, "PACK", "Range: 100,000-109,999");
        } else if (ViewValidation.isValidSerumId(assetId)) {
            return (true, "SERUM", "Range: 110,000+");
        }
        return (false, "UNKNOWN", "Invalid asset ID");
    }

    /**
     * @dev Get supported ranges for the ecosystem
     */
    function getEcosystemRanges() external pure returns (
        uint256 traitMax,
        uint256 packMin,
        uint256 packMax,
        uint256 serumMin
    ) {
        return (TRAIT_ID_MAX, PACK_ID_MIN, PACK_ID_MAX, SERUM_ID_MIN);
    }

    function getFullTokenState(uint256 tokenId, uint256[] calldata inventoryTraitIds)
        external
        view
        returns (TokenView memory state)
    {
        state.owner = IAdrianLabCore(labCore).ownerOf(tokenId);

        (state.generation,, state.mutation) = IAdrianLabCore(labCore).getTraits(tokenId);

        // ✅ FASE 2: Integrar información de skins
        (state.skinId, state.skinName) = lab.getTokenSkin(tokenId);
        if (state.skinId > 0) {
            (, state.skinRarity,) = lab.getSkin(state.skinId);
        } else {
            state.skinRarity = 0;
        }

        state.equippedTraits = IAdrianLabExtensions(labExtensions).getEquippedTraits(tokenId);

        // Inventario: leer balances de traits específicos con validación de rangos
        uint256 len = inventoryTraitIds.length;
        state.inventoryTraitIds = inventoryTraitIds;
        state.inventoryBalances = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            // ✅ FASE 2: Solo procesar IDs válidos
            if (ViewValidation.isValidTraitId(inventoryTraitIds[i]) || 
                ViewValidation.isValidPackId(inventoryTraitIds[i]) || 
                ViewValidation.isValidSerumId(inventoryTraitIds[i])) {
                state.inventoryBalances[i] = IAdrianTraitsCore(traitsCore).balanceOf(state.owner, inventoryTraitIds[i]);
            } else {
                state.inventoryBalances[i] = 0;
            }
        }

        // Historia del token
        if (historyContract != address(0)) {
            state.history = IAdrianHistory(historyContract).getEventsForToken(tokenId);
        }
    }

    /// @notice Obtiene los items del inventario de un token
    function getInventoryItems(uint256 tokenId) external view returns (
        uint256[] memory traitIds,
        uint256[] memory amounts
    ) {
        require(inventoryModule != address(0), "Inventory module not set");
        return IAdrianInventoryModule(inventoryModule).getInventoryItems(tokenId);
    }

    /// @notice Obtiene los traits equipados de un token
    function getEquippedTraits(uint256 tokenId) external view returns (uint256[] memory) {
        require(inventoryModule != address(0), "Inventory module not set");
        return IAdrianInventoryModule(inventoryModule).getEquippedTraits(tokenId);
    }

    /// @notice Obtiene el estado de mutación de un token
    function getMutationStatus(uint256 tokenId) external view returns (
        uint8 mutationLevel,
        bool hasBeenDuplicated,
        bool canDuplicate
    ) {
        return (
            IAdrianLabCore(labCore).mutationLevel(tokenId),
            IAdrianLabCore(labCore).hasBeenDuplicated(tokenId),
            IAdrianLabCore(labCore).canDuplicate(tokenId)
        );
    }

    /// @notice Devuelve todos los tokens que posee un wallet
    function tokensOfOwner(address owner) external view returns (uint256[] memory) {
        uint256 total = lab.tokenCounter();
        uint256 count = 0;

        for (uint256 i = 0; i < total; ++i) {
            if (lab.exists(i) && lab.ownerOf(i) == owner) {
                count++;
            }
        }

        uint256[] memory result = new uint256[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < total; ++i) {
            if (lab.exists(i) && lab.ownerOf(i) == owner) {
                result[index] = i;
                index++;
            }
        }

        return result;
    }

    /// @notice Devuelve todos los tokens existentes
    function allTokens() external view returns (uint256[] memory) {
        uint256 total = lab.tokenCounter();
        uint256 count = 0;

        for (uint256 i = 0; i < total; ++i) {
            if (lab.exists(i)) {
                count++;
            }
        }

        uint256[] memory result = new uint256[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < total; ++i) {
            if (lab.exists(i)) {
                result[index] = i;
                index++;
            }
        }

        return result;
    }

    /// @notice Devuelve el token de un owner en un índice específico (como tokenOfOwnerByIndex)
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256) {
        uint256 total = lab.tokenCounter();
        uint256 count = 0;

        for (uint256 i = 0; i < total; ++i) {
            if (lab.exists(i) && lab.ownerOf(i) == owner) {
                if (count == index) {
                    return i;
                }
                count++;
            }
        }

        revert("Index out of bounds");
    }

    /// @notice Devuelve el token global en un índice específico (como tokenByIndex)
    function tokenByIndex(uint256 index) external view returns (uint256) {
        uint256 total = lab.tokenCounter();
        uint256 count = 0;

        for (uint256 i = 0; i < total; ++i) {
            if (lab.exists(i)) {
                if (count == index) {
                    return i;
                }
                count++;
            }
        }

        revert("Index out of bounds");
    }

    function getAllTokenIdsOfOwner(address owner) external view returns (uint256[] memory) {
        uint256 total = lab.tokenCounter();
        uint256 count = 0;

        for (uint256 i = 0; i < total; ++i) {
            if (lab.exists(i) && lab.ownerOf(i) == owner) {
                count++;
            }
        }

        uint256[] memory tokenIds = new uint256[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < total; ++i) {
            if (lab.exists(i) && lab.ownerOf(i) == owner) {
                tokenIds[index] = i;
                index++;
            }
        }

        return tokenIds;
    }

    function getDuplicableTokensOfOwner(address owner) external view returns (uint256[] memory) {
        uint256 total = lab.tokenCounter();
        uint256 count = 0;

        for (uint256 i = 0; i < total; ++i) {
            if (!lab.exists(i)) continue;

            if (
                lab.ownerOf(i) == owner &&
                !lab.hasBeenDuplicated(i) &&
                lab.mutationLevel(i) == 0 && // MutationType.NONE
                lab.canDuplicate(i)
            ) {
                count++;
            }
        }

        uint256[] memory result = new uint256[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < total; ++i) {
            if (!lab.exists(i)) continue;

            if (
                lab.ownerOf(i) == owner &&
                !lab.hasBeenDuplicated(i) &&
                lab.mutationLevel(i) == 0 &&
                lab.canDuplicate(i)
            ) {
                result[index] = i;
                index++;
            }
        }

        return result;
    }

    /// @notice Obtiene el historial completo de un token en formato HistoricalEvent
    function getTokenHistory(uint256 tokenId) external view returns (IAdrianHistory.HistoricalEvent[] memory) {
        require(historyContract != address(0), "History contract not set");
        return IAdrianHistory(historyContract).getEventsForToken(tokenId);
    }

    /// @notice Obtiene el estado completo del token incluyendo historia e inventario
    function getFullStateWithHistory(uint256 tokenId, uint256[] calldata inventoryTraitIds)
        external
        view
        returns (TokenView memory state)
    {
        state = this.getFullTokenState(tokenId, inventoryTraitIds);
        if (historyContract != address(0)) {
            state.history = IAdrianHistory(historyContract).getEventsForToken(tokenId);
        }
    }

    // =============== FASE 2: Funciones adicionales de utilidad ===============

    /**
     * @dev Get tokens with specific skin
     */
    function getTokensWithSkin(uint256 skinId) external view returns (uint256[] memory) {
        uint256 total = lab.tokenCounter();
        uint256 count = 0;

        // First pass: count tokens with skin
        for (uint256 i = 1; i <= total; i++) {
            if (lab.exists(i)) {
                (uint256 tokenSkinId,) = lab.getTokenSkin(i);
                if (tokenSkinId == skinId) {
                    count++;
                }
            }
        }

        // Second pass: collect tokens
        uint256[] memory result = new uint256[](count);
        uint256 index = 0;

        for (uint256 i = 1; i <= total; i++) {
            if (lab.exists(i)) {
                (uint256 tokenSkinId,) = lab.getTokenSkin(i);
                if (tokenSkinId == skinId) {
                    result[index] = i;
                    index++;
                }
            }
        }

        return result;
    }

    /**
     * @dev Get tokens by generation
     */
    function getTokensByGeneration(uint256 generation) external view returns (uint256[] memory) {
        uint256 total = lab.tokenCounter();
        uint256 count = 0;

        // First pass: count tokens of generation
        for (uint256 i = 1; i <= total; i++) {
            if (lab.exists(i)) {
                (uint256 tokenGeneration,,) = lab.getTraits(i);
                if (tokenGeneration == generation) {
                    count++;
                }
            }
        }

        // Second pass: collect tokens
        uint256[] memory result = new uint256[](count);
        uint256 index = 0;

        for (uint256 i = 1; i <= total; i++) {
            if (lab.exists(i)) {
                (uint256 tokenGeneration,,) = lab.getTraits(i);
                if (tokenGeneration == generation) {
                    result[index] = i;
                    index++;
                }
            }
        }

        return result;
    }

    /**
     * @dev Get ecosystem statistics
     */
    function getEcosystemStats() external view returns (
        uint256 totalTokens,
        uint256 totalSkins,
        uint256 averageGeneration,
        uint256 duplicatedCount
    ) {
        uint256 total = lab.tokenCounter();
        totalTokens = 0;
        uint256 generationSum = 0;
        duplicatedCount = 0;

        for (uint256 i = 1; i <= total; i++) {
            if (lab.exists(i)) {
                totalTokens++;
                (uint256 generation,,) = lab.getTraits(i);
                generationSum += generation;
                
                if (lab.hasBeenDuplicated(i)) {
                    duplicatedCount++;
                }
            }
        }

        if (totalTokens > 0) {
            averageGeneration = generationSum / totalTokens;
        }

        (uint256[] memory skinIds,) = lab.getAllSkins();
        totalSkins = skinIds.length;

        return (totalTokens, totalSkins, averageGeneration, duplicatedCount);
    }

    // ✅ SETTERS PARA ACTUALIZACIONES DE CONTRATOS
    
    /**
     * @dev Actualiza la dirección del contrato AdrianLabCore
     */
    function setLabCore(address _labCore) external {
        require(msg.sender == labCore || labCore == address(0), "Unauthorized");
        require(_labCore != address(0), "Invalid address");
        address oldCore = labCore;
        labCore = _labCore;
        lab = IAdrianLabCore(_labCore);
        emit ContractUpdated("LabCore", oldCore, _labCore);
    }
    
    /**
     * @dev Actualiza la dirección del contrato AdrianLabExtensions
     */
    function setLabExtensions(address _labExtensions) external {
        require(msg.sender == labCore, "Only core can update");
        require(_labExtensions != address(0), "Invalid address");
        address oldExtensions = labExtensions;
        labExtensions = _labExtensions;
        emit ContractUpdated("LabExtensions", oldExtensions, _labExtensions);
    }
    
    /**
     * @dev Actualiza la dirección del contrato AdrianTraitsCore
     */
    function setTraitsCore(address _traitsCore) external {
        require(msg.sender == labCore, "Only core can update");
        require(_traitsCore != address(0), "Invalid address");
        address oldTraitsCore = traitsCore;
        traitsCore = _traitsCore;
        emit ContractUpdated("TraitsCore", oldTraitsCore, _traitsCore);
    }
    
    /**
     * @dev Actualiza la dirección del contrato AdrianHistory
     */
    function setHistoryContract(address _historyContract) external {
        require(msg.sender == labCore, "Only core can update");
        require(_historyContract != address(0), "Invalid address");
        address oldHistory = historyContract;
        historyContract = _historyContract;
        emit ContractUpdated("HistoryContract", oldHistory, _historyContract);
    }
    
    /**
     * @dev Actualiza la dirección del contrato AdrianInventoryModule
     */
    function setInventoryModule(address _inventoryModule) external {
        require(msg.sender == labCore, "Only core can update");
        require(_inventoryModule != address(0), "Invalid address");
        address oldInventory = inventoryModule;
        inventoryModule = _inventoryModule;
        emit ContractUpdated("InventoryModule", oldInventory, _inventoryModule);
    }
    
    /**
     * @dev Actualiza la dirección del contrato AdrianLabAdmin
     */
    function setAdminContract(address _adminContract) external {
        require(msg.sender == labCore, "Only core can update");
        require(_adminContract != address(0), "Invalid address");
        address oldAdmin = adminContract;
        adminContract = _adminContract;
        emit ContractUpdated("AdminContract", oldAdmin, _adminContract);
    }
}