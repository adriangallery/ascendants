// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AdrianLabCore
 * @dev ERC721 with batches, body types, mutations and extensions
 */
contract AdrianLabCore is ERC721Enumerable, Ownable, ReentrancyGuard {
    using Strings for uint256;

    // =============== Type Definitions ===============
    enum MutationType {
        NONE,
        MILD,
        SEVERE
    }

    struct BatchConfig {
        uint256 id;                    // ID del batch
        uint256 price;                 // Precio en $ADRIAN  
        uint256 maxSupply;             // Cuántos tokens en este batch
        uint256 minted;                // Cuántos ya se han minteado
        bool active;                   // Si está disponible para mint
        string name;                   // Nombre descriptivo del batch
        uint256 startTime;             // Cuándo puede empezar (0 = inmediatamente)
        uint256 endTime;               // Cuándo termina (0 = sin límite)
        uint256 maxPerWallet;          // Máximo de mints por wallet
    }

    struct Skin {
        string name;           // "BaseAdrian", "Medium", "Alien"
        uint256 rarity;        // Peso de rareza (1-1000)
        bool active;           // Si está activo para mint
    }

    // =============== State Variables ===============
    
    // Token counters
    uint256 public tokenCounter;
    uint256 public totalGen0Tokens;

    // Batch system
    mapping(uint256 => BatchConfig) public batches;
    uint256 public activeBatch = 0;        // Batch actualmente activo (0 = ninguno)
    uint256 public nextBatchId = 1;        // Próximo ID disponible
    bool public mintPaused = false;        // Pausa general del mint
    uint256 public mintPrice = 50 * 10**18; // Precio por defecto (legacy)

    // Whitelist system
    mapping(uint256 => bool) public isWhitelistEnabledForBatch;
    mapping(address => mapping(uint256 => bool)) public isWhitelistedForBatch;

    // Mint limits per wallet
    mapping(uint256 => mapping(address => uint256)) public mintedPerWalletPerBatch;

    // Duplicación especial
    mapping(uint256 => bool) public allowedDuplication;

    // Skin system
    mapping(uint256 => Skin) public skins;
    mapping(uint256 => uint256) public tokenSkin; // tokenId => skinId
    uint256 public nextSkinId = 1;
    uint256 public totalSkinWeight;
    bool public randomSkinEnabled = true;
    
    // Base URI for metadata
    string public baseURI = "https://adrianlab.vercel.app/api/metadata/";

    // Payment token
    IERC20 public paymentToken;

    // Replication and mutation settings
    uint256 public replicationChanceForGen0 = 80;
    uint256 public maxReplicationsPerToken = 3;
    uint256 public replicationCooldown = 1 days;
    uint256 public mildMutationChance = 10;
    uint256 public severeMutationChance = 5;

    // Contract references
    address public extensionsContract;
    address public traitsContract;
    address public adrianLabExtensions;
    
    // Financial distribution
    address public treasuryWallet;

    // =============== Token Data Mappings ===============
    
    mapping(uint256 => uint256) public generation;
    mapping(uint256 => bool) public isGen0Token;
    mapping(uint256 => MutationType) public mutationLevel;
    mapping(uint256 => bool) public canReplicate;
    mapping(uint256 => uint256) public replicationCount;
    mapping(uint256 => uint256) public lastReplication;
    mapping(uint256 => bool) public hasBeenModified;
    mapping(uint256 => bool) public hasBeenDuplicated;
    mapping(uint256 => bool) public hasBeenMutatedBySerum;
    
    // NUEVA FUNCIONALIDAD: Módulo de serums y mutación por nombre
    mapping(uint256 => string) public mutationLevelName;
    address public adrianSerumModule;

    // Traits
    // tokenId => category => traitId
    mapping(uint256 => mapping(string => uint256)) public tokenTraits;
    
    // Extension system: function selector => implementation address
    mapping(bytes32 => address) public functionImplementations;

    // =============== Events ===============
    
    // Minting events
    event Mint(address indexed to, uint256 indexed tokenId);
    event BatchCreated(uint256 indexed batchId, string name, uint256 price, uint256 maxSupply);
    event BatchActivated(uint256 indexed batchId);
    event BatchDeactivated(uint256 indexed batchId);
    event BatchCompleted(uint256 indexed batchId, uint256 totalMinted);
    event BatchUpdated(uint256 indexed batchId);
    event MintPriceUpdated(uint256 newPrice);
    event TokenDuplicated(uint256 originalId, uint256 duplicateId, address owner);

    // Skin events
    event SkinCreated(uint256 indexed skinId, string name, uint256 rarity);
    event SkinAssigned(uint256 indexed tokenId, uint256 skinId, string name);
    event RandomSkinToggled(bool enabled);
    event BaseURIUpdated(string newURI);

    // Replication and mutation events
    event ReplicationEnabled(uint256 indexed tokenId);
    event Replicated(uint256 indexed parentId, uint256 indexed childId);
    event MutationAssigned(uint256 indexed tokenId);
    event SerumApplied(uint256 indexed tokenId, uint256 serumId);
    
    // NUEVO EVENTO: Mutación por nombre
    event MutationNameAssigned(uint256 indexed tokenId, string newMutation);

    // Contract events
    event ExtensionsContractUpdated(address newContract);
    event TraitsContractUpdated(address newContract);
    event PaymentTokenUpdated(address newToken);
    event ProceedsWithdrawn(address indexed wallet, uint256 amount);
    event TreasuryWalletUpdated(address newWallet);

    // NEW: Modification events
    event FirstModification(uint256 indexed tokenId);
    event FunctionImplementationUpdated(bytes4 indexed selector, address indexed implementation);

    // Evento para el burn
    event TokenBurnt(uint256 indexed tokenId, address indexed burner);

    // =============== Modifiers ===============
    
    modifier onlyExtensions() {
        require(msg.sender == extensionsContract, "!ext");
        _;
    }

    modifier onlyTraitsContract() {
        require(msg.sender == traitsContract, "!traits");
        _;
    }
    
    // NUEVO MODIFICADOR: Para el módulo de serums
    modifier onlySerumModule() {
        require(msg.sender == adrianSerumModule, "!serum");
        _;
    }

    // =============== Constructor ===============
    
    constructor(
        address _paymentToken,
        address _treasuryWallet
    ) ERC721("BaseAdrians", "BADRIAN") Ownable(msg.sender) {
        paymentToken = IERC20(_paymentToken);
        treasuryWallet = _treasuryWallet;
    }
    
    // =============== NUEVA FUNCIONALIDAD: Módulo de Serums ===============
    
    /**
     * @dev Función llamada solo por el contrato de serums para aplicar una mutación.
     */
    function applyMutationFromSerum(
        uint256 tokenId,
        string calldata newMutation,
        string calldata narrativeText
    ) external onlySerumModule {
        require(_exists(tokenId), "!exist");

        mutationLevelName[tokenId] = newMutation;
        hasBeenModified[tokenId] = true;
        hasBeenMutatedBySerum[tokenId] = true;

        require(adrianLabExtensions != address(0), "Extensions not set");
        AdrianLabExtensions(adrianLabExtensions).registerMutation(tokenId, newMutation);
        AdrianLabExtensions(adrianLabExtensions).registerSerum(tokenId, 0); // 0 indica que no es un serum específico

        emit MutationNameAssigned(tokenId, newMutation);
        
        // Registra el evento narrativo en el contrato de extensiones
        if (extensionsContract != address(0)) {
            // Codifica los datos del evento
            bytes memory eventData = abi.encode(narrativeText, uint256(0));
            IAdrianLabExtensions(extensionsContract).recordHistory(tokenId, keccak256(bytes("MUTATION")), eventData);
        }
    }

    /**
     * @dev Obtiene el nivel de mutación por nombre
     */
    function getMutationLevelName(uint256 tokenId) external view returns (string memory) {
        return mutationLevelName[tokenId];
    }

    // =============== Batch Management Functions ===============

    /**
     * @dev Create new batch
     */
    function createBatch(
        string memory name,
        uint256 price,
        uint256 maxSupply,
        uint256 startTime,
        uint256 endTime,
        bool makeActive,
        bool enableWhitelist,
        uint256 maxPerWallet
    ) public onlyOwner returns (uint256) {
        require(maxSupply > 0, "!supply");
        
        uint256 batchId = nextBatchId++;
        
        batches[batchId] = BatchConfig({
            id: batchId,
            price: price,
            maxSupply: maxSupply,
            minted: 0,
            active: false,
            name: name,
            startTime: startTime,
            endTime: endTime,
            maxPerWallet: maxPerWallet
        });
        
        isWhitelistEnabledForBatch[batchId] = enableWhitelist;
        
        emit BatchCreated(batchId, name, price, maxSupply);
        
        if (makeActive) {
            _setBatchActive(batchId, true);
        }
        
        return batchId;
    }

    /**
     * @dev Activate batch
     */
    function activateBatch(uint256 batchId) external onlyOwner {
        require(batchId < nextBatchId, "!exist");
        require(batches[batchId].minted < batches[batchId].maxSupply, "sold out");
        
        if (activeBatch != 0) {
            batches[activeBatch].active = false;
            emit BatchDeactivated(activeBatch);
        }
        
        _setBatchActive(batchId, true);
    }

    /**
     * @dev Deactivate current batch
     */
    function deactivateCurrentBatch() external onlyOwner {
        if (activeBatch != 0) {
            batches[activeBatch].active = false;
            emit BatchDeactivated(activeBatch);
            activeBatch = 0;
        }
    }

    /**
     * @dev Update batch details
     */
    function updateBatch(
        uint256 batchId,
        uint256 newPrice,
        uint256 newMaxSupply,
        uint256 newStartTime,
        uint256 newEndTime,
        string memory newName
    ) external onlyOwner {
        require(batchId < nextBatchId, "!exist");
        
        BatchConfig storage batch = batches[batchId];
        require(newMaxSupply >= batch.minted, "!supply");
        
        batch.price = newPrice;
        batch.maxSupply = newMaxSupply;
        batch.startTime = newStartTime;
        batch.endTime = newEndTime;
        batch.name = newName;
        
        emit BatchUpdated(batchId);
    }

    /**
     * @dev Update whitelist for a specific batch
     */
    function updateWhitelistForBatch(
        uint256 batchId,
        address[] calldata addresses,
        bool enabled
    ) external onlyOwner {
        require(batchId < nextBatchId, "!batch");
        for (uint256 i = 0; i < addresses.length; i++) {
            isWhitelistedForBatch[addresses[i]][batchId] = enabled;
        }
    }

    /**
     * @dev Enable/disable whitelist for an existing batch
     */
    function setWhitelistEnabledForBatch(uint256 batchId, bool enabled) external onlyOwner {
        require(batchId < nextBatchId, "!batch");
        isWhitelistEnabledForBatch[batchId] = enabled;
    }

    /**
     * @dev Update max mints per wallet for a batch
     */
    function updateMaxPerWallet(uint256 batchId, uint256 newMax) external onlyOwner {
        require(batchId < nextBatchId, "!batch");
        batches[batchId].maxPerWallet = newMax;
    }

    // =============== Skin Management Functions ===============

    /**
     * @dev Create a new skin
     */
    function createSkin(
        string memory name,
        uint256 rarity
    ) public onlyOwner returns (uint256) {
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

    /**
     * @dev Initialize the 3 skin types
     */
    function initializeSkins() external onlyOwner {
        require(nextSkinId == 1, "!init");
        
        createSkin("BaseAdrian", 750);  // 75%
        createSkin("Medium", 240);       // 24%
        createSkin("Alien", 10);         // 1%
        
        randomSkinEnabled = true;
    }
    
    /**
     * @dev Verificar si un token ha sido modificado alguna vez
     */
    function isTokenModified(uint256 tokenId) public view returns (bool) {
        return hasBeenModified[tokenId];
    }

    // Extension System

    /**
     * @dev Set the Extensions contract address
     */
    function setExtensionsContract(address _extensionsContract) external onlyOwner {
        require(_extensionsContract != address(0), "Invalid address");
        extensionsContract = _extensionsContract;
        emit ExtensionsContractUpdated(_extensionsContract);
    }

    // Function implementation management moved to AdrianLabAdmin contract

    // =============== Main Minting Functions ===============

    /**
     * @dev Mint from active batch
     */
    function mint() external nonReentrant {
        require(!mintPaused && activeBatch != 0, "!active");
        
        BatchConfig storage batch = batches[activeBatch];
        require(batch.active && batch.minted < batch.maxSupply, "!avail");
        
        // Validación de whitelist
        if (isWhitelistEnabledForBatch[activeBatch]) {
            require(
                isWhitelistedForBatch[msg.sender][activeBatch],
                "Not whitelisted for this batch"
            );
        }

        // Validación de límite por wallet
        uint256 userMints = mintedPerWalletPerBatch[activeBatch][msg.sender];
        require(userMints + 1 <= batch.maxPerWallet, "Mint limit exceeded");
        mintedPerWalletPerBatch[activeBatch][msg.sender] += 1;
        
        // Transferir pago solo si el precio es mayor que 0
        if (batch.price > 0) {
            require(paymentToken.transferFrom(msg.sender, treasuryWallet, batch.price), "!pay");
        }
        
        uint256 tokenId = ++tokenCounter;
        
        // Asignaciones básicas
        isGen0Token[tokenId] = true;
        generation[tokenId] = 0;
        totalGen0Tokens++;
        
        // Mint y actualizar batch
        _mint(msg.sender, tokenId);
        batch.minted++;
        
        // Emitir solo el evento principal
        emit Mint(msg.sender, tokenId);
        
        // Verificar si el batch está completo
        if (batch.minted >= batch.maxSupply) {
            batch.active = false;
            activeBatch = 0;
            emit BatchCompleted(batch.id, batch.minted);
        }
    }

    /**
     * @dev Mint multiple tokens in one transaction
     */
    function mintMultiple(uint256 quantity) external nonReentrant {
        require(quantity > 0 && quantity <= 10, "!qty");
        require(!mintPaused && activeBatch != 0, "!active");
        
        BatchConfig storage batch = batches[activeBatch];
        require(batch.active && batch.minted + quantity <= batch.maxSupply, "!avail");
        
        // Validación de whitelist
        if (isWhitelistEnabledForBatch[activeBatch]) {
            require(
                isWhitelistedForBatch[msg.sender][activeBatch],
                "Not whitelisted for this batch"
            );
        }

        // Validación de límite por wallet
        uint256 userMints = mintedPerWalletPerBatch[activeBatch][msg.sender];
        require(userMints + quantity <= batch.maxPerWallet, "Mint limit exceeded");
        mintedPerWalletPerBatch[activeBatch][msg.sender] += quantity;
        
        // Calcular el costo total
        uint256 totalCost = batch.price * quantity;
        
        // Transferir pago solo si el precio es mayor que 0
        if (totalCost > 0) {
            require(paymentToken.transferFrom(msg.sender, treasuryWallet, totalCost), "!pay");
        }
        
        // Mint tokens
        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = ++tokenCounter;
            
            isGen0Token[tokenId] = true;
            generation[tokenId] = 0;
            totalGen0Tokens++;
            
            _mint(msg.sender, tokenId);
            batch.minted++;
            
            emit Mint(msg.sender, tokenId);
        }
        
        // Verificar si el batch está completo
        if (batch.minted >= batch.maxSupply) {
            batch.active = false;
            activeBatch = 0;
            emit BatchCompleted(batch.id, batch.minted);
        }
    }

    /**
     * @dev Replicate a token to create a new one
     */
    function replicate(uint256 tokenId) external nonReentrant {
        require(ownerOf(tokenId) == msg.sender, "!owner");
        require(canReplicate[tokenId], "!can");
        require(replicationCount[tokenId] < maxReplicationsPerToken, "!max");
        require(block.timestamp >= lastReplication[tokenId] + replicationCooldown, "!cool");
        
        // Mutation restrictions
        if (mutationLevel[tokenId] == MutationType.MILD) {
            require(replicationCount[tokenId] == 0, "!mild");
        } else if (mutationLevel[tokenId] == MutationType.SEVERE) {
            revert("!severe");
        }
        
        uint256 newTokenId = ++tokenCounter;
        
        generation[newTokenId] = generation[tokenId] + 1;
        mutationLevel[newTokenId] = _determineMutation(tokenId);
        
        // Inherit skin from parent
        tokenSkin[newTokenId] = tokenSkin[tokenId];
        
        // Set replication ability for new token
        if (mutationLevel[newTokenId] == MutationType.NONE || 
            mutationLevel[newTokenId] == MutationType.MILD) {
            if (_randomChance(50)) {
                canReplicate[newTokenId] = true;
                emit ReplicationEnabled(newTokenId);
            }
        }
        
        _mint(msg.sender, newTokenId);
        
        replicationCount[tokenId]++;
        lastReplication[tokenId] = block.timestamp;
        
        // Notify extensions contract
        if (extensionsContract != address(0)) {
            IAdrianLabExtensions(extensionsContract).onTokenReplicated(tokenId, newTokenId);
        }
        
        emit Replicated(tokenId, newTokenId);
        
        if (mutationLevel[newTokenId] != MutationType.NONE) {
            emit MutationAssigned(newTokenId);
        }
    }

    // =============== Token Data Management ===============

    /**
     * @dev Get current batch info
     */
    function getCurrentBatchInfo() external view returns (
        uint256 batchId,
        string memory name,
        uint256 price,
        uint256 minted,
        uint256 maxSupply,
        bool active,
        uint256 startTime,
        uint256 endTime
    ) {
        if (activeBatch == 0) {
            return (0, "", 0, 0, 0, false, 0, 0);
        }
        
        BatchConfig storage batch = batches[activeBatch];
        return (
            batch.id,
            batch.name,
            batch.price,
            batch.minted,
            batch.maxSupply,
            batch.active,
            batch.startTime,
            batch.endTime
        );
    }

    /**
     * @dev Get specific batch info
     */
    function getBatchInfo(uint256 batchId) external view returns (
        uint256 id,
        string memory name,
        uint256 price,
        uint256 minted,
        uint256 maxSupply,
        bool active,
        uint256 startTime,
        uint256 endTime
    ) {
        require(batchId < nextBatchId, "!exist");
        
        BatchConfig storage batch = batches[batchId];
        return (
            batch.id,
            batch.name,
            batch.price,
            batch.minted,
            batch.maxSupply,
            batch.active,
            batch.startTime,
            batch.endTime
        );
    }

    /**
     * @dev Check if user can mint
     */
    function canMint() external view returns (
        bool mintable,
        string memory reason,
        uint256 price,
        uint256 available
    ) {
        if (mintPaused) {
            return (false, "paused", 0, 0);
        }
        
        if (activeBatch == 0) {
            return (false, "no batch", 0, 0);
        }
        
        BatchConfig storage batch = batches[activeBatch];
        
        if (!batch.active) {
            return (false, "!active", 0, 0);
        }
        
        if (batch.minted >= batch.maxSupply) {
            return (false, "sold out", 0, 0);
        }
        
        if (batch.startTime > 0 && block.timestamp < batch.startTime) {
            return (false, "!started", 0, 0);
        }
        
        if (batch.endTime > 0 && block.timestamp > batch.endTime) {
            return (false, "ended", 0, 0);
        }
        
        return (
            true, 
            "ok", 
            batch.price, 
            batch.maxSupply - batch.minted
        );
    }

    /**
     * @dev Get skin info
     */
    function getSkin(uint256 skinId) external view returns (
        string memory name,
        uint256 rarity,
        bool active
    ) {
        Skin storage skin = skins[skinId];
        return (
            skin.name,
            skin.rarity,
            skin.active
        );
    }

    /**
     * @dev Get token's skin
     */
    function getTokenSkin(uint256 tokenId) external view returns (
        uint256 skinId,
        string memory name
    ) {
        require(_exists(tokenId), "!exist");
        
        skinId = tokenSkin[tokenId];
        if (skinId > 0) {
            return (skinId, skins[skinId].name);
        }
        
        return (0, "BaseAdrian");
    }

    /**
     * @dev Calculate rarity percentage
     */
    function getSkinRarityPercentage(uint256 skinId) external view returns (uint256) {
        if (totalSkinWeight == 0) return 0;
        return (skins[skinId].rarity * 10000) / totalSkinWeight;
    }

    /**
     * @dev Get basic token data
     */
    function getTokenData(uint256 tokenId) external view returns (
        uint256 tokenGeneration,
        MutationType tokenMutationLevel,
        bool tokenCanReplicate,
        uint256 tokenReplicationCount,
        uint256 tokenLastReplication,
        bool tokenHasBeenModified
    ) {
        require(_exists(tokenId), "!exist");
        
        return (
            generation[tokenId],
            mutationLevel[tokenId],
            canReplicate[tokenId],
            replicationCount[tokenId],
            lastReplication[tokenId],
            hasBeenModified[tokenId]
        );
    }

    /**
     * @dev Get tokens owned by address
     */
    function getTokensOfOwner(address owner) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(owner);
        uint256[] memory tokenIds = new uint256[](tokenCount);
        
        for (uint256 i = 0; i < tokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(owner, i);
        }
        
        return tokenIds;
    }

    /**
     * @dev Check if token is eligible for mutation (duplication or serum)
     */
    function isEligibleForMutation(uint256 tokenId) external view returns (bool) {
        return isGen0Token[tokenId] && 
               !hasBeenDuplicated[tokenId] && 
               !hasBeenMutatedBySerum[tokenId] &&
               _exists(tokenId);
    }

    /**
     * @dev Token URI - returns baseURI + tokenId
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "!exist");
        return string(abi.encodePacked(baseURI, tokenId.toString()));
    }

    // =============== Admin Functions ===============

    /**
     * @dev Set traits contract
     */
    function setTraitsContract(address _traitsContract) external onlyOwner {
        traitsContract = _traitsContract;
        emit TraitsContractUpdated(_traitsContract);
    }

    /**
     * @dev Set payment token
     */
    function setPaymentToken(address _paymentToken) external onlyOwner {
        paymentToken = IERC20(_paymentToken);
        emit PaymentTokenUpdated(_paymentToken);
    }

    /**
     * @dev Set mint price (legacy support)
     */
    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
        emit MintPriceUpdated(newPrice);
    }

    /**
     * @dev Toggle mint pause
     */
    function setMintPaused(bool paused) external onlyOwner {
        mintPaused = paused;
    }

    /**
     * @dev Set replication settings
     */
    function setReplicationSettings(
        uint256 chance,
        uint256 maxReplications,
        uint256 cooldown
    ) external onlyOwner {
        require(chance <= 100, "!chance");
        
        replicationChanceForGen0 = chance;
        maxReplicationsPerToken = maxReplications;
        replicationCooldown = cooldown;
    }

    /**
     * @dev Set mutation probabilities
     */
    function setMutationProbabilities(
        uint256 mild,
        uint256 severe
    ) external onlyOwner {
        require(mild + severe <= 100, "!chance");
        
        mildMutationChance = mild;
        severeMutationChance = severe;
    }

    /**
     * @dev Withdraw pending proceeds
     */
    function withdrawProceeds(address wallet) external onlyOwner {
        uint256 amount = paymentToken.balanceOf(address(this));
        require(amount > 0, "!funds");
        paymentToken.transfer(wallet, amount);
        emit ProceedsWithdrawn(wallet, amount);
    }

    /**
     * @dev Emergency withdraw tokens
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner(), amount);
    }

    function assignTokenAttributes(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "!owner");
        require(tokenSkin[tokenId] == 0, "!assigned");
        
        // Asignar skin si está habilitado
        if (randomSkinEnabled && totalSkinWeight > 0) {
            uint256 skinId = _selectRandomSkin();
            tokenSkin[tokenId] = skinId;
            emit SkinAssigned(tokenId, skinId, skins[skinId].name);
        }
        
        // Verificar replicación
        if (!canReplicate[tokenId] && _randomChance(replicationChanceForGen0)) {
            canReplicate[tokenId] = true;
            emit ReplicationEnabled(tokenId);
        }
    }

    function setTreasuryWallet(address _treasuryWallet) external onlyOwner {
        require(_treasuryWallet != address(0), "!zero");
        treasuryWallet = _treasuryWallet;
        emit TreasuryWalletUpdated(_treasuryWallet);
    }

    /**
     * @dev Marcar un token como duplicable
     */
    function setAllowedDuplication(uint256 tokenId, bool allowed) external onlyOwner {
        allowedDuplication[tokenId] = allowed;
    }

    /**
     * @dev Marcar múltiples tokens como duplicables
     */
    function setAllowedDuplicationBatch(uint256[] calldata tokenIds, bool allowed) external onlyOwner {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            allowedDuplication[tokenIds[i]] = allowed;
        }
    }

    /**
     * @dev Obtener tokens duplicables de un owner
     */
    function getDuplicableTokens(address owner) external view returns (uint256[] memory) {
        uint256 balance = balanceOf(owner);
        uint256 count;
        uint256[] memory temp = new uint256[](balance);

        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(owner, i);

            if (
                !hasBeenDuplicated[tokenId] &&
                mutationLevel[tokenId] == MutationType.NONE &&
                _canDuplicate(tokenId)
            ) {
                temp[count] = tokenId;
                count++;
            }
        }

        uint256[] memory result = new uint256[](count);
        for (uint256 j = 0; j < count; j++) {
            result[j] = temp[j];
        }

        return result;
    }

    // Agregar después de las otras variables de estado
    IAdrianHistory public history;

    /**
     * @dev Set history contract
     */
    function setHistoryContract(address _history) external onlyOwner {
        history = IAdrianHistory(_history);
    }

    /**
     * @dev Quema un token NFT
     * @param tokenId ID del token a quemar
     */
    function burn(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender || getApproved(tokenId) == msg.sender || isApprovedForAll(ownerOf(tokenId), msg.sender), "Not owner or approved");
        
        // Registrar el evento en el historial antes de quemar
        if (address(history) != address(0)) {
            history.recordEvent(
                tokenId,
                "BURNT",
                msg.sender,
                abi.encode("sacrifice"),
                block.number
            );
        }

        // Resetear el estado del token
        hasBeenModified[tokenId] = false;
        delete mutationLevel[tokenId];
        
        // Emitir evento
        emit TokenBurnt(tokenId, msg.sender);
        
        // Quemar el token
        _burn(tokenId);
    }

    // =============== Internal Functions ===============

    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    function _setBatchActive(uint256 batchId, bool active) internal {
        batches[batchId].active = active;
        
        if (active) {
            activeBatch = batchId;
            emit BatchActivated(batchId);
        } else {
            if (activeBatch == batchId) {
                activeBatch = 0;
            }
            emit BatchDeactivated(batchId);
        }
    }

    function _selectRandomSkin() internal view returns (uint256) {
        if (totalSkinWeight == 0) return 0;
        
        uint256 randomValue = _random(block.timestamp, totalSkinWeight);
        uint256 cumulativeWeight = 0;
        
        for (uint256 i = 1; i < nextSkinId; i++) {
            if (skins[i].active) {
                cumulativeWeight += skins[i].rarity;
                if (randomValue < cumulativeWeight) {
                    return i;
                }
            }
        }
        
        return 1;
    }

    function _determineMutation(uint256 parentId) internal view returns (MutationType) {
        if (mutationLevel[parentId] == MutationType.MILD) {
            uint256 rand = _random(parentId, 100);
            if (rand < 80) return MutationType.SEVERE;
            return MutationType.MILD;
        } else {
            uint256 rand = _random(parentId, 100);
            
            if (rand < mildMutationChance) return MutationType.MILD;
            if (rand < mildMutationChance + severeMutationChance) return MutationType.SEVERE;
            
            return MutationType.NONE;
        }
    }

    function _determineRandomMutation() internal view returns (MutationType) {
        require(
            mildMutationChance + severeMutationChance <= 100,
            "!prob"
        );
        
        uint256 randomNum = uint256(keccak256(abi.encodePacked(
            block.timestamp, 
            block.prevrandao,
            msg.sender,
            tokenCounter
        ))) % 100 + 1;
        
        if (randomNum <= mildMutationChance) return MutationType.MILD;
        if (randomNum <= mildMutationChance + severeMutationChance) return MutationType.SEVERE;
        
        return MutationType.NONE;
    }

    function _random(uint256 seed, uint256 max) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            blockhash(block.number - 1),
            block.timestamp,
            msg.sender,
            seed
        ))) % max;
    }

    function _randomChance(uint256 chance) internal view returns (bool) {
        require(chance <= 100, "!chance");
        return _random(tokenCounter, 100) < chance;
    }

    /**
     * @dev Verificar si un token puede ser duplicado
     */
    function _canDuplicate(uint256 tokenId) internal view returns (bool) {
        if (generation[tokenId] == 0) return true;
        return allowedDuplication[tokenId];
    }

    // Extension System: Fallback

    /**
     * @dev Fallback function: delega llamadas a extensiones mapeadas
     */
    fallback() external payable {
        bytes32 key = keccak256("ADMIN");
        address impl = functionImplementations[key];
        require(impl != address(0), "Admin module not set");

        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    /**
     * @dev Receive function para aceptar ETH
     */
    receive() external payable {}
}

// =============== Interfaces ===============

interface AdrianLabExtensions {
    function registerReplication(uint256 parentId, uint256 childId) external;
    function registerMutation(uint256 tokenId, string calldata mutation) external;
    function registerSerum(uint256 tokenId, uint256 serumId) external;
}

interface IAdrianLabExtensions {
    function onTokenMinted(uint256 tokenId, address to) external;
    function onTokenReplicated(uint256 parentId, uint256 childId) external;
    function onTokenDuplicated(uint256 originalId, uint256 newId) external;
    function onSerumApplied(uint256 tokenId, uint256 serumId) external;
    function getTokenURI(uint256 tokenId) external view returns (string memory);
    function recordHistory(uint256 tokenId, bytes32 eventType, bytes calldata eventData) external returns (uint256);
}

interface ITraitsContract {
    function getCategory(uint256 traitId) external view returns (string memory);
}

// Agregar después de las otras interfaces
interface IAdrianHistory {
    function recordEvent(
        uint256 tokenId,
        string calldata eventType,
        address caller,
        bytes calldata eventData,
        uint256 blockNumber
    ) external;
}