// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// =============== INTERFACES ===============

interface IAdrianLabCore {
    function safeMint(address to) external returns (uint256);
    function owner() external view returns (address);
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

contract AdrianMintModule is Ownable, ReentrancyGuard {
    
    // =============== Type Definitions ===============
    
    struct BatchConfig {
        uint256 id;
        uint256 price;
        uint256 maxSupply;
        uint256 minted;
        bool active;
        string name;
        uint256 startTime;
        uint256 endTime;
        uint256 maxPerWallet;
        bool useMerkleWhitelist;
        bytes32 merkleRoot;
    }

    // =============== State Variables ===============
    
    address public coreContract;
    IERC20 public paymentToken;
    address public treasuryWallet;
    address public historyContract;

    mapping(uint256 => BatchConfig) public batches;
    uint256 public activeBatch;
    uint256 public nextBatchId;
    bool public mintPaused;

    mapping(uint256 => bool) public isWhitelistEnabledForBatch;
    mapping(address => mapping(uint256 => bool)) public isWhitelistedForBatch;
    mapping(uint256 => mapping(address => uint256)) public mintedPerWalletPerBatch;

    // System statistics
    uint256 public totalMinted;
    uint256 public totalBatchesCreated;
    mapping(address => uint256) public totalMintedByUser;

    // =============== Events ===============
    
    event BatchCreated(uint256 indexed batchId, string name, uint256 price, uint256 maxSupply);
    event BatchActivated(uint256 indexed batchId);
    event BatchDeactivated(uint256 indexed batchId);
    event BatchCompleted(uint256 indexed batchId, uint256 totalMinted);
    event BatchUpdated(uint256 indexed batchId);
    event MintPriceUpdated(uint256 newPrice);
    event Mint(address indexed to, uint256 indexed tokenId, uint256 indexed batchId);
    event MerkleRootUpdated(uint256 indexed batchId, bytes32 root, bool enabled);
    event HistoryContractUpdated(address newContract);
    event TreasuryWalletUpdated(address newWallet);
    event PaymentTokenUpdated(address newToken);
    event StuckFundsWithdrawn(uint256 amount);
    event BatchPriceUpdated(uint256 indexed batchId, uint256 newPrice);

    // =============== Modifiers ===============
    
    modifier onlyCoreOwner() {
        require(msg.sender == IAdrianLabCore(coreContract).owner(), "Not core owner");
        _;
    }

    modifier notPaused() {
        require(!mintPaused, "Minting paused");
        _;
    }

    modifier validBatch(uint256 batchId) {
        require(batchId < nextBatchId, "Invalid batch");
        _;
    }

    // =============== Constructor ===============
    
    constructor(
        address _coreContract,
        address _paymentToken,
        address _treasuryWallet
    ) Ownable(msg.sender) {
        require(_coreContract != address(0) && _coreContract.code.length > 0, "Invalid core");
        require(_paymentToken != address(0), "Invalid payment token");
        require(_treasuryWallet != address(0), "Invalid treasury");
        
        coreContract = _coreContract;
        paymentToken = IERC20(_paymentToken);
        treasuryWallet = _treasuryWallet;
        nextBatchId = 1; // Start from batch ID 1
    }

    // =============== Batch Management ===============

    function createBatch(
        string memory name,
        uint256 price,
        uint256 maxSupply,
        uint256 startTime,
        uint256 endTime,
        bool makeActive,
        bool enableWhitelist,
        uint256 maxPerWallet
    ) external onlyOwner {
        require(maxSupply > 0, "Invalid supply");
        require(maxPerWallet > 0, "Invalid max per wallet");
        require(bytes(name).length > 0, "Empty name");

        uint256 batchId = nextBatchId++;
        totalBatchesCreated++;

        batches[batchId] = BatchConfig({
            id: batchId,
            price: price,
            maxSupply: maxSupply,
            minted: 0,
            active: false,
            name: name,
            startTime: startTime,
            endTime: endTime,
            maxPerWallet: maxPerWallet,
            useMerkleWhitelist: false,
            merkleRoot: bytes32(0)
        });

        isWhitelistEnabledForBatch[batchId] = enableWhitelist;

        if (makeActive) {
            _activateBatch(batchId);
        }

        emit BatchCreated(batchId, name, price, maxSupply);
    }

    function setMerkleRoot(uint256 batchId, bytes32 root, bool enabled) external onlyOwner validBatch(batchId) {
        batches[batchId].merkleRoot = root;
        batches[batchId].useMerkleWhitelist = enabled;
        emit MerkleRootUpdated(batchId, root, enabled);
    }

    function activateBatch(uint256 batchId) external onlyOwner validBatch(batchId) {
        require(batches[batchId].minted < batches[batchId].maxSupply, "Sold out");
        _activateBatch(batchId);
    }

    function _activateBatch(uint256 batchId) internal {
        if (activeBatch != 0 && batches[activeBatch].active) {
            batches[activeBatch].active = false;
            emit BatchDeactivated(activeBatch);
        }

        activeBatch = batchId;
        batches[batchId].active = true;
        emit BatchActivated(batchId);
    }

    function deactivateCurrentBatch() external onlyOwner {
        if (activeBatch != 0 && batches[activeBatch].active) {
            batches[activeBatch].active = false;
            emit BatchDeactivated(activeBatch);
            activeBatch = 0;
        }
    }

    function updateBatch(
        uint256 batchId,
        uint256 newPrice,
        uint256 newMaxSupply,
        uint256 newStartTime,
        uint256 newEndTime,
        string memory newName
    ) external onlyOwner validBatch(batchId) {
        BatchConfig storage batch = batches[batchId];
        require(newMaxSupply >= batch.minted, "Invalid supply");
        require(bytes(newName).length > 0, "Empty name");
        
        batch.price = newPrice;
        batch.maxSupply = newMaxSupply;
        batch.startTime = newStartTime;
        batch.endTime = newEndTime;
        batch.name = newName;

        emit BatchUpdated(batchId);
    }

    // =============== Minting Functions ===============

    function mint(bytes32[] calldata merkleProof) external nonReentrant notPaused {
        require(activeBatch != 0, "No active batch");
        _executeMint(msg.sender, 1, merkleProof);
    }

    function mintMultiple(uint256 quantity, bytes32[] calldata merkleProof) external nonReentrant notPaused {
        require(quantity > 0 && quantity <= 10, "Invalid quantity");
        require(activeBatch != 0, "No active batch");
        _executeMint(msg.sender, quantity, merkleProof);
    }

    function mintTo(address recipient, uint256 quantity) external onlyCoreOwner nonReentrant {
        require(recipient != address(0), "Invalid recipient");
        require(quantity > 0 && quantity <= 10, "Invalid quantity");
        require(activeBatch != 0, "No active batch");
        
        BatchConfig storage batch = batches[activeBatch];
        require(batch.active && batch.minted + quantity <= batch.maxSupply, "Batch not available");

        _processMint(recipient, quantity);
    }

    function _executeMint(address user, uint256 quantity, bytes32[] calldata merkleProof) internal {
        BatchConfig storage batch = batches[activeBatch];
        require(batch.active && batch.minted + quantity <= batch.maxSupply, "Batch not available");

        // Time validation
        if (batch.startTime > 0) {
            require(block.timestamp >= batch.startTime, "Mint not started");
        }
        if (batch.endTime > 0) {
            require(block.timestamp <= batch.endTime, "Mint ended");
        }

        // Whitelist validation
        if (isWhitelistEnabledForBatch[activeBatch]) {
            require(isWhitelistedForBatch[user][activeBatch], "Not whitelisted");
        }

        if (batch.useMerkleWhitelist) {
            bytes32 leaf = keccak256(abi.encodePacked(user));
            require(MerkleProof.verify(merkleProof, batch.merkleRoot, leaf), "Invalid merkle proof");
        }

        // Wallet limit validation
        uint256 userMints = mintedPerWalletPerBatch[activeBatch][user];
        require(userMints + quantity <= batch.maxPerWallet, "Mint limit exceeded");

        // Payment processing
        if (batch.price > 0) {
            uint256 totalCost = batch.price * quantity;
            require(paymentToken.transferFrom(user, treasuryWallet, totalCost), "Payment failed");
        }

        _processMint(user, quantity);
    }

    function _processMint(address user, uint256 quantity) internal {
        BatchConfig storage batch = batches[activeBatch];
        
        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = IAdrianLabCore(coreContract).safeMint(user);
            
            // Record in history if available
            if (historyContract != address(0)) {
                IAdrianHistory(historyContract).recordEvent(
                    tokenId,
                    keccak256("MINTED"),
                    msg.sender,
                    abi.encode(activeBatch, batch.price, block.timestamp),
                    block.number
                );
            }
            
            emit Mint(user, tokenId, activeBatch);
        }

        // Update tracking
        mintedPerWalletPerBatch[activeBatch][user] += quantity;
        batch.minted += quantity;
        totalMinted += quantity;
        totalMintedByUser[user] += quantity;

        // Check if batch is completed
        if (batch.minted >= batch.maxSupply) {
            batch.active = false;
            activeBatch = 0;
            emit BatchCompleted(batch.id, batch.minted);
        }
    }

    // =============== View Functions ===============

    /**
     * @dev MISSING FUNCTION ADDED - Get mint status (REQUIRED by AdrianLabAdmin)
     */
    function getMintStatus(uint256 /* tokenId */) external view returns (bool) {
        // Returns if minting system is active
        return !mintPaused && activeBatch != 0 && batches[activeBatch].active;
    }

    function getCurrentBatchInfo() external view returns (
        uint256 batchId,
        string memory name,
        uint256 price,
        uint256 minted,
        uint256 maxSupply,
        bool active,
        uint256 startTime,
        uint256 endTime,
        bool useMerkleWhitelist
    ) {
        if (activeBatch == 0) {
            return (0, "", 0, 0, 0, false, 0, 0, false);
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
            batch.endTime,
            batch.useMerkleWhitelist
        );
    }

    function getBatchInfo(uint256 batchId) external view validBatch(batchId) returns (
        uint256 id,
        string memory name,
        uint256 price,
        uint256 minted,
        uint256 maxSupply,
        bool active,
        uint256 startTime,
        uint256 endTime,
        bool useMerkleWhitelist
    ) {
        BatchConfig storage batch = batches[batchId];
        return (
            batch.id,
            batch.name,
            batch.price,
            batch.minted,
            batch.maxSupply,
            batch.active,
            batch.startTime,
            batch.endTime,
            batch.useMerkleWhitelist
        );
    }

    function canMint(address user) external view returns (
        bool mintable,
        string memory reason,
        uint256 price,
        uint256 available
    ) {
        if (mintPaused) {
            return (false, "Minting paused", 0, 0);
        }
        
        if (activeBatch == 0) {
            return (false, "No active batch", 0, 0);
        }
        
        BatchConfig storage batch = batches[activeBatch];
        
        if (!batch.active) {
            return (false, "Batch not active", 0, 0);
        }
        
        if (batch.minted >= batch.maxSupply) {
            return (false, "Sold out", 0, 0);
        }
        
        if (batch.startTime > 0 && block.timestamp < batch.startTime) {
            return (false, "Not started", 0, 0);
        }
        
        if (batch.endTime > 0 && block.timestamp > batch.endTime) {
            return (false, "Ended", 0, 0);
        }

        if (isWhitelistEnabledForBatch[activeBatch] && !isWhitelistedForBatch[user][activeBatch]) {
            return (false, "Not whitelisted", 0, 0);
        }

        uint256 userMinted = mintedPerWalletPerBatch[activeBatch][user];
        if (userMinted >= batch.maxPerWallet) {
            return (false, "Limit reached", 0, 0);
        }
        
        return (
            true, 
            "Can mint", 
            batch.price, 
            batch.maxSupply - batch.minted
        );
    }

    function getUserMintInfo(address user, uint256 batchId) external view returns (
        uint256 mintedInBatch,
        uint256 maxAllowed,
        uint256 remaining,
        bool isWhitelisted
    ) {
        mintedInBatch = mintedPerWalletPerBatch[batchId][user];
        maxAllowed = batches[batchId].maxPerWallet;
        remaining = maxAllowed > mintedInBatch ? maxAllowed - mintedInBatch : 0;
        isWhitelisted = !isWhitelistEnabledForBatch[batchId] || isWhitelistedForBatch[user][batchId];
    }

    function getSystemStats() external view returns (
        uint256 totalMintedTokens,
        uint256 totalBatches,
        uint256 activeBatchId,
        bool systemPaused
    ) {
        return (totalMinted, totalBatchesCreated, activeBatch, mintPaused);
    }

    function getUserStats(address user) external view returns (
        uint256 totalMintedByAddress,
        uint256 mintedInCurrentBatch
    ) {
        totalMintedByAddress = totalMintedByUser[user];
        mintedInCurrentBatch = activeBatch != 0 ? mintedPerWalletPerBatch[activeBatch][user] : 0;
    }

    // =============== Admin Functions ===============

    function setMintPaused(bool paused) external onlyOwner {
        mintPaused = paused;
    }

    function updateWhitelistForBatch(
        uint256 batchId,
        address[] calldata addresses,
        bool enabled
    ) external onlyOwner validBatch(batchId) {
        for (uint256 i = 0; i < addresses.length; i++) {
            isWhitelistedForBatch[addresses[i]][batchId] = enabled;
        }
    }

    function setWhitelistEnabledForBatch(uint256 batchId, bool enabled) external onlyOwner validBatch(batchId) {
        isWhitelistEnabledForBatch[batchId] = enabled;
    }

    function setHistoryContract(address _historyContract) external onlyOwner {
        require(_historyContract != address(0) && _historyContract.code.length > 0, "Invalid contract");
        historyContract = _historyContract;
        emit HistoryContractUpdated(_historyContract);
    }

    function setTreasuryWallet(address _treasuryWallet) external onlyOwner {
        require(_treasuryWallet != address(0), "Invalid treasury");
        treasuryWallet = _treasuryWallet;
        emit TreasuryWalletUpdated(_treasuryWallet);
    }

    function setPaymentToken(address _paymentToken) external onlyOwner {
        require(_paymentToken != address(0), "Invalid payment token");
        paymentToken = IERC20(_paymentToken);
        emit PaymentTokenUpdated(_paymentToken);
    }

    function setCoreContract(address _coreContract) external onlyOwner {
        require(_coreContract != address(0) && _coreContract.code.length > 0, "Invalid core");
        coreContract = _coreContract;
    }

    /**
     * @dev Emergency function to withdraw any stuck tokens
     */
    function emergencyWithdraw(address token, uint256 amount, address to) external onlyOwner {
        require(to != address(0), "Invalid recipient");
        IERC20(token).transfer(to, amount);
    }

    /**
     * @dev Reset user mint count for a batch (emergency function)
     */
    function resetUserMintCount(address user, uint256 batchId) external onlyOwner {
        mintedPerWalletPerBatch[batchId][user] = 0;
    }

    /**
     * @dev Force complete a batch
     */
    function forceCompleteBatch(uint256 batchId) external onlyOwner validBatch(batchId) {
        BatchConfig storage batch = batches[batchId];
        batch.active = false;
        if (activeBatch == batchId) {
            activeBatch = 0;
        }
        emit BatchCompleted(batchId, batch.minted);
    }

    // =============== Whitelist Management ===============

    /**
     * @dev Verifica si un usuario está en la whitelist para un batch específico
     * @param user Dirección del usuario a verificar
     * @param batchId ID del batch
     * @return bool True si el usuario está en la whitelist
     */
    function isUserWhitelisted(address user, uint256 batchId) external view returns (bool) {
        require(batchId < nextBatchId, "Invalid batch");
        return isWhitelistedForBatch[user][batchId];
    }

    // =============== Financial Management ===============

    /**
     * @dev Retira fondos atascados en el contrato
     * @param amount Cantidad a retirar
     */
    function withdrawStuckFunds(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be > 0");
        require(amount <= paymentToken.balanceOf(address(this)), "Insufficient balance");
        
        paymentToken.transfer(treasuryWallet, amount);
        emit StuckFundsWithdrawn(amount);
    }

    /**
     * @dev Actualiza el precio de un batch existente
     * @param batchId ID del batch
     * @param newPrice Nuevo precio en wei
     */
    function updateBatchPrice(uint256 batchId, uint256 newPrice) external onlyOwner validBatch(batchId) {
        require(newPrice > 0, "Price must be > 0");
        batches[batchId].price = newPrice;
        emit BatchPriceUpdated(batchId, newPrice);
    }
    // =============== BATCH PÚBLICO - CÓDIGO A AÑADIR ===============

/**
 * @dev Crea un batch público sin whitelist ni merkle proof
 * @param name Nombre del batch
 * @param price Precio por mint en tokens
 * @param maxSupply Suministro máximo del batch
 * @param startTime Tiempo de inicio (0 para inmediato)
 * @param endTime Tiempo de finalización (0 para sin límite)
 * @param maxPerWallet Máximo por wallet
 * @param makeActive Si activar inmediatamente el batch
 */
function createPublicBatch(
    string memory name,
    uint256 price,
    uint256 maxSupply,
    uint256 startTime,
    uint256 endTime,
    uint256 maxPerWallet,
    bool makeActive
) external onlyOwner {
    require(maxSupply > 0, "Invalid supply");
    require(maxPerWallet > 0, "Invalid max per wallet");
    require(bytes(name).length > 0, "Empty name");

    uint256 batchId = nextBatchId++;
    totalBatchesCreated++;

    batches[batchId] = BatchConfig({
        id: batchId,
        price: price,
        maxSupply: maxSupply,
        minted: 0,
        active: false,
        name: name,
        startTime: startTime,
        endTime: endTime,
        maxPerWallet: maxPerWallet,
        useMerkleWhitelist: false,  // Sin merkle proof
        merkleRoot: bytes32(0)
    });

    // Sin whitelist habilitada
    isWhitelistEnabledForBatch[batchId] = false;

    if (makeActive) {
        _activateBatch(batchId);
    }

    emit BatchCreated(batchId, name, price, maxSupply);
}

/**
 * @dev Mint público sin merkle proof (1 token)
 */
function mintPublic() external nonReentrant notPaused {
    require(activeBatch != 0, "No active batch");
    _executePublicMint(msg.sender, 1);
}

/**
 * @dev Mint público múltiple sin merkle proof
 * @param quantity Cantidad a mintear (1-10)
 */
function mintMultiplePublic(uint256 quantity) external nonReentrant notPaused {
    require(quantity > 0 && quantity <= 10, "Invalid quantity");
    require(activeBatch != 0, "No active batch");
    _executePublicMint(msg.sender, quantity);
}

/**
 * @dev Ejecuta mint público sin validaciones de whitelist ni merkle
 * @param user Usuario que minta
 * @param quantity Cantidad a mintear
 */
function _executePublicMint(address user, uint256 quantity) internal {
    BatchConfig storage batch = batches[activeBatch];
    require(batch.active && batch.minted + quantity <= batch.maxSupply, "Batch not available");

    // Time validation
    if (batch.startTime > 0) {
        require(block.timestamp >= batch.startTime, "Mint not started");
    }
    if (batch.endTime > 0) {
        require(block.timestamp <= batch.endTime, "Mint ended");
    }

    // Wallet limit validation
    uint256 userMints = mintedPerWalletPerBatch[activeBatch][user];
    require(userMints + quantity <= batch.maxPerWallet, "Mint limit exceeded");

    // Payment processing
    if (batch.price > 0) {
        uint256 totalCost = batch.price * quantity;
        require(paymentToken.transferFrom(user, treasuryWallet, totalCost), "Payment failed");
    }

    _processMint(user, quantity);
}

/**
 * @dev Verifica si el batch actual es público (sin whitelist ni merkle)
 * @return bool True si el batch es público
 */
function isCurrentBatchPublic() external view returns (bool) {
    if (activeBatch == 0) {
        return false;
    }
    
    BatchConfig storage batch = batches[activeBatch];
    return !batch.useMerkleWhitelist && !isWhitelistEnabledForBatch[activeBatch];
}

/**
 * @dev Verifica si un batch específico es público
 * @param batchId ID del batch a verificar
 * @return bool True si el batch es público
 */
function isBatchPublic(uint256 batchId) external view validBatch(batchId) returns (bool) {
    BatchConfig storage batch = batches[batchId];
    return !batch.useMerkleWhitelist && !isWhitelistEnabledForBatch[batchId];
}
}