// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

// =============== FASE 2+ CONSTANTS ===============

uint256 constant TRAIT_ID_MAX = 99_999;
uint256 constant PACK_ID_MIN = 100_000;
uint256 constant PACK_ID_MAX = 109_999;
uint256 constant SERUM_ID_MIN = 110_000;

// =============== BIBLIOTECAS FASE 2+ ===============

/**
 * @title ExtensionsValidation
 * @dev Biblioteca especializada para validaciones de extensiones FASE 2+
 */
library ExtensionsValidation {
    
    /**
     * @dev Valida rangos de IDs según FASE 2
     */
    function validateIdRanges(uint256 tokenId) internal pure returns (bool isValid, string memory tokenType) {
        if (tokenId <= TRAIT_ID_MAX) return (true, "TOKEN");
        if (tokenId >= PACK_ID_MIN && tokenId <= PACK_ID_MAX) return (false, "PACK");
        if (tokenId >= SERUM_ID_MIN) return (false, "SERUM");
        return (false, "INVALID");
    }
    
    /**
     * @dev Verifica si un token es válido para operaciones de extensión
     */
    function isValidForExtensions(uint256 tokenId) internal pure returns (bool) {
        return tokenId > 0 && tokenId <= TRAIT_ID_MAX; // Solo tokens básicos
    }
    
    /**
     * @dev Valida si una dirección puede ser autorizada como extensión
     */
    function isValidExtensionAddress(address extension) internal view returns (bool) {
        return extension != address(0) && extension.code.length > 0;
    }
    
    /**
     * @dev Calcula prioridad de hook basado en tipo de evento
     */
    function getHookPriority(bytes32 eventType) internal pure returns (uint256) {
        if (eventType == keccak256("MINT")) return 100;
        if (eventType == keccak256("SERUM_USED")) return 90;
        if (eventType == keccak256("DUPLICATED")) return 80;
        if (eventType == keccak256("REPLICATE")) return 70;
        return 50; // Prioridad por defecto
    }
}

/**
 * @title ExtensionsAnalytics
 * @dev Sistema de análisis para extensiones FASE 2+
 */
library ExtensionsAnalytics {
    
    struct ExtensionMetrics {
        uint256 totalHooksExecuted;
        uint256 successfulHooks;
        uint256 failedHooks;
        uint256 lastActivity;
        uint256 averageGasUsed;
    }
    
    /**
     * @dev Calcula métricas básicas de extensión
     */
    function calculateBasicMetrics(
        uint256 totalExecuted,
        uint256 successful,
        uint256 failed
    ) internal view returns (ExtensionMetrics memory metrics) {
        metrics.totalHooksExecuted = totalExecuted;
        metrics.successfulHooks = successful;
        metrics.failedHooks = failed;
        metrics.lastActivity = block.timestamp;
        metrics.averageGasUsed = totalExecuted > 0 ? 50000 : 0; // Placeholder
    }
    
    /**
     * @dev Verifica la salud del sistema de extensiones
     */
    function isSystemHealthy(
        uint256 totalHooks,
        uint256 successfulHooks,
        uint256 lastActivity
    ) internal view returns (bool healthy, string memory reason) {
        if (totalHooks == 0) return (true, "No hooks executed yet");
        
        uint256 successRate = (successfulHooks * 100) / totalHooks;
        if (successRate < 80) return (false, "Success rate below 80%");
        
        if (block.timestamp - lastActivity > 7 days) return (false, "No activity for 7 days");
        
        return (true, "System healthy");
    }
}

// =============== INTERFACES FASE 2+ ===============

interface IAdrianLabCore {
    function ownerOf(uint256 tokenId) external view returns (address);
    function getTokenData(uint256 tokenId) external view returns (
        uint256 tokenGeneration,
        uint8 mutationLevelValue,
        bool canReplicate,
        uint256 replicationCount,
        uint256 lastReplication,
        bool tokenHasBeenModified
    );
    function exists(uint256 tokenId) external view returns (bool);
    function setExtensionsContract(address _extensions) external;
    
    // FASE 2+ - Sistema de skins
    function getTokenSkin(uint256 tokenId) external view returns (uint256 skinId, string memory name);
    function applyMutationSkin(uint256 tokenId, string calldata mutation) external;
    function getAllSkins() external view returns (string[] memory names, uint256[] memory rarities);
}

interface IAdrianTraitsCore {
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function getCategory(uint256 assetId) external view returns (string memory);
    function getTraitInfo(uint256 assetId) external view returns (string memory category, bool isTemp);
    function getName(uint256 assetId) external view returns (string memory);
    function burn(address from, uint256 id, uint256 amount) external;
    function getCategoryList() external view returns (string[] memory);
}

interface IAdrianHistory {
    function recordEvent(
        uint256 tokenId,
        bytes32 eventType,
        address actor,
        bytes calldata eventData,
        uint256 blockNumber
    ) external;
    
    function getHistoryCount(uint256 tokenId) external view returns (uint256);
    function getHistoryEvent(uint256 tokenId, uint256 eventIndex) external view returns (
        uint256 timestamp,
        bytes32 eventType,
        address actorAddress,
        bytes memory eventData,
        uint256 blockNumber
    );
}

interface IAdrianSerumModule {
    function useSerum(uint256 serumId, uint256 tokenId, string calldata narrativeText) external;
    function getSerumData(uint256 serumId) external view returns (string memory targetMutation, uint256 potency);
}

interface IAdrianLabAdmin {
    function isExtensionAuthorized(address extension) external view returns (bool);
    function getSystemConfig() external view returns (bool emergencyMode, bool extensionsEnabled);
}

/**
 * @title AdrianLabExtensions
 * @dev Sistema central de extensiones FASE 2+ COMPLETO
 */
contract AdrianLabExtensions is Ownable, ReentrancyGuard {
    using Strings for uint256;
    using ExtensionsValidation for uint256;
    using ExtensionsAnalytics for uint256;

    // =============== Constants FASE 2+ ===============
    
    bytes32 constant EVENT_MINT = keccak256("MINT");
    bytes32 constant EVENT_REPLICATE = keccak256("REPLICATE");
    bytes32 constant EVENT_MUTATE = keccak256("MUTATE");
    bytes32 constant EVENT_SERUM_USED = keccak256("SERUM_USED");
    bytes32 constant EVENT_DUPLICATED = keccak256("DUPLICATED");
    bytes32 constant EVENT_SKIN_APPLIED = keccak256("SKIN_APPLIED");
    bytes32 constant EVENT_TRAIT_EQUIPPED = keccak256("TRAIT_EQUIPPED");
    bytes32 constant EVENT_PACK_OPENED = keccak256("PACK_OPENED");

    // =============== Type Definitions FASE 2+ ===============
    
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

    enum ExtensionStatus {
        INACTIVE,
        ACTIVE,
        PAUSED,
        EMERGENCY
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
        string skinName;
        uint256 lastExtensionActivity;
    }
    
    struct HookData {
        bytes32 eventType;
        uint256 priority;
        bool enabled;
        uint256 gasLimit;
        uint256 executionCount;
        uint256 failureCount;
    }
    
    struct ExtensionInfo {
        address extensionAddress;
        ExtensionStatus status;
        uint256 totalHooksExecuted;
        uint256 successfulHooks;
        uint256 lastActivity;
        string name;
    }

    // =============== State Variables FASE 2+ ===============
    
    // Contract references
    address public coreContract;
    address public traitsContract;
    address public adminContract;
    address public historyContract;
    address public serumModule;
    
    // Extension system FASE 2+
    mapping(address => bool) public extensionAuthorized;
    mapping(address => ExtensionInfo) public extensionInfo;
    mapping(address => mapping(bytes32 => bool)) public extensionHookPermissions;
    address[] public authorizedExtensions;
    
    // Hook system FASE 2+
    mapping(bytes32 => HookData) public hookData;
    mapping(bytes32 => address[]) public hookExecutors;
    mapping(uint256 => bytes32[]) public tokenActiveHooks;
    bool public hooksEnabled = true;
    uint256 public maxHookExecutors = 10;
    uint256 public defaultHookGasLimit = 100000;
    
    // Emergency system FASE 2+
    bool public emergencyMode = false;
    mapping(bytes4 => bool) public pausedFunctions;
    mapping(address => bool) public emergencyAuthorized;
    uint256 public emergencyModeActivations = 0;
    
    // URI management FASE 2+
    string public baseExternalURI = "https://adrianlab.vercel.app/api/metadata/";
    mapping(uint256 => string) public overrideTokenURIs;
    mapping(uint256 => bool) public uriLocked;
    
    // Analytics FASE 2+
    uint256 public totalHooksExecuted;
    uint256 public totalSuccessfulHooks;
    uint256 public totalFailedHooks;
    uint256 public lastSystemActivity;
    mapping(bytes32 => uint256) public eventTypeCount;
    mapping(address => uint256) public extensionCallCount;
    
    // FASE 1 Integration
    mapping(uint256 => string) public tokenSkinOverrides;
    mapping(string => bool) public supportedMutations;
    uint256 public skinSystemVersion = 2; // FASE 2 version

    // =============== Events FASE 2+ ===============
    
    event SerumUsed(address indexed user, uint256 tokenId, uint256 serumId);
    event TokenDuplicated(uint256 indexed originalTokenId, uint256 indexed newTokenId, MutationType mutationType);
    event TokenMutatedBySerum(uint256 indexed tokenId, MutationType mutationType);
    event FirstModification(uint256 indexed tokenId);
    event ExtensionAuthorized(address indexed extension, bool authorized);
    event EmergencyModeSet(bool enabled);
    event FunctionPauseToggled(bytes4 functionSelector, bool paused);
    event TraitContractUpdated(address newContract);
    event CoreContractUpdated(address newContract);
    event HistoryContractUpdated(address newContract);
    event SerumAppliedFromTraits(address indexed user, uint256 indexed tokenId, uint256 indexed serumId, bool success);
    event HookExecuted(bytes32 indexed hookType, uint256 indexed tokenId, address indexed executor, bool success, uint256 gasUsed);
    
    // Eventos FASE 2+ específicos
    event ExtensionRegistered(address indexed extension, string name, ExtensionStatus status);
    event HookConfigured(bytes32 indexed eventType, uint256 priority, bool enabled, uint256 gasLimit);
    event SystemMetricsUpdated(uint256 totalHooks, uint256 successRate, uint256 lastActivity);
    event SkinSystemUpgraded(uint256 oldVersion, uint256 newVersion);
    event TokenSkinApplied(uint256 indexed tokenId, string skinName, bool viaExtension);
    event EmergencyAction(address indexed actor, string action, bytes data);
    event URILocked(uint256 indexed tokenId, bool locked);

    // =============== Modifiers FASE 2+ ===============
    
    modifier onlyAuthorizedExtension() {
        require(
            msg.sender == owner() || 
            extensionAuthorized[msg.sender] || 
            (adminContract != address(0) && IAdrianLabAdmin(adminContract).isExtensionAuthorized(msg.sender)),
            "Not authorized"
        );
        _;
    }

    modifier onlyCore() {
        require(msg.sender == coreContract, "!core");
        _;
    }

    modifier notPaused(bytes4 selector) {
        require(!emergencyMode || !pausedFunctions[selector], "paused");
        _;
    }

    modifier validToken(uint256 tokenId) {
        require(IAdrianLabCore(coreContract).exists(tokenId), "!exist");
        (bool isValid, string memory tokenType) = tokenId.validateIdRanges();
        require(isValid, string(abi.encodePacked("Invalid token type: ", tokenType)));
        _;
    }

    modifier hooksEnabledCheck() {
        require(hooksEnabled, "Hooks disabled");
        _;
    }
    
    modifier onlyEmergencyAuthorized() {
        require(emergencyAuthorized[msg.sender] || msg.sender == owner(), "Not emergency authorized");
        _;
    }
    
    modifier gasLimited(uint256 gasLimit) {
        uint256 gasStart = gasleft();
        _;
        require(gasStart - gasleft() <= gasLimit, "Gas limit exceeded");
    }

    // =============== Constructor FASE 2+ ===============
    
    constructor(address _coreContract) Ownable(msg.sender) {
        require(_coreContract != address(0) && _coreContract.code.length > 0, "Invalid core contract");
        coreContract = _coreContract;
        
        // Initialize FASE 2+ hooks with priorities
        _initializeHooks();
        
        // Set up emergency authorization
        emergencyAuthorized[msg.sender] = true;
        
        // Initialize supported mutations from FASE 1
        supportedMutations["MILD"] = true;
        supportedMutations["SEVERE"] = true;
        supportedMutations["SPECIAL"] = true;
        
        lastSystemActivity = block.timestamp;
    }

    // =============== Core Contract Hooks FASE 2+ ===============

    /**
     * @dev Called when a token is minted - FASE 2+ OPTIMIZADA
     */
    function onTokenMinted(uint256 tokenId, address to) external onlyCore hooksEnabledCheck validToken(tokenId) {
        _executeHook(EVENT_MINT, tokenId, abi.encode(to, block.timestamp));
    }

    /**
     * @dev Called when a token is replicated - FASE 2+ OPTIMIZADA
     */
    function onTokenReplicated(uint256 parentId, uint256 childId) external onlyCore hooksEnabledCheck {
        require(parentId.isValidForExtensions() && childId.isValidForExtensions(), "Invalid token for replication");
        
        _executeHook(EVENT_REPLICATE, parentId, abi.encode(childId, block.timestamp));
        _executeHook(EVENT_REPLICATE, childId, abi.encode(parentId, block.timestamp));
    }

    /**
     * @dev Called when a token is duplicated - FASE 2+ NUEVA
     */
    function onTokenDuplicated(uint256 originalId, uint256 newId) external onlyCore hooksEnabledCheck validToken(originalId) validToken(newId) {
        // Obtener información de mutación
        (, uint8 mutationTypeRaw,,,, ) = IAdrianLabCore(coreContract).getTokenData(newId);
        MutationType mutationType = MutationType(mutationTypeRaw);
        
        // Aplicar skin si es necesario (FASE 1 integration)
        _handleSkinApplication(newId, originalId);
        
        _executeHook(EVENT_DUPLICATED, originalId, abi.encode(newId, mutationType, block.timestamp));
        
        emit TokenDuplicated(originalId, newId, mutationType);
    }

    /**
     * @dev Called when serum is applied - FASE 2+ OPTIMIZADA
     */
    function onSerumApplied(uint256 tokenId, uint256 serumId) external onlyCore hooksEnabledCheck validToken(tokenId) {
        _executeHook(EVENT_SERUM_USED, tokenId, abi.encode(serumId, block.timestamp));
    }

    // =============== FUNCIONES REQUERIDAS POR OTROS CONTRATOS ===============

    /**
     * @dev Apply serum from traits (REQUERIDA por AdrianTraitsCore)
     */
    function applySerumFromTraits(
        address user,
        uint256 tokenId,
        uint256 serumId
    ) external nonReentrant notPaused(this.applySerumFromTraits.selector) returns (bool) {
        require(msg.sender == traitsContract, "Only traits contract");
        require(IAdrianLabCore(coreContract).ownerOf(tokenId) == user, "Not token owner");
        require(tokenId.isValidForExtensions(), "Invalid token for serum");
        
        bool success = _executeSerumApplication(user, tokenId, serumId);
        
        _executeHook(EVENT_SERUM_USED, tokenId, abi.encode(serumId, user, success, block.timestamp));
        
        emit SerumAppliedFromTraits(user, tokenId, serumId, success);
        return success;
    }

    /**
     * @dev Get token URI - REQUERIDA por AdrianLabCore
     */
    function getTokenURI(uint256 tokenId) external view validToken(tokenId) returns (string memory) {
        if (bytes(overrideTokenURIs[tokenId]).length > 0) {
            return overrideTokenURIs[tokenId];
        }
        return string(abi.encodePacked(baseExternalURI, tokenId.toString()));
    }

    /**
     * @dev Record history - REQUERIDA por múltiples contratos
     */
    function recordHistory(uint256 tokenId, bytes32 eventType, bytes calldata eventData) 
        external 
        onlyAuthorizedExtension 
        validToken(tokenId)
        returns (uint256) 
    {
        if (historyContract == address(0)) return 0;
        
        IAdrianHistory(historyContract).recordEvent(
            tokenId,
            eventType,
            msg.sender,
            eventData,
            block.number
        );
        
        // Update analytics
        extensionCallCount[msg.sender]++;
        lastSystemActivity = block.timestamp;
        
        return 1; // Return success indicator
    }

    // =============== FUNCIONES ESPECÍFICAS FASE 2+ ===============

    /**
     * @dev Apply skin to token (FASE 1 integration)
     */
    function applySkinToToken(uint256 tokenId, string calldata skinName) 
        external 
        onlyAuthorizedExtension 
        validToken(tokenId) 
    {
        require(supportedMutations[skinName] || bytes(skinName).length > 0, "Unsupported skin");
        
        try IAdrianLabCore(coreContract).applyMutationSkin(tokenId, skinName) {
            tokenSkinOverrides[tokenId] = skinName;
            _executeHook(EVENT_SKIN_APPLIED, tokenId, abi.encode(skinName, msg.sender, block.timestamp));
            emit TokenSkinApplied(tokenId, skinName, true);
        } catch {
            // Fallback a override local
            tokenSkinOverrides[tokenId] = skinName;
            emit TokenSkinApplied(tokenId, skinName, false);
        }
    }

    /**
     * @dev Get comprehensive token information - FASE 2+
     */
    function getTokenCompleteInfo(uint256 tokenId) 
        external 
        view 
        validToken(tokenId) 
        returns (TokenCompleteInfo memory info) 
    {
        (
            uint256 generation,
            uint8 mutationLevelValue,
            bool canReplicate,
            uint256 replicationCount,
            uint256 lastReplication,
            bool hasBeenModified
        ) = IAdrianLabCore(coreContract).getTokenData(tokenId);
        
        // Get skin information
        (uint256 skinId, string memory skinName) = _getTokenSkinInfo(tokenId);
        
        return TokenCompleteInfo({
            tokenId: tokenId,
            generation: generation,
            mutationLevel: MutationType(mutationLevelValue),
            canReplicate: canReplicate,
            replicationCount: replicationCount,
            lastReplication: lastReplication,
            hasBeenModified: hasBeenModified,
            skinId: skinId,
            skinName: skinName,
            lastExtensionActivity: lastSystemActivity
        });
    }

    /**
     * @dev Execute batch hooks for multiple tokens
     */
    function executeBatchHooks(
        bytes32 eventType,
        uint256[] calldata tokenIds,
        bytes[] calldata eventDatas
    ) external onlyAuthorizedExtension hooksEnabledCheck {
        require(tokenIds.length == eventDatas.length, "Arrays length mismatch");
        require(tokenIds.length <= 50, "Too many tokens");
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (IAdrianLabCore(coreContract).exists(tokenIds[i])) {
                _executeHook(eventType, tokenIds[i], eventDatas[i]);
            }
        }
    }

    /**
     * @dev Get system analytics
     */
    function getSystemAnalytics() external view returns (
        ExtensionsAnalytics.ExtensionMetrics memory systemMetrics,
        bool systemHealthy,
        string memory healthReason,
        uint256 activeExtensions
    ) {
        systemMetrics = ExtensionsAnalytics.calculateBasicMetrics(
            totalHooksExecuted,
            totalSuccessfulHooks,
            totalFailedHooks
        );
        
        (systemHealthy, healthReason) = ExtensionsAnalytics.isSystemHealthy(
            totalHooksExecuted,
            totalSuccessfulHooks,
            lastSystemActivity
        );
        
        activeExtensions = authorizedExtensions.length;
    }

    // =============== Internal Functions FASE 2+ ===============

    /**
     * @dev Initialize hooks with FASE 2+ configuration
     */
    function _initializeHooks() internal {
        bytes32[] memory eventTypes = new bytes32[](8);
        eventTypes[0] = EVENT_MINT;
        eventTypes[1] = EVENT_REPLICATE;
        eventTypes[2] = EVENT_MUTATE;
        eventTypes[3] = EVENT_SERUM_USED;
        eventTypes[4] = EVENT_DUPLICATED;
        eventTypes[5] = EVENT_SKIN_APPLIED;
        eventTypes[6] = EVENT_TRAIT_EQUIPPED;
        eventTypes[7] = EVENT_PACK_OPENED;
        
        for (uint256 i = 0; i < eventTypes.length; i++) {
            bytes32 eventType = eventTypes[i];
            hookData[eventType] = HookData({
                eventType: eventType,
                priority: ExtensionsValidation.getHookPriority(eventType),
                enabled: true,
                gasLimit: defaultHookGasLimit,
                executionCount: 0,
                failureCount: 0
            });
        }
    }

    /**
     * @dev Execute hook with gas optimization
     */
    function _executeHook(bytes32 eventType, uint256 tokenId, bytes memory eventData) internal {
        if (!hookData[eventType].enabled) return;
        
        uint256 gasStart = gasleft();
        bool success = true;
        
        // Record event directly if history contract is available
        if (historyContract != address(0)) {
            try IAdrianHistory(historyContract).recordEvent(
                    tokenId,
                eventType,
                address(this),
                eventData,
                block.number
            ) {
                // Event recorded successfully
            } catch {
                success = false;
                hookData[eventType].failureCount++;
            }
        }
        
        hookData[eventType].executionCount++;
        totalHooksExecuted++;
        
        if (success) {
            totalSuccessfulHooks++;
        } else {
            totalFailedHooks++;
        }
        
        uint256 gasUsed = gasStart - gasleft();
        lastSystemActivity = block.timestamp;
        eventTypeCount[eventType]++;
        
        emit HookExecuted(eventType, tokenId, address(this), success, gasUsed);
    }

    /**
     * @dev Record history event internal
     */
    function _recordHistoryEvent(uint256 tokenId, bytes32 eventType, bytes memory eventData) internal returns (uint256) {
        if (historyContract == address(0)) return 0;
        
        IAdrianHistory(historyContract).recordEvent(
                    tokenId,
            eventType,
            address(this),
            eventData,
            block.number
        );
        
        return 1;
    }

    /**
     * @dev Execute serum application
     */
    function _executeSerumApplication(address /* user */, uint256 tokenId, uint256 serumId) internal returns (bool) {
        if (serumModule == address(0)) return false;
        
        try IAdrianSerumModule(serumModule).useSerum(serumId, tokenId, "Applied from extensions") {
            return true;
        } catch {
        return false;
        }
    }

    /**
     * @dev Handle skin application for duplication
     */
    function _handleSkinApplication(uint256 newTokenId, uint256 originalTokenId) internal {
        // Get skin from original token
        try IAdrianLabCore(coreContract).getTokenSkin(originalTokenId) returns (uint256, string memory skinName) {
            if (bytes(skinName).length > 0) {
                // Apply same skin to new token
                try IAdrianLabCore(coreContract).applyMutationSkin(newTokenId, skinName) {
                    tokenSkinOverrides[newTokenId] = skinName;
                } catch {
                    // Skin application failed, continue
                }
            }
        } catch {
            // Original token has no skin, continue
        }
    }

    /**
     * @dev Get token skin information
     */
    function _getTokenSkinInfo(uint256 tokenId) internal view returns (uint256 skinId, string memory skinName) {
        // Check local override first
        if (bytes(tokenSkinOverrides[tokenId]).length > 0) {
            return (1, tokenSkinOverrides[tokenId]);
        }
        
        // Check core contract
        try IAdrianLabCore(coreContract).getTokenSkin(tokenId) returns (uint256 id, string memory name) {
            return (id, name);
        } catch {
            return (0, "");
        }
    }

    // =============== View Functions FASE 2+ ===============

    /**
     * @dev Check if hook is enabled
     */
    function isHookEnabled(bytes32 hookType) external view returns (bool) {
        return hooksEnabled && hookData[hookType].enabled;
    }

    /**
     * @dev Get hook information
     */
    function getHookInfo(bytes32 eventType) external view returns (HookData memory) {
        return hookData[eventType];
    }

    /**
     * @dev Get extension information
     */
    function getExtensionInfo(address extension) external view returns (ExtensionInfo memory) {
        return extensionInfo[extension];
    }

    /**
     * @dev Get all authorized extensions
     */
    function getAuthorizedExtensions() external view returns (address[] memory) {
        return authorizedExtensions;
    }

    /**
     * @dev Get event type statistics
     */
    function getEventTypeStats(bytes32 eventType) external view returns (
        uint256 totalExecutions,
        uint256 failures,
        uint256 successRate,
        bool enabled
    ) {
        HookData memory hook = hookData[eventType];
        totalExecutions = hook.executionCount;
        failures = hook.failureCount;
        successRate = totalExecutions > 0 ? ((totalExecutions - failures) * 100) / totalExecutions : 0;
        enabled = hook.enabled;
    }

    // =============== Admin Functions FASE 2+ ===============

    function setTraitsContract(address _traitsContract) external onlyOwner {
        require(_traitsContract != address(0) && _traitsContract.code.length > 0, "Invalid address");
        traitsContract = _traitsContract;
        emit TraitContractUpdated(_traitsContract);
    }

    function setCoreContract(address _coreContract) external onlyOwner {
        require(_coreContract != address(0) && _coreContract.code.length > 0, "Invalid address");
        coreContract = _coreContract;
        emit CoreContractUpdated(_coreContract);
    }

    function setHistoryContract(address _historyContract) external onlyOwner {
        require(_historyContract != address(0) && _historyContract.code.length > 0, "Invalid contract");
        historyContract = _historyContract;
        emit HistoryContractUpdated(_historyContract);
    }

    function setSerumModule(address _serumModule) external onlyOwner {
        require(_serumModule != address(0) && _serumModule.code.length > 0, "Invalid module");
        serumModule = _serumModule;
    }

    function setAdminContract(address _adminContract) external onlyOwner {
        require(_adminContract != address(0), "Invalid address");
        adminContract = _adminContract;
    }

    /**
     * @dev Register extension with full info
     */
    function registerExtension(
        address extension,
        string calldata name,
        bool authorized
    ) external onlyOwner {
        require(ExtensionsValidation.isValidExtensionAddress(extension), "Invalid extension");
        
        if (authorized && !extensionAuthorized[extension]) {
            authorizedExtensions.push(extension);
        }
        
        extensionAuthorized[extension] = authorized;
        extensionInfo[extension] = ExtensionInfo({
            extensionAddress: extension,
            status: authorized ? ExtensionStatus.ACTIVE : ExtensionStatus.INACTIVE,
            totalHooksExecuted: 0,
            successfulHooks: 0,
            lastActivity: block.timestamp,
            name: name
        });
        
        emit ExtensionRegistered(extension, name, extensionInfo[extension].status);
        emit ExtensionAuthorized(extension, authorized);
    }

    /**
     * @dev Configure hook settings
     */
    function configureHook(
        bytes32 eventType,
        bool enabled,
        uint256 gasLimit,
        uint256 priority
    ) external onlyOwner {
        hookData[eventType].enabled = enabled;
        hookData[eventType].gasLimit = gasLimit;
        hookData[eventType].priority = priority;
        
        emit HookConfigured(eventType, priority, enabled, gasLimit);
    }

    /**
     * @dev Batch configure hooks
     */
    function batchConfigureHooks(
        bytes32[] calldata eventTypes,
        bool[] calldata enabled,
        uint256[] calldata gasLimits
    ) external onlyOwner {
        require(eventTypes.length == enabled.length && enabled.length == gasLimits.length, "Arrays length mismatch");
        
        for (uint256 i = 0; i < eventTypes.length; i++) {
            hookData[eventTypes[i]].enabled = enabled[i];
            hookData[eventTypes[i]].gasLimit = gasLimits[i];
            emit HookConfigured(eventTypes[i], hookData[eventTypes[i]].priority, enabled[i], gasLimits[i]);
        }
    }

    /**
     * @dev Set supported mutations
     */
    function setSupportedMutation(string calldata mutation, bool supported) external onlyOwner {
        supportedMutations[mutation] = supported;
    }

    /**
     * @dev Upgrade skin system
     */
    function upgradeSkinSystem(uint256 newVersion) external onlyOwner {
        uint256 oldVersion = skinSystemVersion;
        skinSystemVersion = newVersion;
        emit SkinSystemUpgraded(oldVersion, newVersion);
    }

    /**
     * @dev Lock/unlock token URI
     */
    function setTokenURILocked(uint256 tokenId, bool locked) external onlyOwner {
        uriLocked[tokenId] = locked;
        emit URILocked(tokenId, locked);
    }

    /**
     * @dev Set custom token URI (only if not locked)
     */
    function setCustomTokenURI(uint256 tokenId, string calldata uri) external onlyOwner {
        require(!uriLocked[tokenId], "URI locked");
        overrideTokenURIs[tokenId] = uri;
    }

    /**
     * @dev Set base external URI
     */
    function setBaseExternalURI(string calldata newBaseURI) external onlyOwner {
        baseExternalURI = newBaseURI;
    }

    /**
     * @dev Set hooks enabled globally
     */
    function setHooksEnabled(bool enabled) external onlyOwner {
        hooksEnabled = enabled;
    }

    /**
     * @dev Set emergency mode
     */
    function setEmergencyMode(bool enabled) external onlyOwner {
        emergencyMode = enabled;
        if (enabled) {
            emergencyModeActivations++;
        }
        emit EmergencyModeSet(enabled);
    }

    /**
     * @dev Set function paused
     */
    function setFunctionPaused(bytes4 functionSelector, bool paused) external onlyOwner {
        pausedFunctions[functionSelector] = paused;
        emit FunctionPauseToggled(functionSelector, paused);
    }

    /**
     * @dev Set emergency authorized
     */
    function setEmergencyAuthorized(address account, bool authorized) external onlyOwner {
        emergencyAuthorized[account] = authorized;
    }

    // =============== Emergency Functions FASE 2+ ===============

    /**
     * @dev Emergency disable all hooks
     */
    function emergencyDisableHooks() external onlyEmergencyAuthorized {
        hooksEnabled = false;
        emit EmergencyAction(msg.sender, "DISABLE_HOOKS", "");
    }

    /**
     * @dev Emergency reset hook counters
     */
    function emergencyResetHookCounters() external onlyEmergencyAuthorized {
        totalHooksExecuted = 0;
        totalSuccessfulHooks = 0;
        totalFailedHooks = 0;
        lastSystemActivity = block.timestamp;
        
        emit EmergencyAction(msg.sender, "RESET_COUNTERS", "");
    }

    /**
     * @dev Emergency force record event
     */
    function emergencyForceRecordEvent(
        uint256 tokenId,
        bytes32 eventType,
        bytes calldata eventData
    ) external onlyEmergencyAuthorized {
        _recordHistoryEvent(tokenId, eventType, eventData);
        emit EmergencyAction(msg.sender, "FORCE_RECORD_EVENT", abi.encode(tokenId, eventType));
    }

    // =============== Legacy Support ===============

    /**
     * @dev Legacy function for backward compatibility
     */
    function setExtensionAuthorization(address extension, bool authorized) external onlyOwner {
        extensionAuthorized[extension] = authorized;
        emit ExtensionAuthorized(extension, authorized);
    }
}