// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AdrianTraitsStorage.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title AdrianTraits
 * @dev Contrato principal para el sistema de traits ERC1155 de AdrianLab
 */
contract AdrianTraits is AdrianTraitsStorage {
    using Strings for uint256;

    // Eventos adicionales
    event AllowlistUpdated(uint256 indexed allowlistId, bytes32 merkleRoot);
    event PaymentTokenUpdated(address indexed paymentToken);
    event ProceeedsWithdrawn(address indexed to, uint256 amount);
    event PackURIUpdated(uint256 indexed packId, string newUri);
    
    // Allowlist
    mapping(uint256 => bytes32) public allowlistMerkleRoots;

    /**
     * @dev Inicializa el contrato de traits en lugar de un constructor
     */
    function initialize(
        address _adrianLabContract,
        address _paymentToken
    ) public initializer {
        __ERC1155_init("");
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        
        adrianLabContract = _adrianLabContract;
        paymentToken = _paymentToken;
        
        // Inicializar serums estándar
        serums[BASIC_SERUM_ID] = SerumData({
            serumType: SerumType.BASIC_MUTATION,
            targetMutation: "",
            potency: 50,
            metadata: "{\"name\":\"Basic Mutation Serum\",\"description\":\"50% chance to mutate\"}"
        });
        
        serums[MUTATION_SERUM_ID] = SerumData({
            serumType: SerumType.DIRECTED_MUTATION,
            targetMutation: "MILD",
            potency: 100,
            metadata: "{\"name\":\"Directed Mutation Serum\",\"description\":\"100% chance for MILD mutation\"}"
        });
        
        serums[ADVANCED_SERUM_ID] = SerumData({
            serumType: SerumType.ADVANCED_MUTATION,
            targetMutation: "MODERATE",
            potency: 100,
            metadata: "{\"name\":\"Advanced Mutation Serum\",\"description\":\"Special effects\"}"
        });
    }
    
    /**
     * @dev Registrar un nuevo trait visual
     */
    function registerTrait(
        uint256 traitId,
        string calldata name,
        string calldata category,
        string calldata ipfsPath,
        bool isTraitTemporary,
        uint256 maxSupply
    ) external onlyOwner {
        require(assets[traitId].maxSupply == 0, "Trait ID already registered");
        
        assets[traitId] = AssetData({
            name: name,
            category: category,
            ipfsPath: ipfsPath,
            isTemporary: isTraitTemporary,
            maxSupply: maxSupply,
            assetType: AssetType.VISUAL_TRAIT,
            metadata: ""
        });
        
        if (nextTraitId <= traitId) {
            nextTraitId = traitId + 1;
        }
        
        emit TraitRegistered(traitId, name, category, maxSupply);
    }
    
    /**
     * @dev Mintear un trait a un usuario (solo owner)
     */
    function mintTrait(
        address to,
        uint256 traitId,
        uint256 amount
    ) external onlyOwner {
        require(assets[traitId].maxSupply > 0, "Trait not registered");
        
        if (assets[traitId].maxSupply > 0) {
            require(
                totalMintedPerTrait[traitId] + amount <= assets[traitId].maxSupply,
                "Exceeds max supply"
            );
            totalMintedPerTrait[traitId] += amount;
        }
        
        _mint(to, traitId, amount, "");
        
        emit TraitMinted(traitId, to, amount);
    }
    
    /**
     * @dev Mintear serums (solo owner)
     */
    function mintSerum(address to, uint256 serumId, uint256 amount) external onlyOwner {
        require(serumId >= 10000, "Not a serum ID");
        require(serums[serumId].potency > 0, "Serum not registered");
        
        _mint(to, serumId, amount, "");
        
        emit SerumMinted(to, serumId, amount);
    }
    
    /**
     * @dev Definir un pack de venta
     */
    function definePack(
        uint256 packId,
        uint256 price,
        uint256 maxSupply,
        uint256 itemsPerPack,
        string calldata packUri
    ) external onlyOwner {
        packConfigs[packId] = PackConfig({
            id: packId,
            price: price,
            maxSupply: maxSupply,
            minted: 0,
            itemsPerPack: itemsPerPack,
            active: true,
            uri: packUri
        });
        
        if (nextPackId <= packId) {
            nextPackId = packId + 1;
        }
        
        emit PackDefined(packId, price, maxSupply, itemsPerPack, packUri);
    }
    
    /**
     * @dev Comprar un pack
     */
    function purchasePack(uint256 packId, uint256 quantity) external nonReentrant {
        PackConfig storage config = packConfigs[packId];
        require(config.active, "Pack not active");
        require(config.minted + quantity <= config.maxSupply, "Exceeds max supply");
        
        // Calcular costo total
        uint256 totalCost = config.price * quantity;
        
        // Transferir tokens $ADRIAN
        IERC20(paymentToken).transferFrom(msg.sender, address(this), totalCost);
        pendingProceeds[paymentToken] += totalCost;
        
        // Incrementar contador de packs mintados
        config.minted += quantity;
        
        // Registrar packs sin abrir para el usuario
        unclaimedPacks[msg.sender][packId] += quantity;
        
        emit PackPurchased(msg.sender, packId, quantity);
    }
    
    /**
     * @dev Abrir un pack comprado
     */
    function openPack(uint256 packId) external nonReentrant {
        require(unclaimedPacks[msg.sender][packId] > 0, "No packs to open");
        
        PackConfig storage config = packConfigs[packId];
        require(config.active, "Pack not active");
        
        // Decrementar contador de packs sin abrir
        unclaimedPacks[msg.sender][packId]--;
        
        // Por simplicidad, este ejemplo mintea traits predefinidos
        // En un contrato real, implementarías una selección aleatoria basada en pools
        uint256[] memory selectedTraits = new uint256[](config.itemsPerPack);
        uint256[] memory amounts = new uint256[](config.itemsPerPack);
        
        // Ejemplo simple - mintear items consecutivos desde nextTraitId
        for (uint256 i = 0; i < config.itemsPerPack; i++) {
            selectedTraits[i] = nextTraitId - config.itemsPerPack + i;
            amounts[i] = 1;
            
            _mint(msg.sender, selectedTraits[i], 1, "");
            totalMintedPerTrait[selectedTraits[i]]++;
            
            emit TraitMinted(selectedTraits[i], msg.sender, 1);
        }
        
        emit PackOpened(msg.sender, packId, selectedTraits);
    }
    
    /**
     * @dev Usar serum en un token
     */
    function useSerum(uint256 tokenId, uint256 serumId) external nonReentrant {
        // Verificar posesión
        require(balanceOf(msg.sender, serumId) > 0, "No serum owned");
        require(serumId >= 10000, "Not a serum ID");
        require(IAdrianLab(adrianLabContract).ownerOf(tokenId) == msg.sender, "Not token owner");
        
        // Quemar serum
        _burn(msg.sender, serumId, 1);
        
        // Llamar al contrato principal
        bool success = IAdrianLab(adrianLabContract).useSerum(tokenId, serumId, "");
        require(success, "Serum application failed");
    }
    
    /**
     * @dev Obtener información sobre un trait
     */
    function getTraitInfo(uint256 traitId) external view returns (string memory category, bool traitIsTemporary) {
        require(assets[traitId].maxSupply > 0, "Trait not registered");
        return (assets[traitId].category, assets[traitId].isTemporary);
    }
    
    /**
     * @dev Obtener categoría de un trait
     */
    function getCategory(uint256 traitId) external view returns (string memory) {
        require(assets[traitId].maxSupply > 0, "Trait not registered");
        return assets[traitId].category;
    }
    
    /**
     * @dev Verificar si un trait es temporal
     */
    function isTemporary(uint256 traitId) external view returns (bool) {
        require(assets[traitId].maxSupply > 0, "Trait not registered");
        return assets[traitId].isTemporary;
    }
    
    /**
     * @dev Obtener nombre de un trait
     */
    function getName(uint256 traitId) external view returns (string memory) {
        require(assets[traitId].maxSupply > 0, "Trait not registered");
        return assets[traitId].name;
    }
    
    /**
     * @dev Obtener datos de serum
     */
    function getSerumData(uint256 serumId) external view returns (SerumType, string memory, uint256) {
        require(serumId >= 10000, "Not a serum ID");
        SerumData memory data = serums[serumId];
        return (data.serumType, data.targetMutation, data.potency);
    }
    
    /**
     * @dev Obtener inventario de traits de un usuario
     */
    function getTraitInventory(address user) external view returns (uint256[] memory, uint256[] memory) {
        // Contar cuántos traits diferentes tiene el usuario
        uint256 count = 0;
        for (uint256 i = 0; i < nextTraitId; i++) {
            if (balanceOf(user, i) > 0) {
                count++;
            }
        }
        
        // Crear arrays para devolver
        uint256[] memory traitIds = new uint256[](count);
        uint256[] memory balances = new uint256[](count);
        
        // Llenar arrays
        uint256 index = 0;
        for (uint256 i = 0; i < nextTraitId; i++) {
            uint256 balance = balanceOf(user, i);
            if (balance > 0) {
                traitIds[index] = i;
                balances[index] = balance;
                index++;
            }
        }
        
        return (traitIds, balances);
    }
    
    /**
     * @dev Obtener packs sin reclamar
     */
    function getUnclaimedPacks(address user) external view returns (
        uint256[] memory packIds,
        uint256[] memory quantities
    ) {
        // Contar packs no reclamados
        uint256 count = 0;
        for (uint256 i = 0; i < nextPackId; i++) {
            if (unclaimedPacks[user][i] > 0) {
                count++;
            }
        }
        
        // Crear arrays para devolver
        packIds = new uint256[](count);
        quantities = new uint256[](count);
        
        // Llenar arrays
        uint256 index = 0;
        for (uint256 i = 0; i < nextPackId; i++) {
            if (unclaimedPacks[user][i] > 0) {
                packIds[index] = i;
                quantities[index] = unclaimedPacks[user][i];
                index++;
            }
        }
        
        return (packIds, quantities);
    }
    
    /**
     * @dev Obtener URI de metadatos para un token
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        if (tokenId >= 10000) {
            // Es un serum
            SerumData memory serumData = serums[tokenId];
            return string(abi.encodePacked(
                "data:application/json;base64,",
                _encodeMetadata(tokenId, serumData.metadata)
            ));
        } else {
            // Es un trait
            AssetData memory asset = assets[tokenId];
            return asset.ipfsPath;
        }
    }
    
    /**
     * @dev Encodes simple metadata for on-chain assets
     */
    function _encodeMetadata(uint256 tokenId, string memory metadata) internal pure returns (string memory) {
        bytes memory json = abi.encodePacked(metadata);
        return Base64.encode(json);
    }
    
    /**
     * @dev Quemar token (public para poder ser llamado desde AdrianLab)
     */
    function burn(address account, uint256 id, uint256 amount) public {
        require(
            account == msg.sender || isApprovedForAll(account, msg.sender),
            "Not authorized to burn"
        );
        
        _burn(account, id, amount);
    }
    
    /**
     * @dev Configurar allowlist Merkle root
     */
    function setAllowlistMerkleRoot(uint256 allowlistId, bytes32 merkleRoot) external onlyOwner {
        allowlistMerkleRoots[allowlistId] = merkleRoot;
        emit AllowlistUpdated(allowlistId, merkleRoot);
    }
    
    /**
     * @dev Configurar token de pago
     */
    function setPaymentToken(address _paymentToken) external onlyOwner {
        paymentToken = _paymentToken;
        emit PaymentTokenUpdated(_paymentToken);
    }
    
    /**
     * @dev Configurar contrato AdrianLab
     */
    function setAdrianLabContract(address _adrianLabContract) external onlyOwner {
        adrianLabContract = _adrianLabContract;
    }
    
    /**
     * @dev Retirar fondos
     */
    function withdrawProceeds(address token, address to) external onlyOwner {
        uint256 amount = pendingProceeds[token];
        require(amount > 0, "No proceeds");
        
        pendingProceeds[token] = 0;
        IERC20(token).transfer(to, amount);
        
        emit ProceeedsWithdrawn(to, amount);
    }
    
    /**
     * @dev Actualizar URI de un pack
     */
    function setPackURI(uint256 packId, string calldata newUri) external onlyOwner {
        require(packConfigs[packId].id == packId, "Pack does not exist");
        
        packConfigs[packId].uri = newUri;
        emit PackURIUpdated(packId, newUri);
    }
}

// Interfaz para comunicación con el contrato principal
interface IAdrianLab {
    function ownerOf(uint256 tokenId) external view returns (address);
    function useSerum(uint256 tokenId, uint256 serumId, bytes calldata data) external returns (bool);
}