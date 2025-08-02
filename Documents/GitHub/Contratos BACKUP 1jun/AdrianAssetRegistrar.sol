// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./AdrianTraitsCore.sol";

interface IAdrianTraitsCore {
    function registrarSetAssetMetadata(uint256 assetId, string calldata newUri) external;
    function packTraitsLength(uint256 packId) external view returns (uint256);
    function getPackTraitInfo(uint256 packId, uint256 index) external view returns (
        uint256 traitId,
        uint256 minAmount,
        uint256 maxAmount,
        uint256 chance,
        uint256 remaining
    );
    function assets(uint256) external view returns (
        string memory name,
        string memory category,
        string memory ipfsPath,
        bool tempFlag,
        uint256 maxSupply,
        uint8 assetType,
        string memory metadata
    );
    function setTraitCategory(uint256 traitId, string calldata category) external;
    function nextAssetId() external view returns (uint256);
    function nextPackId() external view returns (uint256);
    function balanceOf(address, uint256) external view returns (uint256);
    function unclaimedPacks(address, uint256) external view returns (uint256);
    function setRegistrar(address _registrar) external;
    function registerAsset(AssetData calldata asset) external;
}

/**
 * @title AdrianAssetRegistrar
 * @dev Contrato para registrar assets antes de su importación en AdrianTraitsCore
 */
contract AdrianAssetRegistrar is Ownable {
    using Strings for uint256;

    struct Asset {
        string name;
        string category;
        string metadataUri;
        bool isTemporary;
        uint256 maxSupply;
        uint256 assetType;
    }

    // Mapping de assets por ID
    mapping(uint256 => Asset) public assets;
    
    // Contador de assets
    uint256 public nextAssetId;
    
    // Referencia al contrato principal
    IAdrianTraitsCore public traitsCore;

    // Referencia al contrato de traits
    IAdrianTraitsCore public traitsContract;

    // Eventos
    event AssetRegistered(uint256 indexed assetId, string name, string category, uint256 assetType);
    event CategoryBatchRegistered(string category, uint256 startId, uint256 count);
    event AssetMetadataUpdated(uint256[] assetIds, string[] newUris);
    event AssetMaxSupplyUpdated(uint256[] assetIds, uint256[] newMaxSupplies);
    event TraitsCoreUpdated(address newTraitsCore);

    constructor() Ownable(msg.sender) {}

    /**
     * @dev Set traits core contract
     */
    function setTraitsCore(address _contract) external onlyOwner {
        require(_contract != address(0) && _contract.code.length > 0, "Invalid contract");
        traitsCore = IAdrianTraitsCore(_contract);
        traitsCore.setRegistrar(address(this));
        emit TraitsCoreUpdated(_contract);
    }

    /**
     * @dev Set traits contract
     */
    function setTraitsContract(address _traitsContract) external onlyOwner {
        require(_traitsContract != address(0) && _traitsContract.code.length > 0, "Invalid contract");
        traitsContract = IAdrianTraitsCore(_traitsContract);
    }

    /**
     * @dev Actualiza la metadata de un asset en el core
     */
    function setAssetMetadata(uint256 assetId, string calldata newUri) external onlyOwner {
        require(address(traitsCore) != address(0), "TraitsCore not set");
        traitsCore.registrarSetAssetMetadata(assetId, newUri);
    }

    /**
     * @dev Registra un batch de assets de la misma categoría
     */
    function batchRegisterAssets(
        string calldata category,
        string calldata baseUri,
        string calldata namePrefix,
        uint256 startId,
        uint256 count,
        uint256 maxSupply,
        bool isTemporary,
        uint256 assetType
    ) external onlyOwner returns (uint256[] memory) {
        require(count > 0, "Count must be > 0");
        require(bytes(category).length > 0, "Category required");
        require(bytes(baseUri).length > 0, "Base URI required");
        
        uint256[] memory registeredIds = new uint256[](count);
        
        // Mover variables calldata a memory para reducir stack depth
        string memory _category = category;
        string memory _namePrefix = namePrefix;
        string memory _baseUri = baseUri;

        for (uint256 i = 0; i < count; i++) {
            uint256 assetId = nextAssetId++;
            uint256 traitId = startId + i;

            string memory name = string(abi.encodePacked(_namePrefix, traitId.toString()));
            string memory uri = string(abi.encodePacked(_baseUri, traitId.toString(), ".json"));

            assets[assetId] = Asset({
                name: name,
                category: _category,
                metadataUri: uri,
                isTemporary: isTemporary,
                maxSupply: maxSupply,
                assetType: assetType
            });

            registeredIds[i] = assetId;
            emit AssetRegistered(assetId, name, _category, assetType);
        }
        
        emit CategoryBatchRegistered(_category, startId, count);
        return registeredIds;
    }

    /**
     * @dev Registra un asset individual
     */
    function registerAsset(
        string calldata name,
        string calldata category,
        string calldata ipfsPath,
        bool isTemporary,
        uint256 maxSupply
    ) external onlyOwner {
        require(address(traitsCore) != address(0), "TraitsCore not set");
        traitsCore.registerAsset(name, category, ipfsPath, isTemporary, maxSupply);
    }

    /**
     * @dev Actualiza un asset existente
     */
    function updateAsset(
        uint256 assetId,
        string calldata name,
        string calldata category,
        string calldata metadataUri,
        bool isTemporary,
        uint256 maxSupply,
        uint256 assetType
    ) external onlyOwner {
        require(assetId < nextAssetId, "Asset does not exist");
        
        assets[assetId] = Asset({
            name: name,
            category: category,
            metadataUri: metadataUri,
            isTemporary: isTemporary,
            maxSupply: maxSupply,
            assetType: assetType
        });
        
        emit AssetRegistered(assetId, name, category, assetType);
    }

    /**
     * @dev Obtiene los IDs de assets por categoría
     */
    function getAssetsByCategory(string calldata category) external view returns (uint256[] memory) {
        uint256 count = 0;
        
        // Primero contamos cuántos assets hay en esta categoría
        for (uint256 i = 0; i < nextAssetId; i++) {
            if (keccak256(bytes(assets[i].category)) == keccak256(bytes(category))) {
                count++;
            }
        }
        
        // Luego creamos el array con el tamaño correcto
        uint256[] memory assetIds = new uint256[](count);
        uint256 index = 0;
        
        // Finalmente llenamos el array
        for (uint256 i = 0; i < nextAssetId; i++) {
            if (keccak256(bytes(assets[i].category)) == keccak256(bytes(category))) {
                assetIds[index] = i;
                index++;
            }
        }
        
        return assetIds;
    }

    /**
     * @dev Actualiza la metadata de múltiples assets
     */
    function updateMetadataBatch(
        uint256[] calldata assetIds,
        string[] calldata newUris
    ) external onlyOwner {
        require(assetIds.length == newUris.length, "Length mismatch");
        
        for (uint256 i = 0; i < assetIds.length; i++) {
            require(assetIds[i] < nextAssetId, "Asset does not exist");
            require(bytes(newUris[i]).length > 0, "Empty URI");
            
            assets[assetIds[i]].metadataUri = newUris[i];
        }
        
        emit AssetMetadataUpdated(assetIds, newUris);
    }

    /**
     * @dev Actualiza el maxSupply de múltiples assets
     */
    function updateMaxSupplyBatch(
        uint256[] calldata assetIds,
        uint256[] calldata newMaxSupplies
    ) external onlyOwner {
        require(assetIds.length == newMaxSupplies.length, "Length mismatch");
        
        for (uint256 i = 0; i < assetIds.length; i++) {
            require(assetIds[i] < nextAssetId, "Asset does not exist");
            require(newMaxSupplies[i] > 0, "Invalid max supply");
            
            assets[assetIds[i]].maxSupply = newMaxSupplies[i];
        }
        
        emit AssetMaxSupplyUpdated(assetIds, newMaxSupplies);
    }

    /**
     * @dev Actualiza el tipo de múltiples assets
     */
    function updateAssetTypeBatch(
        uint256[] calldata assetIds,
        uint256[] calldata newTypes
    ) external onlyOwner {
        require(assetIds.length == newTypes.length, "Length mismatch");
        
        for (uint256 i = 0; i < assetIds.length; i++) {
            require(assetIds[i] < nextAssetId, "Asset does not exist");
            
            assets[assetIds[i]].assetType = newTypes[i];
        }
    }

    /**
     * @dev Obtiene la información de los traits de un pack
     */
    function getPackTraits(address coreAddress, uint256 packId) external view returns (
        uint256[] memory traitIds,
        uint256[] memory minAmounts,
        uint256[] memory maxAmounts,
        uint256[] memory chances,
        uint256[] memory remaining
    ) {
        IAdrianTraitsCore core = IAdrianTraitsCore(coreAddress);

        uint256 length = core.packTraitsLength(packId);
        traitIds = new uint256[](length);
        minAmounts = new uint256[](length);
        maxAmounts = new uint256[](length);
        chances = new uint256[](length);
        remaining = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            (
                uint256 traitId,
                uint256 minAmount,
                uint256 maxAmount,
                uint256 chance,
                uint256 remainingAmount
            ) = core.getPackTraitInfo(packId, i);

            traitIds[i] = traitId;
            minAmounts[i] = minAmount;
            maxAmounts[i] = maxAmount;
            chances[i] = chance;
            remaining[i] = remainingAmount;
        }
    }

    /**
     * @dev Obtiene la metadata de un trait
     */
    function getTraitMetadata(uint256 traitId) external view returns (string memory) {
        (,,,,,,string memory metadata) = traitsContract.assets(traitId);
        return metadata;
    }

    /**
     * @dev Actualiza la categoría de múltiples traits de una vez
     */
    function setCategoryBatch(uint256[] calldata traitIds, string calldata category) external onlyOwner {
        for (uint256 i = 0; i < traitIds.length; i++) {
            traitsContract.setTraitCategory(traitIds[i], category);
        }
    }

    function getInventory(address _traitsCore, address user) external view returns (
        uint256[] memory assetIds,
        uint256[] memory balances
    ) {
        uint256 _nextAssetId = IAdrianTraitsCore(_traitsCore).nextAssetId();
        uint256 count = 0;
        for (uint256 i = 1; i < _nextAssetId; i++) {
            if (IAdrianTraitsCore(_traitsCore).balanceOf(user, i) > 0) {
                count++;
            }
        }
        assetIds = new uint256[](count);
        balances = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 1; i < _nextAssetId; i++) {
            uint256 balance = IAdrianTraitsCore(_traitsCore).balanceOf(user, i);
            if (balance > 0) {
                assetIds[index] = i;
                balances[index] = balance;
                index++;
            }
        }
        return (assetIds, balances);
    }

    function getUnopenedPacks(address _traitsCore, address user) external view returns (
        uint256[] memory packIds,
        uint256[] memory quantities
    ) {
        uint256 _nextPackId = IAdrianTraitsCore(_traitsCore).nextPackId();
        uint256 count = 0;
        for (uint256 i = 1; i < _nextPackId; i++) {
            if (IAdrianTraitsCore(_traitsCore).unclaimedPacks(user, i) > 0) {
                count++;
            }
        }
        packIds = new uint256[](count);
        quantities = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 1; i < _nextPackId; i++) {
            uint256 qty = IAdrianTraitsCore(_traitsCore).unclaimedPacks(user, i);
            if (qty > 0) {
                packIds[index] = i;
                quantities[index] = qty;
                index++;
            }
        }
        return (packIds, quantities);
    }
} 