// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AdrianStorage.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AdrianTraitsExtensions is AdrianStorage, ReentrancyGuard, Initializable {
    event ListingCreated(uint256 indexed listingId, address seller, uint256 assetId, uint256 amount, uint256 pricePerUnit);
    event ListingUpdated(uint256 indexed listingId, uint256 amount, uint256 pricePerUnit);
    event ListingCancelled(uint256 indexed listingId);
    event ListingSold(uint256 indexed listingId, address buyer, uint256 amount);
    event RecipeCreated(uint256 indexed recipeId, uint256[] ingredientIds, uint256 resultId);
    event RecipeUpdated(uint256 indexed recipeId, uint256[] ingredientIds, uint256 resultId);
    event RecipeActivated(uint256 indexed recipeId);
    event RecipeDeactivated(uint256 indexed recipeId);
    event ItemCrafted(uint256 indexed recipeId, address crafter, uint256 resultId);
    event AllowlistUpdated(uint256 indexed recipeId, bytes32 merkleRoot);
    event AllowlistClaimed(uint256 indexed recipeId, address user);
    event MarketplaceFeeUpdated(uint256 newFee);
    event FeeRecipientUpdated(address newRecipient);
    event EmergencyModeActivated();
    event EmergencyModeDeactivated();
    event FunctionPaused(bytes4 functionSelector);
    event FunctionUnpaused(bytes4 functionSelector);

    function initialize(address _admin) public initializer {
        admin = _admin;
    }

    // Mantener solo funciones y eventos propios. El storage y structs están en AdrianStorage.
    // ...
}