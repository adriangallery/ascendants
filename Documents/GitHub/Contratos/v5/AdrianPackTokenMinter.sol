// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// =============== STRUCTS & ENUMS ===============

struct PackConfig {
    uint256 id;
    uint256 publicPrice;
    uint256 maxSupply;
    uint256 minted;
    uint256 itemsPerPack;
    uint256 maxPerWallet;
    uint256 startTime;
    uint256 endTime;
    bool active;
    uint256 allowlistFreeAmount;
    uint256 allowlistPrice;
    bool hasPublicSale;
    bool hasAllowlist;
}

// ❌ ELIMINADO: struct PackTrait - Ya no necesario

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
    function getAssetData(uint256 assetId) external view returns (AssetData memory);
}

// Struct para compatibilidad con TraitsCore
struct AssetData {
    string category;
    bool tempFlag;
    uint256 maxSupply;
    uint8 assetType; // AssetType enum as uint8
}

/**
 * @title AdrianFloppyDiscs
 * @dev Contract for pack purchasing and opening functionality - ULTRA-SIMPLIFIED SUPPLY-WEIGHTED
 */
contract AdrianFloppyDiscs is Ownable, ReentrancyGuard {

    // =============== STATE VARIABLES ===============
    
    // Contract references
    IAdrianTraitsCore public immutable traitsCore;
    IERC20 public immutable paymentToken;

    // ✅ NUEVO: Treasury wallet management
    address public treasuryWallet;

    // Pack management
    mapping(uint256 => PackConfig) public packConfigs;
    // ✅ NUEVO: Simple mapping de assets por pack (reemplaza PackTrait[])
    mapping(uint256 => uint256[]) public packAssets; // packId → [assetId1, assetId2, ...]

    // Allowlist tracking - MANTENER INTACTO
    mapping(uint256 => mapping(address => uint256)) public allowlistFreeClaimed;
    mapping(uint256 => mapping(address => uint256)) public allowlistPaidClaimed;
    mapping(uint256 => mapping(address => bool)) public simpleAllowlist;

    // ✅ MANTENER: Enhanced randomness system
    uint256 private nonce;

    // =============== EVENTS ===============
    
    // MANTENER TODOS LOS EVENTOS INTACTOS
    event PackPurchased(address indexed buyer, uint256 packId, uint256 quantity, bool useAllowlist);
    event PackOpened(address indexed user, uint256 packId, uint256[] assetIds, uint256[] amounts);
    event PackConfigured(uint256 indexed packId, uint256 publicPrice, uint256 maxSupply);
    event PackAllowlistConfigured(uint256 indexed packId, uint256 freeAmount, uint256 paidPrice);
    // ✅ MODIFICADO: Event simplificado para assets
    event PackAssetsSet(uint256 indexed packId, uint256 assetsCount);
    event PackSaleFlagsUpdated(uint256 indexed packId, bool hasPublicSale, bool hasAllowlist);
    event AllowlistPurchase(address indexed buyer, uint256 packId, uint256 quantity, uint256 freeUsed, uint256 paidUsed);
    event WalletAddedToAllowlist(uint256 indexed packId, address wallet);
    event WalletRemovedFromAllowlist(uint256 indexed packId, address wallet);
    // ✅ NUEVO: Treasury wallet event
    event TreasuryWalletUpdated(address indexed newTreasuryWallet);

    // =============== CONSTRUCTOR ===============
    
    constructor(address _traitsCore, address _paymentToken, address _treasuryWallet) Ownable(msg.sender) {
        require(_traitsCore != address(0), "Invalid traits core");
        require(_paymentToken != address(0), "Invalid payment token");
        require(_treasuryWallet != address(0), "Invalid treasury wallet");
        
        traitsCore = IAdrianTraitsCore(_traitsCore);
        paymentToken = IERC20(_paymentToken);
        treasuryWallet = _treasuryWallet;
    }

    // =============== PURCHASE FLOW (100% INTACTO - NO TOCAR) ===============
    
    function purchasePack(uint256 packId, uint256 quantity, bool useAllowlist) external nonReentrant {
        PackConfig storage config = packConfigs[packId];
        require(config.active, "Pack not active");
        
        if (useAllowlist) {
            require(config.hasAllowlist, "Allowlist not enabled for this pack");
            _processAllowlistPurchase(packId, quantity);
        } else {
            require(config.hasPublicSale, "Public sale not enabled for this pack");
            _processPublicPurchase(packId, quantity);
        }
        
        // Mint pack tokens via TraitsCore
        traitsCore.mintFromExtension(msg.sender, packId, quantity);
        
        // Update minted count
        packConfigs[packId].minted += quantity;
        
        emit PackPurchased(msg.sender, packId, quantity, useAllowlist);
    }

    function _processAllowlistPurchase(uint256 packId, uint256 quantity) internal {
        PackConfig storage config = packConfigs[packId];
        require(simpleAllowlist[packId][msg.sender], "Not in allowlist");
        
        // Verificar timing (MISMO que public sale)
        if (config.startTime > 0) require(block.timestamp >= config.startTime, "Not started");
        if (config.endTime > 0) require(block.timestamp <= config.endTime, "Ended");
        
        uint256 userFreeClaimed = allowlistFreeClaimed[packId][msg.sender];
        uint256 userPaidClaimed = allowlistPaidClaimed[packId][msg.sender];
        uint256 totalUserClaimed = userFreeClaimed + userPaidClaimed;
        
        // Verificar límites
        if (config.maxPerWallet > 0) {
            require(totalUserClaimed + quantity <= config.maxPerWallet, "Exceeds wallet limit");
        }
        require(config.minted + quantity <= config.maxSupply, "Exceeds max supply");
        
        // Calcular distribución free vs paid
        uint256 freeAvailable = config.allowlistFreeAmount > userFreeClaimed ? 
            config.allowlistFreeAmount - userFreeClaimed : 0;
        
        uint256 freeToUse = quantity > freeAvailable ? freeAvailable : quantity;
        uint256 paidToUse = quantity - freeToUse;
        
        // Actualizar claimed amounts
        if (freeToUse > 0) {
            allowlistFreeClaimed[packId][msg.sender] += freeToUse;
        }
        if (paidToUse > 0) {
            allowlistPaidClaimed[packId][msg.sender] += paidToUse;
        }
        
        // Procesar pago si es necesario
        if (paidToUse > 0 && config.allowlistPrice > 0) {
            uint256 totalCost = config.allowlistPrice * paidToUse;
            require(
                paymentToken.transferFrom(msg.sender, treasuryWallet, totalCost),
                "Payment failed"
            );
        }
        
        emit AllowlistPurchase(msg.sender, packId, quantity, freeToUse, paidToUse);
    }

    function _processPublicPurchase(uint256 packId, uint256 quantity) internal {
        PackConfig storage config = packConfigs[packId];
        
        // Verificar timing
        if (config.startTime > 0) require(block.timestamp >= config.startTime, "Not started");
        if (config.endTime > 0) require(block.timestamp <= config.endTime, "Ended");
        
        // Verificar límites
        if (config.maxPerWallet > 0) {
            uint256 userMinted = traitsCore.balanceOf(msg.sender, packId);
            require(userMinted + quantity <= config.maxPerWallet, "Exceeds wallet limit");
        }
        require(config.minted + quantity <= config.maxSupply, "Exceeds max supply");
        
        // Procesar pago
        if (config.publicPrice > 0) {
            uint256 totalCost = config.publicPrice * quantity;
            require(
                paymentToken.transferFrom(msg.sender, treasuryWallet, totalCost),
                "Payment failed"
            );
        }
    }

    // =============== ✅ OPEN FLOW - ULTRA-SIMPLIFIED SUPPLY-WEIGHTED ===============
    
    function openPack(uint256 packId) external nonReentrant {
        require(traitsCore.balanceOf(msg.sender, packId) > 0, "No pack tokens");
        PackConfig storage config = packConfigs[packId];
        require(config.active, "Pack not active");
        
        // ✅ ULTRA-SIMPLE: Generate pack contents
        (uint256[] memory assetIds, uint256[] memory amounts) = _generatePackContents(packId);
        
        // Burn pack token
        traitsCore.burnFromExtension(msg.sender, packId, 1);
        
        // Mint assets to user via TraitsCore
        for (uint256 i = 0; i < assetIds.length; i++) {
                traitsCore.mintFromExtension(msg.sender, assetIds[i], amounts[i]);
        }
        
        emit PackOpened(msg.sender, packId, assetIds, amounts);
    }

    // =============== ✅ PACK CONFIGURATION - SIMPLIFICADO PERO COMPATIBLE ===============
    
    function setPackConfig(
        uint256 packId, 
        uint256[] calldata assetIds,        // ✅ NUEVO: incluir assets en configuración
        uint256 itemsPerPack,               // ✅ MANTENER: cantidad de items
        uint256 publicPrice, 
        uint256 maxSupply, 
        bool active, 
        uint256 maxPerWallet, 
        uint256 startTime, 
        uint256 endTime,
        bool hasPublicSale,
        bool hasAllowlist
    ) external onlyOwner {
        require(endTime == 0 || endTime > startTime, "Invalid timing");
        require(itemsPerPack > 0, "Invalid items per pack");
        require(assetIds.length > 0, "Must specify pack assets");
        
        // ✅ BULLETPROOF: Verificar que el pack existe en TraitsCore y es de tipo PACK
        require(_isValidPack(packId), "Pack must be created in TraitsCore first and be of type PACK");
        
        // ✅ NUEVO: Validar y guardar assets
        for (uint256 i = 0; i < assetIds.length; i++) {
            require(_assetExistsSafe(assetIds[i]), "Asset does not exist in TraitsCore");
        }
        packAssets[packId] = assetIds;
        
        // ✅ MANTENER: Configuración PackConfig normal
        packConfigs[packId].id = packId;
        packConfigs[packId].publicPrice = publicPrice;
        packConfigs[packId].maxSupply = maxSupply;
        packConfigs[packId].active = active;
        packConfigs[packId].itemsPerPack = itemsPerPack;
        packConfigs[packId].maxPerWallet = maxPerWallet;
        packConfigs[packId].startTime = startTime;
        packConfigs[packId].endTime = endTime;
        packConfigs[packId].hasPublicSale = hasPublicSale;
        packConfigs[packId].hasAllowlist = hasAllowlist;
        
        emit PackConfigured(packId, publicPrice, maxSupply);
        emit PackAssetsSet(packId, assetIds.length);
    }

    // ✅ MANTENER INTACTO: Allowlist config
    function setPackAllowlistConfig(uint256 packId, uint256 freeAmount, uint256 paidPrice) external onlyOwner {
        packConfigs[packId].allowlistFreeAmount = freeAmount;
        packConfigs[packId].allowlistPrice = paidPrice;
        
        emit PackAllowlistConfigured(packId, freeAmount, paidPrice);
    }

    // ✅ NUEVO: Función para actualizar flags de venta
    function setPackSaleFlags(uint256 packId, bool hasPublicSale, bool hasAllowlist) external onlyOwner {
        packConfigs[packId].hasPublicSale = hasPublicSale;
        packConfigs[packId].hasAllowlist = hasAllowlist;
        
        emit PackSaleFlagsUpdated(packId, hasPublicSale, hasAllowlist);
        }
        
    // ✅ NUEVO: Setter independiente para pack contents
    function setPackContents(uint256 packId, uint256[] calldata assetIds) external onlyOwner {
        require(assetIds.length > 0, "Must specify pack assets");
        require(_isValidPack(packId), "Pack must exist and be of type PACK");
        
        // Validar que todos los assets existen en TraitsCore
        for (uint256 i = 0; i < assetIds.length; i++) {
            require(_assetExistsSafe(assetIds[i]), "Asset does not exist in TraitsCore");
        }
        
        // Actualizar solo los contenidos del pack
        packAssets[packId] = assetIds;
        
        emit PackAssetsSet(packId, assetIds.length);
    }
        
    // ✅ NUEVO: Treasury wallet setter
    function setTreasuryWallet(address _newTreasuryWallet) external onlyOwner {
        require(_newTreasuryWallet != address(0), "Invalid treasury wallet");
        treasuryWallet = _newTreasuryWallet;
        emit TreasuryWalletUpdated(_newTreasuryWallet);
    }
        
    // ❌ ELIMINADO: setPackTraits() - Ya no necesario

    // =============== ALLOWLIST SYSTEM (100% INTACTO - NO TOCAR) ===============

    function isInAllowlist(uint256 packId, address wallet) external view returns (bool) {
        return simpleAllowlist[packId][wallet];
    }

    function addWalletToAllowlist(uint256 packId, address wallet) external onlyOwner {
        require(wallet != address(0), "Invalid wallet");
        simpleAllowlist[packId][wallet] = true;
        emit WalletAddedToAllowlist(packId, wallet);
    }

    function removeWalletFromAllowlist(uint256 packId, address wallet) external onlyOwner {
        simpleAllowlist[packId][wallet] = false;
        emit WalletRemovedFromAllowlist(packId, wallet);
    }

    function addMultipleToAllowlist(uint256 packId, address[] calldata wallets) external onlyOwner {
        require(wallets.length > 0, "Empty wallets array");
        require(wallets.length <= 100, "Too many wallets");
        
        for (uint256 i = 0; i < wallets.length; i++) {
            require(wallets[i] != address(0), "Invalid wallet address");
            simpleAllowlist[packId][wallets[i]] = true;
            emit WalletAddedToAllowlist(packId, wallets[i]);
        }
    }

    // =============== VIEW FUNCTIONS (COMPATIBLES - MANTENER INTACTAS) ===============
    
    function canPurchasePack(address user, uint256 packId, uint256 quantity, bool useAllowlist) external view returns (bool canPurchase, string memory reason) {
        PackConfig storage config = packConfigs[packId];
        if (!config.active) return (false, "Pack not active");
        if (config.minted + quantity > config.maxSupply) return (false, "Exceeds max supply");
        
        // Verificar timing
        if (config.startTime > 0 && block.timestamp < config.startTime) return (false, "Not started");
        if (config.endTime > 0 && block.timestamp > config.endTime) return (false, "Ended");
        
        if (useAllowlist) {
            if (!config.hasAllowlist) return (false, "Allowlist not enabled for this pack");
            if (!simpleAllowlist[packId][user]) return (false, "Not in allowlist");
            // Verificar límites allowlist
            uint256 userTotal = allowlistFreeClaimed[packId][user] + allowlistPaidClaimed[packId][user];
            if (config.maxPerWallet > 0 && userTotal + quantity > config.maxPerWallet) {
                return (false, "Exceeds allowlist limit");
            }
        } else {
            if (!config.hasPublicSale) return (false, "Public sale not enabled for this pack");
            // Verificar límites públicos
            if (config.maxPerWallet > 0) {
                uint256 userMinted = traitsCore.balanceOf(user, packId);
                if (userMinted + quantity > config.maxPerWallet) return (false, "Exceeds wallet limit");
            }
            if (config.publicPrice > 0 && paymentToken.balanceOf(user) < config.publicPrice * quantity) {
                return (false, "Insufficient balance");
            }
        }
        
        return (true, "Can purchase");
    }

    function canOpenPack(address user, uint256 packId) external view returns (bool canOpen, string memory reason) {
        PackConfig storage config = packConfigs[packId];
        if (!config.active) return (false, "Pack not active");
        if (traitsCore.balanceOf(user, packId) == 0) return (false, "No pack tokens");
        if (packAssets[packId].length == 0) return (false, "Pack has no contents");
        
        // Count available unique assets
        uint256 availableCount = 0;
        uint256[] storage assets = packAssets[packId];
        for (uint256 i = 0; i < assets.length; i++) {
            if (_getAvailableSupplySafe(assets[i]) > 0) {
                availableCount++;
            }
        }
        
        if (availableCount == 0) return (false, "No assets currently available");
        
        // Check if we have enough unique assets for full pack
        if (availableCount < config.itemsPerPack) {
            return (true, "Can open but will receive fewer items due to limited supply");
        }
        
        return (true, "Can open");
    }

    function getPackConfig(uint256 packId) external view returns (PackConfig memory) {
        return packConfigs[packId];
    }

    function getUserAllowlistStatus(address user, uint256 packId) external view returns (
        uint256 freeClaimed,
        uint256 paidClaimed,
        uint256 freeRemaining,
        uint256 totalAllowed,
        bool inAllowlist
    ) {
        PackConfig storage config = packConfigs[packId];
        
        freeClaimed = allowlistFreeClaimed[packId][user];
        paidClaimed = allowlistPaidClaimed[packId][user];
        freeRemaining = config.allowlistFreeAmount > freeClaimed ? 
            config.allowlistFreeAmount - freeClaimed : 0;
        totalAllowed = config.maxPerWallet;
        inAllowlist = simpleAllowlist[packId][user];
    }

    // =============== ✅ ULTRA-SIMPLE SUPPLY-WEIGHTED RANDOMNESS SYSTEM ===============
    
    /**
     * @dev Simple random generation with nonce
     * @param seed Additional seed for randomness
     * @return Generated random number
     */
    function _generateRandom(uint256 seed) private returns (uint256) {
        nonce++;
        return uint256(keccak256(abi.encodePacked(
            block.timestamp,     // Block time
            block.prevrandao,    // Primary entropy source (post-merge)
            msg.sender,          // User address
            nonce,              // Incremental nonce for uniqueness
            seed                // Additional seed
        )));
    }

    /**
     * @dev ✅ ULTRA-SIMPLE: Generates pack contents with selection without replacement
     * @param packId The pack ID to generate contents for
     * @return assetIds Array of asset IDs to mint
     * @return amounts Array of amounts for each asset
     */
    function _generatePackContents(uint256 packId) internal returns (uint256[] memory assetIds, uint256[] memory amounts) {
        PackConfig storage config = packConfigs[packId];
        uint256[] storage assets = packAssets[packId];
        
        require(assets.length > 0, "No pack contents configured");
        
        // ✅ STEP 1: Get available assets (respects max supply)
        uint256[] memory availableAssets = _getAvailableAssets(assets);
        require(availableAssets.length > 0, "No assets available in pack");
        
        // ✅ STEP 2: Determine how many items we can actually give
        uint256 itemsToSelect = config.itemsPerPack;
        if (itemsToSelect > availableAssets.length) {
            itemsToSelect = availableAssets.length; // Can't select more than available unique assets
        }
        
        assetIds = new uint256[](itemsToSelect);
        amounts = new uint256[](itemsToSelect);
        
        // ✅ STEP 3: Fisher-Yates shuffle for predictable gas usage
        // Work directly with availableAssets array
        for (uint256 i = 0; i < itemsToSelect; i++) {
            // Generate random index from remaining range
            uint256 randomIndex = i + (_generateRandom(i) % (availableAssets.length - i));
            
            // Select the asset at random index
            assetIds[i] = availableAssets[randomIndex];
            amounts[i] = 1;
            
            // Swap to remove from selectable range (Fisher-Yates)
            availableAssets[randomIndex] = availableAssets[i];
        }
        
        return (assetIds, amounts);
    }

    /**
     * @dev ✅ Get assets with available supply (called once per pack opening)
     * @param assets Array of all pack assets
     * @return availableAssets Array of assets that have supply > 0
     */
    function _getAvailableAssets(uint256[] storage assets) private view returns (uint256[] memory availableAssets) {
        // First pass: count available assets
        uint256 availableCount = 0;
        for (uint256 i = 0; i < assets.length; i++) {
            if (_getAvailableSupplySafe(assets[i]) > 0) {
                availableCount++;
            }
        }
        
        require(availableCount > 0, "No assets currently available");
        
        // Second pass: populate available assets array
        availableAssets = new uint256[](availableCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < assets.length; i++) {
            if (_getAvailableSupplySafe(assets[i]) > 0) {
                availableAssets[index] = assets[i];
                index++;
            }
        }
        
        return availableAssets;
    }

    // =============== ✅ BULLETPROOF HELPER FUNCTIONS ===============
    
    /**
     * @dev Safe wrapper for getAvailableSupply with try-catch
     * @param assetId Asset ID to check
     * @return available Available supply (0 if call fails)
     */
    function _getAvailableSupplySafe(uint256 assetId) private view returns (uint256) {
        try traitsCore.getAvailableSupply(assetId) returns (uint256 available) {
            return available;
        } catch {
            return 0; // If call fails, assume no supply available
            }
        }
        
    /**
     * @dev Safe wrapper for asset existence checking with try-catch
     * @param assetId Asset ID to check
     * @return exists True if asset exists (false if call fails)
     */
    function _assetExistsSafe(uint256 assetId) private view returns (bool) {
        try traitsCore.getAssetData(assetId) returns (AssetData memory asset) {
            return asset.maxSupply > 0; // Asset exists if has maxSupply configured
        } catch {
            return false; // If call fails, assume asset doesn't exist
        }
    }

    /**
     * @dev Verifica que el asset existe y es de tipo PACK
     * @param packId Asset ID to check
     * @return isValid True if asset exists and is of type PACK
     */
    function _isValidPack(uint256 packId) private view returns (bool) {
        try traitsCore.getAssetData(packId) returns (AssetData memory asset) {
            return asset.maxSupply > 0 && asset.assetType == 4; // 4 = AssetType.PACK
        } catch {
            return false; // If call fails, assume asset doesn't exist
        }
    }

    // =============== ✅ NUEVAS FUNCIONES DE VISTA PARA COMPATIBILIDAD Y DEBUGGING ===============
    
    /**
     * @dev Get pack assets (replaces getPackTraits functionality)
     * @param packId Pack ID to query
     * @return assets Array of asset IDs in pack
     */
    function getPackAssets(uint256 packId) external view returns (uint256[] memory) {
        return packAssets[packId];
    }

    /**
     * @dev Get count of assets in a pack (replaces getPackTraitsCount)
     * @param packId Pack ID to query
     * @return count Number of assets
     */
    function getPackAssetsCount(uint256 packId) external view returns (uint256) {
        return packAssets[packId].length;
    }

    /**
     * @dev Preview what a pack opening might contain (simplified for UX)
     * @param packId Pack ID to preview
     * @return previewAssets Possible asset IDs
     */
    function previewPackContents(uint256 packId) external view returns (uint256[] memory previewAssets) {
        return packAssets[packId]; // All assets in pack (equal probability, no duplicates possible)
    }

    // ✅ NUEVO: Treasury wallet getter for compatibility
    function getTreasuryWallet() external view returns (address) {
        return treasuryWallet;
    }
}