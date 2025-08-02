// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AdrianLabStorage
 * @dev Contrato de almacenamiento para el sistema AdrianLab
 */
contract AdrianLabStorage is 
    Initializable, 
    ERC721EnumerableUpgradeable, 
    OwnableUpgradeable, 
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    // =============== Type Definitions ===============

    enum MutationType {
        NONE,   // No mutado (GEN0)
        MILD,   // Mutación leve
        MODERATE, // Mutación moderada
        SEVERE  // Mutación severa
    }

    struct HistoricalEvent {
        uint256 timestamp;
        bytes32 eventType;      // Tipo de evento codificado como bytes32
        address actorAddress;   // Quién ejecutó la acción (owner o contrato)
        bytes eventData;        // Datos específicos del evento
        uint256 blockNumber;    // Para verificación
    }
    
    struct TokenTraitInfo {
        string category;
        uint256 traitId;
    }
    
    struct TokenCompleteInfo {
        uint256 tokenId;
        uint256 generation;
        MutationType mutationLevel;
        bool canReplicate;
        uint256 replicationCount;
        uint256 lastReplication;
        bool hasBeenModified;
        TokenTraitInfo[] traits;
    }

    // =============== Constants ===============

    bytes32 constant EVENT_MINT = keccak256("MINT");
    bytes32 constant EVENT_REPLICATE = keccak256("REPLICATE");
    bytes32 constant EVENT_MUTATE = keccak256("MUTATE");
    bytes32 constant EVENT_TRAIT_EQUIPPED = keccak256("TRAIT_EQUIPPED");
    bytes32 constant EVENT_TRAIT_REMOVED = keccak256("TRAIT_REMOVED");
    bytes32 constant EVENT_SERUM_USED = keccak256("SERUM_USED");
    bytes32 constant EVENT_BACKGROUND_EQUIPPED = keccak256("BACKGROUND_EQUIPPED");
    
    // =============== State Variables ===============

    // Token counters and limits
    uint256 public tokenCounter;
    uint256 public mintBatchSize;
    uint256 public mintedInCurrentBatch;
    uint256 public mintPrice;
    bool public mintPaused;
    uint256 public totalGen0Tokens;

    // Replication and mutation
    uint256 public replicationChanceForGen0;
    uint256 public maxReplicationsPerToken;
    uint256 public replicationCooldown;
    uint256 public mildMutationChance;
    uint256 public moderateMutationChance;
    uint256 public severeMutationChance;

    // Metadata and rendering
    string public renderBaseURI;
    
    // Trait system
    address public traitsContractAddress;
    
    // Financial distribution
    address public devWallet;
    address public artistWallet;
    address public treasuryWallet;
    address public communityWallet;
    uint256 public devShare;
    uint256 public artistShare;
    uint256 public treasuryShare;
    uint256 public communityShare;
    mapping(address => uint256) public pendingProceeds;
    
    // Emergency mode
    bool public emergencyMode;
    mapping(bytes4 => bool) public pausedFunctions;
    mapping(address => bool) public historyWriters;
    
    // =============== Mappings ===============
    
    // Token attributes
    mapping(uint256 => uint256) public generation;
    mapping(uint256 => bool) public isGen0Token;
    mapping(uint256 => MutationType) public mutationLevel;
    mapping(uint256 => bool) public canReplicate;
    mapping(uint256 => uint256) public replicationCount;
    mapping(uint256 => uint256) public lastReplication;
    mapping(uint256 => bool) public hasBeenModified;
    mapping(uint256 => bool) public hasBeenDuplicated;
    mapping(uint256 => bool) public hasBeenMutatedBySerum;
    
    // Traits
    mapping(uint256 => mapping(string => uint256)) public tokenTraits;
    string[] public categoryList;
    
    // History system
    mapping(uint256 => HistoricalEvent[]) internal tokenHistory;
    
    // =============== Events ===============
    
    event Mint(address indexed to, uint256 indexed tokenId);
    event MintBatchCompleted(uint256 batchNumber, uint256 totalMinted);
    event MintPriceUpdated(uint256 newPrice);
    event ReplicationEnabled(uint256 indexed tokenId);
    event Replicated(uint256 indexed parentId, uint256 indexed childId);
    event MutationAssigned(uint256 indexed tokenId);
    event TraitEquipped(uint256 indexed tokenId, string category, uint256 traitId);
    event TraitRemoved(uint256 indexed tokenId, string category);
    event SerumUsed(address indexed user, uint256 tokenId, uint256 newTokenId, uint256 serumId);
    event TokenDuplicated(uint256 indexed originalTokenId, uint256 indexed newTokenId, MutationType mutationType);
    event TokenMutatedBySerum(uint256 indexed tokenId, MutationType mutationType);
    event BackgroundEquipped(uint256 indexed tokenId, uint256 backgroundId);
    event FirstModification(uint256 indexed tokenId);
    event HistoryRecorded(uint256 indexed tokenId, bytes32 indexed eventType, uint256 eventIndex);
    event HistoryBatchRecorded(uint256 indexed tokenId, uint256 startIndex, uint256 endIndex);
    event HistoryWriterUpdated(address writer, bool authorized);
    event EmergencyModeSet(bool enabled);
    event FunctionPauseToggled(bytes4 functionSelector, bool paused);
    event EmergencyStateRestored(uint256 tokenId);
    event EmergencyTraitsRestored(uint256 tokenId);
    event ProceedsWithdrawn(address indexed wallet, uint256 amount);
    event RenderBaseURIUpdated(string newURI);
    event TraitsContractUpdated(address newContract);
    event ReplicationSettingsUpdated(uint256 chance, uint256 maxReplications, uint256 cooldown);
    event MutationProbabilitiesUpdated(uint256 mild, uint256 moderate, uint256 severe);
    
    // =============== Modifiers ===============
    
    modifier notPaused(bytes4 selector) {
        require(!emergencyMode || !pausedFunctions[selector], "Function paused in emergency mode");
        _;
    }
    
    modifier onlyHistoryWriter() {
        require(msg.sender == owner() || historyWriters[msg.sender], "Not authorized to write history");
        _;
    }
    
    modifier onlyTraitsContract() {
        require(msg.sender == traitsContractAddress, "Only traits contract can call");
        _;
    }
    
    /**
     * @dev Implementación del mecanismo _authorizeUpgrade para UUPS
     * Solo el propietario puede autorizar actualizaciones
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

// Definición de enumeración SerumType
enum SerumType {
    BASIC_MUTATION,
    DIRECTED_MUTATION,
    ADVANCED_MUTATION
}

interface ITraits {
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;
    function burn(address account, uint256 id, uint256 amount) external;
    function getTraitInfo(uint256 traitId) external view returns (string memory category, bool isTemporary);
    function getCategory(uint256 traitId) external view returns (string memory);
    function getName(uint256 traitId) external view returns (string memory);
    function isTemporary(uint256 traitId) external view returns (bool);
    function getSerumData(uint256 serumId) external view returns (SerumType, string memory, uint256);
    function getTraitInventory(address user) external view returns (uint256[] memory, uint256[] memory);
}