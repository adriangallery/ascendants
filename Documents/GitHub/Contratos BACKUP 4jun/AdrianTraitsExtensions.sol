// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IAdrianHistory.sol";
import {IAdrianTraitsCore} from "./AdrianTraitsCore.sol";

// =============== Interfaces adicionales ===============
interface IAdrianLabCore {
    function setExtensionsContract(address _extensions) external;
}

interface IAdrianLab {
    function ownerOf(uint256 tokenId) external view returns (address);
}

/**
 * @title AdrianTraitsExtensions
 * @dev Advanced features for traits system including token trait management
 */
contract AdrianTraitsExtensions is ERC1155, Ownable, ReentrancyGuard {
    using Strings for uint256;

    // =============== Type Definitions ===============

    struct TraitInfo {
        string name;
        string category;
        uint256 maxSupply;
        bool isPack;
    }

    // =============== State Variables ===============
    
    address public coreContract;
    address public adrianLabContract;
    IAdrianTraitsCore public immutable traitsCore;
    IAdrianHistory public historyContract;
    address public treasury;
    
    // Allowlist system
    mapping(uint256 => bytes32) public allowlistMerkleRoots;
    mapping(address => mapping(uint256 => bool)) public allowlistClaimed;
    
    // Token trait management
    mapping(uint256 => mapping(string => uint256)) public equippedTrait;    // tokenId => category => traitId
    mapping(uint256 => string[]) public tokenCategories;                  // tokenId => categories array
    mapping(uint256 => mapping(string => bool)) public tokenHasCategory;  // tokenId => category => exists
    
    // Token inventories (for AdrianZERO)
    mapping(uint256 => mapping(uint256 => uint256[])) public tokenInventory; // tokenId => assetType => assetIds[]
    
    // URI management
    string public baseExternalURI = "https://adrianlab.vercel.app/api/metadata/";
    mapping(uint256 => string) public overrideAssetURIs;
    
    // Emergency features
    bool public emergencyMode = false;
    mapping(bytes4 => bool) public pausedFunctions;

    // Trait configuration
    mapping(uint256 => TraitInfo) public traitInfo;
    mapping(uint256 => uint256) public traitSupply;
    mapping(uint256 => bool) public isPack;
    
    // Pack configuration
    mapping(uint256 => uint256[]) public packContents;
    
    // New trait sale configuration
    mapping(uint256 => uint256) public traitPrice;                // traitId => precio en wei
    mapping(uint256 => bool) public traitAvailable;               // traitId => habilitado para venta
    mapping(uint256 => uint256) public traitSaleStart;            // traitId => tiempo inicio
    mapping(uint256 => uint256) public traitSaleEnd;              // traitId => tiempo fin
    mapping(uint256 => bytes32) public traitWhitelistRoot;        // traitId => Merkle root para whitelist

    // =============== Events ===============
    
    event AllowlistUpdated(uint256 indexed allowlistId, bytes32 merkleRoot);
    event AllowlistPackClaimed(address indexed user, uint256 allowlistId, uint256 packId);
    event AssetAddedToInventory(uint256 indexed tokenId, uint256 assetId, uint256 amount);
    event AssetRemovedFromInventory(uint256 indexed tokenId, uint256 assetId, uint256 amount);
    event AssetUsedFromInventory(uint256 indexed tokenId, uint256 assetId);
    event TraitEquipped(uint256 indexed tokenId, string category, uint256 traitId);
    event TraitUnequipped(uint256 indexed tokenId, string category, uint256 traitId);
    event EmergencyModeSet(bool enabled);
    event FunctionPauseToggled(bytes4 functionSelector, bool paused);
    event TraitMinted(address indexed to, uint256 indexed traitId, uint256 amount);
    event PackMinted(address indexed to, uint256 indexed packId);
    event TraitCreated(uint256 indexed traitId, string name, string category, uint256 maxSupply);
    event PackCreated(uint256 indexed packId, uint256[] contents);
    event TraitSaleConfigured(
        uint256 indexed traitId,
        uint256 price,
        bool available,
        uint256 startTime,
        uint256 endTime,
        bytes32 whitelistRoot
    );
    event PackOpenedWithExtensions(address indexed user, uint256 indexed packId);

    // =============== Modifiers ===============
    
    modifier onlyCore() {
        require(msg.sender == coreContract, "Only core contract");
        _;
    }

    modifier notPaused(bytes4 selector) {
        require(!emergencyMode || !pausedFunctions[selector], "Function paused in emergency mode");
        _;
    }

    modifier onlyTokenOwner(uint256 tokenId) {
        require(IAdrianLab(adrianLabContract).ownerOf(tokenId) == msg.sender, "Not token owner");
        _;
    }

    // =============== Constructor ===============
    
    constructor(
        address _coreContract,
        IAdrianTraitsCore _traitsCore
    ) ERC1155("https://api.adrianlab.com/traits/{id}") Ownable(msg.sender) {
        coreContract = _coreContract;
        traitsCore = _traitsCore;
    }

    // =============== Allowlist System ===============
    
    /**
     * @dev Set allowlist merkle root
     */
    function setAllowlistMerkleRoot(uint256 allowlistId, bytes32 merkleRoot) external onlyOwner {
        allowlistMerkleRoots[allowlistId] = merkleRoot;
        emit AllowlistUpdated(allowlistId, merkleRoot);
    }

    /**
     * @dev Claim pack with allowlist proof
     */
    function claimAllowlistPack(
        uint256 packId,
        uint256 allowlistId,
        bytes32[] calldata merkleProof
    ) external nonReentrant {
        require(!allowlistClaimed[msg.sender][allowlistId], "Already claimed from this allowlist");
        
        // Verify merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(
            MerkleProof.verify(merkleProof, allowlistMerkleRoots[allowlistId], leaf),
            "Invalid merkle proof"
        );
        
        allowlistClaimed[msg.sender][allowlistId] = true;
        
        // Call core contract to handle pack
        traitsCore.purchasePack(packId, 1, merkleProof);
        
        emit AllowlistPackClaimed(msg.sender, allowlistId, packId);
    }

    /**
     * @notice Abre un pack ya comprado en el core
     */
    function openExistingPack(uint256 packId) external nonReentrant {
        // Verifica y abre en el core
        traitsCore.openPack(packId);

        // Emitir evento
        emit PackOpenedWithExtensions(msg.sender, packId);
    }

    // =============== Token Trait Management (NUEVAS FUNCIONES) ===============
    
    /**
     * @dev Equip trait to token
     */
    function equipTraitToToken(uint256 tokenId, uint256 traitId) external onlyTokenOwner(tokenId) {
        require(traitsCore.balanceOf(msg.sender, traitId) > 0, "Don't own trait");
        require(!_traitAlreadyEquipped(tokenId, traitId), "Trait already equipped");

        string memory category = traitsCore.getCategory(traitId);
        require(bytes(category).length > 0, "Invalid category");
        require(!_categoryExceedsLimit(tokenId, category), "Category limit exceeded");

        // Obtener datos del trait y quemar si es temporal
        (string memory traitCategory, bool isTemporary) = traitsCore.getTraitInfo(traitId);
        if (isTemporary) {
            traitsCore.burn(msg.sender, traitId, 1);
        }

        // Unequip previous trait in this category if exists
        uint256 currentTrait = equippedTrait[tokenId][category];
        if (currentTrait != 0) {
            emit TraitUnequipped(tokenId, category, currentTrait);
        }

        // Equip new trait
        equippedTrait[tokenId][category] = traitId;

        // Add category to token if not exists
        if (!tokenHasCategory[tokenId][category]) {
            tokenCategories[tokenId].push(category);
            tokenHasCategory[tokenId][category] = true;
        }

        // Registrar el evento en AdrianHistory
        if (address(historyContract) != address(0)) {
            IAdrianHistory(historyContract).recordEvent(
                tokenId,
                keccak256("EQUIP_TRAIT"),
                msg.sender,
                abi.encode(traitId),
                block.number
            );
        }

        emit TraitEquipped(tokenId, category, traitId);
    }

    function _traitAlreadyEquipped(uint256 tokenId, uint256 traitId) internal view returns (bool) {
        string memory category = traitsCore.getCategory(traitId);
        return equippedTrait[tokenId][category] == traitId;
    }

    function _categoryExceedsLimit(uint256 tokenId, string memory category) internal view returns (bool) {
        // Implementar lógica para verificar si la categoría permite más de un trait
        // Por ejemplo, si la categoría es "BACKGROUND", no permitir más de uno
        return false; // Cambiar según la lógica de negocio
    }

    /**
     * @dev Unequip trait from token
     */
    function unequipTrait(uint256 tokenId, string calldata category) external onlyTokenOwner(tokenId) {
        uint256 traitId = equippedTrait[tokenId][category];
        require(traitId != 0, "No trait equipped in category");
        
        equippedTrait[tokenId][category] = 0;
        emit TraitUnequipped(tokenId, category, traitId);
    }

    /**
     * @dev Get all equipped traits for a token
     */
    function getAllEquippedTraits(uint256 tokenId) public view returns (string[] memory categories, uint256[] memory traitIds) {
        string[] memory tokenCats = tokenCategories[tokenId];
        uint256 equippedCount = 0;
        
        // Count equipped traits
        for (uint256 i = 0; i < tokenCats.length; i++) {
            if (equippedTrait[tokenId][tokenCats[i]] != 0) {
                equippedCount++;
            }
        }
        
        // Create result arrays
        categories = new string[](equippedCount);
        traitIds = new uint256[](equippedCount);
        
        uint256 index = 0;
        for (uint256 i = 0; i < tokenCats.length; i++) {
            uint256 traitId = equippedTrait[tokenId][tokenCats[i]];
            if (traitId != 0) {
                categories[index] = tokenCats[i];
                traitIds[index] = traitId;
                index++;
            }
        }
        
        return (categories, traitIds);
    }

    /**
     * @dev Get all categories registered in core contract
     */
    function getCategories() public view returns (string[] memory) {
        return IAdrianTraitsCore(coreContract).getCategoryList();
    }

    /**
     * @dev Get trait for specific category on a token
     */
    function getTrait(uint256 tokenId, string memory category) public view returns (uint256) {
        return equippedTrait[tokenId][category];
    }

    // =============== Inventory System for AdrianZERO ===============
    
    /**
     * @dev Add asset to AdrianZERO inventory
     */
    function addAssetToInventory(
        uint256 tokenId,
        uint256 assetId,
        uint256 amount
    ) external onlyTokenOwner(tokenId) {
        // Inline asset validation
        string memory name = traitsCore.getName(assetId);
        require(bytes(name).length > 0, "Invalid asset");
        
        require(IERC1155(coreContract).balanceOf(msg.sender, assetId) >= amount, "Insufficient assets");
        
        // Transfer assets to this contract (escrow)
        IERC1155(coreContract).safeTransferFrom(
            msg.sender,
            address(this),
            assetId,
            amount,
            ""
        );
        
        // Add to token inventory - simplified to use assetId directly
        for (uint256 i = 0; i < amount; i++) {
            tokenInventory[tokenId][0].push(assetId); // Use 0 as general inventory
        }
        
        emit AssetAddedToInventory(tokenId, assetId, amount);
    }

    /**
     * @dev Remove asset from AdrianZERO inventory
     */
    function removeAssetFromInventory(
        uint256 tokenId,
        uint256 assetId,
        uint256 amount
    ) external onlyTokenOwner(tokenId) {
        uint256[] storage inventory = tokenInventory[tokenId][0];
        
        uint256 removed = 0;
        for (uint256 i = 0; i < inventory.length && removed < amount; i++) {
            if (inventory[i] == assetId) {
                // Remove using swap and pop
                inventory[i] = inventory[inventory.length - 1];
                inventory.pop();
                removed++;
                i--; // Check the swapped element
            }
        }
        
        require(removed == amount, "Not enough assets in inventory");
        
        // Return assets to user
        IERC1155(coreContract).safeTransferFrom(
            address(this),
            msg.sender,
            assetId,
            amount,
            ""
        );
        
        emit AssetRemovedFromInventory(tokenId, assetId, amount);
    }

    /**
     * @dev Use asset from inventory (consumes it)
     */
    function useAssetFromInventory(
        uint256 tokenId,
        uint256 assetId,
        bytes calldata /* gameData */
    ) external onlyTokenOwner(tokenId) returns (bool) {
        uint256[] storage inventory = tokenInventory[tokenId][0];
        
        bool found = false;
        for (uint256 i = 0; i < inventory.length; i++) {
            if (inventory[i] == assetId) {
                // Remove asset (consumed)
                inventory[i] = inventory[inventory.length - 1];
                inventory.pop();
                found = true;
                break;
            }
        }
        
        require(found, "Asset not in inventory");
        
        emit AssetUsedFromInventory(tokenId, assetId);
        return true;
    }

    // =============== URI and Metadata ===============
    
    /**
     * @dev Get asset URI
     */
    function getAssetURI(uint256 assetId) external view returns (string memory) {
        if (bytes(overrideAssetURIs[assetId]).length > 0) {
            return overrideAssetURIs[assetId];
        }
        return string(abi.encodePacked(baseExternalURI, assetId.toString()));
    }

    /**
     * @dev Set base external URI
     */
    function setBaseExternalURI(string calldata newBaseURI) external onlyOwner {
        baseExternalURI = newBaseURI;
    }

    /**
     * @dev Set custom URI for specific asset
     */
    function setCustomAssetURI(uint256 assetId, string calldata uri) external onlyOwner {
        overrideAssetURIs[assetId] = uri;
    }

    // =============== View Functions ===============
    
    /**
     * @dev Get token inventory
     */
    function getTokenInventory(uint256 tokenId, uint256 assetType) external view returns (uint256[] memory) {
        return tokenInventory[tokenId][assetType];
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

    // =============== Admin Functions ===============
    
    /**
     * @dev Set core contract
     */
    function setCoreContract(address _coreContract) external onlyOwner {
        require(_coreContract != address(0) && _coreContract.code.length > 0, "Invalid contract");
        coreContract = _coreContract;
    }

    /**
     * @dev Set AdrianLab contract
     */
    function setAdrianLabContract(address _adrianLabContract) external onlyOwner {
        require(_adrianLabContract != address(0) && _adrianLabContract.code.length > 0, "Invalid contract");
        adrianLabContract = _adrianLabContract;
        IAdrianLabCore(_adrianLabContract).setExtensionsContract(address(this));
    }

    // =============== ERC1155 Receiver ===============
    
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

    // =============== External Functions ===============

    function mintTraitPaid(
        uint256 traitId,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external payable nonReentrant {
        require(!isPack[traitId], "Use mintPack for packs");
        require(traitAvailable[traitId], "Not available for sale");
        require(traitInfo[traitId].maxSupply > 0, "Invalid trait");
        require(traitSupply[traitId] + amount <= traitInfo[traitId].maxSupply, "Exceeds max supply");
        require(block.timestamp >= traitSaleStart[traitId], "Sale not started");
        require(traitSaleEnd[traitId] == 0 || block.timestamp <= traitSaleEnd[traitId], "Sale ended");

        if (traitWhitelistRoot[traitId] != bytes32(0)) {
            bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
            require(MerkleProof.verify(merkleProof, traitWhitelistRoot[traitId], leaf), "Not whitelisted");
        }

        uint256 totalPrice = traitPrice[traitId] * amount;
        require(msg.value >= totalPrice, "Insufficient payment");

        traitSupply[traitId] += amount;
        _mint(msg.sender, traitId, amount, "");

        payable(treasury).transfer(msg.value);
        
        emit TraitMinted(msg.sender, traitId, amount);
    }

    function mintPack(uint256 packId) external payable nonReentrant {
        require(isPack[packId], "Not a pack");
        require(traitAvailable[packId], "Pack not available");
        
        uint256[] memory contents = packContents[packId];
        require(contents.length > 0, "Empty pack");
        
        // Verificar disponibilidad de todos los traits en el pack
        for (uint256 i = 0; i < contents.length; i++) {
            uint256 traitId = contents[i];
            require(traitSupply[traitId] < traitInfo[traitId].maxSupply, "Pack trait sold out");
            traitSupply[traitId]++;
            _mint(msg.sender, traitId, 1, "");
        }
        
        emit PackMinted(msg.sender, packId);
    }

    // =============== View Functions ===============

    function getRemainingSupply(uint256 traitId) external view returns (uint256) {
        return traitInfo[traitId].maxSupply - traitSupply[traitId];
    }

    function getPackContents(uint256 packId) external view returns (uint256[] memory) {
        require(isPack[packId], "Not a pack");
        return packContents[packId];
    }

    // =============== Admin Functions ===============

    function setTraitSaleConfig(
        uint256 traitId,
        uint256 priceInWei,
        bool available,
        uint256 startTimestamp,
        uint256 endTimestamp,
        bytes32 whitelistMerkleRoot
    ) external onlyOwner {
        traitPrice[traitId] = priceInWei;
        traitAvailable[traitId] = available;
        traitSaleStart[traitId] = startTimestamp;
        traitSaleEnd[traitId] = endTimestamp;
        traitWhitelistRoot[traitId] = whitelistMerkleRoot;

        emit TraitSaleConfigured(
            traitId,
            priceInWei,
            available,
            startTimestamp,
            endTimestamp,
            whitelistMerkleRoot
        );
    }

    function createTrait(
        uint256 traitId,
        string memory name,
        string memory category,
        uint256 maxSupply
    ) external onlyOwner {
        require(traitInfo[traitId].maxSupply == 0, "Trait already exists");
        
        traitInfo[traitId] = TraitInfo({
            name: name,
            category: category,
            maxSupply: maxSupply,
            isPack: false
        });
        
        emit TraitCreated(traitId, name, category, maxSupply);
    }

    function createPack(
        uint256 packId,
        uint256[] calldata contents
    ) external onlyOwner {
        require(contents.length > 0, "Empty contents");
        require(traitInfo[packId].maxSupply == 0, "Pack already exists");
        
        packContents[packId] = contents;
        isPack[packId] = true;
        
        traitInfo[packId] = TraitInfo({
            name: "Pack",
            category: "Packs",
            maxSupply: type(uint256).max, // Unlimited supply for packs
            isPack: true
        });
        
        emit PackCreated(packId, contents);
    }

    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Invalid treasury");
        treasury = _treasury;
    }

    function setURI(string memory newuri) external onlyOwner {
        _setURI(newuri);
    }

    // =============== Internal Functions ===============

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    /**
     * @dev Burn and equip trait in one transaction
     */
    function burnAndEquipTrait(
        uint256 tokenId,
        uint256 traitId,
        string calldata category
    ) external onlyCore {
        require(traitAvailable[traitId], "Trait not available");
        require(balanceOf(msg.sender, traitId) > 0, "Insufficient trait balance");
        _burn(msg.sender, traitId, 1);
        equippedTrait[tokenId][category] = traitId;

        // Add category to token if not exists
        if (!tokenHasCategory[tokenId][category]) {
            tokenCategories[tokenId].push(category);
            tokenHasCategory[tokenId][category] = true;
        }

        emit TraitEquipped(tokenId, category, traitId);
    }

    /**
     * @dev Set history contract
     */
    function setHistoryContract(address _historyContract) external onlyOwner {
        require(_historyContract != address(0) && _historyContract.code.length > 0, "Invalid contract");
        historyContract = IAdrianHistory(_historyContract);
    }
}