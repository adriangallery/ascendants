// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


// ✅ CONSTANTS DIRECTAMENTE EN EL ARCHIVO
uint256 constant TRAIT_ID_MAX = 99_999;
uint256 constant PACK_ID_MIN = 100_000;
uint256 constant PACK_ID_MAX = 109_999;
uint256 constant SERUM_ID_MIN = 110_000;

// ✅ ENUM DIRECTAMENTE EN EL ARCHIVO
    enum AssetType {
        VISUAL_TRAIT,
        INVENTORY_ITEM,
        CONSUMABLE,
        SERUM,
        PACK
    }

// ✅ LIBRARY DIRECTAMENTE EN EL ARCHIVO
library SimpleValidation {
    function isTraitAsset(uint256 id) internal pure returns (bool) {
        return id > 0 && id <= TRAIT_ID_MAX;
    }
    
    function isPackAsset(uint256 id) internal pure returns (bool) {
        return id >= PACK_ID_MIN && id <= PACK_ID_MAX;
    }
    
    function isValidForEquipping(uint256 id) internal pure returns (bool) {
        return isTraitAsset(id);
    }
}

// =============== INTERFACES ===============

interface IAdrianTraitsCore is IERC1155 {
    // ✅ FUNCIONES BÁSICAS DE ASSETS
    function getName(uint256 assetId) external view returns (string memory);
    function getCategory(uint256 assetId) external view returns (string memory);
    function getTraitInfo(uint256 assetId) external view returns (string memory category, bool isTemp);
    function getCategoryList() external view returns (string[] memory);
    
    // ✅ FUNCIONES DE VALIDACIÓN DE IDs
    function isValidTraitId(uint256 id) external pure returns (bool);
    function isValidPackId(uint256 id) external pure returns (bool);
    function isValidSerumId(uint256 id) external pure returns (bool);
    
    // ✅ FUNCIONES DE SUPPLY Y DISPONIBILIDAD
    function getAvailableSupply(uint256 assetId) external view returns (uint256);
    function getTotalMinted(uint256 assetId) external view returns (uint256);
    
    // ✅ FUNCIONES DE MINT/BURN
    function burn(address from, uint256 id, uint256 amount) external;
    function mintFromExtension(address to, uint256 traitId, uint256 amount) external;
    function burnFromExtension(address from, uint256 id, uint256 amount) external;
    
    // ✅ FUNCIONES DE PACK
    function getPackInfo(uint256 packId) external view returns (uint256 price, uint256 maxSupply, uint256 minted, uint256 itemsPerPack, uint256 maxPerWallet, bool active, bool requiresAllowlist);
    function getUnclaimedPacks(address user, uint256 packId) external view returns (uint256);
    function getPacksMintedPerWallet(address user, uint256 packId) external view returns (uint256);
    function updatePackMinted(uint256 packId, uint256 amount) external;
    function updatePacksMintedPerWallet(address user, uint256 packId, uint256 amount) external;
    function setUnclaimedPacks(address user, uint256 packId, uint256 amount) external;
    function reduceUnclaimedPacks(address user, uint256 packId, uint256 amount) external;
    
    // ✅ FUNCIONES DE REGISTRO DE ASSETS
    function registerAssetFromExtension(uint256 assetId, uint8 categoryId, uint256 maxSupply, AssetType assetType) external;
    
    // ✅ FUNCIONES DE EXTENSIONES
    function addExtension(address extension) external;
    function removeExtension(address extension) external;
    function authorizedExtensions(address extension) external view returns (bool);
    
    // ✅ FUNCIONES DE CATEGORÍAS
    function validCategories(string memory category) external view returns (bool);
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

interface IAdrianLab {
    function ownerOf(uint256 tokenId) external view returns (address);
}

interface IAdrianLabCore {
    function setExtensionsContract(address _extensions) external;
}

/**
 * @title AdrianTraitsExtensions
 * @dev SIMPLIFIED traits system for AdrianLab - FASE 2+ OPTIMIZED
 */
contract AdrianTraitsExtensions is Ownable, ReentrancyGuard {
    using SimpleValidation for uint256;
    using Strings for uint256;

    // =============== State Variables ===============
    
    address public adrianTraitsCoreContract;
    address public adrianLabCoreContract;
    IAdrianTraitsCore public immutable traitsCore;
    IAdrianHistory public historyContract;
    address public treasury;
    
    // Allowlist system (BASIC)
    mapping(uint256 => bytes32) public allowlistMerkleRoots;
    mapping(address => mapping(uint256 => bool)) public allowlistClaimed;
    
    // Token trait management (BASIC)
    mapping(uint256 => mapping(string => uint256)) public equippedTrait;
    mapping(uint256 => string[]) public tokenCategories;
    mapping(uint256 => mapping(string => bool)) public tokenHasCategory;
    
    // Token inventories (BASIC - most functionality in AdrianInventoryModule)
    mapping(uint256 => mapping(uint256 => uint256[])) public tokenInventory;
    
    // Emergency
    bool public emergencyMode = false;
    mapping(bytes4 => bool) public pausedFunctions;

    IERC20 public paymentToken;

    // Progressive pricing system
    struct ProgressivePricing {
        uint256 basePrice;
        uint256 priceIncrement;
        uint256 tierSize;
        bool enabled;
    }
    mapping(uint256 => ProgressivePricing) public progressivePricing;

    // Simple trait info (only what's needed)
    struct TraitInfo {
        string name;
        string category;
        uint256 maxSupply;
        bool isPack;
    }

    struct TraitSaleConfig {
        uint256 price;
        bool available;
        uint256 startTime;
        uint256 endTime;
        bytes32 whitelistRoot;
    }

    mapping(uint256 => TraitInfo) public traitInfo;
    mapping(uint256 => uint256) public traitSupply;
    mapping(uint256 => TraitSaleConfig) public traitSaleConfig;
    mapping(uint256 => uint256[]) public packContents;

    // =============== Events ===============
    
    event AllowlistUpdated(uint256 indexed allowlistId, bytes32 merkleRoot);
    event AllowlistPackClaimed(address indexed user, uint256 allowlistId, uint256 packId);
    event TraitEquipped(uint256 indexed tokenId, string category, uint256 traitId);
    event TraitUnequipped(uint256 indexed tokenId, string category, uint256 traitId);
    event TraitMinted(address indexed to, uint256 indexed traitId, uint256 amount);
    event PackMinted(address indexed to, uint256 indexed packId);
    event TraitCreated(uint256 indexed traitId, string name, string category, uint256 maxSupply);
    event PackCreated(uint256 indexed packId, uint256[] contents);
    event PackOpenedWithExtensions(address indexed user, uint256 indexed packId);

    // =============== Modifiers ===============
    
    modifier onlyTraitsCore() {
        require(msg.sender == adrianTraitsCoreContract, "Only traits core");
        _;
    }

    modifier notPaused(bytes4 selector) {
        require(!emergencyMode || !pausedFunctions[selector], "Function paused");
        _;
    }

    modifier onlyTokenOwner(uint256 tokenId) {
        require(IAdrianLab(adrianLabCoreContract).ownerOf(tokenId) == msg.sender, "Not token owner");
        _;
    }

    // =============== Constructor ===============
    
    constructor(address _traitsCore) Ownable(msg.sender) {
        traitsCore = IAdrianTraitsCore(_traitsCore);
    }

    /**
     * @dev Verifica si el módulo está autorizado como extensión
     * @return bool Si está autorizado
     */
    function isAuthorizedExtension() external view returns (bool) {
        if (address(traitsCore) == address(0)) {
            return false;
        }
        
        try traitsCore.authorizedExtensions(address(this)) returns (bool authorized) {
            return authorized;
        } catch {
            return false;
        }
    }

    /**
     * @dev Función de diagnóstico para verificar configuración
     */
    function getConfigurationStatus() external view returns (
        bool traitsCoreSet,
        bool labCoreSet,
        bool isAuthorized,
        string memory status
    ) {
        traitsCoreSet = address(traitsCore) != address(0);
        labCoreSet = adrianLabCoreContract != address(0);
        
        if (!traitsCoreSet) {
            return (false, labCoreSet, false, "TraitsCore not configured");
        }
        
        if (!labCoreSet) {
            return (traitsCoreSet, false, false, "LabCore not configured");  
        }
        
        try traitsCore.authorizedExtensions(address(this)) returns (bool authorized) {
            isAuthorized = authorized;
            status = authorized ? "Fully configured and authorized" : "Not authorized as extension";
        } catch {
            isAuthorized = false;
            status = "Error checking authorization";
        }
        
        return (traitsCoreSet, labCoreSet, isAuthorized, status);
    }

    /**
     * @dev Función helper para configuración manual
     * @notice El owner debe llamar traitsCore.addExtension(address(this)) directamente
     */
    function getRequiredManualSetup() external pure returns (string memory) {
        return "Owner must call: traitsCore.addExtension(address(this))";
    }

    // =============== Allowlist System ===============
    
    function setAllowlistMerkleRoot(uint256 allowlistId, bytes32 merkleRoot) external onlyOwner {
        allowlistMerkleRoots[allowlistId] = merkleRoot;
    }

    function claimAllowlistPack(
        uint256 packId,
        uint256 allowlistId,
        bytes32[] calldata merkleProof
    ) external nonReentrant {
        require(!allowlistClaimed[msg.sender][allowlistId], "Already claimed");
        require(packId.isPackAsset(), "Invalid pack ID");
        
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(
            MerkleProof.verify(merkleProof, allowlistMerkleRoots[allowlistId], leaf),
            "Invalid proof"
        );
        
        allowlistClaimed[msg.sender][allowlistId] = true;
        
        emit AllowlistPackClaimed(msg.sender, allowlistId, packId);
    }

    // =============== Trait Management ===============

    function equipTrait(uint256 tokenId, uint256 traitId) external onlyTokenOwner(tokenId) nonReentrant {
        require(traitId.isValidForEquipping(), "Invalid trait for equipping");
        
        // ✅ VERIFICACIÓN EXPLÍCITA DE DISPONIBILIDAD
        uint256 userBalance = traitsCore.balanceOf(msg.sender, traitId);
        if (userBalance == 0) {
            revert("No trait tokens to equip");
        }
        
        string memory category = traitsCore.getCategory(traitId);
        require(traitsCore.validCategories(category), "Invalid category");
        
        // Unequip current trait in this category if any
        uint256 currentTrait = equippedTrait[tokenId][category];
        if (currentTrait != 0) {
            equippedTrait[tokenId][category] = 0;
        }
        
        // Equip new trait
        equippedTrait[tokenId][category] = traitId;
        
        // Track categories for this token
        if (!tokenHasCategory[tokenId][category]) {
            tokenCategories[tokenId].push(category);
            tokenHasCategory[tokenId][category] = true;
        }
        
        emit TraitEquipped(tokenId, category, traitId);
        
        // Record in history if available
        if (address(historyContract) != address(0)) {
            try historyContract.recordEvent(
                tokenId,
                keccak256("TRAIT_EQUIPPED"),
                msg.sender,
                abi.encode(traitId, category),
                block.number
            ) {} catch {}
        }
    }

    function unequipTrait(uint256 tokenId, string calldata category) external onlyTokenOwner(tokenId) nonReentrant {
        uint256 currentTrait = equippedTrait[tokenId][category];
        require(currentTrait != 0, "No trait equipped in this category");
        
        equippedTrait[tokenId][category] = 0;
        emit TraitUnequipped(tokenId, category, currentTrait);
        
        // Record in history if available
        if (address(historyContract) != address(0)) {
            try historyContract.recordEvent(
                tokenId,
                keccak256("TRAIT_UNEQUIPPED"),
                msg.sender,
                abi.encode(currentTrait, category),
                block.number
            ) {} catch {}
        }
    }

    // =============== Inventory Management ===============

    function addAssetToInventory(uint256 tokenId, uint256 assetId, uint256 amount) external onlyTokenOwner(tokenId) nonReentrant {
        require(amount > 0, "Invalid amount");
        
        // ✅ CORREGIDO: Actualizar inventario ANTES de la transferencia
        for (uint256 i = 0; i < amount; i++) {
            tokenInventory[tokenId][assetId].push(block.timestamp);
        }

        // ✅ CORREGIDO: Transferir DESPUÉS de actualizar inventario
        // safeTransferFrom ya verifica el balance automáticamente
        IERC1155(adrianTraitsCoreContract).safeTransferFrom(
            msg.sender,
            address(this),
            assetId,
            amount,
            ""
        );
    }

    function removeAssetFromInventory(uint256 tokenId, uint256 assetId, uint256 amount) external onlyTokenOwner(tokenId) nonReentrant {
        require(amount > 0, "Invalid amount");
        
        // ✅ VERIFICACIÓN EXPLÍCITA DE DISPONIBILIDAD EN INVENTARIO
        uint256 inventoryBalance = tokenInventory[tokenId][assetId].length;
        if (inventoryBalance < amount) {
            revert("Insufficient inventory balance");
        }

        // Remove from inventory
        for (uint256 i = 0; i < amount; i++) {
            tokenInventory[tokenId][assetId].pop();
        }

        IERC1155(adrianTraitsCoreContract).safeTransferFrom(
            address(this),
            msg.sender,
            assetId,
            amount,
            ""
        );
    }

    // =============== Progressive Pricing ===============

    function setProgressivePricing(
        uint256 assetId,
        uint256 basePrice,
        uint256 priceIncrement,
        uint256 tierSize,
        bool enabled
    ) external onlyOwner {
        progressivePricing[assetId] = ProgressivePricing({
            basePrice: basePrice,
            priceIncrement: priceIncrement,
            tierSize: tierSize,
            enabled: enabled
        });
    }

    function getProgressivePrice(uint256 assetId, uint256 currentSupply) public view returns (uint256) {
        ProgressivePricing memory pricing = progressivePricing[assetId];
        
        if (!pricing.enabled || pricing.tierSize == 0) {
            return traitSaleConfig[assetId].price;
        }
        
        uint256 tier = currentSupply / pricing.tierSize;
        return pricing.basePrice + (tier * pricing.priceIncrement);
    }

    // =============== Admin Functions ===============

    function createTrait(
        uint256 traitId,
        uint8 categoryId,
        uint256 maxSupply
    ) external onlyOwner {
        require(traitId.isTraitAsset(), "Invalid trait ID");
        require(traitInfo[traitId].maxSupply == 0, "Already exists");

        // ✅ CORREGIDO: Validación dinámica usando getCategoryList
        string[] memory categories = traitsCore.getCategoryList();
        require(categoryId < categories.length, "Invalid category ID");

        // Registrar en Core
        traitsCore.registerAssetFromExtension(traitId, categoryId, maxSupply, AssetType.VISUAL_TRAIT);
        
        // Registrar localmente para tracking
        string memory category = categories[categoryId];
        
        traitInfo[traitId] = TraitInfo({
            name: string(abi.encodePacked("Asset #", traitId.toString())),
            category: category,
            maxSupply: maxSupply,
            isPack: false
        });

        emit TraitCreated(traitId, string(abi.encodePacked("Asset #", traitId.toString())), category, maxSupply);
    }

    // NUEVA función para ser llamada desde Core
    function createTraitFromCore(
        uint256 traitId,
        uint8 categoryId,
        uint256 maxSupply
    ) external {
        require(msg.sender == address(traitsCore), "Only traits core");
        require(traitId.isTraitAsset(), "Invalid trait ID");
        require(traitInfo[traitId].maxSupply == 0, "Already exists");
        
        // ✅ CORREGIDO: Validación dinámica usando getCategoryList
        string[] memory categories = traitsCore.getCategoryList();
        require(categoryId < categories.length, "Invalid category ID");
        
        string memory category = categories[categoryId];

        traitInfo[traitId] = TraitInfo({
            name: string(abi.encodePacked("Asset #", traitId.toString())),
            category: category,
            maxSupply: maxSupply,
            isPack: false
        });

        emit TraitCreated(traitId, string(abi.encodePacked("Asset #", traitId.toString())), category, maxSupply);
    }

    function createPack(
        uint256 packId,
        uint256[] calldata contents
    ) external onlyOwner {
        require(packId.isPackAsset(), "Invalid pack ID");
        require(contents.length > 0, "Empty pack");
        require(traitInfo[packId].maxSupply == 0, "Already exists");

        for (uint256 i = 0; i < contents.length; i++) {
            require(contents[i].isTraitAsset(), "Invalid content");
        }

        packContents[packId] = contents;

        traitInfo[packId] = TraitInfo({
            name: "Pack",
            category: "Packs",
            maxSupply: type(uint256).max,
            isPack: true
        });

        emit PackCreated(packId, contents);
    }

    function setTraitSaleConfig(
        uint256 traitId,
        uint256 price,
        bool available,
        uint256 startTime,
        uint256 endTime,
        bytes32 whitelistRoot
    ) external onlyOwner {
        traitSaleConfig[traitId] = TraitSaleConfig({
            price: price,
            available: available,
            startTime: startTime,
            endTime: endTime,
            whitelistRoot: whitelistRoot
        });
    }

    // =============== View Functions ===============
    
    function getRemainingSupply(uint256 traitId) external view returns (uint256) {
        return traitInfo[traitId].maxSupply - traitSupply[traitId];
    }

    /**
     * @dev ✅ NUEVA FUNCIÓN: Verificación explícita de disponibilidad
     */
    function isTraitAvailable(uint256 traitId, uint256 requiredAmount) external view returns (bool available, string memory reason) {
        // Verificar si es un trait válido
        if (!traitId.isTraitAsset()) {
            return (false, "Invalid trait ID");
        }
        
        // Verificar si el trait existe
        if (traitInfo[traitId].maxSupply == 0) {
            return (false, "Trait does not exist");
        }
        
        // Verificar disponibilidad en el supply total
        uint256 available_supply = traitsCore.getAvailableSupply(traitId);
        if (available_supply < requiredAmount) {
            return (false, "Insufficient global supply");
        }
        
        return (true, "Trait available");
    }

    /**
     * @dev ✅ NUEVA FUNCIÓN: Verificación de disponibilidad para usuario específico
     */
    function canUserAccessTrait(address user, uint256 traitId, uint256 requiredAmount) external view returns (bool canAccess, string memory reason) {
        // Verificar disponibilidad general primero
        (bool available, string memory availabilityReason) = this.isTraitAvailable(traitId, requiredAmount);
        if (!available) {
            return (false, availabilityReason);
        }
        
        // Verificar balance del usuario
        uint256 userBalance = traitsCore.balanceOf(user, traitId);
        if (userBalance < requiredAmount) {
            return (false, "Insufficient user balance");
        }
        
        return (true, "User can access trait");
    }

    function getPackContents(uint256 packId) external view returns (uint256[] memory) {
        require(packId.isPackAsset(), "Invalid pack ID");
        require(traitInfo[packId].isPack, "Not a pack");
        return packContents[packId];
    }

    function getCategories() public view returns (string[] memory) {
        return traitsCore.getCategoryList();
    }

    function getTrait(uint256 tokenId, string memory category) public view returns (uint256) {
        return equippedTrait[tokenId][category];
    }

    // =============== Contract Management ===============

    function setAdrianTraitsCoreContract(address _contract) external onlyOwner {
        require(_contract != address(0), "Invalid address");
        adrianTraitsCoreContract = _contract;
    }

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

    function setHistoryContract(address _historyContract) external onlyOwner {
        require(_historyContract != address(0), "Invalid address");
        historyContract = IAdrianHistory(_historyContract);
    }

    function setEmergencyMode(bool enabled) external onlyOwner {
        emergencyMode = enabled;
    }

    function setFunctionPaused(bytes4 functionSelector, bool paused) external onlyOwner {
        pausedFunctions[functionSelector] = paused;
    }

    // =============== ERC1155 Receiver Functions ===============
    
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

    // =============== Legacy Support ===============

    // Añadir función para sincronizar con core cuando se mintea
    function notifyTraitMinted(uint256 traitId, uint256 amount) external {
        require(msg.sender == address(traitsCore), "Only traits core");
        traitSupply[traitId] += amount;
    }
}