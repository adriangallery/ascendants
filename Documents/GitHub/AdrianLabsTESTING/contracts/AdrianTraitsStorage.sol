// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AdrianTraitsStorage
 * @dev Storage contract for the AdrianTraits logic
 */
contract AdrianTraitsStorage is 
    Initializable, 
    ERC1155URIStorageUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    // Enums
    enum AssetType {
        VISUAL_TRAIT,
        SERUM,
        BACKGROUND,
        SPECIAL
    }
    
    enum SerumType {
        BASIC_MUTATION,
        DIRECTED_MUTATION,
        ADVANCED_MUTATION
    }
    
    // Structs
    struct AssetData {
        string name;
        string category;
        string ipfsPath;
        bool isTemporary;
        uint256 maxSupply;
        AssetType assetType;
        string metadata;
    }
    
    struct SerumData {
        SerumType serumType;
        string targetMutation;
        uint256 potency;
        string metadata;
    }
    
    struct PackConfig {
        uint256 id;
        uint256 price;
        uint256 maxSupply;
        uint256 minted;
        uint256 itemsPerPack;
        bool active;
        string uri;
    }
    
    // Constants
    uint256 constant BASIC_SERUM_ID = 10001;
    uint256 constant MUTATION_SERUM_ID = 10002;
    uint256 constant ADVANCED_SERUM_ID = 10003;
    
    // State variables
    address public adrianLabContract;
    address public paymentToken;
    
    // Asset management
    mapping(uint256 => AssetData) public assets;
    mapping(uint256 => SerumData) public serums;
    mapping(uint256 => uint256) public totalMintedPerTrait;
    uint256 public nextTraitId;
    
    // Pack system
    mapping(uint256 => PackConfig) public packConfigs;
    mapping(address => mapping(uint256 => uint256)) public unclaimedPacks;
    uint256 public nextPackId;
    
    // Financial
    mapping(address => uint256) public pendingProceeds;
    
    // Events
    event TraitRegistered(uint256 indexed traitId, string name, string category, uint256 maxSupply);
    event TraitMinted(uint256 indexed traitId, address indexed to, uint256 amount);
    event SerumRegistered(uint256 indexed serumId, SerumType serumType, string targetMutation, uint256 potency);
    event SerumMinted(address indexed to, uint256 indexed serumId, uint256 amount);
    event PackDefined(uint256 indexed packId, uint256 price, uint256 maxSupply, uint256 itemsPerPack, string uri);
    event PackPurchased(address indexed buyer, uint256 indexed packId, uint256 quantity);
    event PackOpened(address indexed buyer, uint256 indexed packId, uint256[] traits);
    
    /**
     * @dev Implementación del mecanismo _authorizeUpgrade para UUPS
     * Solo el propietario puede autorizar actualizaciones
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}