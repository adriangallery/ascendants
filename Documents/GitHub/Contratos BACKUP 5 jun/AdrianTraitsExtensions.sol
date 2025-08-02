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

// =============== Libraries ===============
library TraitManagement {
    struct TraitInfo {
        string name;
        string category;
        uint256 maxSupply;
        bool isPack;
    }

    struct TraitSaleConfig {
        uint256 price;
        bool available;
        uint256 startTime;
        uint256 endTime;
        bytes32 whitelistRoot;
    }

    function validateTraitSale(
        TraitInfo storage trait,
        TraitSaleConfig storage config,
        uint256 currentSupply,
        uint256 amount,
        uint256 timestamp
    ) internal view {
        require(!trait.isPack, "Use mintPack for packs");
        require(config.available, "Trait not available");
        require(trait.maxSupply > 0, "Trait does not exist");
        require(currentSupply + amount <= trait.maxSupply, "Max supply exceeded");
        require(timestamp >= config.startTime, "Sale not started");
        require(config.endTime == 0 || timestamp <= config.endTime, "Sale ended");
    }
}

library PackManagement {
    struct PackInfo {
        uint256[] contents;
        bool isPack;
    }

    function validatePackMint(
        PackInfo storage pack,
        mapping(uint256 => TraitManagement.TraitInfo) storage traitInfo,
        mapping(uint256 => uint256) storage traitSupply
    ) internal view {
        require(pack.isPack, "Not a pack");
        require(pack.contents.length > 0, "Empty pack");

        for (uint256 i = 0; i < pack.contents.length; i++) {
            uint256 traitId = pack.contents[i];
            require(traitSupply[traitId] < traitInfo[traitId].maxSupply, "Trait in pack sold out");
        }
    }
}

library InventoryManagement {
    function addToInventory(
        mapping(uint256 => mapping(uint256 => uint256[])) storage inventory,
        uint256 tokenId,
        uint256 assetId,
        uint256 amount
    ) internal {
        for (uint256 i = 0; i < amount; i++) {
            inventory[tokenId][0].push(assetId);
        }
    }

    function removeFromInventory(
        mapping(uint256 => mapping(uint256 => uint256[])) storage inventory,
        uint256 tokenId,
        uint256 assetId,
        uint256 amount
    ) internal returns (bool) {
        uint256[] storage items = inventory[tokenId][0];
        uint256 removedCount = 0;
        
        for (uint256 i = 0; i < items.length && removedCount < amount; i++) {
            if (items[i] == assetId) {
                items[i] = items[items.length - 1];
                items.pop();
                removedCount++;
                i--;
            }
        }
        
        return removedCount == amount;
    }
}

/**
 * @title AdrianTraitsExtensions
 * @dev Advanced features for traits system including token trait management
 */
contract AdrianTraitsExtensions is ERC1155, Ownable, ReentrancyGuard {
    using Strings for uint256;
    using TraitManagement for TraitManagement.TraitInfo;
    using PackManagement for PackManagement.PackInfo;
    using InventoryManagement for mapping(uint256 => mapping(uint256 => uint256[]));

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
    mapping(uint256 => TraitManagement.TraitInfo) public traitInfo;
    mapping(uint256 => uint256) public traitSupply;
    mapping(uint256 => TraitManagement.TraitSaleConfig) public traitSaleConfig;
    
    // Pack configuration
    mapping(uint256 => PackManagement.PackInfo) public packInfo;

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

    function setAllowlistMerkleRoot(uint256 allowlistId, bytes32 merkleRoot) external onlyOwner {
        allowlistMerkleRoots[allowlistId] = merkleRoot;
        emit AllowlistUpdated(allowlistId, merkleRoot);
    }

    function claimAllowlistPack(
        uint256 packId,
        uint256 allowlistId,
        bytes32[] calldata merkleProof
    ) external nonReentrant {
        require(!allowlistClaimed[msg.sender][allowlistId], "Already claimed from allowlist");

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(
            MerkleProof.verify(merkleProof, allowlistMerkleRoots[allowlistId], leaf),
            "Invalid merkle proof"
        );

        allowlistClaimed[msg.sender][allowlistId] = true;
        traitsCore.purchasePack(packId, 1, merkleProof);

        emit AllowlistPackClaimed(msg.sender, allowlistId, packId);
    }

    function openExistingPack(uint256 packId) external nonReentrant {
        traitsCore.openPack(packId);
        emit PackOpenedWithExtensions(msg.sender, packId);
    }

    // =============== Token Trait Management ===============

    function equipTraitToToken(uint256 tokenId, uint256 traitId) external onlyTokenOwner(tokenId) {
        require(traitsCore.balanceOf(msg.sender, traitId) > 0, "Don't own trait");
        require(!_traitAlreadyEquipped(tokenId, traitId), "Trait already equipped");

        string memory category = traitsCore.getCategory(traitId);
        require(bytes(category).length > 0, "Invalid category");
        require(!_categoryExceedsLimit(tokenId, category), "Category limit exceeded");

        (, bool isTemporary) = traitsCore.getTraitInfo(traitId);
        if (isTemporary) {
            traitsCore.burn(msg.sender, traitId, 1);
        }

        uint256 currentTrait = equippedTrait[tokenId][category];
        if (currentTrait != 0) {
            emit TraitUnequipped(tokenId, category, currentTrait);
        }

        equippedTrait[tokenId][category] = traitId;

        if (!tokenHasCategory[tokenId][category]) {
            tokenCategories[tokenId].push(category);
            tokenHasCategory[tokenId][category] = true;
        }

        if (address(historyContract) != address(0)) {
            historyContract.recordEvent(
                tokenId,
                keccak256("EQUIP_TRAIT"),
                msg.sender,
                abi.encode(traitId),
                block.number
            );
        }

        emit TraitEquipped(tokenId, category, traitId);
    }

    function unequipTrait(uint256 tokenId, string calldata category) external onlyTokenOwner(tokenId) {
        uint256 traitId = equippedTrait[tokenId][category];
        require(traitId != 0, "No trait equipped");

        equippedTrait[tokenId][category] = 0;
        emit TraitUnequipped(tokenId, category, traitId);
    }

    function getAllEquippedTraits(uint256 tokenId)
        public
        view
        returns (string[] memory categories, uint256[] memory traitIds)
    {
        string[] memory tokenCats = tokenCategories[tokenId];
        uint256 totalCategories = tokenCats.length;

        uint256 equippedCount = 0;
        for (uint256 i = 0; i < totalCategories; i++) {
            if (equippedTrait[tokenId][tokenCats[i]] != 0) {
                equippedCount++;
            }
        }

        string[] memory _categories = new string[](equippedCount);
        uint256[] memory _traitIds = new uint256[](equippedCount);

        uint256 index = 0;
        for (uint256 i = 0; i < tokenCats.length; i++) {
            uint256 traitId = equippedTrait[tokenId][tokenCats[i]];
            if (traitId != 0) {
                _categories[index] = tokenCats[i];
                _traitIds[index] = traitId;
                index++;
            }
        }

        return (_categories, _traitIds);
    }

    function _traitAlreadyEquipped(uint256 tokenId, uint256 traitId) internal view returns (bool) {
        string memory category = traitsCore.getCategory(traitId);
        return equippedTrait[tokenId][category] == traitId;
    }

    function _categoryExceedsLimit(uint256 tokenId, string memory category) internal view returns (bool) {
        return false;
    }

    // =============== Inventory System ===============

    function addAssetToInventory(
        uint256 tokenId,
        uint256 assetId,
        uint256 amount
    ) external onlyTokenOwner(tokenId) {
        string memory assetName = traitsCore.getName(assetId);
        require(bytes(assetName).length > 0, "Invalid asset");

        require(
            IERC1155(coreContract).balanceOf(msg.sender, assetId) >= amount,
            "Insufficient asset balance"
        );

        IERC1155(coreContract).safeTransferFrom(
            msg.sender,
            address(this),
            assetId,
            amount,
            ""
        );

        tokenInventory.addToInventory(tokenId, assetId, amount);
        emit AssetAddedToInventory(tokenId, assetId, amount);
    }

    function removeAssetFromInventory(
        uint256 tokenId,
        uint256 assetId,
        uint256 amount
    ) external onlyTokenOwner(tokenId) {
        bool success = tokenInventory.removeFromInventory(tokenId, assetId, amount);
        require(success, "Not enough assets in inventory");

        IERC1155(coreContract).safeTransferFrom(
            address(this),
            msg.sender,
            assetId,
            amount,
            ""
        );

        emit AssetRemovedFromInventory(tokenId, assetId, amount);
    }

    function useAssetFromInventory(
        uint256 tokenId,
        uint256 assetId,
        bytes calldata /* gameData */
    ) external onlyTokenOwner(tokenId) returns (bool) {
        bool success = tokenInventory.removeFromInventory(tokenId, assetId, 1);
        require(success, "Asset not in inventory");

        emit AssetUsedFromInventory(tokenId, assetId);
        return true;
    }

    // =============== External Minting Functions ===============

    function mintTraitPaid(
        uint256 traitId,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external payable nonReentrant {
        TraitManagement.TraitSaleConfig storage config = traitSaleConfig[traitId];
        TraitManagement.TraitInfo storage trait = traitInfo[traitId];

        trait.validateTraitSale(config, traitSupply[traitId], amount, block.timestamp);

        if (config.whitelistRoot != bytes32(0)) {
            bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
            require(
                MerkleProof.verify(merkleProof, config.whitelistRoot, leaf),
                "Not whitelisted"
            );
        }

        uint256 totalPrice = config.price * amount;
        require(msg.value >= totalPrice, "Insufficient payment");

        traitSupply[traitId] += amount;
        _mint(msg.sender, traitId, amount, "");

        payable(treasury).transfer(msg.value);
        emit TraitMinted(msg.sender, traitId, amount);
    }

    function mintPack(uint256 packId) external payable nonReentrant {
        PackManagement.PackInfo storage pack = packInfo[packId];
        pack.validatePackMint(traitInfo, traitSupply);

        for (uint256 i = 0; i < pack.contents.length; i++) {
            uint256 traitId = pack.contents[i];
            traitSupply[traitId]++;
            _mint(msg.sender, traitId, 1, "");
        }

        emit PackMinted(msg.sender, packId);
    }

    // =============== Administrative Functions ===============

    function setTraitSaleConfig(
        uint256 traitId,
        uint256 priceInWei,
        bool available,
        uint256 startTimestamp,
        uint256 endTimestamp,
        bytes32 whitelistMerkleRoot
    ) external onlyOwner {
        traitSaleConfig[traitId] = TraitManagement.TraitSaleConfig({
            price: priceInWei,
            available: available,
            startTime: startTimestamp,
            endTime: endTimestamp,
            whitelistRoot: whitelistMerkleRoot
        });

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

        traitInfo[traitId] = TraitManagement.TraitInfo({
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
        require(contents.length > 0, "Pack contents empty");
        require(traitInfo[packId].maxSupply == 0, "Pack already exists");

        packInfo[packId] = PackManagement.PackInfo({
            contents: contents,
            isPack: true
        });

        traitInfo[packId] = TraitManagement.TraitInfo({
            name: "Pack",
            category: "Packs",
            maxSupply: type(uint256).max,
            isPack: true
        });

        emit PackCreated(packId, contents);
    }

    // =============== View Functions ===============

    function getRemainingSupply(uint256 traitId) external view returns (uint256) {
        return traitInfo[traitId].maxSupply - traitSupply[traitId];
    }

    function getPackContents(uint256 packId) external view returns (uint256[] memory) {
        require(packInfo[packId].isPack, "Not a pack");
        return packInfo[packId].contents;
    }

    function getCategories() public view returns (string[] memory) {
        return IAdrianTraitsCore(coreContract).getCategoryList();
    }

    function getTrait(uint256 tokenId, string memory category) public view returns (uint256) {
        return equippedTrait[tokenId][category];
    }

    // =============== Emergency Management ===============

    function setEmergencyMode(bool enabled) external onlyOwner {
        emergencyMode = enabled;
        emit EmergencyModeSet(enabled);
    }

    function setFunctionPaused(bytes4 functionSelector, bool paused) external onlyOwner {
        pausedFunctions[functionSelector] = paused;
        emit FunctionPauseToggled(functionSelector, paused);
    }

    // =============== Contract Management ===============

    function setCoreContract(address _coreContract) external onlyOwner {
        require(_coreContract != address(0) && _coreContract.code.length > 0, "Invalid core contract");
        coreContract = _coreContract;
    }

    function setAdrianLabContract(address _adrianLabContract) external onlyOwner {
        require(_adrianLabContract != address(0) && _adrianLabContract.code.length > 0, "Invalid AdrianLab contract");
        adrianLabContract = _adrianLabContract;
        IAdrianLabCore(_adrianLabContract).setExtensionsContract(address(this));
    }

    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Invalid treasury address");
        treasury = _treasury;
    }

    function setURI(string memory newuri) external onlyOwner {
        _setURI(newuri);
    }

    function setHistoryContract(address _historyContract) external onlyOwner {
        require(_historyContract != address(0) && _historyContract.code.length > 0, "Invalid history contract");
        historyContract = IAdrianHistory(_historyContract);
    }

    // =============== ERC1155 Receiver Functions ===============

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

    // =============== Internal Functions ===============

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function burnAndEquipTrait(
        uint256 tokenId,
        uint256 traitId,
        string calldata category
    ) external onlyCore {
        require(traitSaleConfig[traitId].available, "Trait not available");
        require(balanceOf(msg.sender, traitId) > 0, "Insufficient trait balance");

        _burn(msg.sender, traitId, 1);
        equippedTrait[tokenId][category] = traitId;

        if (!tokenHasCategory[tokenId][category]) {
            tokenCategories[tokenId].push(category);
            tokenHasCategory[tokenId][category] = true;
        }

        emit TraitEquipped(tokenId, category, traitId);
    }
}