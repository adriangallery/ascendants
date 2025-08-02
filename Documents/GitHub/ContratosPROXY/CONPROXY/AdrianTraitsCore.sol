// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AdrianStorage.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title AdrianTraitsCore
 * @dev Lógica modular para traits, packs, serums y distribución (sin storage propio)
 */
contract AdrianTraitsCore is AdrianStorage, ReentrancyGuard, Initializable {
    using Strings for uint256;

    // =============== Variables locales para proxy y estado ===============
    address public proxyAddress;
    bool private initialized;

    // =============== Eventos propios ===============
    event AssetURIUpdated(uint256 indexed assetId, string newUri);
    event SerumRegistered(uint256 indexed serumId, string targetMutation, uint256 potency);
    event AssetMinted(uint256 indexed assetId, address indexed to, uint256 amount);
    event ExtensionsContractUpdated(address newContract);
    event CoreContractUpdated(address newContract);
    event PaymentTokenUpdated(address newToken);
    event SerumModuleUpdated(address newModule);
    event AssetCreated(uint256 indexed assetId, string name, string category);
    event AssetUpdated(uint256 indexed assetId, string name, string category);
    event SerumCreated(uint256 indexed serumId, string targetMutation, uint256 potency);
    event SerumUpdated(uint256 indexed serumId, string targetMutation, uint256 potency);
    event PackCreated(uint256 indexed packId, uint256 price, uint256 maxSupply);
    event PackUpdated(uint256 indexed packId, uint256 price, uint256 maxSupply);
    event PackActivated(uint256 indexed packId);
    event PackDeactivated(uint256 indexed packId);
    event PromoCodeCreated(bytes32 indexed code, uint256 packId, uint256 maxUses);
    event PromoCodeUsed(bytes32 indexed code, address user);
    event TreasuryWalletUpdated(address newTreasuryWallet);
    event ProceedsWithdrawn(address recipient, uint256 amount);

    // =============== Constantes de rangos ===============
    uint256 constant TRAIT_ID_MAX = 999_999;
    uint256 constant PACK_ID_MIN = 1_000_000;
    uint256 constant PACK_ID_MAX = 1_999_999;

    // =============== Modificadores ===============
    modifier onlyProxy() {
        require(msg.sender == proxyAddress, "Solo proxy");
        _;
    }

    // =============== Inicialización ===============
    function initialize(address _proxy, address _paymentToken, address _treasuryWallet) external initializer {
        require(!initialized, "Ya inicializado");
        proxyAddress = _proxy;
        traits_paymentToken = _paymentToken;
        traits_treasuryWallet = _treasuryWallet;
        initialized = true;
        // Inicializar categorías
        traits_categoryList = [
            "BACKGROUND",
            "BASE",
            "BODY",
            "CLOTHING",
            "EYES",
            "MOUTH",
            "HEAD",
            "ACCESSORIES"
        ];
        for (uint256 i = 0; i < traits_categoryList.length; i++) {
            validCategories[traits_categoryList[i]] = true;
        }
    }

    // =============== Asset Management ===============
    function setAssetURI(uint256 assetId, string calldata newUri) external onlyProxy {
        assets[assetId].ipfsPath = newUri;
        emit AssetURIUpdated(assetId, newUri);
    }

    function registerSerum(
        uint256 serumId,
        string calldata targetMutation,
        uint256 potency,
        string calldata name,
        string calldata metadata
    ) external onlyProxy {
        require(potency <= 100, "!potency");
        assets[serumId] = AssetData({
            name: name,
            category: "SERUM",
            ipfsPath: "",
            tempFlag: false,
            maxSupply: 0,
            assetType: uint8(3), // SERUM
            metadata: metadata
        });
        serums[serumId] = SerumData({
            targetMutation: targetMutation,
            potency: potency,
            metadata: metadata
        });
        emit SerumRegistered(serumId, targetMutation, potency);
    }

    function updateSerum(
        uint256 serumId,
        string calldata targetMutation,
        uint256 potency
    ) external onlyProxy {
        require(assets[serumId].assetType == 3, "!serum");
        require(potency <= 100, "!potency");
        serums[serumId].targetMutation = targetMutation;
        serums[serumId].potency = potency;
        emit SerumRegistered(serumId, targetMutation, potency);
    }

    function mintAssets(
        address to,
        uint256 assetId,
        uint256 amount
    ) external onlyProxy {
        if (assets[assetId].assetType == 4) {
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
        // _mint debe ser llamada por el proxy
        emit AssetMinted(assetId, to, amount);
    }

    function setBaseMetadataURI(string calldata _baseURI) external onlyProxy {
        baseMetadataURI = _baseURI;
    }

    // =============== Pack System ===============
    // ... (mantener la lógica, pero usando storage centralizado y tipos uint8 para assetType)
    // ... existing code ...
    // =============== Admin Functions ===============
    function setExtensionsContract(address _extensionsContract) external onlyProxy {
        traits_extensionsContract = _extensionsContract;
        emit ExtensionsContractUpdated(_extensionsContract);
    }
    function setCoreContract(address _coreContract) external onlyProxy {
        traits_coreContract = _coreContract;
        emit CoreContractUpdated(_coreContract);
    }
    function setPaymentToken(address _paymentToken) external onlyProxy {
        traits_paymentToken = _paymentToken;
        emit PaymentTokenUpdated(_paymentToken);
    }
    function withdrawProceeds() external onlyProxy {
        uint256 amount = pendingProceeds[traits_treasuryWallet];
        require(amount > 0, "!funds");
        pendingProceeds[traits_treasuryWallet] = 0;
        // Transferencia debe ser realizada por el proxy
    }
    function setSerumModule(address _module) external onlyProxy {
        serumModule = _module;
        emit SerumModuleUpdated(_module);
    }
    function setTreasuryWallet(address _treasuryWallet) external onlyProxy {
        traits_treasuryWallet = _treasuryWallet;
        emit TreasuryWalletUpdated(_treasuryWallet);
    }
    // ... existing code ...
    // =============== View Functions ===============
    // ... (adaptar getters para usar storage centralizado y tipos uint8)
    // ... existing code ...
    // =============== Internal Functions ===============
    // ... existing code ...
    // =============== Interfaces ===============
    // Eliminar IAssetRegistrar
}