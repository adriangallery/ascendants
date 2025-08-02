// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// =============== STRUCTS & ENUMS ===============
enum AssetType {
    VISUAL_TRAIT,    // 0
    INVENTORY_ITEM,  // 1
    CONSUMABLE,      // 2
    SERUM,           // 3
    PACK             // 4
}

struct AssetData {
    string category;
    bool tempFlag;
    uint256 maxSupply;
    AssetType assetType;
}

/**
 * @title AdrianTraitsCore
 * @dev ERC1155 core contract for traits, packs, serums and other assets
 */
contract AdrianTraitsCore is ERC1155, Ownable, ReentrancyGuard {
    using Strings for uint256;

    // =============== STATE VARIABLES ===============
    
    // Asset management
    mapping(uint256 => AssetData) public assets;
    mapping(uint256 => uint256) public totalMintedPerAsset;
    uint256 public nextAssetId = 1;

    // Categories
    string[] public categoryList;
    mapping(string => bool) public validCategories;

    // AssetTypes - Lista de nombres para display
    string[] public assetTypeNames;

    // Financial
    IERC20 public paymentToken;
    address public treasury;
    
    // =============== URI SYSTEM VARIABLES ===============
    // Sistema híbrido IPFS: individual + base fallback
    mapping(uint256 => string) private _tokenURIs;  // URIs individuales (IPFS específico)
    string public baseTokenURI;                     // Base URI para prereveal/fallback (IPFS)
    string private _contractURI;                    // Contract metadata URI

    // Extensions system
    mapping(address => bool) public authorizedExtensions;
    address[] public extensionsList;

    // =============== EVENTS ===============
    
    event AssetRegistered(uint256 indexed assetId, string category, AssetType assetType);
    event AssetMinted(uint256 indexed assetId, address indexed to, uint256 amount);
    event AssetBurned(uint256 indexed assetId, address indexed from, uint256 amount);
    event CategoryAdded(string indexed category);
    event CategoryRemoved(string indexed category);
    event AssetTypeAdded(string typeName);
    event ExtensionAdded(address indexed extension);
    event ExtensionRemoved(address indexed extension);
    event PaymentTokenUpdated(address newToken);
    event AssetUpdated(uint256 indexed assetId, string field, string newValue);
    event BaseURIUpdated(string newURI);

    // =============== MODIFIERS ===============
    
    modifier onlyAuthorizedExtension() {
        require(authorizedExtensions[msg.sender] || msg.sender == owner(), "!authorized extension");
        _;
    }

    modifier validAsset(uint256 assetId) {
        require(assetId < nextAssetId && assetId > 0, "!asset");
        _;
    }

    // =============== CONSTRUCTOR ===============
    
    constructor(address _paymentToken, address _treasury) ERC1155("") Ownable(msg.sender) {
        require(_paymentToken != address(0), "Invalid payment token");
        require(_treasury != address(0), "Invalid treasury");
        
        paymentToken = IERC20(_paymentToken);
        treasury = _treasury;
        baseTokenURI = "ipfs://QmPrerevealPlaceholder/";  // Base IPFS para prereveal
        
        // Inicializar nombres de AssetTypes base
        assetTypeNames = [
            "VISUAL_TRAIT",
            "INVENTORY_ITEM", 
            "CONSUMABLE",
            "SERUM",
            "PACK"
        ];

        // Inicializar categorías base
        categoryList = [
            "BACKGROUND",
            "EYES", 
            "MOUTH",
            "HEAD",
            "EAR",
            "SERUMS",
            "NECK",
            "SKINTRAIT",
            "SWAG",
            "NOSE",
            "PACKS"
        ];
        
        for (uint256 i = 0; i < categoryList.length; i++) {
            validCategories[categoryList[i]] = true;
        }
    }

    // =============== CORE ADMIN FUNCTIONS ===============
    
    function setAuthorizedContract(address _contract, bool authorized) external onlyOwner {
        require(_contract != address(0), "Invalid contract");
        
        if (authorized && !authorizedExtensions[_contract]) {
            authorizedExtensions[_contract] = true;
            extensionsList.push(_contract);
            emit ExtensionAdded(_contract);
        } else if (!authorized && authorizedExtensions[_contract]) {
            authorizedExtensions[_contract] = false;
            
            // Remove from array
            for (uint256 i = 0; i < extensionsList.length; i++) {
                if (extensionsList[i] == _contract) {
                    extensionsList[i] = extensionsList[extensionsList.length - 1];
                    extensionsList.pop();
                    break;
                }
            }
            emit ExtensionRemoved(_contract);
        }
    }

    function treasuryWallet() external view returns (address) {
        return treasury;
    }

    function setPaymentToken(address _paymentToken) external onlyOwner {
        require(_paymentToken != address(0), "Invalid payment token");
        paymentToken = IERC20(_paymentToken);
        emit PaymentTokenUpdated(_paymentToken);
    }

    // =============== EXTENSIONS MANAGEMENT ===============
    
    function getAuthorizedExtensions() external view returns (address[] memory) {
        return extensionsList;
    }

    // =============== EXTENSION FUNCTIONS ===============
    
    function mintFromExtension(address to, uint256 id, uint256 amount) external onlyAuthorizedExtension nonReentrant {
        // Verificar maxSupply si aplica
        if (assets[id].maxSupply > 0) {
            require(totalMintedPerAsset[id] + amount <= assets[id].maxSupply, "Exceeds max supply");
        }
        _mint(to, id, amount, "");
        totalMintedPerAsset[id] += amount;
        emit AssetMinted(id, to, amount);
    }

    function burnFromExtension(address from, uint256 id, uint256 amount) external onlyAuthorizedExtension {
        _burn(from, id, amount);
    }

    function registerAssetFromExtension(
        uint256 assetId, 
        uint8 categoryId, 
        uint256 maxSupply, 
        AssetType assetType
    ) external onlyAuthorizedExtension {
        require(assetId > 0, "Invalid asset ID");
        require(categoryId < categoryList.length, "Invalid category ID");
        require(assets[assetId].maxSupply == 0, "Asset exists");
        
        string memory category = categoryList[categoryId];
        _createAssetInternal(assetId, category, maxSupply, assetType);
    }

    // =============== CATEGORY MANAGEMENT ===============
    
    function addCategory(string calldata category) external onlyOwner {
        require(bytes(category).length > 0, "Empty category name");
        require(!validCategories[category], "Category already exists");
        
        categoryList.push(category);
        validCategories[category] = true;
        
        emit CategoryAdded(category);
    }

    function removeCategory(string calldata category) external onlyOwner {
        require(validCategories[category], "Category does not exist");
        
        // Encontrar y remover la categoría del array
        for (uint256 i = 0; i < categoryList.length; i++) {
            if (keccak256(bytes(categoryList[i])) == keccak256(bytes(category))) {
                // Mover el último elemento a la posición actual
                categoryList[i] = categoryList[categoryList.length - 1];
                categoryList.pop();
                break;
            }
        }
        
        validCategories[category] = false;
        
        emit CategoryRemoved(category);
    }

    // =============== VIEW FUNCTIONS ===============
    
    function isTrait(uint256 id) external view returns (bool) {
        return assets[id].assetType == AssetType.VISUAL_TRAIT;
    }

    function isPack(uint256 id) external view returns (bool) {
        return assets[id].assetType == AssetType.PACK;
    }

    function isSerum(uint256 id) external view returns (bool) {
        return assets[id].assetType == AssetType.SERUM;
    }

    function getTraitInfo(uint256 assetId) external view returns (string memory category, bool isTemp) {
        AssetData storage asset = assets[assetId];
        return (asset.category, asset.tempFlag);
    }

    function getName(uint256 assetId) external pure returns (string memory) {
        return string(abi.encodePacked("Asset #", assetId.toString()));
    }

    function name() public pure returns (string memory) {
        return "AdrianLAB";
    }

    function symbol() public pure returns (string memory) {
        return "ADRIANLAB";
    }

    function getCategory(uint256 assetId) external view returns (string memory) {
        return assets[assetId].category;
    }

    function getAssetData(uint256 assetId) external view returns (AssetData memory) {
        return assets[assetId];
    }

    // =============== ASSET CREATION FUNCTIONS ===============
    
    function createAsset(
        uint256 assetId, 
        uint8 categoryId, 
        uint256 maxSupply, 
        AssetType assetType
    ) external onlyOwner {
        require(categoryId < categoryList.length, "Invalid category ID");
        string memory category = categoryList[categoryId];
        _createAssetInternal(assetId, category, maxSupply, assetType);
    }

    function batchCreateAssets(
        uint256[] calldata assetIds,
        uint8[] calldata categoryIds,
        uint256[] calldata maxSupplies,
        AssetType[] calldata assetTypes
    ) external onlyOwner {
        require(assetIds.length == categoryIds.length, "Arrays length mismatch");
        require(assetIds.length == maxSupplies.length, "Arrays length mismatch");
        require(assetIds.length == assetTypes.length, "Arrays length mismatch");
        require(assetIds.length <= 50, "Batch too large");
        
        for (uint256 i = 0; i < assetIds.length; i++) {
            require(categoryIds[i] < categoryList.length, "Invalid category ID");
            string memory category = categoryList[categoryIds[i]];
            _createAssetInternal(assetIds[i], category, maxSupplies[i], assetTypes[i]);
        }
    }

    function _createAssetInternal(
        uint256 assetId,
        string memory category,
        uint256 maxSupply,
        AssetType assetType
    ) internal {
        require(assetId > 0, "Asset ID must be greater than 0");
        require(validCategories[category], "Invalid category");
        require(assets[assetId].maxSupply == 0, "Asset already exists");
        
        assets[assetId] = AssetData({
            category: category,
            tempFlag: false,
            maxSupply: maxSupply,
            assetType: assetType
        });
        
        if (assetId >= nextAssetId) {
            nextAssetId = assetId + 1;
        }
        
        emit AssetRegistered(assetId, category, assetType);
    }

    // =============== ASSETTYPE VALIDATION FUNCTIONS ===============
    
    function canEquipAsset(uint256 assetId) external view returns (bool) {
        return assets[assetId].assetType == AssetType.VISUAL_TRAIT;
    }

    function canConsumeAsset(uint256 assetId) external view returns (bool) {
        return assets[assetId].assetType == AssetType.CONSUMABLE;
    }

    function canUseForInventory(uint256 assetId) external view returns (bool) {
        return assets[assetId].assetType == AssetType.INVENTORY_ITEM;
    }

    function canUseAsSerum(uint256 assetId) external view returns (bool) {
        return assets[assetId].assetType == AssetType.SERUM;
    }

    function canOpenAsPack(uint256 assetId) external view returns (bool) {
        return assets[assetId].assetType == AssetType.PACK;
    }

    function getAssetTypeEnum(uint256 assetId) external view returns (uint8) {
        return uint8(assets[assetId].assetType);
    }

    function getAssetTypeName(uint256 assetId) external view returns (string memory) {
        uint8 typeId = uint8(assets[assetId].assetType);
        require(typeId < assetTypeNames.length, "Invalid asset type");
        return assetTypeNames[typeId];
    }

    function validateAssetType(uint256 assetId, AssetType expectedType) external view returns (bool) {
        return assets[assetId].maxSupply > 0 && assets[assetId].assetType == expectedType;
    }

    // =============== ASSET MANAGEMENT FUNCTIONS ===============
    
    function updateAssetCategory(uint256 assetId, string calldata newCategory) external onlyOwner {
        require(assets[assetId].maxSupply > 0, "Asset does not exist");
        require(validCategories[newCategory], "Invalid category");
        assets[assetId].category = newCategory;
        emit AssetUpdated(assetId, "category", newCategory);
    }

    function updateAssetMaxSupply(uint256 assetId, uint256 newMaxSupply) external onlyOwner {
        require(assets[assetId].maxSupply > 0, "Asset does not exist");
        require(newMaxSupply >= totalMintedPerAsset[assetId], "Cannot reduce below minted amount");
        
        assets[assetId].maxSupply = newMaxSupply;
        emit AssetUpdated(assetId, "maxSupply", newMaxSupply.toString());
    }

    function addAssetType(string calldata typeName) external onlyOwner {
        require(bytes(typeName).length > 0, "Empty type name");
        assetTypeNames.push(typeName);
        emit AssetTypeAdded(typeName);
    }

    function getAssetTypesList() external view returns (string[] memory) {
        return assetTypeNames;
    }

    function getAvailableSupply(uint256 assetId) external view returns (uint256) {
        if (assets[assetId].maxSupply == 0) return 0;
        return assets[assetId].maxSupply - totalMintedPerAsset[assetId];
    }

    function getTotalMinted(uint256 assetId) external view returns (uint256) {
        return totalMintedPerAsset[assetId];
    }

    function mint(address to, uint256 id, uint256 amount) external onlyAuthorizedExtension nonReentrant {
        // Verificar maxSupply si aplica
        if (assets[id].maxSupply > 0) {
            require(totalMintedPerAsset[id] + amount <= assets[id].maxSupply, "Exceeds max supply");
        }
        _mint(to, id, amount, "");
        totalMintedPerAsset[id] += amount;
        emit AssetMinted(id, to, amount);
    }

    function burn(address from, uint256 id, uint256 amount) external onlyAuthorizedExtension {
        _burn(from, id, amount);
        emit AssetBurned(id, from, amount);
    }

    function getCategoryList() external view returns (string[] memory) {
        return categoryList;
    }

    // =============== SISTEMA URI IPFS HÍBRIDO ===============

    /**
     * @dev Sistema URI híbrido IPFS: individual primero, luego base fallback
     * Funciona perfectamente con OpenSea para ERC1155
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        require(exists(tokenId), "URI query for nonexistent token");
        
        // Primero: verificar si tiene URI individual (IPFS específico)
        string memory tokenURI = _tokenURIs[tokenId];
        if (bytes(tokenURI).length > 0) {
            return tokenURI;
        }
        
        // Fallback: usar base URI + tokenId (IPFS prereveal)
        return string(abi.encodePacked(baseTokenURI, Strings.toString(tokenId), ".json"));
    }

    /**
     * @dev Establece URI individual para un token específico (reveal)
     * Emite evento estándar ERC1155 para recacheado automático de OpenSea
     * @param tokenId ID del token
     * @param tokenURI URI IPFS específica del token
     */
    function setTokenURI(uint256 tokenId, string calldata tokenURI) external onlyOwner {
        require(exists(tokenId), "Token does not exist");
        require(bytes(tokenURI).length > 0, "URI cannot be empty");
        
        _tokenURIs[tokenId] = tokenURI;
        
        // Evento estándar ERC1155 - OpenSea lo escucha automáticamente
        emit URI(tokenURI, tokenId);
    }

    /**
     * @dev Establece base URI para todos los tokens sin URI individual (prereveal)
     * @param newBaseURI Nueva base URI IPFS
     */
    function setBaseTokenURI(string calldata newBaseURI) external onlyOwner {
        require(bytes(newBaseURI).length > 0, "URI cannot be empty");
        
        baseTokenURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    /**
     * @dev Remueve URI individual (token vuelve a usar base URI)
     * @param tokenId ID del token
     */
    function removeTokenURI(uint256 tokenId) external onlyOwner {
        require(exists(tokenId), "Token does not exist");
        require(bytes(_tokenURIs[tokenId]).length > 0, "Token has no individual URI");
        
        delete _tokenURIs[tokenId];
        
        // Emite evento con la nueva URI (base fallback)
        string memory newURI = string(abi.encodePacked(baseTokenURI, Strings.toString(tokenId), ".json"));
        emit URI(newURI, tokenId);
    }

    /**
     * @dev Obtiene URI individual de un token (si existe)
     * @param tokenId ID del token
     * @return URI individual o string vacío si usa base URI
     */
    function getTokenURI(uint256 tokenId) external view returns (string memory) {
        return _tokenURIs[tokenId];
    }

    /**
     * @dev Verifica si un token tiene URI individual
     * @param tokenId ID del token
     * @return true si tiene URI individual, false si usa base URI
     */
    function hasTokenURI(uint256 tokenId) external view returns (bool) {
        return bytes(_tokenURIs[tokenId]).length > 0;
    }

    // =============== FUNCIONES HELPER ===============

    /**
     * @dev Check si un token existe (útil para debugging)
     * Un asset existe si fue creado alguna vez (independiente de maxSupply actual)
     * @param tokenId Token a verificar
     * @return exists True si existe
     */
    function exists(uint256 tokenId) public view returns (bool) {
        return bytes(assets[tokenId].category).length > 0;
    }

    /**
     * @dev Get total de tokens creados
     * @return count Número total de tokens
     */
    function totalTokens() public view returns (uint256) {
        return nextAssetId - 1;
    }

    // =============== CONTRACT METADATA (OPENSEA) ===============

    /**
     * @dev Configura la URI del contrato para OpenSea
     * @param newContractURI URI del metadata del contrato completo
     */
    function setContractURI(string calldata newContractURI) external onlyOwner {
        _contractURI = newContractURI;
    }

    /**
     * @dev Retorna la URI del metadata del contrato para OpenSea
     * @return URI del metadata del contrato
     */
    function contractURI() external view returns (string memory) {
        return _contractURI;
    }
}