// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/* ================================================================
 *  CUSTOM ERRORS - AHORRO DE BYTECODE
 * ================================================================
 */
error E(uint8 c);

/* ================================================================
 *  CONSTANTS
 * ================================================================
 */
uint256 constant PACK_ID_MIN  = 100_000;
uint256 constant PACK_ID_MAX  = 109_999;
uint256 constant TRAIT_ID_MAX =  99_999;
uint256 constant SERUM_ID_MIN = 110_000;

/* ================================================================
 *  LIBRARIES
 * ================================================================
 */
library SimpleValidation {
    function isTraitAsset(uint256 id) internal pure returns (bool) {
        return id > 0 && id <= TRAIT_ID_MAX;
    }
    function isPackAsset(uint256 id) internal pure returns (bool) {
        return id >= PACK_ID_MIN && id <= PACK_ID_MAX;
    }
    function isSerumAsset(uint256 id) internal pure returns (bool) {
        return id >= SERUM_ID_MIN;
    }
    function isValidPackContent(uint256 id) internal pure returns (bool) {
        return isTraitAsset(id) || isSerumAsset(id);
    }
}

/* ================================================================
 *  CORE INTERFACE - EXACTAMENTE COMO EN EL CONTRATO DESPLEGADO
 * ================================================================
 */
interface IAdrianTraitsCore {
    function getAvailableSupply(uint256 assetId) external view returns (uint256);
    function updatePackMinted(uint256 packId, uint256 amount) external;
    function mintFromExtension(address to, uint256 id, uint256 amount) external;
    function burnFromExtension(address from, uint256 id, uint256 amount) external;
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function treasuryWallet() external view returns (address);
}

/* ================================================================
 *  PACK TOKEN MINTER - SIMPLIFICADO
 * ================================================================
 */
contract AdrianPackTokenMinter is Ownable, ReentrancyGuard {
    using SimpleValidation for uint256;
    using Strings for uint256;

    IAdrianTraitsCore public immutable traitsCore;
    IERC20            public immutable paymentToken;

    // Asset Types
    enum AssetType {
        VISUAL_TRAIT,
        SERUM,
        PACK,
        OTHER
    }

    // Pack Configuration Management
    struct PackConfig {
        uint256 id;
        uint256 publicPrice;           // Precio público
        uint256 maxSupply;
        uint256 minted;
        uint256 itemsPerPack;
        uint256 maxPerWallet;
        bool active;
        bool hasPublicSale;           // Si hay venta pública
        bool hasAllowlist;            // Si hay allowlist
        uint256 allowlistFreeAmount;  // Cantidad gratis por allowlist
        uint256 allowlistPrice;       // Precio después de gratis
        uint256 startTime;
        uint256 endTime;
    }

    struct PackTrait {
        uint256 assetId;      // Trait, Serum, o cualquier asset
        uint256 minAmount;
        uint256 maxAmount;
        AssetType assetType;  // Tipo del asset
    }

    mapping(uint256 => PackConfig) public packConfigs;
    mapping(uint256 => PackTrait[]) public packTraits;

    // Allowlist tracking simplificado
    mapping(uint256 => mapping(address => uint256)) public allowlistFreeClaimed;
    mapping(uint256 => mapping(address => uint256)) public allowlistPaidClaimed;

    // Sistema simple de allowlist manual
    mapping(uint256 => mapping(address => bool)) public simpleAllowlist;

    /* ---------- Constructor ---------- */
    constructor(
        address _core,
        address _paymentToken,
        address _initialOwner
    ) Ownable(_initialOwner) {
        if (_core == address(0)) revert E(1);
        if (_paymentToken == address(0)) revert E(1);
        if (_initialOwner == address(0)) revert E(1);
        
        traitsCore   = IAdrianTraitsCore(_core);
        paymentToken = IERC20(_paymentToken);
    }

    /* =============================================================
     *                      PURCHASE FLOW
     * ===========================================================*/

    /**
     * @dev Compra de packs simplificada (público + allowlist)
     */
    function purchasePack(
        uint256 packId,
        uint256 quantity,
        bool useAllowlist
    ) external nonReentrant {
        if (useAllowlist) {
            _processAllowlistPurchase(packId, quantity);
        } else {
            _processPublicPurchase(packId, quantity);
        }
        traitsCore.mintFromExtension(msg.sender, packId, quantity);
        traitsCore.updatePackMinted(packId, quantity);
        emit PackPurchased(msg.sender, packId, quantity, useAllowlist);
    }

    function _processAllowlistPurchase(
        uint256 packId, 
        uint256 quantity
    ) internal {
        PackConfig storage config = _getPackConfig(packId);
        
        // Verificar que está en allowlist simple
        require(simpleAllowlist[packId][msg.sender], "Not in allowlist");
        
        uint256 userFreeClaimed = allowlistFreeClaimed[packId][msg.sender];
        uint256 userPaidClaimed = allowlistPaidClaimed[packId][msg.sender];
        uint256 totalUserClaimed = userFreeClaimed + userPaidClaimed;
        
        // Verificar límite per wallet
        if (config.maxPerWallet > 0) {
            require(totalUserClaimed + quantity <= config.maxPerWallet, "Exceeds wallet limit");
        }
        
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
                paymentToken.transferFrom(msg.sender, traitsCore.treasuryWallet(), totalCost),
                "Payment failed"
            );
        }
        
        // Actualizar supply
        config.minted += quantity;
        require(config.minted <= config.maxSupply, "Exceeds max supply");
        
        emit AllowlistPurchase(msg.sender, packId, quantity, freeToUse, paidToUse);
    }

    function _processPublicPurchase(uint256 packId, uint256 quantity) internal {
        PackConfig storage config = _getPackConfig(packId);
        
        // Verificar timing
        if (config.startTime > 0) require(block.timestamp >= config.startTime, "Not started");
        if (config.endTime > 0) require(block.timestamp <= config.endTime, "Ended");
        
        // Verificar límite per wallet
        if (config.maxPerWallet > 0) {
            uint256 userMinted = traitsCore.balanceOf(msg.sender, packId);
            require(userMinted + quantity <= config.maxPerWallet, "Exceeds wallet limit");
        }
        
        // Verificar supply
        require(config.minted + quantity <= config.maxSupply, "Exceeds max supply");
        
        // Procesar pago
        if (config.publicPrice > 0) {
            uint256 totalCost = config.publicPrice * quantity;
            require(
                paymentToken.transferFrom(msg.sender, traitsCore.treasuryWallet(), totalCost),
                "Payment failed"
            );
        }
        
        // Actualizar supply
        config.minted += quantity;
        
        emit PublicPurchase(msg.sender, packId, quantity, config.publicPrice);
    }

    /* =============================================================
     *                       OPEN FLOW
     * ===========================================================*/

    function openPack(uint256 packId) external nonReentrant {
        // 1. Validaciones básicas
        if (!packId.isPackAsset()) revert E(1);
        PackConfig storage config = packConfigs[packId];
        if (config.id != packId || !config.active) revert E(1);
        if (traitsCore.balanceOf(msg.sender, packId) == 0) revert E(1);

        // 2. Generar contenido
        (uint256[] memory traitIds, uint256[] memory amounts) = _generatePackContents(packId);

        // 3. ✅ VALIDAR QUE TODOS LOS TRAITS ESTÁN DISPONIBLES
        for (uint256 i = 0; i < traitIds.length; i++) {
            if (amounts[i] > 0) {
                uint256 available = traitsCore.getAvailableSupply(traitIds[i]);
                require(available >= amounts[i], "Insufficient trait supply");
            }
        }

        // 4. SOLO AHORA hacer cambios de estado
        traitsCore.burnFromExtension(msg.sender, packId, 1);

        // 5. Mint traits (garantizado exitoso)
        for (uint256 i = 0; i < traitIds.length; i++) {
            if (amounts[i] > 0) {
                traitsCore.mintFromExtension(msg.sender, traitIds[i], amounts[i]);
            }
        }

        emit PackOpened(msg.sender, packId, traitIds, amounts);
    }

    // =============== Pack Content Generation ===============

    /**
     * @dev Genera contenido de pack usando 2 funciones auxiliares
     */
    function _generatePackContents(uint256 packId) internal view returns (
        uint256[] memory traitIds,
        uint256[] memory amounts
    ) {
        PackConfig storage cfg = packConfigs[packId];
        uint256[] memory cand = _collectCandidates(packId);
        
        uint256 seed = uint256(
            keccak256(
                abi.encodePacked(block.timestamp, block.prevrandao, tx.origin, packId, tx.gasprice)
            )
        );
        
        return _selectPackContents(packId, cand, cfg.itemsPerPack, seed);
    }

    /**
     * @dev Filtrar assets (traits/serums) que tienen available ≥ minAmount
     */
    function _collectCandidates(uint256 packId) internal view returns (uint256[] memory) {
        PackTrait[] storage traits = packTraits[packId];
        uint256 len = traits.length;
        uint256[] memory cand = new uint256[](len);
        uint256 n = 0;
        
        for (uint256 i = 0; i < len; i++) {
            uint256 available = traitsCore.getAvailableSupply(traits[i].assetId);
            if (available >= traits[i].minAmount) {
                cand[n++] = i;
            }
        }
        
        assembly {
            mstore(cand, n)
        }
        
        return cand;
    }

    /**
     * @dev Seleccionar assets (traits/serums) usando Fisher-Yates truncado
     */
    function _selectPackContents(
        uint256 packId,
        uint256[] memory candidates,
        uint256 itemsPerPack,
        uint256 seed
    ) internal view returns (uint256[] memory traitIds, uint256[] memory amounts) {
        uint256 n = candidates.length;
        if (n == 0) revert E(1);
        
        uint256 k = itemsPerPack > n ? n : itemsPerPack;
        traitIds = new uint256[](k);
        amounts = new uint256[](k);
        
        for (uint256 i = 0; i < k; i++) {
            uint256 j = i + (seed % (n - i));
            uint256 idx = candidates[j];
            
            (candidates[j], candidates[i]) = (candidates[i], idx);
            
            PackTrait storage t = packTraits[packId][idx];
            uint256 available = traitsCore.getAvailableSupply(t.assetId);
            uint256 amount = t.minAmount;
            
            if (amount > available) amount = available;
            if (amount > t.maxAmount) amount = t.maxAmount;
            
            if (t.maxAmount > t.minAmount && amount >= t.minAmount) {
                uint256 maxPossible = t.maxAmount > available ? available : t.maxAmount;
                if (maxPossible > t.minAmount) {
                    uint256 range = maxPossible - t.minAmount + 1;
                    amount = t.minAmount + (seed % range);
                }
            }
            
            traitIds[i] = t.assetId;
            amounts[i] = amount;
            
            seed = uint256(keccak256(abi.encodePacked(seed, i)));
        }
        
        return (traitIds, amounts);
    }

    /* =============================================================
     *                  VIEW FUNCTIONS
     * ===========================================================*/

    function canPurchasePack(
        address user, 
        uint256 packId, 
        uint256 quantity,
        bool /*useAllowlist*/
    ) external view returns (bool canPurchase, string memory reason) {
        PackConfig storage config = packConfigs[packId];
        if (!config.active) return (false, "Pack not available");
        if (config.minted + quantity > config.maxSupply) return (false, "Supply limit");
        return (true, "Can purchase");
    }

    function canOpenPack(address user, uint256 packId) external view returns (bool, string memory) {
        if (!packId.isPackAsset()) return (false, "Invalid ID");

        PackConfig storage config = packConfigs[packId];
        if (config.id != packId || !config.active) return (false, "Not available");
        if (traitsCore.balanceOf(user, packId) == 0) return (false, "No tokens");

        return (true, "OK");
    }

    // =============== Pack Configuration View Functions ===============

    /**
     * @dev Obtiene configuración completa de un pack
     */
    function getPackConfig(uint256 packId) external view returns (PackConfig memory) {
        return packConfigs[packId];
    }

    /**
     * @dev Obtiene traits de un pack
     */
    function getPackTraits(uint256 packId) external view returns (PackTrait[] memory) {
        return packTraits[packId];
    }

    /**
     * @dev Obtiene información específica de trait en pack
     */
    function getPackTraitInfo(uint256 packId, uint256 index) external view returns (
        uint256 assetId,
        uint256 minAmount,
        uint256 maxAmount,
        AssetType assetType
    ) {
        require(index < packTraits[packId].length, "Invalid index");
        PackTrait storage trait = packTraits[packId][index];
        return (trait.assetId, trait.minAmount, trait.maxAmount, trait.assetType);
    }

    /**
     * @dev Obtiene allocation disponible para un usuario
     */
    function getUserAllowlistStatus(address user, uint256 packId) external view returns (
        uint256 freeClaimed,
        uint256 paidClaimed,
        uint256 freeRemaining,
        uint256 totalAllowed
    ) {
        PackConfig storage config = packConfigs[packId];
        
        freeClaimed = allowlistFreeClaimed[packId][user];
        paidClaimed = allowlistPaidClaimed[packId][user];
        freeRemaining = config.allowlistFreeAmount > freeClaimed ? 
            config.allowlistFreeAmount - freeClaimed : 0;
        totalAllowed = config.maxPerWallet;
    }

    /**
     * @dev Obtiene estadísticas generales de un pack
     */
    function getPackStats(uint256 packId) external view returns (
        uint256 totalMinted,
        uint256 maxSupply,
        uint256 remaining,
        bool hasPublicSale,
        bool hasAllowlist,
        bool isActive,
        uint256 publicPrice
    ) {
        PackConfig storage config = packConfigs[packId];
        return (
            config.minted,
            config.maxSupply,
            config.maxSupply > config.minted ? config.maxSupply - config.minted : 0,
            config.hasPublicSale,
            config.hasAllowlist,
            config.active,
            config.publicPrice
        );
    }

    /* =============================================================
     *                  ADMIN FUNCTIONS
     * ===========================================================*/

    // =============== Pack Configuration Functions ===============

    /**
     * @dev Configurar venta pública
     */
    function setPackPublicSale(
        uint256 packId,
        bool enabled,
        uint256 price
    ) external onlyOwner {
        PackConfig storage config = _ensurePackConfig(packId);
        config.hasPublicSale = enabled;
        config.publicPrice   = price;
        emit PackPublicSaleSet(packId, enabled, price);
    }

    /**
     * @dev Configurar allowlist
     */
    function setPackAllowlist(
        uint256 packId,
        bool enabled,
        uint256 freeAmount,
        uint256 paidPrice
    ) external onlyOwner {
        PackConfig storage config = _ensurePackConfig(packId);
        config.hasAllowlist       = enabled;
        config.allowlistFreeAmount= freeAmount;
        config.allowlistPrice     = paidPrice;
        emit PackAllowlistSet(packId, enabled, freeAmount, paidPrice);
    }

    /**
     * @dev Configurar límites
     */
    function setPackLimits(
        uint256 packId,
        uint256 maxPerWallet
    ) external onlyOwner {
        PackConfig storage config = _ensurePackConfig(packId);
        config.maxPerWallet       = maxPerWallet;
        emit PackLimitsSet(packId, maxPerWallet);
    }

    /**
     * @dev Configurar timing de un pack
     */
    function setPackTiming(
        uint256 packId,
        uint256 startTime,
        uint256 endTime
    ) external onlyOwner {
        PackConfig storage config = _ensurePackConfig(packId);
        require(endTime == 0 || endTime > startTime, "Invalid timing");
        config.startTime = startTime;
        config.endTime   = endTime;
        emit PackTimingSet(packId, startTime, endTime);
    }

    /**
     * @dev Activa/desactiva un pack
     */
    function setPackActive(uint256 packId, bool active) external onlyOwner {
        PackConfig storage config = _ensurePackConfig(packId);
        config.active = active;
        emit PackStatusChanged(packId, active);
    }

    // ✅ SIMPLIFICADO: Solo usar autorización del Core
    function updatePackMinted(uint256 packId, uint256 amount) external {
        require(msg.sender == address(traitsCore), "Not authorized");
        PackConfig storage config = _getPackConfig(packId);
        config.minted += amount;
    }

    /**
     * @dev ✅ NUEVA: Función para ser llamada desde AdrianTraitsCore
     */
    function generatePackContents(uint256 packId) external view returns (
        uint256[] memory traitIds,
        uint256[] memory amounts
    ) {
        require(packId.isPackAsset(), "Invalid pack ID");
        return _generatePackContents(packId);
    }

    /**
     * @dev Configurar traits del pack
     */
    function setPackTraits(
        uint256 packId,
        uint256[] calldata assetIds,
        uint256[] calldata minAmounts,
        uint256[] calldata maxAmounts,
        AssetType[] calldata assetTypes
    ) external onlyOwner {
        _ensurePackConfig(packId);
        require(assetIds.length == minAmounts.length, "Length mismatch");
        require(assetIds.length == maxAmounts.length, "Length mismatch");
        require(assetIds.length == assetTypes.length, "Length mismatch");
        require(assetIds.length <= 50, "Too many assets");
        delete packTraits[packId];
        for (uint256 i = 0; i < assetIds.length; i++) {
            require(_validateAssetType(assetIds[i], assetTypes[i]), "Invalid asset type");
            require(minAmounts[i] <= maxAmounts[i], "Invalid amounts");
            packTraits[packId].push(PackTrait({
                assetId: assetIds[i],
                minAmount: minAmounts[i],
                maxAmount: maxAmounts[i],
                assetType: assetTypes[i]
            }));
        }
        emit PackTraitsSet(packId, assetIds.length);
    }

    function _validateAssetType(uint256 assetId, AssetType expectedType) internal pure returns (bool) {
        if (expectedType == AssetType.VISUAL_TRAIT) {
            return assetId > 0 && assetId <= TRAIT_ID_MAX;
        } else if (expectedType == AssetType.SERUM) {
            return assetId >= SERUM_ID_MIN;
        } else if (expectedType == AssetType.PACK) {
            return assetId >= PACK_ID_MIN && assetId <= PACK_ID_MAX;
        }
        // Otros tipos también válidos
        return true;
    }

    /**
     * @dev Configura allowlist desde string de wallets separadas por comas
     * @param packId ID del pack
     * @param walletsString "0x123...,0x456...,0x789..."
     */
    function setAllowlistFromString(
        uint256 packId,
        string calldata walletsString
    ) external onlyOwner {
        _ensurePackConfig(packId);          // crea/valida config
        require(bytes(walletsString).length > 0, "Empty string");
        
        bytes memory data = bytes(walletsString);
        uint256 start = 0;
        uint256 walletCount = 0;
        
        for (uint256 i = 0; i <= data.length; i++) {
            if (i == data.length || data[i] == ",") {
                if (i > start) {
                    bytes memory walletBytes = new bytes(i - start);
                    for (uint256 j = 0; j < i - start; j++) {
                        walletBytes[j] = data[start + j];
                    }
                    
                    address wallet = _parseAddress(string(walletBytes));
                    require(wallet != address(0), "Invalid wallet address");
                    
                    simpleAllowlist[packId][wallet] = true;
                    walletCount++;
                    require(walletCount <= 100, "Too many wallets");
                }
                start = i + 1;
            }
        }
        
        require(walletCount > 0, "No valid wallets found");
        emit AllowlistSetFromString(packId, walletCount);
    }

    /**
     * @dev Convierte string address a address
     */
    function _parseAddress(string memory _addr) internal pure returns (address) {
        bytes memory tmp = bytes(_addr);
        uint256 addr = 0;
        
        require(tmp.length == 42, "Invalid address length");
        require(tmp[0] == "0" && tmp[1] == "x", "Must start with 0x");
        
        for (uint256 i = 2; i < 42; i++) {
            uint256 b = uint256(uint8(tmp[i]));
            if (b >= 48 && b <= 57) b -= 48;
            else if (b >= 65 && b <= 70) b -= 55;
            else if (b >= 97 && b <= 102) b -= 87;
            else revert("Invalid hex character");
            
            addr = addr * 16 + b;
        }
        
        return address(uint160(addr));
    }

    /**
     * @dev Verifica si wallet está en allowlist
     */
    function isInAllowlist(uint256 packId, address wallet) external view returns (bool) {
        return simpleAllowlist[packId][wallet];
    }

    /**
     * @dev Añade wallet individual al allowlist
     */
    function addWalletToAllowlist(uint256 packId, address wallet) external onlyOwner {
        _ensurePackConfig(packId);
        require(wallet != address(0), "Invalid wallet");
        simpleAllowlist[packId][wallet] = true;
        emit WalletAddedToAllowlist(packId, wallet);
    }

    /**
     * @dev Remueve wallet del allowlist
     */
    function removeWalletFromAllowlist(uint256 packId, address wallet) external onlyOwner {
        _ensurePackConfig(packId);
        simpleAllowlist[packId][wallet] = false;
        emit WalletRemovedFromAllowlist(packId, wallet);
    }

    /* =============================================================
     *                         EVENTS
     * ===========================================================*/
    
    // Pack configuration events
    event PackCreated(uint256 indexed packId, uint256 maxSupply, uint256 itemsPerPack);
    event PackPublicSaleSet(uint256 indexed packId, bool enabled, uint256 price);
    event PackAllowlistSet(uint256 indexed packId, bool enabled, uint256 freeAmount, uint256 paidPrice);
    event PackLimitsSet(uint256 indexed packId, uint256 maxPerWallet);
    event PackTraitsSet(uint256 indexed packId, uint256 traitsCount);
    event PackStatusChanged(uint256 indexed packId, bool active);
    event PackTimingSet(uint256 indexed packId, uint256 startTime, uint256 endTime);
    
    // Allowlist events
    event AllowlistSetFromString(uint256 indexed packId, uint256 walletCount);
    event WalletAddedToAllowlist(uint256 indexed packId, address wallet);
    event WalletRemovedFromAllowlist(uint256 indexed packId, address wallet);
    
    // Purchase events
    event PackPurchased(address indexed buyer, uint256 packId, uint256 quantity, bool useAllowlist);
    event AllowlistPurchase(address indexed buyer, uint256 packId, uint256 quantity, uint256 freeUsed, uint256 paidUsed);
    event PublicPurchase(address indexed buyer, uint256 packId, uint256 quantity, uint256 pricePerPack);
    event PackOpened(address indexed user, uint256 packId, uint256[] traitIds, uint256[] amounts);

    /* ──────────────────────────────────────────────────────────
     *                    HELPER  FUNCTIONS
     * ─────────────────────────────────────────────────────────*/

    /**
     * @dev Asegura que el pack existe en Core y que tenemos configuración
     *      local; si no la hay, la crea con valores seguros por defecto.
     */
    function _ensurePackConfig(
        uint256 packId
    ) internal returns (PackConfig storage cfg) {
        require(packId.isPackAsset(), "Invalid pack ID");

        cfg = packConfigs[packId];

        // Si aún no hay configuración local, la generamos in-situ
        if (cfg.id == 0) {
            (, uint256 maxSupply,,,,,) = traitsCore.getPackInfo(packId);
            require(maxSupply > 0, "Pack doesn't exist in Core");

            cfg.id              = packId;
            cfg.maxSupply       = maxSupply;
            cfg.itemsPerPack    = 1;      // default
            cfg.maxPerWallet    = 0;      // sin tope
            cfg.active          = false;  // inactivo hasta que se cambie
            cfg.hasPublicSale   = false;
            cfg.hasAllowlist    = false;
            cfg.allowlistFreeAmount = 0;
            cfg.allowlistPrice  = 0;
            cfg.startTime       = 0;
            cfg.endTime         = 0;
        }
    }

    /**
     * @dev Versión view-only: revierte si la configuración no existe.
     */
    function _getPackConfig(
        uint256 packId
    ) internal view returns (PackConfig storage cfg) {
        require(packId.isPackAsset(), "Invalid pack ID");
        cfg = packConfigs[packId];
        require(cfg.id == packId, "Pack not configured");
    }
}