// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "./interfaces/IAdrianHistory.sol";
import {IAdrianTraitsCore} from "./AdrianTraitsCore.sol";

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
    IAdrianTraitsCore public immutable traitsCore;
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

    // =============== Modifiers ===============
    modifier notPaused(bytes4 selector) {
        require(!emergencyMode || !pausedFunctions[selector], "Function paused");
        _;
    }

    // =============== Constructor ===============
    constructor(IAdrianTraitsCore _traitsCore) {
        require(address(_traitsCore) != address(0), "Invalid contract");
        traitsCore = _traitsCore;
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

        // Mintear el resultado
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
        historyContract = IAdrianHistory(_historyContract);
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
        
        CraftingRecipe storage recipe = craftingRecipes[recipeId];
        recipe.ingredientIds = ingredientIds;
        recipe.ingredientAmounts = ingredientAmounts;
        recipe.resultAmount = resultAmount;
        recipe.consumeIngredients = consumeIngredients;
        recipe.minLevel = minLevel;
        recipe.requiresAllowlist = requiresAllowlist;
    }
}
