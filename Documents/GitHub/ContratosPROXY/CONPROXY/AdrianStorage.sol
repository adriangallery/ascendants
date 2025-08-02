// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract AdrianStorage is Initializable {
    // ================= AdrianLabCore =================
    enum MutationType { NONE, MILD, SEVERE }
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
    }
    struct Skin {
        string name;
        uint256 rarity;
        bool active;
    }
    uint256 public tokenCounter;
    uint256 public totalGen0Tokens;
    mapping(uint256 => BatchConfig) public batches;
    uint256 public activeBatch;
    uint256 public nextBatchId;
    bool public mintPaused;
    uint256 public mintPrice;
    mapping(uint256 => bool) public isWhitelistEnabledForBatch;
    mapping(address => mapping(uint256 => bool)) public isWhitelistedForBatch;
    mapping(uint256 => mapping(address => uint256)) public mintedPerWalletPerBatch;
    mapping(uint256 => bool) public allowedDuplication;
    mapping(uint256 => Skin) public skins;
    mapping(uint256 => uint256) public tokenSkin;
    uint256 public nextSkinId;
    uint256 public totalSkinWeight;
    bool public randomSkinEnabled;
    string public baseURI;
    address public paymentToken;
    uint256 public replicationChanceForGen0;
    uint256 public maxReplicationsPerToken;
    uint256 public replicationCooldown;
    uint256 public mildMutationChance;
    uint256 public severeMutationChance;
    address public extensionsContract;
    address public traitsContract;
    address public adrianLabExtensions;
    address public treasuryWallet;
    mapping(uint256 => uint256) public generation;
    mapping(uint256 => bool) public isGen0Token;
    mapping(uint256 => MutationType) public mutationLevel;
    mapping(uint256 => bool) public canReplicate;
    mapping(uint256 => uint256) public replicationCount;
    mapping(uint256 => uint256) public lastReplication;
    mapping(uint256 => bool) public hasBeenModified;
    mapping(uint256 => bool) public hasBeenDuplicated;
    mapping(uint256 => bool) public hasBeenMutatedBySerum;
    mapping(uint256 => string) public mutationLevelName;
    address public adrianSerumModule;
    mapping(uint256 => mapping(string => uint256)) public tokenTraits;
    mapping(bytes32 => address) public functionImplementations;

    // ================= AdrianLabAdmin =================
    address public core;
    address public adminExtensionsContract;

    // ================= AdrianLabExtensions =================
    address public coreContract;
    address public adminContract;
    string[] public categoryList;
    mapping(uint256 => mapping(string => uint256)) public ext_tokenTraits;
    mapping(uint256 => bool) public ext_hasBeenModified;
    mapping(uint256 => mapping(string => uint256)) public previousTrait;
    mapping(string => mapping(uint256 => uint256)) public baseTraits;
    mapping(uint256 => mapping(string => TokenTraitInfo)) public tokenEquippedTraits;
    mapping(uint256 => mapping(string => TokenTraitInfo)) public tokenBaseTraits;
    string[] public equippedTraitCategories;
    mapping(string => bool) public isEquippableCategory;
    address public historyContract;
    mapping(address => bool) public extensionAuthorized;
    mapping(address => bool) public authorizedExtensions;
    bool public emergencyMode;
    mapping(bytes4 => bool) public pausedFunctions;

    struct TokenTraitInfo {
        string category;
        uint256 traitId;
        bool isTemporary;
        uint256 equippedAt;
    }
    struct TokenCompleteInfo {
        uint256 tokenId;
        uint256 generation;
        MutationType mutationLevel;
        bool canReplicate;
        uint256 replicationCount;
        uint256 lastReplication;
        bool hasBeenModified;
        uint256 skinId;
        TokenTraitInfo[] traits;
    }

    // ================= AdrianTraitsCore =================
    address public traits_extensionsContract;
    address public traits_coreContract;
    address public serumModule;
    address public assetRegistrar;
    string public baseMetadataURI;
    mapping(uint256 => AssetData) public assets;
    mapping(uint256 => SerumData) public serums;
    mapping(uint256 => uint256) public totalMintedPerAsset;
    mapping(uint256 => uint256) public traitWeights;
    mapping(string => uint256) public totalTraitWeight;
    uint256 public nextAssetId;
    string[] public traits_categoryList;
    mapping(string => bool) public validCategories;
    mapping(uint256 => PackConfig) public packConfigs;
    mapping(uint256 => PackTrait[]) public packTraits;
    mapping(address => mapping(uint256 => uint256)) public packsMintedPerWallet;
    mapping(address => mapping(uint256 => uint256)) public unclaimedPacks;
    mapping(bytes32 => uint256) public promoCodeToPack;
    mapping(bytes32 => uint256) public promoCodeUses;
    mapping(bytes32 => uint256) public promoCodeMaxUses;
    mapping(address => bool) public authorizedPackProviders;
    uint256 public nextPackId;
    address public traits_paymentToken;
    mapping(address => uint256) public pendingProceeds;
    address public traits_treasuryWallet;
    uint256 public constant BASIC_SERUM_ID = 10001;
    uint256 public constant DIRECTED_SERUM_ID = 10002;
    uint256 public constant ADVANCED_SERUM_ID = 10003;
    struct AssetData {
        string name;
        string category;
        string ipfsPath;
        bool tempFlag;
        uint256 maxSupply;
        uint8 assetType;
        string metadata;
    }
    struct SerumData {
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
        uint256 maxPerWallet;
        bool active;
        bool requiresAllowlist;
        bytes32 merkleRoot;
        string uri;
    }
    struct PackTrait {
        uint256 traitId;
        uint256 minAmount;
        uint256 maxAmount;
        uint256 chance;
        uint256 remaining;
    }

    // ================= AdrianTraitsExtensions =================
    address public traitsExt_coreContract;
    address public adrianLabContract;
    mapping(uint256 => MarketplaceListing) public listings;
    mapping(address => uint256[]) public userListings;
    uint256 public nextListingId;
    uint256 public marketplaceFee;
    address public marketplaceFeeRecipient;
    mapping(uint256 => CraftingRecipe) public craftingRecipes;
    uint256 public nextRecipeId;
    mapping(uint256 => bytes32) public allowlistMerkleRoots;
    mapping(address => mapping(uint256 => bool)) public allowlistClaimed;
    mapping(uint256 => mapping(string => uint256)) public traitsExt_tokenTraits;
    mapping(uint256 => string[]) public tokenCategories;
    mapping(uint256 => mapping(string => bool)) public tokenHasCategory;
    mapping(uint256 => mapping(uint256 => uint256[])) public tokenInventory;
    string public traitsExt_baseMetadataURI;
    mapping(uint256 => string) public customAssetURIs;
    mapping(uint256 => mapping(uint256 => bool)) public appliedSerums;
    bool public traitsExt_emergencyMode;
    mapping(bytes4 => bool) public traitsExt_pausedFunctions;
    struct MarketplaceListing {
        address seller;
        uint256 assetId;
        uint256 amount;
        uint256 pricePerUnit;
        uint256 expiration;
        bool active;
    }
    struct CraftingRecipe {
        uint256 id;
        uint256[] ingredientIds;
        uint256[] ingredientAmounts;
        uint256 resultId;
        uint256 resultAmount;
        bool active;
    }

    // ================= AdrianSerumModule =================
    address public serum_owner;
    address public serum_traitsContract;
    address public serum_coreContract;
    mapping(address => uint256[]) public serumsUsed;
    mapping(uint256 => uint256[]) public tokenSerumHistory;
    mapping(uint256 => uint256) public totalUsed;
    mapping(uint256 => uint256) public totalSuccess;
    mapping(uint256 => mapping(uint256 => bool)) public serumUsedOnToken;

    // ================= AdrianHistory =================
    struct HistoricalEvent {
        uint256 timestamp;
        bytes32 eventType;
        address actorAddress;
        bytes eventData;
        uint256 blockNumber;
    }
    mapping(uint256 => HistoricalEvent[]) public tokenHistory;
    mapping(address => bool) public historyWriters;

    function initialize() public initializer {
        // Inicialización básica si es necesaria
    }
} 