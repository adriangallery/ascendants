// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AdrianLabCore
 * @dev ERC721Enumerable con lógica inmutable para mutación y minting externalizado
 * @notice UPGRADED - FASE 1: Sistema de Skins por Mutación + Gestión Avanzada de Skins
 */
contract AdrianLabCore is ERC721Enumerable, Ownable, ReentrancyGuard {
    using Strings for uint256;

    // =============== Type Definitions ===============
    enum MutationType {
        NONE,
        MILD,
        SEVERE
    }

    struct Skin {
        string name;           // "Zero", "Dark", "Alien", etc.
        uint256 rarity;        // Peso de rareza (1-1000)
        bool active;           // Si está activo para mint
    }

    // =============== State Variables ===============
    
    // Token counters
    uint256 public totalGen0Tokens;
    uint256 public tokenCounter;

    // Skin system
    mapping(uint256 => Skin) public skins;
    mapping(uint256 => uint256) public tokenSkin;
    uint256 public nextSkinId = 1;
    uint256 public totalSkinWeight;
    bool public randomSkinEnabled = true;
    
    // ✅ NEW: Sistema de Skins por Mutación
    mapping(string => uint256) public mutationToSkin;     // mutación → skinId especial
    mapping(uint256 => bool) public isSpecialSkin;        // skinId → es especial
    mapping(uint256 => string) public specialSkinMutation; // skinId → mutación origen
    
    // Base URI for metadata
    string public baseURI = "https://adrianlab.vercel.app/api/metadata/";

    // Payment token
    IERC20 public paymentToken;

    // Contract references
    address public extensionsContract;
    address public traitsContract;
    address public adrianLabExtensions;
    address public adminContract;
    
    // Financial distribution
    address public treasuryWallet;

    // Token Data Mappings
    mapping(uint256 => uint256) public generation;
    mapping(uint256 => bool) public isGen0Token;
    mapping(uint256 => MutationType) public mutationLevel;
    mapping(uint256 => bool) public hasBeenModified;
    mapping(uint256 => bool) public hasBeenMutatedBySerum;
    mapping(uint256 => bool) public hasBeenDuplicated;
    mapping(uint256 => string) public mutationLevelName;
    mapping(uint256 => bool) public tokenModified;
    mapping(uint256 => bool) public tokenDuplicated;
    mapping(uint256 => bool) public tokenMutatedBySerum;
    mapping(uint256 => uint8) public tokenMutationLevel;
    
    // Módulos
    address public serumModule;
    address public mintModule;
    address public duplicatorModule;

    // Traits
    mapping(uint256 => mapping(string => uint256)) public tokenTraits;
    
    // Dynamic extension system
    mapping(bytes4 => address) public functionImplementations;

    // History contract
    IAdrianHistory public history;

    // =============== Events ===============
    
    event TokenMinted(address indexed to, uint256 indexed tokenId);
    event SkinCreated(uint256 indexed skinId, string name, uint256 rarity);
    event SkinAssigned(uint256 indexed tokenId, uint256 skinId, string name);
    event RandomSkinToggled(bool enabled);
    event BaseURIUpdated(string newURI);
    event MutationAssigned(uint256 indexed tokenId);
    event SerumApplied(uint256 indexed tokenId, uint256 serumId);
    event MutationNameAssigned(uint256 indexed tokenId, string newMutation);
    event ExtensionsContractUpdated(address newContract);
    event TraitsContractUpdated(address newContract);
    event PaymentTokenUpdated(address newToken);
    event ProceedsWithdrawn(address indexed wallet, uint256 amount);
    event TreasuryWalletUpdated(address newWallet);
    event FirstModification(uint256 indexed tokenId);
    event FunctionImplementationUpdated(bytes4 indexed selector, address indexed implementation);
    event TokenBurnt(uint256 indexed tokenId, address indexed burner);
    event AdminContractUpdated(address newAdmin);

    // ✅ NEW: Eventos para Sistema de Skins por Mutación
    event MutationSkinSet(string indexed mutation, uint256 indexed skinId);
    event SkinUpdated(uint256 indexed skinId, string name, uint256 rarity, bool active);
    event SpecialSkinApplied(uint256 indexed tokenId, uint256 indexed skinId, string mutation);
    event SkinRemoved(uint256 indexed skinId);

    // =============== Modifiers ===============
    
    modifier onlyExtensions() {
        require(msg.sender == extensionsContract, "!ext");
        _;
    }

    modifier onlyTraitsContract() {
        require(msg.sender == traitsContract, "!traits");
        _;
    }
    
    modifier onlySerumModule() {
        require(msg.sender == serumModule, "!serum");
        _;
    }

    modifier onlyMintModule() {
        require(msg.sender == mintModule || msg.sender == owner(), "Not authorized");
        _;
    }

    modifier onlyDuplicatorModule() {
        require(msg.sender == duplicatorModule, "!duplicator");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == adminContract || msg.sender == owner(), "!admin");
        _;
    }

    // =============== Constructor ===============
    
    constructor(
        address _paymentToken,
        address _treasuryWallet
    ) ERC721("AdrianZERO", "BADRIAN") Ownable(msg.sender) {
        paymentToken = IERC20(_paymentToken);
        treasuryWallet = _treasuryWallet;
        tokenCounter = 0;
    }

    // =============== Main Functions ===============

    function setMintModule(address _module) external onlyOwner {
        require(_module != address(0) && _module.code.length > 0, "Invalid module");
        mintModule = _module;
    }

    function setDuplicatorModule(address _module) external onlyOwner {
        require(_module != address(0) && _module.code.length > 0, "Invalid module");
        duplicatorModule = _module;
    }

    function safeMint(address to) external onlyMintModule returns (uint256) {
        tokenCounter++;
        uint256 tokenId = tokenCounter;
        _safeMint(to, tokenId);

        // Set as Gen0 if minted directly
        if (msg.sender == mintModule) {
            isGen0Token[tokenId] = true;
            generation[tokenId] = 0;
            totalGen0Tokens++;
        }

        // Record in history
        if (address(history) != address(0)) {
            history.recordEvent(
                tokenId,
                keccak256("MINT"),
                msg.sender,
                abi.encodePacked(block.timestamp),
                block.number
            );
        }

        emit TokenMinted(to, tokenId);
        return tokenId;
    }

    function createSkin(string memory name, uint256 rarity) public onlyOwner returns (uint256) {
        require(rarity > 0 && rarity <= 1000, "!rarity");
        
        uint256 skinId = nextSkinId++;
        
        skins[skinId] = Skin({
            name: name,
            rarity: rarity,
            active: true
        });
        
        totalSkinWeight += rarity;
        
        emit SkinCreated(skinId, name, rarity);
        return skinId;
    }

    // ✅ UPDATED: Cambio de skins base según roadmap
    function initializeSkins() external onlyOwner {
        require(nextSkinId == 1, "!init");
        
        createSkin("Zero", 750);   // ✅ Cambio: era "BareAdrian"
        createSkin("Dark", 240);   // ✅ Cambio: era "Medium"
        createSkin("Alien", 10);   // ✅ Mismo nombre
        
        randomSkinEnabled = true;
    }

    // =============== NEW: Sistema de Skins por Mutación ===============

    /**
     * @dev Configura qué skin se aplica automáticamente con una mutación específica
     * @param mutation Nombre de la mutación (ej: "Radioactive", "Viral", "Quantum")
     * @param skinId ID del skin que se aplicará (puede ser nuevo o existente)
     */
    function setMutationSkin(string calldata mutation, uint256 skinId) external onlyOwner {
        require(skinId > 0 && skinId < nextSkinId, "Skin does not exist");
        require(bytes(mutation).length > 0, "Empty mutation name");
        
        mutationToSkin[mutation] = skinId;
        isSpecialSkin[skinId] = true;
        specialSkinMutation[skinId] = mutation;
        
        emit MutationSkinSet(mutation, skinId);
    }

    /**
     * @dev Aplica skin especial automáticamente cuando se usa un serum
     * @param tokenId Token al que aplicar el skin
     * @param mutation Mutación que trigger el skin especial
     */
    function applyMutationSkin(uint256 tokenId, string calldata mutation) external onlySerumModule {
        require(_exists(tokenId), "Token does not exist");
        
        uint256 specialSkinId = mutationToSkin[mutation];
        if (specialSkinId > 0) {
            // Aplicar el skin especial
            tokenSkin[tokenId] = specialSkinId;
            
            // Registrar en history si está disponible
            if (address(history) != address(0)) {
                history.recordEvent(
                    tokenId,
                    keccak256("SPECIAL_SKIN_APPLIED"),
                    msg.sender,
                    abi.encode(specialSkinId, mutation),
                    block.number
                );
            }
            
            emit SpecialSkinApplied(tokenId, specialSkinId, mutation);
        }
    }

    /**
     * @dev Modifica un skin existente (nombre, rareza, estado activo)
     * @param skinId ID del skin a modificar
     * @param newName Nuevo nombre del skin
     * @param newRarity Nueva rareza (1-1000)
     * @param active Si el skin está activo para asignación aleatoria
     */
    function updateSkin(
        uint256 skinId, 
        string memory newName, 
        uint256 newRarity, 
        bool active
    ) external onlyOwner {
        require(skinId > 0 && skinId < nextSkinId, "Skin does not exist");
        require(newRarity > 0 && newRarity <= 1000, "Invalid rarity");
        require(bytes(newName).length > 0, "Empty name");

        Skin storage skin = skins[skinId];
        
        // Actualizar peso total si cambió la rareza
        if (skin.rarity != newRarity) {
            totalSkinWeight = totalSkinWeight - skin.rarity + newRarity;
        }
        
        skin.name = newName;
        skin.rarity = newRarity;
        skin.active = active;
        
        emit SkinUpdated(skinId, newName, newRarity, active);
    }

    /**
     * @dev Crea un skin especial específico para una mutación
     * @param name Nombre del skin especial
     * @param rarity Rareza del skin (1-1000)
     * @param mutation Mutación asociada
     * @return skinId ID del skin creado
     */
    function createSpecialSkin(
        string memory name,
        uint256 rarity,
        string memory mutation
    ) external onlyOwner returns (uint256) {
        uint256 skinId = createSkin(name, rarity);
        
        // Marcar como especial y asociar con mutación
        isSpecialSkin[skinId] = true;
        specialSkinMutation[skinId] = mutation;
        mutationToSkin[mutation] = skinId;
        
        emit MutationSkinSet(mutation, skinId);
        return skinId;
    }

    /**
     * @dev Elimina la asociación de una mutación con un skin
     * @param mutation Mutación a desasociar
     */
    function removeMutationSkin(string calldata mutation) external onlyOwner {
        uint256 skinId = mutationToSkin[mutation];
        require(skinId > 0, "Mutation not associated with skin");
        
        delete mutationToSkin[mutation];
        isSpecialSkin[skinId] = false;
        delete specialSkinMutation[skinId];
        
        emit MutationSkinSet(mutation, 0);
    }

    // =============== REQUIRED FUNCTIONS (Compatibility) ===============

    /**
     * @dev Sets token info (required by AdrianDuplicatorModule)
     */
    function setTokenInfo(uint256 tokenId, uint256 _generation, string calldata mutation) external onlyDuplicatorModule {
        require(_exists(tokenId), "Token does not exist");
        generation[tokenId] = _generation;
        mutationLevelName[tokenId] = mutation;
        
        // Mark as modified if not Gen0
        if (_generation > 0) {
            hasBeenModified[tokenId] = true;
            tokenModified[tokenId] = true;
        }
    }

    /**
     * @dev Gets token traits info (required by multiple modules)
     */
    function getTraits(uint256 tokenId) external view returns (uint256 _generation, uint256 unused, string memory mutation) {
        require(_exists(tokenId), "Token does not exist");
        return (generation[tokenId], 0, mutationLevelName[tokenId]);
    }

    /**
     * @dev Checks if token can duplicate
     */
    function canDuplicate(uint256 tokenId) external view returns (bool) {
        return isGen0Token[tokenId] && 
               !hasBeenDuplicated[tokenId] &&
               mutationLevel[tokenId] == MutationType.NONE &&
               _exists(tokenId);
    }

    /**
     * @dev Gets token data for extensions
     */
    function getTokenData(uint256 tokenId) external view returns (
        uint256 tokenGeneration,
        uint8 mutationLevelValue,
        bool canReplicate,
        uint256 replicationCount,
        uint256 lastReplication,
        bool tokenHasBeenModified
    ) {
        require(_exists(tokenId), "!exist");
        
        return (
            generation[tokenId],
            uint8(mutationLevel[tokenId]),
            this.canDuplicate(tokenId),
            0, // replicationCount placeholder
            0, // lastReplication placeholder
            hasBeenModified[tokenId]
        );
    }

    // =============== Token State Management ===============

    function setTokenModified(uint256 tokenId, bool modified) external onlyAdmin {
        require(_exists(tokenId), "Token does not exist");
        hasBeenModified[tokenId] = modified;
        tokenModified[tokenId] = modified;
    }

    function setTokenDuplicated(uint256 tokenId, bool duplicated) external onlyAdmin {
        require(_exists(tokenId), "Token does not exist");
        hasBeenDuplicated[tokenId] = duplicated;
        tokenDuplicated[tokenId] = duplicated;
    }

    function setTokenMutatedBySerum(uint256 tokenId, bool mutated) external onlyAdmin {
        require(_exists(tokenId), "Token does not exist");
        hasBeenMutatedBySerum[tokenId] = mutated;
        tokenMutatedBySerum[tokenId] = mutated;
    }

    function setTokenMutationLevel(uint256 tokenId, uint8 level) external onlyAdmin {
        require(_exists(tokenId), "Token does not exist");
        require(level <= uint8(MutationType.SEVERE), "Invalid mutation level");
        mutationLevel[tokenId] = MutationType(level);
        tokenMutationLevel[tokenId] = level;
    }

    function setAdminContract(address _admin) external onlyOwner {
        require(_admin != address(0), "Invalid admin");
        adminContract = _admin;
        emit AdminContractUpdated(_admin);
    }

    // =============== View Functions ===============

    function getSkin(uint256 skinId) external view returns (
        string memory name,
        uint256 rarity,
        bool active
    ) {
        Skin memory skin = skins[skinId];
        return (skin.name, skin.rarity, skin.active);
    }

    function getTokenSkin(uint256 tokenId) external view returns (
        uint256 skinId,
        string memory name
    ) {
        require(_exists(tokenId), "!exist");
        
        skinId = tokenSkin[tokenId];
        if (skinId > 0) {
            return (skinId, skins[skinId].name);
        }
        
        return (0, "Zero"); // ✅ Cambio: era "BareAdrian"
    }

    function getSkinRarityPercentage(uint256 skinId) external view returns (uint256) {
        if (totalSkinWeight == 0) return 0;
        return (skins[skinId].rarity * 10000) / totalSkinWeight;
    }

    // ✅ NEW: View functions para sistema de mutación → skin
    function getMutationSkin(string calldata mutation) external view returns (uint256) {
        return mutationToSkin[mutation];
    }

    function isSkinSpecial(uint256 skinId) external view returns (bool) {
        return isSpecialSkin[skinId];
    }

    function getSkinMutation(uint256 skinId) external view returns (string memory) {
        return specialSkinMutation[skinId];
    }

    function getAllSkins() external view returns (
        uint256[] memory skinIds,
        string[] memory names,
        uint256[] memory rarities,
        bool[] memory activeStates,
        bool[] memory isSpecial
    ) {
        uint256 totalSkins = nextSkinId - 1;
        
        skinIds = new uint256[](totalSkins);
        names = new string[](totalSkins);
        rarities = new uint256[](totalSkins);
        activeStates = new bool[](totalSkins);
        isSpecial = new bool[](totalSkins);
        
        for (uint256 i = 1; i <= totalSkins; i++) {
            skinIds[i-1] = i;
            names[i-1] = skins[i].name;
            rarities[i-1] = skins[i].rarity;
            activeStates[i-1] = skins[i].active;
            isSpecial[i-1] = isSpecialSkin[i];
        }
    }

    function isTokenModified(uint256 tokenId) public view returns (bool) {
        return hasBeenModified[tokenId];
    }

    function isEligibleForMutation(uint256 tokenId) external view returns (bool) {
        return isGen0Token[tokenId] && 
               !hasBeenMutatedBySerum[tokenId] &&
               _exists(tokenId);
    }

    function exists(uint256 tokenId) public view returns (bool) {
        return _exists(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "URI query for nonexistent token");
        if (extensionsContract != address(0)) {
            try IAdrianLabExtensions(extensionsContract).getTokenURI(tokenId) returns (string memory uri) {
                return uri;
            } catch {
                return string(abi.encodePacked(baseURI, tokenId.toString()));
            }
        }
        return string(abi.encodePacked(baseURI, tokenId.toString()));
    }

    // =============== Admin Functions ===============

    function setExtensionsContract(address _extensionsContract) external onlyOwner {
        require(_extensionsContract != address(0) && _extensionsContract.code.length > 0, "Invalid contract");
        extensionsContract = _extensionsContract;
        IAdrianLabExtensions(_extensionsContract).setCoreContract(address(this));
        emit ExtensionsContractUpdated(_extensionsContract);
    }

    function setTraitsContract(address _traitsContract) external onlyOwner {
        require(_traitsContract != address(0) && _traitsContract.code.length > 0, "Invalid contract");
        traitsContract = _traitsContract;
        emit TraitsContractUpdated(_traitsContract);
    }

    function setPaymentToken(address _paymentToken) external onlyOwner {
        require(_paymentToken != address(0) && _paymentToken.code.length > 0, "Invalid contract");
        paymentToken = IERC20(_paymentToken);
        emit PaymentTokenUpdated(_paymentToken);
    }

    function withdrawProceeds(address wallet) external onlyOwner {
        uint256 amount = paymentToken.balanceOf(address(this));
        require(amount > 0, "!funds");
        paymentToken.transfer(wallet, amount);
        emit ProceedsWithdrawn(wallet, amount);
    }

    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner(), amount);
    }

    function assignTokenAttributes(uint256 tokenId) external nonReentrant {
        require(ownerOf(tokenId) == msg.sender, "!owner");
        require(tokenSkin[tokenId] == 0, "already assigned");
        
        if (randomSkinEnabled && totalSkinWeight > 0) {
            uint256 skinId = _selectRandomSkin();
            tokenSkin[tokenId] = skinId;
            emit SkinAssigned(tokenId, skinId, skins[skinId].name);
        }
    }

    function setTreasuryWallet(address _treasuryWallet) external onlyOwner {
        require(_treasuryWallet != address(0), "!zero");
        treasuryWallet = _treasuryWallet;
        emit TreasuryWalletUpdated(_treasuryWallet);
    }

    function setHistoryContract(address _history) external onlyOwner {
        require(_history != address(0) && _history.code.length > 0, "Invalid contract");
        history = IAdrianHistory(_history);
    }

    function burn(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender || getApproved(tokenId) == msg.sender || isApprovedForAll(ownerOf(tokenId), msg.sender), "Not owner or approved");
        require(address(history) != address(0), "History contract not set");
        
        history.recordEvent(
            tokenId,
            keccak256("BURNT"),
            msg.sender,
            abi.encode("sacrifice"),
            block.number
        );

        hasBeenModified[tokenId] = false;
        delete mutationLevel[tokenId];
        
        emit TokenBurnt(tokenId, msg.sender);
        
        _burn(tokenId);
    }

    function setSerumModule(address _module) external onlyOwner {
        require(_module != address(0) && _module.code.length > 0, "Invalid module");
        serumModule = _module;
    }

    function setAdrianLabExtensions(address _extensions) external onlyOwner {
        extensionsContract = _extensions;
    }

    function setBaseURI(string calldata newURI) external onlyOwner {
        baseURI = newURI;
        emit BaseURIUpdated(newURI);
    }

    function setRandomSkin(bool enabled) external onlyOwner {
        randomSkinEnabled = enabled;
        emit RandomSkinToggled(enabled);
    }

    function setMutationFromSerum(uint256 tokenId, string calldata mutation, string calldata narrative) external {
        require(msg.sender == serumModule, "Not serum module");

        mutationLevelName[tokenId] = mutation;
        hasBeenMutatedBySerum[tokenId] = true;
        emit MutationNameAssigned(tokenId, mutation);

        // ✅ NEW: Intentar aplicar skin especial si existe para esta mutación
        if (mutationToSkin[mutation] > 0) {
            uint256 specialSkinId = mutationToSkin[mutation];
            tokenSkin[tokenId] = specialSkinId;
            emit SpecialSkinApplied(tokenId, specialSkinId, mutation);
        }

        if (address(history) != address(0)) {
            bytes memory data = abi.encode(narrative);
            history.recordEvent(tokenId, keccak256("MUTATION"), msg.sender, data, block.number);
        }
    }

    function setFunctionImplementation(bytes4 selector, address implementation) external onlyOwner {
        functionImplementations[selector] = implementation;
        emit FunctionImplementationUpdated(selector, implementation);
    }

    // =============== Internal Functions ===============

    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    function _selectRandomSkin() internal view returns (uint256) {
        uint256 rand = _random(block.timestamp + totalSupply(), totalSkinWeight);
        uint256 cumulative = 0;

        for (uint256 i = 1; i < nextSkinId; i++) {
            if (skins[i].active) {
                cumulative += skins[i].rarity;
                if (rand < cumulative) {
                    return i;
                }
            }
        }

        return 1;
    }

    function _random(uint256 seed, uint256 max) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            blockhash(block.number - 1),
            block.timestamp,
            msg.sender,
            seed
        ))) % max;
    }

    // =============== Fallback and Receive ===============
    
    fallback() external payable {
        address implementation = functionImplementations[msg.sig];
        require(implementation != address(0), "!impl");

        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {
        revert("NO_ETH_ACCEPTED");
    }
}

// =============== Interfaces ===============

interface IAdrianLabExtensions {
    function onTokenMinted(uint256 tokenId, address to) external;
    function onSerumApplied(uint256 tokenId, uint256 serumId) external;
    function getTokenURI(uint256 tokenId) external view returns (string memory);
    function recordHistory(uint256 tokenId, bytes32 eventType, bytes calldata eventData) external returns (uint256);
    function setCoreContract(address _core) external;
}

interface ITraitsContract {
    function getCategory(uint256 traitId) external view returns (string memory);
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