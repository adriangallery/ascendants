// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./interfaces/IAdrianHistory.sol";

// =============== CONSTANTES DE RANGOS FASE 2 ===============
uint256 constant TRAIT_ID_MAX = 99_999;        // Actualizado desde 999_999
uint256 constant PACK_ID_MIN = 100_000;        // Actualizado desde 1_000_000  
uint256 constant PACK_ID_MAX = 109_999;        // Actualizado desde 1_999_999
uint256 constant SERUM_ID_MIN = 110_000;       // NUEVO rango para serums

// =============== INTERFAZ CORREGIDA FASE 2 ===============
interface IAdrianTraitsCore is IERC1155 {
    struct AssetData {
        string name;
        string category;
        string ipfsPath;
        bool isTemporary;
        uint256 maxSupply;
    }

    function getAssetData(uint256 assetId) external view returns (AssetData memory);
    function burn(address from, uint256 id, uint256 amount) external;
    function mint(address to, uint256 id, uint256 amount) external;  // ✅ AGREGADO
    function getName(uint256 assetId) external view returns (string memory);
    function getCategory(uint256 assetId) external view returns (string memory);
    function getTraitInfo(uint256 assetId) external view returns (string memory category, bool isTemp);
    function getCategoryList() external view returns (string[] memory);
    function purchasePack(uint256 packId, uint256 quantity, bytes32[] calldata merkleProof) external;
    function openPack(uint256 packId) external;
}

// =============== Funciones de Validación de Rangos ===============
library CraftingValidation {
    function isValidTraitId(uint256 id) internal pure returns (bool) {
        return id > 0 && id <= TRAIT_ID_MAX;
    }
    
    function isValidPackId(uint256 id) internal pure returns (bool) {
        return id >= PACK_ID_MIN && id <= PACK_ID_MAX;
    }
    
    function isValidSerumId(uint256 id) internal pure returns (bool) {
        return id >= SERUM_ID_MIN;
    }
    
    function isValidCraftableAsset(uint256 id) internal pure returns (bool) {
        return isValidTraitId(id) || isValidSerumId(id); // Packs no se pueden craftear
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

/**
 * @title AdrianLabCrafting
 * @dev Sistema de crafting para AdrianLab, permite crear y ejecutar recetas de crafting
 */
contract AdrianLabCrafting is Ownable, ReentrancyGuard, ERC1155Holder {
    // =============== Type Definitions ===============
    struct CraftingRecipe {
        uint256 id;
        uint256[] ingredientIds;
        uint256[] ingredientAmounts;
        uint256 resultId;
        uint256 resultAmount;
        bool consumeIngredients;
        bool active;
        uint256 minLevel;        // Nivel mínimo requerido para craftear
        bool requiresAllowlist;  // Si requiere estar en allowlist
    }

    // =============== State Variables ===============
    mapping(uint256 => CraftingRecipe) public craftingRecipes;
    uint256 public nextRecipeId = 1;

    // Contract references
    IAdrianTraitsCore public traitsCore;
    IAdrianHistory public historyContract;
    
    // Allowlist system for recipes
    mapping(uint256 => bytes32) public recipeAllowlistRoots;    // recipeId => merkleRoot
    mapping(address => mapping(uint256 => bool)) public hasUsedRecipe;  // user => recipeId => used

    // Emergency features
    bool public emergencyMode = false;
    mapping(bytes4 => bool) public pausedFunctions;

    // =============== Events ===============
    event CraftingRecipeCreated(
        uint256 indexed recipeId, 
        uint256[] ingredientIds, 
        uint256 resultId,
        uint256 resultAmount,
        bool consumeIngredients,
        uint256 minLevel,
        bool requiresAllowlist
    );
    event AssetCrafted(
        address indexed crafter, 
        uint256 recipeId, 
        uint256 resultId, 
        uint256 amount,
        uint256[] ingredientsUsed
    );
    event RecipeAllowlistUpdated(uint256 indexed recipeId, bytes32 merkleRoot);
    event EmergencyModeSet(bool enabled);
    event FunctionPauseToggled(bytes4 functionSelector, bool paused);

    // ✅ EVENTOS PARA SETTERS
    event ContractUpdated(string contractName, address oldAddress, address newAddress);

    // =============== Modifiers ===============
    modifier notPaused(bytes4 selector) {
        require(!emergencyMode || !pausedFunctions[selector], "Function paused");
        _;
    }

    // =============== Constructor ===============
    constructor(address _traitsCore) Ownable(msg.sender) {
        require(_traitsCore != address(0) && _traitsCore.code.length > 0, "Invalid traits core");
        traitsCore = IAdrianTraitsCore(_traitsCore);
    }

    // =============== Crafting System ===============

    /**
     * @dev Create crafting recipe with advanced options
     */
    function createCraftingRecipe(
        uint256[] calldata ingredientIds,
        uint256[] calldata ingredientAmounts,
        uint256 resultId,
        uint256 resultAmount,
        bool consumeIngredients,
        uint256 minLevel,
        bool requiresAllowlist
    ) external onlyOwner {
        require(ingredientIds.length == ingredientAmounts.length, "Arrays length mismatch");
        require(ingredientIds.length > 0, "No ingredients specified");
        require(resultAmount > 0, "Invalid result amount");

        // ✅ FASE 2: Validaciones de rangos para crafting optimizadas
        for (uint256 i = 0; i < ingredientIds.length; i++) {
            require(CraftingValidation.isValidCraftableAsset(ingredientIds[i]), "Invalid ingredient asset type");
        }
        require(CraftingValidation.isValidCraftableAsset(resultId), "Invalid result asset type");
        require(!CraftingValidation.isPackAsset(resultId), "Cannot craft packs directly");

        uint256 recipeId = nextRecipeId++;

        craftingRecipes[recipeId] = CraftingRecipe({
            id: recipeId,
            ingredientIds: ingredientIds,
            ingredientAmounts: ingredientAmounts,
            resultId: resultId,
            resultAmount: resultAmount,
            consumeIngredients: consumeIngredients,
            active: true,
            minLevel: minLevel,
            requiresAllowlist: requiresAllowlist
        });

        emit CraftingRecipeCreated(
            recipeId, 
            ingredientIds, 
            resultId, 
            resultAmount,
            consumeIngredients,
            minLevel,
            requiresAllowlist
        );
    }

    /**
     * @dev Set allowlist for recipe
     */
    function setRecipeAllowlist(uint256 recipeId, bytes32 merkleRoot) external onlyOwner {
        require(craftingRecipes[recipeId].id == recipeId, "Invalid recipe");
        recipeAllowlistRoots[recipeId] = merkleRoot;
        emit RecipeAllowlistUpdated(recipeId, merkleRoot);
    }

    /**
     * @dev Craft item from recipe
     */
    function craft(
        uint256 recipeId, 
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external nonReentrant notPaused(this.craft.selector) {
        CraftingRecipe storage recipe = craftingRecipes[recipeId];
        require(recipe.active, "Recipe inactive");
        require(amount > 0, "Invalid amount");

        // ✅ FASE 2: Verificar rangos en recipe result optimizado
        require(CraftingValidation.isValidCraftableAsset(recipe.resultId), "Invalid result asset type");

        // Verificar allowlist si es necesario
        if (recipe.requiresAllowlist) {
            bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
            require(
                MerkleProof.verify(merkleProof, recipeAllowlistRoots[recipeId], leaf),
                "Not in allowlist"
            );
        }

        // Verificar ingredientes suficientes
        for (uint256 i = 0; i < recipe.ingredientIds.length; i++) {
            uint256 ingId = recipe.ingredientIds[i];
            uint256 requiredAmount = recipe.ingredientAmounts[i] * amount;
            
            // ✅ FASE 2: Verificar que los ingredientes sean válidos optimizado
            require(CraftingValidation.isValidCraftableAsset(ingId), "Invalid ingredient asset type");
            
            require(
                traitsCore.balanceOf(msg.sender, ingId) >= requiredAmount,
                "Insufficient ingredient"
            );
        }

        // Consumir ingredientes
        if (recipe.consumeIngredients) {
            for (uint256 i = 0; i < recipe.ingredientIds.length; i++) {
                uint256 ingId = recipe.ingredientIds[i];
                uint256 requiredAmount = recipe.ingredientAmounts[i] * amount;
                traitsCore.burn(msg.sender, ingId, requiredAmount);
            }
        }

        // Mintear el resultado - ✅ CORREGIDO: ahora mint() existe en interfaz
        traitsCore.mint(msg.sender, recipe.resultId, recipe.resultAmount * amount);

        // Registrar en history si está configurado
        if (address(historyContract) != address(0)) {
            historyContract.recordEvent(
                recipe.resultId,
                keccak256("ASSET_CRAFTED"),
                msg.sender,
                abi.encode(recipeId, amount, recipe.ingredientIds),
                block.number
            );
        }

        emit AssetCrafted(
            msg.sender, 
            recipeId, 
            recipe.resultId, 
            recipe.resultAmount * amount,
            recipe.ingredientIds
        );
    }

    /**
     * @dev Toggle recipe active status
     */
    function toggleRecipe(uint256 recipeId, bool active) external onlyOwner {
        require(craftingRecipes[recipeId].id == recipeId, "Invalid recipe");
        craftingRecipes[recipeId].active = active;
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
     * @dev Set history contract
     */
    function setHistoryContract(address _historyContract) external onlyOwner {
        require(_historyContract != address(0) && _historyContract.code.length > 0, "Invalid contract");
        address oldContract = address(historyContract);
        historyContract = IAdrianHistory(_historyContract);
        emit ContractUpdated("HistoryContract", oldContract, _historyContract);
    }

    /**
     * @dev Update recipe configuration
     */
    function updateRecipe(
        uint256 recipeId,
        uint256[] calldata ingredientIds,
        uint256[] calldata ingredientAmounts,
        uint256 resultAmount,
        bool consumeIngredients,
        uint256 minLevel,
        bool requiresAllowlist
    ) external onlyOwner {
        require(craftingRecipes[recipeId].id == recipeId, "Invalid recipe");
        require(ingredientIds.length == ingredientAmounts.length, "Arrays length mismatch");
        
        // ✅ FASE 2: Validaciones de rangos en actualización optimizadas
        for (uint256 i = 0; i < ingredientIds.length; i++) {
            require(CraftingValidation.isValidCraftableAsset(ingredientIds[i]), "Invalid ingredient asset type");
        }
        
        CraftingRecipe storage recipe = craftingRecipes[recipeId];
        require(CraftingValidation.isValidCraftableAsset(recipe.resultId), "Invalid result asset type");
        
        recipe.ingredientIds = ingredientIds;
        recipe.ingredientAmounts = ingredientAmounts;
        recipe.resultAmount = resultAmount;
        recipe.consumeIngredients = consumeIngredients;
        recipe.minLevel = minLevel;
        recipe.requiresAllowlist = requiresAllowlist;
    }

    // =============== FASE 2: Funciones de Validación y Utilidad ===============

    /**
     * @dev Validate asset for crafting
     */
    function validateCraftingAsset(uint256 assetId) external pure returns (bool isValid, string memory assetType) {
        if (CraftingValidation.isTraitAsset(assetId)) {
            return (true, "TRAIT");
        } else if (CraftingValidation.isSerumAsset(assetId)) {
            return (true, "SERUM");
        } else if (CraftingValidation.isPackAsset(assetId)) {
            return (false, "PACK - Cannot craft packs");
        }
        return (false, "INVALID");
    }

    /**
     * @dev Get supported asset ranges for crafting
     */
    function getCraftingRanges() external pure returns (
        uint256 traitMax,
        uint256 serumMin,
        string memory info
    ) {
        return (
            TRAIT_ID_MAX, 
            SERUM_ID_MIN, 
            "Traits: 1-99999, Serums: 110000+, Packs: Not craftable"
        );
    }

    /**
     * @dev Check if recipe ingredients are valid
     */
    function validateRecipeIngredients(uint256[] calldata ingredientIds) 
        external 
        pure 
        returns (bool allValid, uint256 firstInvalidId) 
    {
        for (uint256 i = 0; i < ingredientIds.length; i++) {
            if (!CraftingValidation.isValidCraftableAsset(ingredientIds[i])) {
                return (false, ingredientIds[i]);
            }
        }
        return (true, 0);
    }

    /**
     * @dev Get recipe details
     */
    function getRecipeDetails(uint256 recipeId) external view returns (
        uint256[] memory ingredientIds,
        uint256[] memory ingredientAmounts,
        uint256 resultId,
        uint256 resultAmount,
        bool consumeIngredients,
        bool active,
        uint256 minLevel,
        bool requiresAllowlist
    ) {
        CraftingRecipe storage recipe = craftingRecipes[recipeId];
        require(recipe.id == recipeId, "Invalid recipe");
        
        return (
            recipe.ingredientIds,
            recipe.ingredientAmounts,
            recipe.resultId,
            recipe.resultAmount,
            recipe.consumeIngredients,
            recipe.active,
            recipe.minLevel,
            recipe.requiresAllowlist
        );
    }

    /**
     * @dev Check if user can craft recipe
     */
    function canCraftRecipe(uint256 recipeId, address user, uint256 amount) external view returns (
        bool canCraft,
        string memory reason
    ) {
        CraftingRecipe storage recipe = craftingRecipes[recipeId];
        
        if (recipe.id != recipeId) {
            return (false, "Recipe does not exist");
        }
        
        if (!recipe.active) {
            return (false, "Recipe is inactive");
        }
        
        // Check ingredients
        for (uint256 i = 0; i < recipe.ingredientIds.length; i++) {
            uint256 ingId = recipe.ingredientIds[i];
            uint256 requiredAmount = recipe.ingredientAmounts[i] * amount;
            
            if (traitsCore.balanceOf(user, ingId) < requiredAmount) {
                return (false, "Insufficient ingredients");
            }
        }
        
        return (true, "Can craft");
    }

    /**
     * @dev Get all active recipes
     */
    function getActiveRecipes() external view returns (uint256[] memory) {
        uint256 count = 0;
        
        // First pass: count active recipes
        for (uint256 i = 1; i < nextRecipeId; i++) {
            if (craftingRecipes[i].active) {
                count++;
            }
        }
        
        // Second pass: collect active recipes
        uint256[] memory activeRecipes = new uint256[](count);
        uint256 index = 0;
        
        for (uint256 i = 1; i < nextRecipeId; i++) {
            if (craftingRecipes[i].active) {
                activeRecipes[index] = i;
                index++;
            }
        }
        
        return activeRecipes;
    }

    /**
     * @dev Get recipes that result in specific asset
     */
    function getRecipesByResult(uint256 resultId) external view returns (uint256[] memory) {
        uint256 count = 0;
        
        // First pass: count matching recipes
        for (uint256 i = 1; i < nextRecipeId; i++) {
            if (craftingRecipes[i].resultId == resultId && craftingRecipes[i].active) {
                count++;
            }
        }
        
        // Second pass: collect matching recipes
        uint256[] memory matchingRecipes = new uint256[](count);
        uint256 index = 0;
        
        for (uint256 i = 1; i < nextRecipeId; i++) {
            if (craftingRecipes[i].resultId == resultId && craftingRecipes[i].active) {
                matchingRecipes[index] = i;
                index++;
            }
        }
        
        return matchingRecipes;
    }

    /**
     * @dev Validate asset ID range and type for crafting
     */
    function validateAssetForCrafting(uint256 assetId) external pure returns (bool canCraft, string memory reason) {
        if (CraftingValidation.isTraitAsset(assetId)) {
            return (true, "Valid trait asset");
        } else if (CraftingValidation.isSerumAsset(assetId)) {
            return (true, "Valid serum asset");
        } else if (CraftingValidation.isPackAsset(assetId)) {
            return (false, "Packs cannot be used in crafting");
        }
        return (false, "Invalid asset ID range");
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

    // ✅ SETTERS PARA ACTUALIZACIONES DE CONTRATOS
    
    /**
     * @dev Actualiza la dirección del contrato AdrianTraitsCore
     */
    function setTraitsCore(address _traitsCore) external onlyOwner {
        require(_traitsCore != address(0) && _traitsCore.code.length > 0, "Invalid traits core");
        address oldCore = address(traitsCore);
        traitsCore = IAdrianTraitsCore(_traitsCore);
        emit ContractUpdated("TraitsCore", oldCore, _traitsCore);
    }
}