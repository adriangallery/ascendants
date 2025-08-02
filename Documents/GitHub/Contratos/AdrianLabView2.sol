// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAdrianTraitsCore {
    function getPackInfo(uint256 packId) external view returns (
        uint256 price, uint256 maxSupply, uint256 minted, 
        uint256 itemsPerPack, uint256 maxPerWallet, bool active,
        bool requiresAllowlist, string memory packUri
    );
    function getSerumData(uint256 serumId) external view returns (string memory targetMutation, uint256 potency);
    function packTraitsLength(uint256 packId) external view returns (uint256);
    function getPackTraitInfo(uint256 packId, uint256 index) external view returns (
        uint256 traitId, uint256 minAmount, uint256 maxAmount, uint256 chance, uint256 remaining
    );
    function getName(uint256 assetId) external view returns (string memory);
    function getCategory(uint256 assetId) external view returns (string memory);
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function getAvailableSupply(uint256 traitId) external view returns (uint256);
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
    function getHistoryCount(uint256 tokenId) external view returns (uint256);
}

interface IAdrianMintModule {
    function getCurrentBatchInfo() external view returns (
        uint256 batchId, string memory name, uint256 price, uint256 minted,
        uint256 maxSupply, bool active, uint256 startTime, uint256 endTime, bool useMerkleWhitelist
    );
    function getBatchInfo(uint256 batchId) external view returns (
        uint256 id, string memory name, uint256 price, uint256 minted,
        uint256 maxSupply, bool active, uint256 startTime, uint256 endTime, bool useMerkleWhitelist
    );
    function canMint() external view returns (bool mintable, string memory reason, uint256 price, uint256 available);
    function mintedPerWalletPerBatch(address user, uint256 batchId) external view returns (uint256);
}

interface IAdrianSerumModule {
    function simulateUse(uint256 serumId, uint256 tokenId) external view returns (bool);
    function totalUsed(uint256 serumId) external view returns (uint256);
    function totalSuccess(uint256 serumId) external view returns (uint256);
    function serumUsedOnToken(uint256 serumId, uint256 tokenId) external view returns (bool);
}

interface IAdrianLabCrafting {
    struct CraftingRecipe {
        uint256 id;
        uint256[] ingredientIds;
        uint256[] ingredientAmounts;
        uint256 resultId;
        uint256 resultAmount;
        bool consumeIngredients;
        bool active;
        uint256 minLevel;
        bool requiresAllowlist;
    }
    function craftingRecipes(uint256 recipeId) external view returns (CraftingRecipe memory);
    function nextRecipeId() external view returns (uint256);
}

interface IAdrianLabMarketplace {
    struct MarketplaceListing {
        address seller;
        uint256 assetId;
        uint256 amount;
        uint256 pricePerUnit;
        uint256 expiration;
        bool active;
    }
    function listings(uint256 listingId) external view returns (MarketplaceListing memory);
    function getUserListings(address user) external view returns (uint256[] memory);
    function nextListingId() external view returns (uint256);
}

/**
 * @title AdrianLabView2 - Advanced Functions & Analytics
 * @dev Funciones avanzadas, analytics y features especializados
 */
contract AdrianLabView2 {
    // =============== Contract References ===============
    address public traitsCore;
    address public historyContract;
    address public mintModule;
    address public serumModule;
    address public craftingContract;
    address public marketplaceContract;

    constructor(
        address _traits,
        address _history,
        address _mint,
        address _serum,
        address _crafting,
        address _marketplace
    ) {
        traitsCore = _traits;
        historyContract = _history;
        mintModule = _mint;
        serumModule = _serum;
        craftingContract = _crafting;
        marketplaceContract = _marketplace;
    }

    // =============== ESTRUCTURAS AVANZADAS ===============
    
    struct PackFullInfo {
        uint256 id;
        uint256 price;
        uint256 maxSupply;
        uint256 minted;
        uint256 itemsPerPack;
        uint256 maxPerWallet;
        bool active;
        bool requiresAllowlist;
        string packUri;
        PackTraitInfo[] traits;
        uint256 availableSupply;
        uint256 soldPercentage;
    }

    struct PackTraitInfo {
        uint256 traitId;
        string traitName;
        string traitCategory;
        uint256 minAmount;
        uint256 maxAmount;
        uint256 chance;
        uint256 remaining;
        uint256 chancePercentage; // Calculated percentage
    }

    struct SerumFullInfo {
        uint256 id;
        string name;
        string targetMutation;
        uint256 potency;
        uint256 totalUsed;
        uint256 totalSuccess;
        uint256 successRate; // Calculated percentage
        SerumAnalytics analytics;
    }

    struct SerumAnalytics {
        uint256 serumId;
        uint256 totalUsed;
        uint256 totalSuccess;
        uint256 successRate;
        bool canUseOnToken;
        bool alreadyUsedOnToken;
        bool wouldSucceed; // Simulation result
    }

    struct MintInfo {
        bool canMint;
        string reason;
        uint256 price;
        uint256 available;
        uint256 userMinted;
        uint256 maxPerWallet;
        BatchInfo currentBatch;
        MintAnalytics analytics;
    }

    struct BatchInfo {
        uint256 batchId;
        string name;
        uint256 price;
        uint256 minted;
        uint256 maxSupply;
        bool active;
        uint256 startTime;
        uint256 endTime;
        bool useMerkleWhitelist;
        uint256 remainingSupply;
        uint256 soldPercentage;
    }

    struct MintAnalytics {
        uint256 totalBatches;
        uint256 activeBatch;
        bool mintingActive;
        uint256 totalMintedEver;
    }

    struct CraftingRecipeFullInfo {
        uint256 id;
        uint256[] ingredientIds;
        string[] ingredientNames;
        uint256[] ingredientAmounts;
        uint256 resultId;
        string resultName;
        uint256 resultAmount;
        bool consumeIngredients;
        bool active;
        uint256 minLevel;
        bool requiresAllowlist;
        bool canCraft; // User can craft this recipe
        string cantCraftReason;
        CraftingAnalytics analytics;
    }

    struct CraftingAnalytics {
        uint256 totalIngredients;
        uint256 totalCost; // Estimated value
        bool hasRareIngredients;
        uint256 complexity; // 1-5 scale
    }

    struct MarketplaceListingFull {
        uint256 listingId;
        address seller;
        uint256 assetId;
        string assetName;
        string assetCategory;
        uint256 amount;
        uint256 pricePerUnit;
        uint256 totalPrice;
        uint256 expiration;
        bool active;
        bool isExpired;
        uint256 timeRemaining;
    }

    // =============== 1. PACK SYSTEM FUNCTIONS ===============
    
    /**
     * @dev Información completa de pack - CRÍTICA PARA PACK UI 🎯
     */
    function getPackFullInfo(uint256 packId) external view returns (PackFullInfo memory info) {
        if (traitsCore == address(0)) return info;
        
        try IAdrianTraitsCore(traitsCore).getPackInfo(packId) returns (
            uint256 price, uint256 maxSupply, uint256 minted, 
            uint256 itemsPerPack, uint256 maxPerWallet, bool active,
            bool requiresAllowlist, string memory packUri
        ) {
            info.id = packId;
            info.price = price;
            info.maxSupply = maxSupply;
            info.minted = minted;
            info.itemsPerPack = itemsPerPack;
            info.maxPerWallet = maxPerWallet;
            info.active = active;
            info.requiresAllowlist = requiresAllowlist;
            info.packUri = packUri;
            
            // Calculate analytics
            info.availableSupply = maxSupply > minted ? maxSupply - minted : 0;
            if (maxSupply > 0) {
                info.soldPercentage = (minted * 100) / maxSupply;
            }
            
            // Get pack traits with analytics
            info.traits = getPackTraits(packId);
        } catch {}
    }

    /**
     * @dev Información detallada de traits en pack
     */
    function getPackTraits(uint256 packId) public view returns (PackTraitInfo[] memory traits) {
        if (traitsCore == address(0)) return traits;
        
        try IAdrianTraitsCore(traitsCore).packTraitsLength(packId) returns (uint256 length) {
            traits = new PackTraitInfo[](length);
            
            for (uint256 i = 0; i < length; i++) {
                try IAdrianTraitsCore(traitsCore).getPackTraitInfo(packId, i) returns (
                    uint256 traitId, uint256 minAmount, uint256 maxAmount
                ) {
                    traits[i].traitId = traitId;
                    traits[i].minAmount = minAmount;
                    traits[i].maxAmount = maxAmount;
                    traits[i].chance = 0; // ✅ ELIMINADO: No más chance-based logic
                    
                    // ✅ CALCULAR RAREZA BASADA EN DISPONIBILIDAD:
                    try IAdrianTraitsCore(traitsCore).getAvailableSupply(traitId) returns (uint256 available) {
                        traits[i].remaining = available;
                        // La rareza ahora se basa en disponibilidad real
                        traits[i].chancePercentage = available > 0 ? 1 : 0; // Simplificado
                    } catch {
                        traits[i].remaining = 0;
                        traits[i].chancePercentage = 0;
                    }
                    
                    // Get trait details
                    try IAdrianTraitsCore(traitsCore).getName(traitId) returns (string memory name) {
                        traits[i].traitName = name;
                    } catch {
                        traits[i].traitName = "Unknown";
                    }
                    
                    try IAdrianTraitsCore(traitsCore).getCategory(traitId) returns (string memory category) {
                        traits[i].traitCategory = category;
                    } catch {
                        traits[i].traitCategory = "Unknown";
                    }
                } catch {}
            }
        } catch {}
    }

    /**
     * @dev Información de múltiples packs
     */
    function getMultiplePacksInfo(uint256[] calldata packIds) external view returns (PackFullInfo[] memory infos) {
        infos = new PackFullInfo[](packIds.length);
        for (uint256 i = 0; i < packIds.length; i++) {
            infos[i] = this.getPackFullInfo(packIds[i]);
        }
    }

    // =============== 2. SERUM SYSTEM & ANALYTICS ===============
    
    /**
     * @dev Información completa de serum - CRÍTICA PARA SERUM UI 🎯
     */
    function getSerumFullInfo(uint256 serumId) external view returns (SerumFullInfo memory info) {
        if (traitsCore == address(0) || serumModule == address(0)) return info;
        
        info.id = serumId;
        
        try IAdrianTraitsCore(traitsCore).getName(serumId) returns (string memory name) {
            info.name = name;
        } catch {
            info.name = "Unknown Serum";
        }
        
        try IAdrianTraitsCore(traitsCore).getSerumData(serumId) returns (
            string memory targetMutation, uint256 potency
        ) {
            info.targetMutation = targetMutation;
            info.potency = potency;
        } catch {}
        
        try IAdrianSerumModule(serumModule).totalUsed(serumId) returns (uint256 used) {
            info.totalUsed = used;
            info.analytics.totalUsed = used;
        } catch {}
        
        try IAdrianSerumModule(serumModule).totalSuccess(serumId) returns (uint256 success) {
            info.totalSuccess = success;
            info.analytics.totalSuccess = success;
            if (info.totalUsed > 0) {
                info.successRate = (success * 100) / info.totalUsed;
                info.analytics.successRate = info.successRate;
            }
        } catch {}
    }

    /**
     * @dev Analytics específicos de serum para un token
     */
    function getSerumAnalytics(uint256 serumId, uint256 tokenId) external view returns (SerumAnalytics memory analytics) {
        if (serumModule == address(0)) return analytics;
        
        analytics.serumId = serumId;
        
        try IAdrianSerumModule(serumModule).totalUsed(serumId) returns (uint256 used) {
            analytics.totalUsed = used;
        } catch {}
        
        try IAdrianSerumModule(serumModule).totalSuccess(serumId) returns (uint256 success) {
            analytics.totalSuccess = success;
            if (analytics.totalUsed > 0) {
                analytics.successRate = (success * 100) / analytics.totalUsed;
            }
        } catch {}
        
        try IAdrianSerumModule(serumModule).serumUsedOnToken(serumId, tokenId) returns (bool used) {
            analytics.alreadyUsedOnToken = used;
            analytics.canUseOnToken = !used;
        } catch {}
        
        if (analytics.canUseOnToken) {
            try IAdrianSerumModule(serumModule).simulateUse(serumId, tokenId) returns (bool wouldSucceed) {
                analytics.wouldSucceed = wouldSucceed;
            } catch {}
        }
    }

    /**
     * @dev Información de múltiples serums
     */
    function getMultipleSerumsInfo(uint256[] calldata serumIds) external view returns (SerumFullInfo[] memory infos) {
        infos = new SerumFullInfo[](serumIds.length);
        for (uint256 i = 0; i < serumIds.length; i++) {
            infos[i] = this.getSerumFullInfo(serumIds[i]);
        }
    }

    // =============== 3. MINTING SYSTEM & ANALYTICS ===============
    
    /**
     * @dev Información completa de mint - CRÍTICA PARA MINT UI 🎯
     */
    function getMintInfo(address user) external view returns (MintInfo memory info) {
        if (mintModule == address(0)) return info;
        
        try IAdrianMintModule(mintModule).canMint() returns (
            bool mintable, string memory reason, uint256 price, uint256 available
        ) {
            info.canMint = mintable;
            info.reason = reason;
            info.price = price;
            info.available = available;
        } catch {}
        
        try IAdrianMintModule(mintModule).getCurrentBatchInfo() returns (
            uint256 batchId, string memory name, uint256 price, uint256 minted,
            uint256 maxSupply, bool active, uint256 startTime, uint256 endTime, bool useMerkleWhitelist
        ) {
            info.currentBatch.batchId = batchId;
            info.currentBatch.name = name;
            info.currentBatch.price = price;
            info.currentBatch.minted = minted;
            info.currentBatch.maxSupply = maxSupply;
            info.currentBatch.active = active;
            info.currentBatch.startTime = startTime;
            info.currentBatch.endTime = endTime;
            info.currentBatch.useMerkleWhitelist = useMerkleWhitelist;
            
            // Calculate analytics
            info.currentBatch.remainingSupply = maxSupply > minted ? maxSupply - minted : 0;
            if (maxSupply > 0) {
                info.currentBatch.soldPercentage = (minted * 100) / maxSupply;
            }
            
            info.maxPerWallet = maxSupply; // Default fallback
            info.analytics.activeBatch = batchId;
            info.analytics.mintingActive = active;
            
            if (batchId > 0) {
                try IAdrianMintModule(mintModule).mintedPerWalletPerBatch(user, batchId) returns (uint256 userMinted) {
                    info.userMinted = userMinted;
                } catch {}
            }
        } catch {}
    }

    /**
     * @dev Información de batch específico
     */
    function getBatchInfoById(uint256 batchId) external view returns (BatchInfo memory info) {
        if (mintModule == address(0)) return info;
        
        try IAdrianMintModule(mintModule).getBatchInfo(batchId) returns (
            uint256 id, string memory name, uint256 price, uint256 minted,
            uint256 maxSupply, bool active, uint256 startTime, uint256 endTime, bool useMerkleWhitelist
        ) {
            info.batchId = id;
            info.name = name;
            info.price = price;
            info.minted = minted;
            info.maxSupply = maxSupply;
            info.active = active;
            info.startTime = startTime;
            info.endTime = endTime;
            info.useMerkleWhitelist = useMerkleWhitelist;
            
            // Calculate analytics
            info.remainingSupply = maxSupply > minted ? maxSupply - minted : 0;
            if (maxSupply > 0) {
                info.soldPercentage = (minted * 100) / maxSupply;
            }
        } catch {}
    }

    // =============== 4. CRAFTING SYSTEM ===============
    
    /**
     * @dev Información completa de receta de crafting
     */
    function getCraftingRecipeInfo(uint256 recipeId, address user) external view returns (CraftingRecipeFullInfo memory info) {
        if (craftingContract == address(0) || traitsCore == address(0)) return info;
        
        try IAdrianLabCrafting(craftingContract).craftingRecipes(recipeId) returns (
            IAdrianLabCrafting.CraftingRecipe memory recipe
        ) {
            info.id = recipe.id;
            info.ingredientIds = recipe.ingredientIds;
            info.ingredientAmounts = recipe.ingredientAmounts;
            info.resultId = recipe.resultId;
            info.resultAmount = recipe.resultAmount;
            info.consumeIngredients = recipe.consumeIngredients;
            info.active = recipe.active;
            info.minLevel = recipe.minLevel;
            info.requiresAllowlist = recipe.requiresAllowlist;
            
            // Get ingredient names
            info.ingredientNames = new string[](recipe.ingredientIds.length);
            for (uint256 i = 0; i < recipe.ingredientIds.length; i++) {
                try IAdrianTraitsCore(traitsCore).getName(recipe.ingredientIds[i]) returns (string memory name) {
                    info.ingredientNames[i] = name;
                } catch {
                    info.ingredientNames[i] = "Unknown";
                }
            }
            
            // Get result name
            try IAdrianTraitsCore(traitsCore).getName(recipe.resultId) returns (string memory name) {
                info.resultName = name;
            } catch {
                info.resultName = "Unknown";
            }
            
            // Analytics
            info.analytics.totalIngredients = recipe.ingredientIds.length;
            info.analytics.complexity = _calculateRecipeComplexity(recipe);
            
            // Check if user can craft
            (info.canCraft, info.cantCraftReason) = _canUserCraftRecipe(recipe, user);
        } catch {}
    }

    /**
     * @dev Todas las recetas activas con info de usuario
     */
    function getAllActiveRecipes(address user) external view returns (CraftingRecipeFullInfo[] memory recipes) {
        if (craftingContract == address(0)) return new CraftingRecipeFullInfo[](0);
        
        try IAdrianLabCrafting(craftingContract).nextRecipeId() returns (uint256 nextId) {
            CraftingRecipeFullInfo[] memory tempRecipes = new CraftingRecipeFullInfo[](nextId);
            uint256 activeCount = 0;
            
            for (uint256 i = 1; i < nextId; i++) {
                CraftingRecipeFullInfo memory recipeInfo = this.getCraftingRecipeInfo(i, user);
                if (recipeInfo.active) {
                    tempRecipes[activeCount] = recipeInfo;
                    activeCount++;
                }
            }
            
            // Create final array with correct size
            recipes = new CraftingRecipeFullInfo[](activeCount);
            for (uint256 i = 0; i < activeCount; i++) {
                recipes[i] = tempRecipes[i];
            }
        } catch {}
    }

    function _calculateRecipeComplexity(IAdrianLabCrafting.CraftingRecipe memory recipe) internal pure returns (uint256) {
        uint256 complexity = 1;
        
        if (recipe.ingredientIds.length > 3) complexity++;
        if (recipe.requiresAllowlist) complexity++;
        if (recipe.minLevel > 0) complexity++;
        if (!recipe.consumeIngredients) complexity++; // Rare recipes
        
        return complexity > 5 ? 5 : complexity;
    }

    function _canUserCraftRecipe(IAdrianLabCrafting.CraftingRecipe memory recipe, address user) 
        internal view returns (bool canCraft, string memory reason) {
        if (!recipe.active) {
            return (false, "Recipe not active");
        }
        
        // Check ingredients
        for (uint256 i = 0; i < recipe.ingredientIds.length; i++) {
            try IAdrianTraitsCore(traitsCore).balanceOf(user, recipe.ingredientIds[i]) returns (uint256 balance) {
                if (balance < recipe.ingredientAmounts[i]) {
                    return (false, "Insufficient ingredients");
                }
            } catch {
                return (false, "Error checking ingredients");
            }
        }
        
        return (true, "Can craft");
    }

    // =============== 5. MARKETPLACE FUNCTIONS ===============
    
    /**
     * @dev Información completa de listing del marketplace
     */
    function getMarketplaceListingFull(uint256 listingId) external view returns (MarketplaceListingFull memory info) {
        if (marketplaceContract == address(0)) return info;
        
        try IAdrianLabMarketplace(marketplaceContract).listings(listingId) returns (
            IAdrianLabMarketplace.MarketplaceListing memory listing
        ) {
            info.listingId = listingId;
            info.seller = listing.seller;
            info.assetId = listing.assetId;
            info.amount = listing.amount;
            info.pricePerUnit = listing.pricePerUnit;
            info.totalPrice = listing.amount * listing.pricePerUnit;
            info.expiration = listing.expiration;
            info.active = listing.active;
            info.isExpired = block.timestamp > listing.expiration;
            
            if (!info.isExpired && listing.expiration > block.timestamp) {
                info.timeRemaining = listing.expiration - block.timestamp;
            }
            
            // Get asset info
            if (traitsCore != address(0)) {
                try IAdrianTraitsCore(traitsCore).getName(listing.assetId) returns (string memory name) {
                    info.assetName = name;
                } catch {
                    info.assetName = "Unknown Asset";
                }
                
                try IAdrianTraitsCore(traitsCore).getCategory(listing.assetId) returns (string memory category) {
                    info.assetCategory = category;
                } catch {
                    info.assetCategory = "Unknown";
                }
            }
        } catch {}
    }

    /**
     * @dev Listings de un usuario
     */
    function getUserMarketplaceListings(address user) external view returns (MarketplaceListingFull[] memory listings) {
        if (marketplaceContract == address(0)) return new MarketplaceListingFull[](0);
        
        try IAdrianLabMarketplace(marketplaceContract).getUserListings(user) returns (uint256[] memory listingIds) {
            listings = new MarketplaceListingFull[](listingIds.length);
            
            for (uint256 i = 0; i < listingIds.length; i++) {
                listings[i] = this.getMarketplaceListingFull(listingIds[i]);
            }
        } catch {}
    }

    // =============== 6. ADVANCED HISTORY FUNCTIONS ===============
    
    /**
     * @dev Eventos por tipo específico
     */
    function getEventsByType(uint256 tokenId, bytes32 eventType) external view returns (IAdrianHistory.HistoricalEvent[] memory events) {
        if (historyContract == address(0)) return new IAdrianHistory.HistoricalEvent[](0);
        
        try IAdrianHistory(historyContract).getEventsForToken(tokenId) returns (IAdrianHistory.HistoricalEvent[] memory allEvents) {
            uint256 matchingCount = 0;
            
            // Count matching events
            for (uint256 i = 0; i < allEvents.length; i++) {
                if (allEvents[i].eventType == eventType) {
                    matchingCount++;
                }
            }
            
            // Create result array
            events = new IAdrianHistory.HistoricalEvent[](matchingCount);
            uint256 index = 0;
            
            for (uint256 i = 0; i < allEvents.length; i++) {
                if (allEvents[i].eventType == eventType) {
                    events[index] = allEvents[i];
                    index++;
                }
            }
        } catch {}
    }

    /**
     * @dev Analytics de historia del token
     */
    function getTokenHistoryAnalytics(uint256 tokenId) external view returns (
        uint256 totalEvents,
        uint256 mintEvents,
        uint256 mutationEvents,
        uint256 tradeEvents,
        uint256 lastActivityTimestamp
    ) {
        if (historyContract == address(0)) return (0, 0, 0, 0, 0);
        
        try IAdrianHistory(historyContract).getEventsForToken(tokenId) returns (IAdrianHistory.HistoricalEvent[] memory events) {
            totalEvents = events.length;
            
            for (uint256 i = 0; i < events.length; i++) {
                if (events[i].eventType == keccak256("MINT")) {
                    mintEvents++;
                } else if (events[i].eventType == keccak256("MUTATION") || events[i].eventType == keccak256("SERUM_USED")) {
                    mutationEvents++;
                } else if (events[i].eventType == keccak256("TRANSFER")) {
                    tradeEvents++;
                }
                
                if (events[i].timestamp > lastActivityTimestamp) {
                    lastActivityTimestamp = events[i].timestamp;
                }
            }
        } catch {}
    }

    // =============== 7. PLACEHOLDER FUNCTIONS ===============
    
    /**
     * @dev Funciones placeholder para futuras expansiones
     */
    function getUserSerumHistory(address /* user */) external pure returns (uint256[] memory serumIds) {
        return new uint256[](0);
    }

    function getTokenSerumHistory(uint256 /* tokenId */) external pure returns (uint256[] memory serumIds) {
        return new uint256[](0);
    }

    // =============== 8. UPDATE FUNCTIONS ===============
    
    function updateContracts(
        address _traits,
        address _history,
        address _mint,
        address _serum,
        address _crafting,
        address _marketplace
    ) external {
        // Note: Add access control if needed
        traitsCore = _traits;
        historyContract = _history;
        mintModule = _mint;
        serumModule = _serum;
        craftingContract = _crafting;
        marketplaceContract = _marketplace;
    }
}