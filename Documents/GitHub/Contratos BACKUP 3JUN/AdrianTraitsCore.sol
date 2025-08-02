// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// Enums compartidos centralizados aquí
enum AssetType {
    VISUAL_TRAIT,
    INVENTORY_ITEM,
    CONSUMABLE,
    SERUM,
    PACK
}

enum SerumType {
    BASIC,
    DIRECTED,
    ADVANCED
}

/**
 * @title AdrianTraitsCore
 * @dev ERC1155 for traits, packs, serums, backgrounds and distribution
 */
contract AdrianTraitsCore is ERC1155, Ownable, ReentrancyGuard {
    using Strings for uint256;

    // =============== Type Definitions ===============
    
    // Rangos de IDs para traits y packs
    uint256 constant TRAIT_ID_MAX = 999_999;
    uint256 constant PACK_ID_MIN = 1_000_000;
    uint256 constant PACK_ID_MAX = 1_999_999;

    struct AssetInput {
        string name;
        string category;
        string ipfsPath;
        bool isTemporary;
        uint256 maxSupply;
        AssetType assetType;
        string metadata;
        uint256 weight;
    }

    struct AssetData {
        string name;
        string category;
        string ipfsPath;
        bool tempFlag;  // Renombrado para evitar conflicto con getter público
        uint256 maxSupply;
        AssetType assetType;
        string metadata;
    }

    struct SerumData {
        string targetMutation;
        uint256 potency;
        string metadata;
    }

    struct PackConfig {
        uint256 id;
        uint256 price;              // 0 = gratis
        uint256 maxSupply;
        uint256 minted;
        uint256 itemsPerPack;
        uint256 maxPerWallet;
        bool active;
        bool requiresAllowlist;
        bytes32 merkleRoot;
        string uri;
    }

    struct PackTrait {
        uint256 traitId;
        uint256 minAmount;          // Cantidad mínima garantizada
        uint256 maxAmount;          // Cantidad máxima posible
        uint256 chance;             // Probabilidad (0-10000 = 0-100%)
        uint256 remaining;          // Cuántos quedan en el pool
    }

    // =============== State Variables ===============
    
    // Contract references
    address public extensionsContract;
    address public coreContract;
    address public serumModule;
    string public baseMetadataURI;  // Nueva variable para URI base
    
    // Asset management
    mapping(uint256 => AssetData) public assets;
    mapping(uint256 => SerumData) public serums;
    mapping(uint256 => uint256) public totalMintedPerAsset;
    mapping(uint256 => uint256) public traitWeights;
    mapping(string => uint256) public totalTraitWeight;
    uint256 public nextAssetId = 1;
    
    // Categories
    string[] public categoryList;
    mapping(string => bool) public validCategories;
    
    // Packs system
    mapping(uint256 => PackConfig) public packConfigs;
    mapping(uint256 => PackTrait[]) public packTraits;
    mapping(address => mapping(uint256 => uint256)) public packsMintedPerWallet;
    mapping(address => mapping(uint256 => uint256)) public unclaimedPacks;
    mapping(bytes32 => uint256) public promoCodeToPack;
    mapping(bytes32 => uint256) public promoCodeUses;
    mapping(bytes32 => uint256) public promoCodeMaxUses;
    mapping(address => bool) public authorizedPackProviders;
    uint256 public nextPackId = 1;
    
    // Financial
    IERC20 public paymentToken;
    mapping(address => uint256) public pendingProceeds;
    address public treasuryWallet;
    
    // Serum IDs
    uint256 public constant BASIC_SERUM_ID = 10001;
    uint256 public constant DIRECTED_SERUM_ID = 10002;
    uint256 public constant ADVANCED_SERUM_ID = 10003;

    // Declarar los módulos autorizados
    address public mintModule;
    address public inventoryModule;

    // =============== Events ===============
    
    event AssetRegistered(uint256 indexed assetId, string name, string category, AssetType assetType);
    event SerumRegistered(uint256 indexed serumId, string targetMutation, uint256 potency);
    event AssetURIUpdated(uint256 indexed assetId, string newUri);
    event PackCreated(uint256 indexed packId, uint256 price, uint256 maxSupply, bool requiresAllowlist);
    event PackTraitAdded(uint256 indexed packId, uint256 traitId, uint256 minAmount, uint256 maxAmount, uint256 chance);
    event PackPurchased(address indexed buyer, uint256 packId, uint256 quantity);
    event PackOpened(address indexed user, uint256 packId, uint256[] traitIds, uint256[] amounts);
    event PackURIUpdated(uint256 indexed packId, string newUri);
    event PackAllowlistUpdated(uint256 indexed packId, bytes32 merkleRoot);
    event PromoCodeCreated(string code, uint256 packId, uint256 maxUses);
    event PromoCodeRedeemed(address indexed user, string code, uint256 packId);
    event PackProviderAuthorized(address indexed provider, bool status);
    event CustomPackMinted(address indexed provider, address indexed recipient, uint256[] traitIds, uint256[] amounts);
    event AssetMinted(uint256 indexed assetId, address indexed to, uint256 amount);
    event SerumUsed(address indexed user, uint256 tokenId, uint256 serumId);
    event ExtensionsContractUpdated(address newContract);
    event CoreContractUpdated(address newContract);
    event PaymentTokenUpdated(address newToken);
    event SerumModuleUpdated(address newModule);  // Nuevo evento para el módulo de serums

    // =============== Modifiers ===============
    
    modifier onlyExtensions() {
        require(msg.sender == extensionsContract, "!ext");
        _;
    }

    modifier onlyAuthorizedProvider() {
        require(authorizedPackProviders[msg.sender], "!provider");
        _;
    }

    modifier onlySerumModule() {
        require(msg.sender == serumModule, "!serum");
        _;
    }

    modifier validAsset(uint256 assetId) {
        require(assetId < nextAssetId && assetId > 0, "!asset");
        _;
    }

    // =============== Constructor ===============
    
    constructor(
        address _paymentToken,
        address _treasuryWallet
    ) ERC1155("AdrianLAB") Ownable(msg.sender) {
        paymentToken = IERC20(_paymentToken);
        treasuryWallet = _treasuryWallet;
        
        // Initialize categories
        categoryList = [
            "BACKGROUND",
            "BASE", 
            "BODY",
            "CLOTHING",
            "EYES",
            "MOUTH",
            "HEAD",
            "ACCESSORIES"
        ];
        
        for (uint256 i = 0; i < categoryList.length; i++) {
            validCategories[categoryList[i]] = true;
        }
    }

    // =============== Asset Management ===============
    
    /**
     * @dev Update asset URI (unified for all asset types)
     */
    function setAssetURI(uint256 assetId, string calldata newUri) external onlyOwner validAsset(assetId) {
        assets[assetId].ipfsPath = newUri;
        emit AssetURIUpdated(assetId, newUri);
    }
    
    /**
     * @dev Register a serum
     */
    function registerSerum(
        uint256 serumId,
        string calldata targetMutation,
        uint256 potency,
        string calldata name,
        string calldata metadata
    ) external onlyOwner {
        require(potency <= 100, "!potency");
        
        assets[serumId] = AssetData({
            name: name,
            category: "SERUM",
            ipfsPath: "",
            tempFlag: false,
            maxSupply: 0,
            assetType: AssetType.SERUM,
            metadata: metadata
        });
        
        serums[serumId] = SerumData({
            targetMutation: targetMutation,
            potency: potency,
            metadata: metadata
        });
        
        emit SerumRegistered(serumId, targetMutation, potency);
    }
    
    /**
     * @dev Update serum properties
     */
    function updateSerum(
        uint256 serumId,
        string calldata targetMutation,
        uint256 potency
    ) external onlyOwner {
        require(assets[serumId].assetType == AssetType.SERUM, "!serum");
        require(potency <= 100, "!potency");
        
        serums[serumId].targetMutation = targetMutation;
        serums[serumId].potency = potency;
        
        emit SerumRegistered(serumId, targetMutation, potency);
    }

    /**
     * @dev Mint assets (para uso administrativo general)
     */
    function mintAssets(
        address to,
        uint256 assetId,
        uint256 amount
    ) external onlyOwner validAsset(assetId) {
        require(address(extensionsContract) != address(0), "Extensions contract not set");
        
        // Validación de rangos de ID
        if (assets[assetId].assetType == AssetType.PACK) {
            require(assetId >= PACK_ID_MIN && assetId <= PACK_ID_MAX, "Pack ID out of range");
        } else {
            require(assetId <= TRAIT_ID_MAX, "Trait ID out of range");
        }
        
        AssetData storage asset = assets[assetId];
        
        if (asset.maxSupply > 0) {
            require(
                totalMintedPerAsset[assetId] + amount <= asset.maxSupply,
                "!supply"
            );
        }
        
        totalMintedPerAsset[assetId] += amount;
        _mint(to, assetId, amount, "");
        
        emit AssetMinted(assetId, to, amount);
    }

    /**
     * @dev Set base metadata URI
     */
    function setBaseMetadataURI(string calldata _baseURI) external onlyOwner {
        baseMetadataURI = _baseURI;
    }

    // =============== Pack System ===============
    
    /**
     * @dev Create a new pack (price 0 = free pack)
     */
    function createPack(
        uint256 packId,
        uint256 price,
        uint256 maxSupply,
        uint256 itemsPerPack,
        uint256 maxPerWallet,
        bool requiresAllowlist,
        string calldata packUri
    ) external onlyOwner {
        require(itemsPerPack > 0, "!items");
        
        packConfigs[packId] = PackConfig({
            id: packId,
            price: price,
            maxSupply: maxSupply,
            minted: 0,
            itemsPerPack: itemsPerPack,
            maxPerWallet: maxPerWallet,
            active: true,
            requiresAllowlist: requiresAllowlist,
            merkleRoot: bytes32(0),
            uri: packUri
        });
        
        if (packId >= nextPackId) {
            nextPackId = packId + 1;
        }
        
        emit PackCreated(packId, price, maxSupply, requiresAllowlist);
    }

    /**
     * @dev Add traits to pack (including serums)
     */
    function addPackTraits(
        uint256 packId,
        uint256[] calldata traitIds,
        uint256[] calldata minAmounts,
        uint256[] calldata maxAmounts,
        uint256[] calldata chances,
        uint256[] calldata poolAmounts
    ) external onlyOwner {
        require(packConfigs[packId].id == packId, "!pack");
        require(traitIds.length == minAmounts.length, "!length");
        require(traitIds.length == maxAmounts.length, "!length");
        require(traitIds.length == chances.length, "!length");
        require(traitIds.length == poolAmounts.length, "!length");
        
        // Clear existing traits if any
        delete packTraits[packId];
        
        for (uint256 i = 0; i < traitIds.length; i++) {
            require(minAmounts[i] <= maxAmounts[i], "!amounts");
            require(chances[i] <= 10000, "!chance");
            
            packTraits[packId].push(PackTrait({
                traitId: traitIds[i],
                minAmount: minAmounts[i],
                maxAmount: maxAmounts[i],
                chance: chances[i],
                remaining: poolAmounts[i]
            }));
            
            emit PackTraitAdded(packId, traitIds[i], minAmounts[i], maxAmounts[i], chances[i]);
        }
    }

    /**
     * @dev Set pack allowlist
     */
    function setPackAllowlist(uint256 packId, bytes32 merkleRoot) external onlyOwner {
        require(packConfigs[packId].id == packId, "!pack");
        packConfigs[packId].merkleRoot = merkleRoot;
        emit PackAllowlistUpdated(packId, merkleRoot);
    }

    /**
     * @dev Create promo code for a pack
     */
    function createPromoCode(
        string calldata code,
        uint256 packId,
        uint256 maxUses
    ) external onlyOwner {
        require(packConfigs[packId].id == packId, "!pack");
        bytes32 codeHash = keccak256(abi.encodePacked(code));
        
        promoCodeToPack[codeHash] = packId;
        promoCodeMaxUses[codeHash] = maxUses;
        promoCodeUses[codeHash] = 0;
        
        emit PromoCodeCreated(code, packId, maxUses);
    }

    /**
     * @dev Purchase or claim pack
     */
    function purchasePack(
        uint256 packId, 
        uint256 quantity,
        bytes32[] calldata merkleProof
    ) external nonReentrant {
        require(packId >= PACK_ID_MIN && packId <= PACK_ID_MAX, "Invalid pack ID range");
        
        PackConfig storage config = packConfigs[packId];
        require(config.active, "!active");
        require(config.minted + quantity <= config.maxSupply, "!supply");
        require(packTraits[packId].length > 0, "!traits");
        
        // Check wallet limit
        if (config.maxPerWallet > 0) {
            require(
                packsMintedPerWallet[msg.sender][packId] + quantity <= config.maxPerWallet,
                "!limit"
            );
        }
        
        // Check allowlist if required
        if (config.requiresAllowlist) {
            bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
            require(
                MerkleProof.verify(merkleProof, config.merkleRoot, leaf),
                "!allowlist"
            );
        }
        
        // Handle payment if not free
        if (config.price > 0) {
            uint256 totalCost = config.price * quantity;
            require(paymentToken.transferFrom(msg.sender, address(this), totalCost), "!pay");
            pendingProceeds[treasuryWallet] += totalCost;
        }
        
        config.minted += quantity;
        packsMintedPerWallet[msg.sender][packId] += quantity;
        unclaimedPacks[msg.sender][packId] += quantity;
        
        emit PackPurchased(msg.sender, packId, quantity);
    }

    /**
     * @dev Redeem with promo code (CORREGIDO - eliminado evento duplicado)
     */
    function redeemPromoCode(string calldata code) external nonReentrant {
        bytes32 codeHash = keccak256(abi.encodePacked(code));
        uint256 packId = promoCodeToPack[codeHash];
        require(packId > 0, "!code");
        require(promoCodeUses[codeHash] < promoCodeMaxUses[codeHash], "!uses");
        
        PackConfig storage config = packConfigs[packId];
        require(config.active, "!active");
        require(config.price == 0, "!free");
        require(config.minted < config.maxSupply, "!supply");
        
        // Check wallet limit
        if (config.maxPerWallet > 0) {
            require(
                packsMintedPerWallet[msg.sender][packId] < config.maxPerWallet,
                "!limit"
            );
        }
        
        promoCodeUses[codeHash]++;
        config.minted++;
        packsMintedPerWallet[msg.sender][packId]++;
        unclaimedPacks[msg.sender][packId]++;
        
        // SOLO evento de promo code - eliminado PackPurchased duplicado
        emit PromoCodeRedeemed(msg.sender, code, packId);
    }

    /**
     * @dev Open pack
     */
    function openPack(uint256 packId) external nonReentrant {
        require(packId >= PACK_ID_MIN && packId <= PACK_ID_MAX, "Invalid pack ID range");
        
        PackConfig storage config = packConfigs[packId];
        require(unclaimedPacks[msg.sender][packId] > 0, "!packs");
        require(config.active, "!active");
        
        unclaimedPacks[msg.sender][packId]--;
        
        // Get pack contents
        (uint256[] memory traitIds, uint256[] memory amounts) = _generatePackContents(packId);
        
        // Mint all items
        for (uint256 i = 0; i < traitIds.length; i++) {
            if (amounts[i] > 0) {
                _mint(msg.sender, traitIds[i], amounts[i], "");
                totalMintedPerAsset[traitIds[i]] += amounts[i];
                emit AssetMinted(traitIds[i], msg.sender, amounts[i]);
            }
        }
        
        emit PackOpened(msg.sender, packId, traitIds, amounts);
    }

    /**
     * @dev Update pack URI
     */
    function setPackURI(uint256 packId, string calldata newUri) external onlyOwner {
        require(packConfigs[packId].id == packId, "!pack");
        packConfigs[packId].uri = newUri;
        emit PackURIUpdated(packId, newUri);
    }

    /**
     * @dev Toggle pack active status
     */
    function setPackActive(uint256 packId, bool active) external onlyOwner {
        require(packConfigs[packId].id == packId, "!pack");
        packConfigs[packId].active = active;
    }
    
    /**
     * @dev Replenish trait pool for a pack
     */
    function replenishPackPool(
        uint256 packId,
        uint256[] calldata traitIds,
        uint256[] calldata amounts
    ) external onlyOwner {
        require(packConfigs[packId].id == packId, "!pack");
        require(traitIds.length == amounts.length, "!length");
        
        PackTrait[] storage traits = packTraits[packId];
        
        for (uint256 i = 0; i < traitIds.length; i++) {
            bool found = false;
            for (uint256 j = 0; j < traits.length; j++) {
                if (traits[j].traitId == traitIds[i]) {
                    traits[j].remaining += amounts[i];
                    found = true;
                    break;
                }
            }
            require(found, "!trait in pack");
        }
    }

    /**
     * @dev Authorize pack provider
     */
    function setPackProvider(address provider, bool authorized) external onlyOwner {
        authorizedPackProviders[provider] = authorized;
        emit PackProviderAuthorized(provider, authorized);
    }

    /**
     * @dev Create custom pack (para contratos externos autorizados)
     * MANTENIDO SEPARADO de mintAssets porque tiene propósito específico
     */
    function createCustomPack(
        address recipient,
        uint256[] calldata traitIds,
        uint256[] calldata amounts
    ) external onlyAuthorizedProvider nonReentrant {
        require(traitIds.length == amounts.length, "!length");
        
        for (uint256 i = 0; i < traitIds.length; i++) {
            uint256 traitId = traitIds[i];
            uint256 amount = amounts[i];
            require(traitId < nextAssetId, "!trait");
            
            if (assets[traitId].maxSupply > 0) {
                require(
                    totalMintedPerAsset[traitId] + amount <= assets[traitId].maxSupply,
                    "!supply"
                );
            }
            
            totalMintedPerAsset[traitId] += amount;
            _mint(recipient, traitId, amount, "");
        }
        
        emit CustomPackMinted(msg.sender, recipient, traitIds, amounts);
    }

    // =============== Serum System ===============
    
    /**
     * @dev Use serum on BareAdrian
     */
    function useSerum(uint256 serumId, uint256 tokenId) external nonReentrant {
        require(balanceOf(msg.sender, serumId) > 0, "!serum");
        require(assets[serumId].assetType == AssetType.SERUM, "!type");
        
        _burn(msg.sender, serumId, 1);
        
        bool success = IAdrianLabExtensions(extensionsContract).applySerumFromTraits(
            msg.sender,
            tokenId, 
            serumId
        );
        require(success, "!apply");
        
        emit SerumUsed(msg.sender, tokenId, serumId);
    }

    // =============== View Functions ===============
    
    /**
     * @dev Verifica si un ID corresponde a un trait
     */
    function isTrait(uint256 id) public pure returns (bool) {
        return id > 0 && id <= TRAIT_ID_MAX;
    }

    /**
     * @dev Verifica si un ID corresponde a un pack
     */
    function isPack(uint256 id) public pure returns (bool) {
        return id >= PACK_ID_MIN && id <= PACK_ID_MAX;
    }
    
    /**
     * @dev Get trait info (for Extensions compatibility)
     */
    function getTraitInfo(uint256 assetId) external view returns (string memory category, bool isTemp) {
        AssetData storage asset = assets[assetId];
        return (asset.category, asset.tempFlag);
    }

    /**
     * @dev Get category
     */
    function getCategory(uint256 assetId) external view returns (string memory) {
        return assets[assetId].category;
    }

    /**
     * @dev Get name
     */
    function getName(uint256 assetId) external view returns (string memory) {
        return assets[assetId].name;
    }

    /**
     * @dev Is temporary
     */
    function isTemporary(uint256 assetId) external view returns (bool) {
        return assets[assetId].tempFlag;
    }

    /**
     * @dev Get serum data
     */
    function getSerumData(uint256 serumId) external view returns (
        string memory targetMutation,
        uint256 potency
    ) {
        SerumData storage serum = serums[serumId];
        return (serum.targetMutation, serum.potency);
    }

    /**
     * @dev Get pack info
     */
    function getPackInfo(uint256 packId) external view returns (
        uint256 price,
        uint256 maxSupply,
        uint256 minted,
        uint256 itemsPerPack,
        uint256 maxPerWallet,
        bool active,
        bool requiresAllowlist,
        string memory packUri
    ) {
        PackConfig storage config = packConfigs[packId];
        return (
            config.price,
            config.maxSupply,
            config.minted,
            config.itemsPerPack,
            config.maxPerWallet,
            config.active,
            config.requiresAllowlist,
            config.uri
        );
    }

    /**
     * @dev Obtiene la longitud del array de traits de un pack
     */
    function packTraitsLength(uint256 packId) external view returns (uint256) {
        return packTraits[packId].length;
    }

    /**
     * @dev Obtiene la información de un trait específico en un pack
     */
    function getPackTraitInfo(uint256 packId, uint256 index) external view returns (
        uint256 traitId,
        uint256 minAmount,
        uint256 maxAmount,
        uint256 chance,
        uint256 remaining
    ) {
        PackTrait storage trait = packTraits[packId][index];
        return (
            trait.traitId,
            trait.minAmount,
            trait.maxAmount,
            trait.chance,
            trait.remaining
        );
    }

    // =============== Admin Functions ===============
    
    /**
     * @dev Set extensions contract
     */
    function setExtensionsContract(address _extensionsContract) external onlyOwner {
        extensionsContract = _extensionsContract;
        emit ExtensionsContractUpdated(_extensionsContract);
    }

    /**
     * @dev Set core contract
     */
    function setCoreContract(address _coreContract) external onlyOwner {
        coreContract = _coreContract;
        emit CoreContractUpdated(_coreContract);
    }

    /**
     * @dev Set payment token
     */
    function setPaymentToken(address _paymentToken) external onlyOwner {
        paymentToken = IERC20(_paymentToken);
        emit PaymentTokenUpdated(_paymentToken);
    }

    /**
     * @dev Withdraw proceeds
     */
    function withdrawProceeds() external onlyOwner {
        uint256 amount = pendingProceeds[treasuryWallet];
        require(amount > 0, "!funds");
        
        pendingProceeds[treasuryWallet] = 0;
        require(paymentToken.transfer(treasuryWallet, amount), "!transfer");
    }

    /**
     * @dev Set serum module
     */
    function setSerumModule(address _module) external onlyOwner {
        serumModule = _module;
        emit SerumModuleUpdated(_module);
    }

    /**
     * @dev Set mint module
     */
    function setMintModule(address _m) external onlyOwner {
        require(_m != address(0) && _m.code.length > 0, "Invalid");
        mintModule = _m;
    }

    /**
     * @dev Set inventory module
     */
    function setInventoryModule(address _m) external onlyOwner {
        require(_m != address(0) && _m.code.length > 0, "Invalid");
        inventoryModule = _m;
    }

    /**
     * @dev Reescribir mint para delegación externa
     */
    function mint(address to, uint256 id, uint256 amount) external {
        require(msg.sender == mintModule || msg.sender == owner(), "Not allowed");
        _mint(to, id, amount, "");
    }

    /**
     * @dev Reescribir burn para control externo
     */
    function burn(address from, uint256 id, uint256 amount) external {
        require(msg.sender == inventoryModule || msg.sender == owner(), "Not allowed");
        _burn(from, id, amount);
    }

    // =============== Internal Functions ===============
    
    /**
     * @dev Generate pack contents based on configuration
     */
    function _generatePackContents(uint256 packId) internal returns (
        uint256[] memory traitIds,
        uint256[] memory amounts
    ) {
        PackConfig storage config = packConfigs[packId];
        PackTrait[] storage traits = packTraits[packId];
        
        // Arrays temporales para almacenar selecciones
        uint256[] memory selectedTraitIds = new uint256[](config.itemsPerPack);
        uint256[] memory selectedAmounts = new uint256[](config.itemsPerPack);
        uint256 actualItemCount = 0;
        
        // Primero, agregar cantidades mínimas garantizadas
        for (uint256 i = 0; i < traits.length; i++) {
            if (traits[i].minAmount > 0 && traits[i].remaining >= traits[i].minAmount) {
                // Verificar si ya tenemos espacio
                if (actualItemCount + traits[i].minAmount <= config.itemsPerPack) {
                    selectedTraitIds[actualItemCount] = traits[i].traitId;
                    selectedAmounts[actualItemCount] = traits[i].minAmount;
                    actualItemCount++;
                }
            }
        }
        
        // Llenar los slots restantes aleatoriamente
        uint256 attemptsPerSlot = 10;
        
        while (actualItemCount < config.itemsPerPack) {
            bool slotFilled = false;
            
            for (uint256 attempt = 0; attempt < attemptsPerSlot && !slotFilled; attempt++) {
                // Generar índice aleatorio ponderado
                uint256 randomValue = _random(actualItemCount * 1000 + attempt) % 10000;
                
                for (uint256 i = 0; i < traits.length; i++) {
                    if (randomValue < traits[i].chance && traits[i].remaining > 0) {
                        // Verificar si ya seleccionamos este trait
                        uint256 existingIndex = type(uint256).max;
                        uint256 currentAmount = 0;
                        
                        for (uint256 j = 0; j < actualItemCount; j++) {
                            if (selectedTraitIds[j] == traits[i].traitId) {
                                existingIndex = j;
                                currentAmount = selectedAmounts[j];
                                break;
                            }
                        }
                        
                        // Si no existe o podemos agregar más
                        if (existingIndex == type(uint256).max) {
                            // Nuevo trait
                            selectedTraitIds[actualItemCount] = traits[i].traitId;
                            selectedAmounts[actualItemCount] = 1;
                            actualItemCount++;
                            slotFilled = true;
                        } else if (currentAmount < traits[i].maxAmount) {
                            // Incrementar cantidad existente
                            selectedAmounts[existingIndex]++;
                            slotFilled = true;
                        }
                        
                        break;
                    }
                }
            }
            
            // Si no se pudo llenar el slot después de todos los intentos, salir
            if (!slotFilled) {
                break;
            }
        }
        
        // Crear arrays finales con el tamaño correcto
        traitIds = new uint256[](actualItemCount);
        amounts = new uint256[](actualItemCount);
        
        // Transferir datos y actualizar pools
        for (uint256 i = 0; i < actualItemCount; i++) {
            uint256 traitId = selectedTraitIds[i];
            uint256 amount = selectedAmounts[i];
            
            // Encontrar el trait en el array
            for (uint256 j = 0; j < traits.length; j++) {
                if (traits[j].traitId == traitId) {
                    // Asegurar que no excedemos lo disponible
                    if (amount > traits[j].remaining) {
                        amount = traits[j].remaining;
                    }
                    
                    traitIds[i] = traitId;
                    amounts[i] = amount;
                    traits[j].remaining -= amount;
                    break;
                }
            }
        }
        
        return (traitIds, amounts);
    }

    /**
     * @dev Enhanced random function with better distribution
     */
    function _random(uint256 seed) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.prevrandao,
            msg.sender,
            seed,
            block.number,
            gasleft()
        )));
    }

    /**
     * @dev Override URI to use dynamic JSON
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        if (extensionsContract != address(0)) {
            return IAdrianTraitsExtensions(extensionsContract).getAssetURI(tokenId);
        }
        
        return string(abi.encodePacked(baseMetadataURI, tokenId.toString(), ".json"));
    }

    // Función para obtener el balance de un trait (override correcto)
    function balanceOf(address account, uint256 id) public view override returns (uint256) {
        return super.balanceOf(account, id);
    }

    function balanceOfBatch(address[] memory accounts, uint256[] memory ids) public view override returns (uint256[] memory) {
        return super.balanceOfBatch(accounts, ids);
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) public override {
        super.safeTransferFrom(from, to, id, amount, data);
    }

    function safeBatchTransferFrom(address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public override {
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }
}

// =============== Interfaces ===============

interface IAdrianLabExtensions {
    function applySerumFromTraits(address user, uint256 tokenId, uint256 serumId) external returns (bool);
}

interface IAdrianTraitsExtensions {
    function getAssetURI(uint256 tokenId) external view returns (string memory);
}

// =============== Interfaces ===============
interface IAdrianTraitsCore {
    struct AssetData {
        string name;
        string category;
        string ipfsPath;
        bool isTemporary;
        uint256 maxSupply;
    }

    function getAssetData(uint256 assetId) external view returns (AssetData memory);
    function burn(address from, uint256 id, uint256 amount) external;
}