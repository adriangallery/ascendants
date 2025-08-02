// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// =============== FASE 2+ CONSTANTS ===============

uint256 constant TRAIT_ID_MAX = 99_999;
uint256 constant PACK_ID_MIN = 100_000;
uint256 constant PACK_ID_MAX = 109_999;
uint256 constant SERUM_ID_MIN = 110_000;

// =============== BIBLIOTECAS FASE 2+ ===============

/**
 * @title DuplicationValidation
 * @dev Biblioteca especializada para validaciones de duplicación FASE 2+
 */
library DuplicationValidation {
    
    /**
     * @dev Valida si un token es válido para duplicación
     */
    function isValidForDuplication(uint256 tokenId) internal pure returns (bool) {
        return tokenId > 0 && tokenId <= TRAIT_ID_MAX; // Solo tokens básicos se pueden duplicar
    }
    
    /**
     * @dev Valida rangos de IDs según FASE 2
     */
    function validateIdRanges(uint256 tokenId) internal pure returns (bool isValid, string memory tokenType) {
        if (tokenId <= TRAIT_ID_MAX) return (true, "TOKEN");
        if (tokenId >= PACK_ID_MIN && tokenId <= PACK_ID_MAX) return (false, "PACK"); // Packs no se duplican
        if (tokenId >= SERUM_ID_MIN) return (false, "SERUM"); // Serums no se duplican
        return (false, "INVALID");
    }
    
    /**
     * @dev Calcula factor de rareza para duplicación
     */
    function calculateRarityFactor(uint256 generation, string memory mutation) internal pure returns (uint256) {
        uint256 baseRarity = 100;
        
        // Factor por generación
        if (generation >= 3) baseRarity += 50;
        if (generation >= 5) baseRarity += 100;
        
        // Factor por mutación
        bytes32 mutationHash = keccak256(abi.encodePacked(mutation));
        if (mutationHash == keccak256("SPECIAL") || mutationHash == keccak256("LEGENDARY")) {
            baseRarity += 200;
        }
        
        return baseRarity;
    }
    
    /**
     * @dev Valida si un recipient puede recibir duplicados
     */
    function isValidRecipient(address recipient) internal view returns (bool) {
        return recipient != address(0) && recipient.code.length == 0; // Solo EOAs
    }
}

/**
 * @title DuplicationAnalytics
 * @dev Sistema de análisis avanzado para duplicaciones
 */
library DuplicationAnalytics {
    
    struct DuplicationMetrics {
        uint256 totalDuplications;
        uint256 averageGeneration;
        uint256 uniqueMutations;
        uint256 lastActivity;
    }
    
    /**
     * @dev Calcula métricas de duplicación (versión simplificada para evitar problemas de acceso)
     */
    function calculateBasicMetrics(
        uint256[] memory duplicates
    ) internal view returns (DuplicationMetrics memory metrics) {
        metrics.totalDuplications = duplicates.length;
        metrics.lastActivity = block.timestamp;
        
        // Métricas simplificadas para evitar acceso complejo a mappings
        if (duplicates.length == 0) return metrics;
        
        metrics.averageGeneration = 1; // Placeholder simplificado
        metrics.uniqueMutations = duplicates.length > 0 ? 1 : 0; // Placeholder simplificado
    }
}

// =============== INTERFACES FASE 2+ ===============

interface IAdrianLabCore {
    function owner() external view returns (address);
    function safeMint(address to) external returns (uint256);
    function getTraits(uint256 tokenId) external view returns (uint256 generation, uint256 unused, string memory mutation);
    function setTokenInfo(uint256 tokenId, uint256 generation, string calldata mutation) external;
    function ownerOf(uint256 tokenId) external view returns (address);
    function isEligibleForMutation(uint256 tokenId) external view returns (bool);
    function canDuplicate(uint256 tokenId) external view returns (bool);
    function exists(uint256 tokenId) external view returns (bool);
    
    // FASE 2+ - Sistema de skins
    function applyMutationSkin(uint256 tokenId, string calldata mutation) external;
    function getTokenSkin(uint256 tokenId) external view returns (uint256 skinId, string memory name);
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

interface IAdrianLabAdmin {
    function getAssetMaxSupply(uint256 assetId) external view returns (uint256);
    function canTokenBeDuplicated(uint256 tokenId) external view returns (bool allowed, string memory reason);
}

/**
 * @title AdrianDuplicatorModule
 * @dev Sistema avanzado de duplicación de tokens FASE 2+ COMPLETO
 */
contract AdrianDuplicatorModule is Ownable, ReentrancyGuard {
    using DuplicationValidation for uint256;
    
    // =============== State Variables ===============
    
    address public coreContract;
    address public historyContract;
    address public adminContract;

    // Estado interno de duplicaciones FASE 2+
    mapping(uint256 => bool) public hasBeenDuplicated;
    mapping(uint256 => uint256) public duplicatedFromToken; // newTokenId => originalTokenId
    mapping(uint256 => uint256[]) public duplicatesOfToken; // originalTokenId => duplicateIds[]
    mapping(uint256 => uint256) public duplicateCount;
    mapping(uint256 => uint256) public tokenGenerations; // Para analytics
    mapping(uint256 => string) public tokenMutations; // Para analytics
    
    // Control de duplicación avanzado FASE 2+
    mapping(uint256 => uint256) public maxDuplicatesPerToken;
    mapping(string => bool) public bannedMutations; // Mutaciones que no se pueden duplicar
    mapping(address => bool) public authorizedDuplicators; // Direcciones autorizadas adicionales
    uint256 public globalMaxDuplicates = 1;
    bool public duplicationsEnabled = true;
    
    // Sistema de cooldown avanzado
    mapping(uint256 => uint256) public lastDuplicationTime;
    mapping(uint256 => uint256) public customCooldowns; // Cooldowns por token
    uint256 public duplicationCooldown = 24 hours;
    uint256 public minimumCooldown = 1 hours;
    
    // Sistema de costos y restricciones FASE 2+
    mapping(uint256 => uint256) public duplicationCosts; // Costo por token específico
    uint256 public baseDuplicationCost = 0; // Costo base
    bool public costBasedOnGeneration = true;
    bool public costBasedOnRarity = true;
    
    // Analytics y métricas FASE 2+
    uint256 public totalSystemDuplications;
    mapping(address => uint256) public userDuplicationCount;
    mapping(string => uint256) public mutationDuplicationCount;
    uint256 public lastSystemActivity;

    // =============== Events FASE 2+ ===============
    
    event HistoryContractUpdated(address newContract);
    event AdminContractUpdated(address newContract);
    event TokenDuplicated(
        uint256 indexed originalTokenId, 
        uint256 indexed newTokenId, 
        address indexed recipient,
        uint256 generation,
        string mutation,
        uint256 cost
    );
    event DuplicationSettingsUpdated(
        bool enabled, 
        uint256 globalMaxDuplicates, 
        uint256 cooldown
    );
    event TokenDuplicationLimitSet(uint256 indexed tokenId, uint256 maxDuplicates);
    event MutationBanned(string mutation, bool banned);
    event DuplicatorAuthorized(address indexed duplicator, bool authorized);
    event DuplicationCostSet(uint256 indexed tokenId, uint256 cost);
    event SystemMetricsUpdated(uint256 totalDuplications, uint256 lastActivity);
    
    // Eventos específicos FASE 2+
    event SpecialDuplicationEvent(uint256 indexed tokenId, string eventType, bytes data);
    event DuplicationTreeAnalyzed(uint256 indexed rootToken, uint256 totalBranches, uint256 maxDepth);
    event RarityBasedDuplication(uint256 indexed tokenId, uint256 rarityFactor, uint256 adjustedCost);

    // =============== Modifiers FASE 2+ ===============

    modifier onlyCoreOwner() {
        require(msg.sender == IAdrianLabCore(coreContract).owner(), "Not core owner");
        _;
    }

    modifier onlyAuthorizedDuplicator() {
        require(
            msg.sender == IAdrianLabCore(coreContract).owner() || 
            authorizedDuplicators[msg.sender],
            "Not authorized duplicator"
        );
        _;
    }

    modifier duplicationEnabled() {
        require(duplicationsEnabled, "Duplications disabled");
        _;
    }

    modifier validToken(uint256 tokenId) {
        require(IAdrianLabCore(coreContract).exists(tokenId), "Token does not exist");
        (bool isValid, string memory tokenType) = tokenId.validateIdRanges();
        require(isValid, string(abi.encodePacked("Invalid token type: ", tokenType)));
        _;
    }
    
    modifier validForDuplication(uint256 tokenId) {
        require(tokenId.isValidForDuplication(), "Token not valid for duplication");
        _;
    }
    
    modifier notBannedMutation(uint256 tokenId) {
        (, , string memory mutation) = IAdrianLabCore(coreContract).getTraits(tokenId);
        require(!bannedMutations[mutation], "Mutation is banned from duplication");
        _;
    }

    // =============== Constructor ===============
    
    constructor(address _core) Ownable(msg.sender) {
        require(_core != address(0) && _core.code.length > 0, "Invalid address");
        coreContract = _core;
        lastSystemActivity = block.timestamp;
    }

    // =============== ESTRUCTURAS PARA OPTIMIZACIÓN ===============
    
    struct DuplicationData {
        uint256 generation;
        uint256 newGeneration;
        string mutation;
        uint256 cost;
        uint256 newTokenId;
    }

    // =============== Main Duplication Function FASE 2+ OPTIMIZADA ===============

    /**
     * @dev Duplicate an AdrianZERO token - OPTIMIZADA PARA EVITAR STACK TOO DEEP
     */
    function duplicateAdrian(
        uint256 originalTokenId, 
        address recipient
    ) external 
        nonReentrant 
        onlyAuthorizedDuplicator 
        duplicationEnabled 
        validToken(originalTokenId) 
        validForDuplication(originalTokenId)
        notBannedMutation(originalTokenId)
        returns (uint256) 
    {
        // Validaciones básicas
        _validateDuplication(originalTokenId, recipient);
        
        // Obtener y validar datos del token
        DuplicationData memory data = _prepareDuplicationData(originalTokenId);
        
        // Ejecutar duplicación
        data.newTokenId = _executeDuplication(originalTokenId, recipient, data);
        
        // Finalizar proceso
        _finalizeDuplication(originalTokenId, recipient, data);
        
        return data.newTokenId;
    }

    /**
     * @dev Validaciones iniciales de duplicación
     */
    function _validateDuplication(uint256 originalTokenId, address recipient) internal view {
        require(!hasBeenDuplicated[originalTokenId], "Already duplicated");
        require(address(historyContract) != address(0), "History contract not set");
        require(DuplicationValidation.isValidRecipient(recipient), "Invalid recipient");
        require(IAdrianLabCore(coreContract).canDuplicate(originalTokenId), "Token cannot be duplicated");
        
        // Verificar con admin contract si está configurado
        if (adminContract != address(0)) {
            (bool allowed, string memory reason) = IAdrianLabAdmin(adminContract).canTokenBeDuplicated(originalTokenId);
            require(allowed, reason);
        }
        
        // Verificar cooldown personalizado o global
        uint256 cooldown = customCooldowns[originalTokenId];
        if (cooldown == 0) cooldown = duplicationCooldown;
        require(
            block.timestamp >= lastDuplicationTime[originalTokenId] + cooldown,
            "Duplication cooldown active"
        );
        
        // Verificar límites de duplicación
        uint256 maxDups = maxDuplicatesPerToken[originalTokenId];
        if (maxDups == 0) maxDups = globalMaxDuplicates;
        require(duplicateCount[originalTokenId] < maxDups, "Max duplications reached");
    }

    /**
     * @dev Preparar datos para la duplicación
     */
    function _prepareDuplicationData(uint256 originalTokenId) internal view returns (DuplicationData memory data) {
        (data.generation, , data.mutation) = IAdrianLabCore(coreContract).getTraits(originalTokenId);
        data.newGeneration = data.generation + 1;
        data.cost = _calculateDuplicationCost(originalTokenId, data.generation, data.mutation);
    }

    /**
     * @dev Ejecutar el minteo y configuración del nuevo token
     */
    function _executeDuplication(
        uint256 /* originalTokenId */,
        address recipient,
        DuplicationData memory data
    ) internal returns (uint256 newTokenId) {
        // Mintear nuevo token
        newTokenId = IAdrianLabCore(coreContract).safeMint(recipient);

        // Configurar información del nuevo token
        IAdrianLabCore(coreContract).setTokenInfo(newTokenId, data.newGeneration, data.mutation);
        
        // Aplicar skin de mutación si es necesario (FASE 2+)
        if (bytes(data.mutation).length > 0) {
            try IAdrianLabCore(coreContract).applyMutationSkin(newTokenId, data.mutation) {
                // Skin aplicado exitosamente
            } catch {
                // Continuar si falla la aplicación de skin
            }
        }

        return newTokenId;
    }

    /**
     * @dev Finalizar proceso de duplicación y registrar eventos
     */
    function _finalizeDuplication(
        uint256 originalTokenId,
        address recipient,
        DuplicationData memory data
    ) internal {
        // Actualizar estado de duplicación
        hasBeenDuplicated[originalTokenId] = true;
        duplicatedFromToken[data.newTokenId] = originalTokenId;
        duplicatesOfToken[originalTokenId].push(data.newTokenId);
        duplicateCount[originalTokenId]++;
        lastDuplicationTime[originalTokenId] = block.timestamp;
        
        // Guardar datos para analytics
        tokenGenerations[data.newTokenId] = data.newGeneration;
        tokenMutations[data.newTokenId] = data.mutation;
        
        // Actualizar métricas del sistema
        _updateSystemMetrics();
        userDuplicationCount[msg.sender]++;
        mutationDuplicationCount[data.mutation]++;

        // Registrar eventos en AdrianHistory
        _recordDuplicationEvents(originalTokenId, recipient, data);
        
        // Evento especial si es una duplicación rara
        _checkRareDuplication(data);

        emit TokenDuplicated(originalTokenId, data.newTokenId, recipient, data.newGeneration, data.mutation, data.cost);
    }

    /**
     * @dev Registrar eventos en el historial
     */
    function _recordDuplicationEvents(
        uint256 originalTokenId,
        address recipient,
        DuplicationData memory data
    ) internal {
        IAdrianHistory(historyContract).recordEvent(
            originalTokenId,
            keccak256("DUPLICATION_SOURCE"),
            msg.sender,
            abi.encode(data.newTokenId, recipient, data.newGeneration, data.mutation, data.cost, block.timestamp),
            block.number
        );

        IAdrianHistory(historyContract).recordEvent(
            data.newTokenId,
            keccak256("DUPLICATION_CREATED"),
            msg.sender,
            abi.encode(originalTokenId, data.generation, data.newGeneration, data.mutation, data.cost, block.timestamp),
            block.number
        );
    }

    /**
     * @dev Verificar y emitir eventos para duplicaciones raras
     */
    function _checkRareDuplication(DuplicationData memory data) internal {
        uint256 rarityFactor = DuplicationValidation.calculateRarityFactor(data.generation, data.mutation);
        if (rarityFactor > 300) {
            emit SpecialDuplicationEvent(
                data.newTokenId, 
                "RARE_DUPLICATION", 
                abi.encode(rarityFactor, data.generation, data.mutation)
            );
            emit RarityBasedDuplication(data.newTokenId, rarityFactor, data.cost);
        }
    }

    /**
     * @dev Batch duplication FASE 2+ (optimizada para evitar stack issues)
     */
    function batchDuplicateAdrians(
        uint256[] calldata originalTokenIds,
        address[] calldata recipients
    ) external nonReentrant onlyAuthorizedDuplicator duplicationEnabled returns (uint256[] memory newTokenIds) {
        require(originalTokenIds.length == recipients.length, "Arrays length mismatch");
        require(originalTokenIds.length <= 10, "Too many duplications at once");

        newTokenIds = new uint256[](originalTokenIds.length);

        for (uint256 i = 0; i < originalTokenIds.length; i++) {
            newTokenIds[i] = this.duplicateAdrian(originalTokenIds[i], recipients[i]);
        }
        
        // Evento de batch completion simplificado
        emit SpecialDuplicationEvent(
            0,
            "BATCH_DUPLICATION_COMPLETE",
            abi.encode(originalTokenIds.length, block.timestamp)
        );

        return newTokenIds;
    }

    // =============== View Functions FASE 2+ ===============

    /**
     * @dev Check if a token can be duplicated - FASE 2+ COMPLETA
     */
    function canTokenBeDuplicated(uint256 tokenId) external view returns (
        bool canDuplicate,
        string memory reason,
        uint256 estimatedCost,
        uint256 cooldownRemaining
    ) {
        if (!duplicationsEnabled) return (false, "Duplications disabled globally", 0, 0);
        
        (bool isValid, string memory tokenType) = tokenId.validateIdRanges();
        if (!isValid) return (false, string(abi.encodePacked("Invalid type: ", tokenType)), 0, 0);
        
        if (!IAdrianLabCore(coreContract).exists(tokenId)) return (false, "Token does not exist", 0, 0);
        if (hasBeenDuplicated[tokenId]) return (false, "Already duplicated", 0, 0);
        if (!IAdrianLabCore(coreContract).canDuplicate(tokenId)) return (false, "Token not eligible", 0, 0);
        
        // Check banned mutations
        (, , string memory mutation) = IAdrianLabCore(coreContract).getTraits(tokenId);
        if (bannedMutations[mutation]) return (false, "Mutation banned", 0, 0);
        
        // Check cooldown
        uint256 cooldown = customCooldowns[tokenId];
        if (cooldown == 0) cooldown = duplicationCooldown;
        uint256 cooldownEnd = lastDuplicationTime[tokenId] + cooldown;
        if (block.timestamp < cooldownEnd) {
            cooldownRemaining = cooldownEnd - block.timestamp;
            return (false, "Cooldown active", 0, cooldownRemaining);
        }
        
        // Check duplication limits
        uint256 maxDups = maxDuplicatesPerToken[tokenId];
        if (maxDups == 0) maxDups = globalMaxDuplicates;
        if (duplicateCount[tokenId] >= maxDups) {
            return (false, "Max duplications reached", 0, 0);
        }
        
        // Calcular costo estimado
        (uint256 generation, , ) = IAdrianLabCore(coreContract).getTraits(tokenId);
        estimatedCost = _calculateDuplicationCost(tokenId, generation, mutation);
        
        return (true, "Can be duplicated", estimatedCost, 0);
    }

    /**
     * @dev Get comprehensive duplication info FASE 2+ (optimizada)
     */
    function getDuplicationInfo(uint256 tokenId) external view returns (
        bool hasDuplicated,
        uint256 duplicatesCreated,
        uint256 maxDuplicatesAllowed,
        uint256 cooldownRemaining,
        uint256 estimatedCost,
        uint256[] memory duplicateTokenIds
    ) {
        hasDuplicated = hasBeenDuplicated[tokenId];
        duplicatesCreated = duplicateCount[tokenId];
        maxDuplicatesAllowed = maxDuplicatesPerToken[tokenId];
        if (maxDuplicatesAllowed == 0) maxDuplicatesAllowed = globalMaxDuplicates;
        
        uint256 cooldown = customCooldowns[tokenId];
        if (cooldown == 0) cooldown = duplicationCooldown;
        uint256 cooldownEnd = lastDuplicationTime[tokenId] + cooldown;
        cooldownRemaining = block.timestamp < cooldownEnd ? cooldownEnd - block.timestamp : 0;
        
        (, , string memory mutation) = IAdrianLabCore(coreContract).getTraits(tokenId);
        (uint256 generation, , ) = IAdrianLabCore(coreContract).getTraits(tokenId);
        estimatedCost = _calculateDuplicationCost(tokenId, generation, mutation);
        
        duplicateTokenIds = duplicatesOfToken[tokenId];
    }

    /**
     * @dev Get detailed duplication metrics (separate function to avoid stack issues)
     */
    function getDuplicationMetrics(uint256 tokenId) external view returns (
        DuplicationAnalytics.DuplicationMetrics memory metrics
    ) {
        uint256[] memory duplicateTokenIds = duplicatesOfToken[tokenId];
        metrics = DuplicationAnalytics.calculateBasicMetrics(duplicateTokenIds);
    }

    /**
     * @dev Análisis básico de árbol de duplicación FASE 2+ (optimizado)
     */
    function analyzeDuplicationTree(uint256 tokenId) external view returns (
        uint256 rootToken,
        uint256 totalBranches,
        uint256 maxDepth,
        uint256 totalDescendants
    ) {
        // Encontrar token raíz
        uint256 original = duplicatedFromToken[tokenId];
        rootToken = original != 0 ? original : tokenId;
        
        uint256[] memory allDuplicates = duplicatesOfToken[rootToken];
        totalBranches = allDuplicates.length;
        totalDescendants = totalBranches;
        
        // Calcular profundidad máxima
        maxDepth = 0;
        if (totalBranches > 0) {
            for (uint256 i = 0; i < allDuplicates.length; i++) {
                uint256 gen = tokenGenerations[allDuplicates[i]];
                if (gen > maxDepth) maxDepth = gen;
            }
        }
    }

    /**
     * @dev Get detailed tree analysis (separate function to avoid stack issues)
     */
    function getTreeAnalysisDetails(uint256 tokenId) external view returns (
        string[] memory uniqueMutations,
        uint256[] memory generationDistribution
    ) {
        uint256 original = duplicatedFromToken[tokenId];
        uint256 rootToken = original != 0 ? original : tokenId;
        uint256[] memory allDuplicates = duplicatesOfToken[rootToken];
        
        if (allDuplicates.length == 0) {
            uniqueMutations = new string[](0);
            generationDistribution = new uint256[](0);
            return (uniqueMutations, generationDistribution);
        }
        
        // Simplificado para evitar stack issues
        uint256[] memory genDist = new uint256[](5); // Máximo 5 generaciones para simplicidad
        string[] memory mutations = new string[](allDuplicates.length);
        uint256 uniqueCount = 0;
        
        for (uint256 i = 0; i < allDuplicates.length && i < 20; i++) { // Límite para evitar gas issues
            uint256 gen = tokenGenerations[allDuplicates[i]];
            if (gen < 5) genDist[gen]++;
            
            string memory mutation = tokenMutations[allDuplicates[i]];
            if (bytes(mutation).length > 0 && uniqueCount < mutations.length) {
                mutations[uniqueCount] = mutation;
                uniqueCount++;
            }
        }
        
        // Redimensionar arrays
        uniqueMutations = new string[](uniqueCount);
        for (uint256 i = 0; i < uniqueCount; i++) {
            uniqueMutations[i] = mutations[i];
        }
        
        generationDistribution = genDist;
    }

    /**
     * @dev Trigger analysis event for duplication tree (separate function)
     */
    function triggerDuplicationTreeAnalysis(uint256 tokenId) external onlyOwner {
        uint256 original = duplicatedFromToken[tokenId];
        uint256 rootToken = original != 0 ? original : tokenId;
        
        uint256[] memory allDuplicates = duplicatesOfToken[rootToken];
        uint256 totalBranches = allDuplicates.length;
        
        uint256 maxDepth = 0;
        if (totalBranches > 0) {
            for (uint256 i = 0; i < allDuplicates.length; i++) {
                uint256 gen = tokenGenerations[allDuplicates[i]];
                if (gen > maxDepth) maxDepth = gen;
            }
        }
        
        emit DuplicationTreeAnalyzed(rootToken, totalBranches, maxDepth);
    }

    /**
     * @dev Get system-wide analytics FASE 2+ (simplificado)
     */
    function getSystemAnalytics() external view returns (
        uint256 totalDuplications,
        bool systemEnabled,
        uint256 systemCooldown,
        uint256 systemMaxDuplicates,
        uint256 systemUptime
    ) {
        totalDuplications = totalSystemDuplications;
        systemEnabled = duplicationsEnabled;
        systemCooldown = duplicationCooldown;
        systemMaxDuplicates = globalMaxDuplicates;
        systemUptime = block.timestamp - lastSystemActivity;
    }

    // =============== Admin Functions FASE 2+ ===============

    /**
     * @dev Set history contract
     */
    function setHistoryContract(address _historyContract) external onlyOwner {
        require(_historyContract != address(0) && _historyContract.code.length > 0, "Invalid contract");
        historyContract = _historyContract;
        emit HistoryContractUpdated(_historyContract);
    }

    /**
     * @dev Set admin contract
     */
    function setAdminContract(address _adminContract) external onlyOwner {
        require(_adminContract != address(0) && _adminContract.code.length > 0, "Invalid contract");
        adminContract = _adminContract;
        emit AdminContractUpdated(_adminContract);
    }

    /**
     * @dev Set core contract
     */
    function setCoreContract(address _coreContract) external onlyOwner {
        require(_coreContract != address(0) && _coreContract.code.length > 0, "Invalid contract");
        coreContract = _coreContract;
    }

    /**
     * @dev Authorize additional duplicators FASE 2+
     */
    function setAuthorizedDuplicator(address duplicator, bool authorized) external onlyOwner {
        authorizedDuplicators[duplicator] = authorized;
        emit DuplicatorAuthorized(duplicator, authorized);
    }

    /**
     * @dev Ban/unban mutations from duplication FASE 2+
     */
    function setBannedMutation(string calldata mutation, bool banned) external onlyOwner {
        bannedMutations[mutation] = banned;
        emit MutationBanned(mutation, banned);
    }

    /**
     * @dev Set custom cooldown for specific token FASE 2+
     */
    function setCustomCooldown(uint256 tokenId, uint256 cooldownSeconds) external onlyOwner {
        require(cooldownSeconds >= minimumCooldown, "Cooldown too short");
        customCooldowns[tokenId] = cooldownSeconds;
    }

    /**
     * @dev Set duplication cost for specific token FASE 2+
     */
    function setDuplicationCost(uint256 tokenId, uint256 cost) external onlyOwner {
        duplicationCosts[tokenId] = cost;
        emit DuplicationCostSet(tokenId, cost);
    }

    /**
     * @dev Configure cost calculation parameters FASE 2+
     */
    function setCostParameters(
        uint256 _baseCost,
        bool _generationBased,
        bool _rarityBased
    ) external onlyOwner {
        baseDuplicationCost = _baseCost;
        costBasedOnGeneration = _generationBased;
        costBasedOnRarity = _rarityBased;
    }

    /**
     * @dev Emergency functions FASE 2+
     */
    function emergencyResetSystem() external onlyOwner {
        duplicationsEnabled = false;
        totalSystemDuplications = 0;
        lastSystemActivity = block.timestamp;
        
        emit SpecialDuplicationEvent(0, "EMERGENCY_RESET", abi.encode(block.timestamp));
    }

    /**
     * @dev Bulk operations FASE 2+ (optimizada)
     */
    function bulkSetBannedMutations(
        string[] calldata mutations,
        bool[] calldata banned
    ) external onlyOwner {
        require(mutations.length == banned.length, "Arrays length mismatch");
        require(mutations.length <= 50, "Too many mutations"); // Límite para evitar gas issues
        
        for (uint256 i = 0; i < mutations.length; i++) {
            bannedMutations[mutations[i]] = banned[i];
            emit MutationBanned(mutations[i], banned[i]);
        }
    }

    /**
     * @dev Bulk set duplication limits (optimizada)
     */
    function bulkSetDuplicationLimits(
        uint256[] calldata tokenIds,
        uint256[] calldata maxDuplicates
    ) external onlyOwner {
        require(tokenIds.length == maxDuplicates.length, "Arrays length mismatch");
        require(tokenIds.length <= 100, "Too many tokens"); // Límite para evitar gas issues
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            maxDuplicatesPerToken[tokenIds[i]] = maxDuplicates[i];
            emit TokenDuplicationLimitSet(tokenIds[i], maxDuplicates[i]);
        }
    }

    // =============== Internal Functions FASE 2+ ===============

    /**
     * @dev Calculate duplication cost FASE 2+
     */
    function _calculateDuplicationCost(
        uint256 tokenId,
        uint256 generation,
        string memory mutation
    ) internal view returns (uint256) {
        uint256 cost = duplicationCosts[tokenId];
        if (cost > 0) return cost; // Costo personalizado
        
        cost = baseDuplicationCost;
        
        if (costBasedOnGeneration) {
            cost += generation * 100; // 100 wei por generación
        }
        
        if (costBasedOnRarity) {
            uint256 rarityFactor = DuplicationValidation.calculateRarityFactor(generation, mutation);
            cost += (rarityFactor * cost) / 100; // Porcentaje basado en rareza
        }
        
        return cost;
    }

    /**
     * @dev Update system metrics
     */
    function _updateSystemMetrics() internal {
        totalSystemDuplications++;
        lastSystemActivity = block.timestamp;
        emit SystemMetricsUpdated(totalSystemDuplications, lastSystemActivity);
    }

    // =============== Legacy Support ===============

    /**
     * @dev Legacy functions para compatibilidad hacia atrás
     */
    function getOriginalToken(uint256 duplicateTokenId) external view returns (uint256) {
        return duplicatedFromToken[duplicateTokenId];
    }

    function getDuplicatesOfToken(uint256 originalTokenId) external view returns (uint256[] memory) {
        return duplicatesOfToken[originalTokenId];
    }

    function isDuplicate(uint256 tokenId) external view returns (bool) {
        return duplicatedFromToken[tokenId] != 0;
    }

    function getDuplicationTree(uint256 tokenId) external view returns (
        uint256 rootToken,
        uint256[] memory allDuplicates
    ) {
        uint256 original = duplicatedFromToken[tokenId];
        rootToken = original != 0 ? original : tokenId;
        allDuplicates = duplicatesOfToken[rootToken];
    }

    function setDuplicationSettings(
        bool _enabled,
        uint256 _globalMaxDuplicates,
        uint256 _cooldownSeconds
    ) external onlyOwner {
        duplicationsEnabled = _enabled;
        globalMaxDuplicates = _globalMaxDuplicates;
        duplicationCooldown = _cooldownSeconds;
        
        emit DuplicationSettingsUpdated(_enabled, _globalMaxDuplicates, _cooldownSeconds);
    }

    function setTokenDuplicationLimit(uint256 tokenId, uint256 maxDuplicates) external onlyOwner {
        maxDuplicatesPerToken[tokenId] = maxDuplicates;
        emit TokenDuplicationLimitSet(tokenId, maxDuplicates);
    }

    function emergencyResetDuplication(uint256 tokenId) external onlyOwner {
        hasBeenDuplicated[tokenId] = false;
        duplicateCount[tokenId] = 0;
        lastDuplicationTime[tokenId] = 0;
        delete duplicatesOfToken[tokenId];
    }

    function setDuplicationCooldown(uint256 _cooldownSeconds) external onlyOwner {
        duplicationCooldown = _cooldownSeconds;
    }

    function setDuplicationsEnabled(bool _enabled) external onlyOwner {
        duplicationsEnabled = _enabled;
    }
}