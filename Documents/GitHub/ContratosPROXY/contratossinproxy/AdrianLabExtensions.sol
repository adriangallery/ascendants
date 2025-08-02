// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/**
 * @title AdrianLabExtensions
 * @dev Extensions contract with traits, history and advanced functions
 */
contract AdrianLabExtensions is Ownable, ReentrancyGuard {
    using Strings for uint256;

    // =============== Constants ===============
    
    bytes32 constant EVENT_MINT = keccak256("MINT");
    bytes32 constant EVENT_REPLICATE = keccak256("REPLICATE");
    bytes32 constant EVENT_MUTATE = keccak256("MUTATE");
    bytes32 constant EVENT_TRAIT_EQUIPPED = keccak256("TRAIT_EQUIPPED");
    bytes32 constant EVENT_TRAIT_REMOVED = keccak256("TRAIT_REMOVED");
    bytes32 constant EVENT_SERUM_USED = keccak256("SERUM_USED");
    bytes32 constant EVENT_BACKGROUND_EQUIPPED = keccak256("BACKGROUND_EQUIPPED");

    // =============== Type Definitions ===============
    
    enum MutationType {
        NONE,
        MILD,
        SEVERE
    }

    enum SerumType {
        BASIC_MUTATION,
        DIRECTED_MUTATION,
        ADVANCED_MUTATION
    }

    struct TokenTraitInfo {
        string category;
        uint256 traitId;
        bool isTemporary;
        uint256 equippedAt;
    }
    
    struct TokenCompleteInfo {
        uint256 tokenId;
        uint256 generation;
        MutationType mutationLevel;
        bool canReplicate;
        uint256 replicationCount;
        uint256 lastReplication;
        bool hasBeenModified;
        uint256 skinId;
        TokenTraitInfo[] traits;
    }

    // =============== State Variables ===============
    
    // Contract references
    address public coreContract;
    address public traitsContract;
    address public adminContract;  // Nueva variable para el contrato admin
    
    // Trait system
    string[] public categoryList;
    mapping(uint256 => mapping(string => uint256)) public tokenTraits;
    mapping(uint256 => bool) public hasBeenModified;
    
    // Previous trait storage for temporary traits
    mapping(uint256 => mapping(string => uint256)) public previousTrait;
    mapping(string => mapping(uint256 => uint256)) public baseTraits;  // Guarda el trait base cuando se equipa uno temporal
    
    // Trait management
    mapping(uint256 => mapping(string => TokenTraitInfo)) public tokenEquippedTraits;
    mapping(uint256 => mapping(string => TokenTraitInfo)) public tokenBaseTraits;
    string[] public equippedTraitCategories;
    mapping(string => bool) public isEquippableCategory;
    
    // History system
    address public historyContract;
    
    // Extension system
    mapping(address => bool) public extensionAuthorized;  // Control de contratos autorizados a llamar funciones específicas
    mapping(address => bool) public authorizedExtensions; // Lista de extensiones autorizadas
    
    // Emergency system
    bool public emergencyMode = false;
    mapping(bytes4 => bool) public pausedFunctions;

    // =============== Events ===============
    
    event TraitEquipped(uint256 indexed tokenId, string category, uint256 traitId);
    event TraitRemoved(uint256 indexed tokenId, string category);
    event SerumUsed(address indexed user, uint256 tokenId, uint256 serumId);
    event TokenDuplicated(uint256 indexed originalTokenId, uint256 indexed newTokenId, MutationType mutationType);
    event TokenMutatedBySerum(uint256 indexed tokenId, MutationType mutationType);
    event BackgroundEquipped(uint256 indexed tokenId, uint256 backgroundId);
    event FirstModification(uint256 indexed tokenId);
    event ExtensionAuthorized(address indexed extension, bool authorized);
    event EmergencyModeSet(bool enabled);
    event FunctionPauseToggled(bytes4 functionSelector, bool paused);
    event EmergencyBackgroundRestored(uint256 indexed tokenId, uint256 backgroundId);
    event EmergencyModificationRestored(uint256 indexed tokenId, bool modified);
    event EmergencyTraitsRestored(uint256 indexed tokenId, string[] categories, uint256[] traitIds);
    event TraitUnequipped(uint256 indexed tokenId, uint256 traitId, string category);
    event TraitGranted(uint256 indexed tokenId, uint256 traitId, string category);
    event TraitContractUpdated(address newContract);
    event CoreContractUpdated(address newContract);
    event AuthorizationUpdated(address indexed account, bool status);

    // =============== Modifiers ===============
    
    modifier onlyAuthorizedExtension() {
        require(msg.sender == owner() || extensionAuthorized[msg.sender], "Not authorized");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == adminContract, "Not admin");
        _;
    }

    modifier onlyCore() {
        require(msg.sender == coreContract, "!core");
        _;
    }

    modifier onlyTraits() {
        require(msg.sender == traitsContract, "!traits");
        _;
    }

    modifier onlyExtension() {
        require(extensionAuthorized[msg.sender], "!extension");
        _;
    }

    modifier notPaused(bytes4 selector) {
        require(!emergencyMode || !pausedFunctions[selector], "paused");
        _;
    }

    modifier tokenExists(uint256 tokenId) {
        require(IERC721(coreContract).ownerOf(tokenId) != address(0), "!exist");
        _;
    }

    // =============== Constructor ===============
    
    constructor(address _coreContract) Ownable(msg.sender) {
        coreContract = _coreContract;
        
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
    }

    // =============== Core Contract Hooks ===============

    /**
     * @dev Called when a token is minted
     */
    function onTokenMinted(uint256 tokenId, address /* to */) external onlyCore {
        IAdrianHistory(historyContract).addNarrativeEvent(
            tokenId,
            EVENT_MINT,
            "A new GEN0 BareAdrian was created",
            0
        );
    }

    /**
     * @dev Called when a token is replicated
     */
    function onTokenReplicated(uint256 parentId, uint256 childId) external onlyCore {
        IAdrianHistory(historyContract).addNarrativeEvent(
            parentId,
            EVENT_REPLICATE,
            string(abi.encodePacked("Replicated to create token #", childId.toString())),
            childId
        );
        
        IAdrianHistory(historyContract).addNarrativeEvent(
            childId,
            EVENT_REPLICATE,
            string(abi.encodePacked("Created by replication from token #", parentId.toString())),
            parentId
        );
    }

    /**
     * @dev Called when a token is duplicated
     */
    function onTokenDuplicated(uint256 originalId, uint256 newId) external onlyCore {
        IAdrianHistory(historyContract).addNarrativeEvent(
            originalId,
            keccak256("DUPLICATED"),
            "This GEN0 token was duplicated",
            newId
        );
        
        (, uint8 mutationTypeRaw, , , , ) = IAdrianLabCore(coreContract).getTokenData(newId);
        MutationType mutationType = MutationType(mutationTypeRaw);
        
        IAdrianHistory(historyContract).addNarrativeEvent(
            newId,
            keccak256("CREATED_BY_DUPLICATION"),
            string(abi.encodePacked(
                "Created as ", _mutationTypeToString(mutationType), 
                " mutation from GEN0 token #", originalId.toString()
            )),
            originalId
        );
    }

    /**
     * @dev Called when serum is applied
     */
    function onSerumApplied(uint256 tokenId, uint256 serumId) external onlyCore {
        string memory serumName = "serum";
        if (serumId == 10001) serumName = "basic serum";
        else if (serumId == 10002) serumName = "directed serum";
        else if (serumId == 10003) serumName = "advanced serum";
        
        IAdrianHistory(historyContract).addNarrativeEvent(
            tokenId,
            EVENT_SERUM_USED,
            string(abi.encodePacked("Mutated using a ", serumName)),
            0
        );
    }

    // =============== Trait Functions ===============

    /**
     * @dev Equip a trait to a token
     */
    function equipTrait(
        uint256 tokenId,
        uint256 traitId,
        string calldata category
    ) external onlyAuthorizedExtension {
        require(IERC721(coreContract).ownerOf(tokenId) != address(0), "!exist");
        require(IAdrianTraitsCore(traitsContract).balanceOf(msg.sender, traitId) > 0, "!trait");
        
        // Obtener información del trait
        (string memory traitCategory, bool isTemporary) = IAdrianTraitsCore(traitsContract).getTraitInfo(traitId);
        require(keccak256(bytes(traitCategory)) == keccak256(bytes(category)), "!category");
        
        // Si es una nueva categoría, agregarla a la lista
        if (!isEquippableCategory[category]) {
            isEquippableCategory[category] = true;
            equippedTraitCategories.push(category);
        }
        
        // Si el trait actual es visual y no temporal, quemarlo
        TokenTraitInfo storage currentTrait = tokenEquippedTraits[tokenId][category];
        if (currentTrait.traitId > 0 && !currentTrait.isTemporary) {
            IAdrianTraitsCore(traitsContract).burn(msg.sender, currentTrait.traitId, 1);
        }
        
        // Si el nuevo trait es temporal, guardar el actual como base
        if (isTemporary) {
            tokenBaseTraits[tokenId][category] = currentTrait;
        }
        
        // Actualizar el trait equipado
        tokenEquippedTraits[tokenId][category] = TokenTraitInfo({
            category: category,
            traitId: traitId,
            isTemporary: isTemporary,
            equippedAt: block.timestamp
        });
        
        emit TraitEquipped(tokenId, category, traitId);
    }

    /**
     * @dev Remove a trait from a token
     */
    function removeTrait(uint256 tokenId, string calldata category) external notPaused(this.removeTrait.selector) tokenExists(tokenId) {
        require(IAdrianLabCore(coreContract).ownerOf(tokenId) == msg.sender, "!owner");
        require(tokenTraits[tokenId][category] != 0, "!equipped");
        
        uint256 traitId = tokenTraits[tokenId][category];
        (, bool isTemporary) = ITraits(traitsContract).getTraitInfo(traitId);
        
        // For temporary traits: restore the previous one if exists
        if (isTemporary && previousTrait[tokenId][category] != 0) {
            uint256 oldTrait = previousTrait[tokenId][category];
            tokenTraits[tokenId][category] = oldTrait;
            previousTrait[tokenId][category] = 0;
            // Note: The temporary trait stays in the user's inventory (not burned)
        } else {
            // If no previous trait, just clear the slot
            tokenTraits[tokenId][category] = 0;
        }
        
        IAdrianHistory(historyContract).addNarrativeEvent(
            tokenId,
            EVENT_TRAIT_REMOVED,
            string(abi.encodePacked(
                "Removed trait #", 
                traitId.toString(),
                " from category ",
                category
            )),
            0
        );
        
        emit TraitRemoved(tokenId, category);
    }

    /**
     * @dev Equip background
     */
    function equipBackground(uint256 tokenId, uint256 backgroundId) external notPaused(this.equipBackground.selector) tokenExists(tokenId) {
        require(IAdrianLabCore(coreContract).ownerOf(tokenId) == msg.sender, "!owner");
        
        string memory category = ITraits(traitsContract).getCategory(backgroundId);
        require(keccak256(bytes(category)) == keccak256(bytes("BACKGROUND")), "!background");
        require(ITraits(traitsContract).balanceOf(msg.sender, backgroundId) > 0, "!own");
        
        bool isTemporary = ITraits(traitsContract).isTemporary(backgroundId);
        uint256 currentBackgroundId = tokenTraits[tokenId]["BACKGROUND"];
        
        if (isTemporary) {
            // Save current background for later restoration
            if (currentBackgroundId != 0) {
                previousTrait[tokenId]["BACKGROUND"] = currentBackgroundId;
            }
            tokenTraits[tokenId]["BACKGROUND"] = backgroundId;
        } else {
            // Clear previous trait storage and burn the new background
            if (currentBackgroundId != 0) {
                previousTrait[tokenId]["BACKGROUND"] = 0;
            }
            ITraits(traitsContract).burn(msg.sender, backgroundId, 1);
            tokenTraits[tokenId]["BACKGROUND"] = backgroundId;
        }
        
        // Mark as modified if first time
        if (!hasBeenModified[tokenId]) {
            hasBeenModified[tokenId] = true;
            IAdrianLabCore(coreContract).setTokenModified(tokenId, true);
            emit FirstModification(tokenId);
        }
        
        IAdrianHistory(historyContract).addNarrativeEvent(
            tokenId,
            EVENT_BACKGROUND_EQUIPPED,
            string(abi.encodePacked(
                "Background changed to ", 
                ITraits(traitsContract).getName(backgroundId)
            )),
            0
        );
        
        emit BackgroundEquipped(tokenId, backgroundId);
    }

    /**
     * @dev Apply serum from traits contract
     */
    function applySerumFromTraits(
        address user, 
        uint256 tokenId, 
        uint256 serumId
    ) external onlyTraits returns (bool) {
        require(IAdrianLabCore(coreContract).ownerOf(tokenId) == user, "!owner");
        
        (uint8 serumTypeRaw, string memory targetMutation, uint256 potency) = 
            ITraits(traitsContract).getSerumData(serumId);
        
        SerumType serumType = SerumType(serumTypeRaw);
        
        if (serumType == SerumType.BASIC_MUTATION) {
            if (_random(tokenId, 100) <= potency) {
                IAdrianLabCore(coreContract).setTokenMutationLevel(tokenId, uint8(MutationType.MILD));
                
                IAdrianHistory(historyContract).addNarrativeEvent(
                    tokenId,
                    EVENT_SERUM_USED,
                    "Mutated using a basic serum",
                    0
                );
                
                return true;
            }
        } 
        else if (serumType == SerumType.DIRECTED_MUTATION) {
            MutationType mutation = MutationType.NONE;
            
            if (keccak256(bytes(targetMutation)) == keccak256(bytes("MILD"))) {
                mutation = MutationType.MILD;
            } else if (keccak256(bytes(targetMutation)) == keccak256(bytes("SEVERE"))) {
                mutation = MutationType.SEVERE;
            }
            
            IAdrianLabCore(coreContract).setTokenMutationLevel(tokenId, uint8(mutation));
            
            IAdrianHistory(historyContract).addNarrativeEvent(
                tokenId,
                EVENT_SERUM_USED,
                string(abi.encodePacked("Mutated to ", targetMutation, " using a directed serum")),
                0
            );
            
            return true;
        }
        else if (serumType == SerumType.ADVANCED_MUTATION) {
            (uint256 generation, , , , , ) = IAdrianLabCore(coreContract).getTokenData(tokenId);
            
            if (generation <= 1) {
                // Advanced serum can create MILD or SEVERE
                uint256 rand = _random(tokenId, 100);
                MutationType mutation = rand < 50 ? MutationType.MILD : MutationType.SEVERE;
                
                IAdrianLabCore(coreContract).setTokenMutationLevel(tokenId, uint8(mutation));
                
                IAdrianHistory(historyContract).addNarrativeEvent(
                    tokenId,
                    EVENT_SERUM_USED,
                    "Transformed using an advanced serum",
                    0
                );
                
                return true;
            }
        }
        
        return false;
    }

    // =============== Extension Management ===============

    /**
     * @dev Authorize/deauthorize extension
     */
    function setExtensionAuthorized(address extension, bool allowed) external onlyOwner {
        extensionAuthorized[extension] = allowed;
        emit ExtensionAuthorized(extension, allowed);
    }

    /**
     * @dev Check if extension is authorized
     */
    function isExtensionAuthorized(address extension) public view returns (bool) {
        return extensionAuthorized[extension];
    }

    /**
     * @dev Hook for authorized extensions to execute logic
     */
    function extensionCall(
        uint256 tokenId,
        bytes calldata data
    ) external onlyExtension tokenExists(tokenId) returns (bytes memory) {
        // Extensions can implement custom logic here
        // Example: decode data and execute specific functions
        
        // Add to history
        IAdrianHistory(historyContract).recordHistory(tokenId, keccak256("EXTENSION_CALL"), data);
        
        // Return empty bytes for now, extensions can define return format
        return "";
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

    /**
     * @dev Emergency restore background
     */
    function emergencyRestoreBackground(uint256 tokenId, uint256 backgroundId) external onlyOwner {
        require(emergencyMode, "!emergency");
        tokenTraits[tokenId]["BACKGROUND"] = backgroundId;
        emit EmergencyBackgroundRestored(tokenId, backgroundId);
    }

    /**
     * @dev Emergency restore modification flag
     */
    function emergencyRestoreModification(uint256 tokenId, bool modified) external onlyOwner {
        require(emergencyMode, "!emergency");
        hasBeenModified[tokenId] = modified;
        IAdrianLabCore(coreContract).setTokenModified(tokenId, modified);
        emit EmergencyModificationRestored(tokenId, modified);
    }

    /**
     * @dev Emergency restore multiple traits
     */
    function emergencyRestoreTraits(
        uint256 tokenId,
        string[] calldata categories,
        uint256[] calldata traitIds
    ) external onlyOwner {
        require(emergencyMode, "!emergency");
        require(categories.length == traitIds.length, "!length");
        
        for (uint256 i = 0; i < categories.length; i++) {
            tokenTraits[tokenId][categories[i]] = traitIds[i];
        }
        
        emit EmergencyTraitsRestored(tokenId, categories, traitIds);
    }

    /**
     * @dev Emergency restore previous traits (for temporary trait system)
     */
    function emergencyRestorePreviousTraits(
        uint256 tokenId,
        string[] calldata categories,
        uint256[] calldata traitIds
    ) external onlyOwner {
        require(emergencyMode, "!emergency");
        require(categories.length == traitIds.length, "!length");
        
        for (uint256 i = 0; i < categories.length; i++) {
            previousTrait[tokenId][categories[i]] = traitIds[i];
        }
    }

    // =============== View Functions ===============

    /**
     * @dev Get all traits for a token
     */
    function getTokenTraits(uint256 tokenId) external view tokenExists(tokenId) returns (
        string[] memory categories,
        uint256[] memory traitIds
    ) {
        categories = new string[](categoryList.length);
        traitIds = new uint256[](categoryList.length);
        
        for (uint256 i = 0; i < categoryList.length; i++) {
            categories[i] = categoryList[i];
            traitIds[i] = tokenTraits[tokenId][categoryList[i]];
        }
        
        return (categories, traitIds);
    }

    /**
     * @dev Get previous trait for a specific category (used for temporary traits)
     */
    function getPreviousTrait(uint256 tokenId, string calldata category) external view returns (uint256) {
        return previousTrait[tokenId][category];
    }

    /**
     * @dev Get all previous traits for a token
     */
    function getAllPreviousTraits(uint256 tokenId) external view tokenExists(tokenId) returns (
        string[] memory categories,
        uint256[] memory traitIds
    ) {
        categories = new string[](categoryList.length);
        traitIds = new uint256[](categoryList.length);
        
        for (uint256 i = 0; i < categoryList.length; i++) {
            categories[i] = categoryList[i];
            traitIds[i] = previousTrait[tokenId][categoryList[i]];
        }
        
        return (categories, traitIds);
    }

    /**
     * @dev Get all non-zero traits
     */
    function getAllTraits(uint256 tokenId) external view tokenExists(tokenId) returns (TokenTraitInfo[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < categoryList.length; i++) {
            if (tokenTraits[tokenId][categoryList[i]] != 0) {
                count++;
            }
        }
        
        TokenTraitInfo[] memory traits = new TokenTraitInfo[](count);
        uint256 index = 0;
        
        for (uint256 i = 0; i < categoryList.length; i++) {
            uint256 traitId = tokenTraits[tokenId][categoryList[i]];
            if (traitId != 0) {
                (string memory category, bool isTemporary) = IAdrianTraitsCore(traitsContract).getTraitInfo(traitId);
                traits[index] = TokenTraitInfo({
                    category: category,
                    traitId: traitId,
                    isTemporary: isTemporary,
                    equippedAt: block.timestamp // Para traits existentes usamos el timestamp actual
                });
                index++;
            }
        }
        
        return traits;
    }

    /**
     * @dev Get complete token info including skin
     */
    function getCompleteTokenInfo(uint256 tokenId) external view tokenExists(tokenId) returns (TokenCompleteInfo memory) {
        (
            uint256 generation,
            uint8 mutationLevelRaw,
            bool canReplicate,
            uint256 replicationCount,
            uint256 lastReplication,
            bool isModified
        ) = IAdrianLabCore(coreContract).getTokenData(tokenId);
        
        (uint256 skinId, ) = IAdrianLabCore(coreContract).getTokenSkin(tokenId);
        
        MutationType mutationLevel = MutationType(mutationLevelRaw);
        TokenTraitInfo[] memory traits = this.getAllTraits(tokenId);
        
        return TokenCompleteInfo({
            tokenId: tokenId,
            generation: generation,
            mutationLevel: mutationLevel,
            canReplicate: canReplicate,
            replicationCount: replicationCount,
            lastReplication: lastReplication,
            hasBeenModified: isModified,
            skinId: skinId,
            traits: traits
        });
    }

    // =============== Extension Management ===============

    /**
     * @dev Set history contract
     */
    function setHistoryContract(address _historyContract) external onlyOwner {
        historyContract = _historyContract;
    }

    // =============== Token Receiver ===============
    
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

    // =============== Admin Functions ===============

    /**
     * @dev Duplicate GEN0 tokens (delegates to core)
     */
    function duplicateGen0Tokens(uint256[] calldata tokenIds) external onlyOwner {
        IAdrianLabCore(coreContract).duplicateGen0Tokens(tokenIds);
    }

    /**
     * @dev Set traits contract
     */
    function setTraitsContract(address _traitsContract) external onlyOwner {
        traitsContract = _traitsContract;
        emit TraitContractUpdated(_traitsContract);
    }

    /**
     * @dev Equipar múltiples traits en un token
     */
    function batchEquipTraits(uint256 tokenId, uint256[] calldata traitIds) external onlyAuthorizedExtension nonReentrant {
        require(IERC721(coreContract).ownerOf(tokenId) != address(0), "Token does not exist");
        
        // Array para trackear categorías ya vistas
        bool[] memory seenCategories = new bool[](categoryList.length);

        for (uint256 i = 0; i < traitIds.length; i++) {
            uint256 traitId = traitIds[i];
            require(IAdrianTraitsCore(traitsContract).balanceOf(msg.sender, traitId) >= 1, "Trait not owned");

            (string memory category, bool isTemporary) = IAdrianTraitsCore(traitsContract).getTraitInfo(traitId);
            uint8 assetType = IAdrianTraitsCore(traitsContract).getAssetType(traitId);

            require(assetType == 0, "Only visual traits allowed");
            
            // Encontrar el índice de la categoría
            uint256 categoryIndex;
            bool categoryFound = false;
            
            for (uint256 j = 0; j < categoryList.length; j++) {
                if (keccak256(bytes(categoryList[j])) == keccak256(bytes(category))) {
                    categoryIndex = j;
                    categoryFound = true;
                    break;
                }
            }
            
            require(categoryFound, "Invalid category");
            require(!seenCategories[categoryIndex], "Duplicate category in batch");
            seenCategories[categoryIndex] = true;

            TokenTraitInfo storage currentTrait = tokenEquippedTraits[tokenId][category];

            if (isTemporary) {
                if (!IAdrianTraitsCore(traitsContract).isTemporary(currentTrait.traitId)) {
                    tokenBaseTraits[tokenId][category] = currentTrait;
                }
            } else {
                delete tokenBaseTraits[tokenId][category];
            }

            tokenEquippedTraits[tokenId][category] = TokenTraitInfo({
                category: category,
                traitId: traitId,
                isTemporary: isTemporary,
                equippedAt: block.timestamp
            });
            
            IAdrianTraitsCore(traitsContract).burn(msg.sender, traitId, 1);

            emit TraitEquipped(tokenId, category, traitId);
        }
    }

    /**
     * @dev Set admin contract
     */
    function setAdminContract(address _admin) external onlyOwner {
        adminContract = _admin;
    }

    // =============== Internal Functions ===============

    function _random(uint256 seed, uint256 max) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            blockhash(block.number - 1),
            block.timestamp,
            msg.sender,
            seed
        ))) % max;
    }

    function _mutationTypeToString(MutationType mutation) internal pure returns (string memory) {
        if (mutation == MutationType.MILD) return "MILD";
        if (mutation == MutationType.SEVERE) return "SEVERE";
        return "NONE";
    }
}

// =============== Interfaces ===============

interface IAdrianLabCore {
    function ownerOf(uint256 tokenId) external view returns (address);
    function isGen0Token(uint256 tokenId) external view returns (bool);
    function hasBeenDuplicated(uint256 tokenId) external view returns (bool);
    function hasBeenMutatedBySerum(uint256 tokenId) external view returns (bool);
    function setTokenModified(uint256 tokenId, bool modified) external;
    function setTokenMutationLevel(uint256 tokenId, uint8 mutation) external;
    function duplicateGen0Tokens(uint256[] calldata tokenIds) external;
    function getTokenData(uint256 tokenId) external view returns (
        uint256 generation,
        uint8 mutationLevel,
        bool canReplicate,
        uint256 replicationCount,
        uint256 lastReplication,
        bool hasBeenModified
    );
    function getTokenSkin(uint256 tokenId) external view returns (uint256 skinId, string memory name);
}

interface IAdrianTraitsCore {
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function burn(address from, uint256 id, uint256 amount) external;
    function getTraitInfo(uint256 traitId) external view returns (string memory category, bool isTemporary);
    function getCategory(uint256 traitId) external view returns (string memory);
    function getName(uint256 traitId) external view returns (string memory);
    function isTemporary(uint256 traitId) external view returns (bool);
    function getSerumData(uint256 serumId) external view returns (uint8, string memory, uint256);
    function getAssetCategory(uint256 traitId) external view returns (string memory);
    function getAssetType(uint256 traitId) external view returns (uint8);
}

interface ITraits {
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;
    function burn(address from, uint256 id, uint256 amount) external;
    function getTraitInfo(uint256 traitId) external view returns (string memory category, bool isTemporary);
    function getCategory(uint256 traitId) external view returns (string memory);
    function getName(uint256 traitId) external view returns (string memory);
    function isTemporary(uint256 traitId) external view returns (bool);
    function getSerumData(uint256 serumId) external view returns (uint8, string memory, uint256);
    function getAssetCategory(uint256 traitId) external view returns (string memory);
    function getAssetType(uint256 traitId) external view returns (uint8);
}

interface IAdrianHistory {
    struct HistoricalEvent {
        uint256 timestamp;
        bytes32 eventType;
        address actorAddress;
        bytes eventData;
        uint256 blockNumber;
    }
    function addNarrativeEvent(uint256 tokenId, bytes32 eventType, string memory description, uint256 relatedId) external;
    function recordHistory(uint256 tokenId, bytes32 eventType, bytes memory eventData) external returns (uint256);
    function registerReplication(uint256 parentId, uint256 childId) external;
    function registerMutation(uint256 tokenId, string calldata mutationName) external;
    function registerSerum(uint256 tokenId, uint256 serumId) external;
    function getHistory(uint256 tokenId) external view returns (HistoricalEvent[] memory);
    function setHistoryWriter(address writer, bool authorized) external;
    function resetTokenHistory(uint256 tokenId) external;
}