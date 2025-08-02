// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./interfaces/IAdrianHistory.sol";

/**
 * @title AdrianLabExtensions
 * @dev Extensions contract with history and advanced functions
 */
contract AdrianLabExtensions is Ownable, ReentrancyGuard {
    using Strings for uint256;

    // =============== Constants ===============
    
    bytes32 constant EVENT_MINT = keccak256("MINT");
    bytes32 constant EVENT_REPLICATE = keccak256("REPLICATE");
    bytes32 constant EVENT_MUTATE = keccak256("MUTATE");
    bytes32 constant EVENT_SERUM_USED = keccak256("SERUM_USED");

    // =============== Type Definitions ===============
    
    enum MutationType {
        NONE,
        MILD,
        SEVERE
    }

    enum SerumType {
        BASIC_MUTATION,
        DIRECTED_MUTATION,
        ADVANCED_MUTATION
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
    }

    // =============== State Variables ===============
    
    // Contract references
    address public coreContract;
    address public traitsContract;
    address public adminContract;
    address public historyContract;
    
    // Extension system
    mapping(address => bool) public extensionAuthorized;
    mapping(address => bool) public authorizedExtensions;
    
    // Emergency system
    bool public emergencyMode = false;
    mapping(bytes4 => bool) public pausedFunctions;

    // URI management
    string public baseExternalURI = "https://adrianlab.vercel.app/api/metadata/";
    mapping(uint256 => string) public overrideTokenURIs;

    // =============== Events ===============
    
    event SerumUsed(address indexed user, uint256 tokenId, uint256 serumId);
    event TokenDuplicated(uint256 indexed originalTokenId, uint256 indexed newTokenId, MutationType mutationType);
    event TokenMutatedBySerum(uint256 indexed tokenId, MutationType mutationType);
    event FirstModification(uint256 indexed tokenId);
    event ExtensionAuthorized(address indexed extension, bool authorized);
    event EmergencyModeSet(bool enabled);
    event FunctionPauseToggled(bytes4 functionSelector, bool paused);
    event EmergencyModificationRestored(uint256 indexed tokenId, bool modified);
    event TraitContractUpdated(address newContract);
    event CoreContractUpdated(address newContract);
    event AuthorizationUpdated(address indexed account, bool status);
    event HistoryContractUpdated(address newContract);

    // =============== Modifiers ===============
    
    modifier onlyAuthorizedExtension() {
        require(msg.sender == owner() || extensionAuthorized[msg.sender], "Not authorized");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == adminContract, "Not admin");
        _;
    }

    modifier onlyCore() {
        require(msg.sender == coreContract, "!core");
        _;
    }

    modifier onlyTraits() {
        require(msg.sender == traitsContract, "!traits");
        _;
    }

    modifier onlyExtension() {
        require(extensionAuthorized[msg.sender], "!extension");
        _;
    }

    modifier notPaused(bytes4 selector) {
        require(!emergencyMode || !pausedFunctions[selector], "paused");
        _;
    }

    modifier tokenExists(uint256 tokenId) {
        require(IERC721(coreContract).ownerOf(tokenId) != address(0), "!exist");
        _;
    }

    // =============== Constructor ===============
    
    constructor(address _coreContract) Ownable(msg.sender) {
        coreContract = _coreContract;
    }

    // =============== Core Contract Hooks ===============

    /**
     * @dev Called when a token is minted
     */
    function onTokenMinted(uint256 tokenId, address /* to */) external onlyCore {
        IAdrianHistory(historyContract).recordEvent(
            tokenId,
            EVENT_MINT,
            msg.sender,
            abi.encodePacked(block.timestamp),
            block.number
        );
    }

    /**
     * @dev Called when a token is replicated
     */
    function onTokenReplicated(uint256 parentId, uint256 childId) external onlyCore {
        IAdrianHistory(historyContract).recordEvent(
            parentId,
            EVENT_REPLICATE,
            msg.sender,
            abi.encodePacked(childId, block.timestamp),
            block.number
        );
        
        IAdrianHistory(historyContract).recordEvent(
            childId,
            EVENT_REPLICATE,
            msg.sender,
            abi.encodePacked(parentId, block.timestamp),
            block.number
        );
    }

    /**
     * @dev Called when a token is duplicated
     */
    function onTokenDuplicated(uint256 originalId, uint256 newId) external onlyCore {
        IAdrianHistory(historyContract).recordEvent(
            originalId,
            keccak256("DUPLICATED"),
            msg.sender,
            abi.encodePacked(newId, block.timestamp),
            block.number
        );
        
        (, uint8 mutationTypeRaw, , , , ) = IAdrianLabCore(coreContract).getTokenData(newId);
        MutationType mutationType = MutationType(mutationTypeRaw);
        
        IAdrianHistory(historyContract).recordEvent(
            newId,
            keccak256("CREATED_BY_DUPLICATION"),
            msg.sender,
            abi.encodePacked(originalId, uint8(mutationType), block.timestamp),
            block.number
        );
    }

    /**
     * @dev Called when serum is applied
     */
    function onSerumApplied(uint256 tokenId, uint256 serumId) external onlyCore {
        IAdrianHistory(historyContract).recordEvent(
            tokenId,
            EVENT_SERUM_USED,
            msg.sender,
            abi.encodePacked(serumId, block.timestamp),
            block.number
        );
    }

    // =============== Admin Functions ===============

    function setTraitsContract(address _traitsContract) external onlyOwner {
        require(_traitsContract != address(0), "Invalid address");
        traitsContract = _traitsContract;
        emit TraitContractUpdated(_traitsContract);
    }

    function setCoreContract(address _coreContract) external onlyOwner {
        require(_coreContract != address(0), "Invalid address");
        coreContract = _coreContract;
        emit CoreContractUpdated(_coreContract);
    }

    function setHistoryContract(address _historyContract) external onlyOwner {
        require(_historyContract != address(0) && _historyContract.code.length > 0, "Invalid contract");
        historyContract = _historyContract;
        emit HistoryContractUpdated(_historyContract);
    }

    function setAdminContract(address _adminContract) external onlyOwner {
        require(_adminContract != address(0), "Invalid address");
        adminContract = _adminContract;
    }

    function setExtensionAuthorization(address extension, bool authorized) external onlyOwner {
        extensionAuthorized[extension] = authorized;
        emit ExtensionAuthorized(extension, authorized);
    }

    function setEmergencyMode(bool enabled) external onlyOwner {
        emergencyMode = enabled;
        emit EmergencyModeSet(enabled);
    }

    function setFunctionPaused(bytes4 functionSelector, bool paused) external onlyOwner {
        pausedFunctions[functionSelector] = paused;
        emit FunctionPauseToggled(functionSelector, paused);
    }

    // =============== Internal Functions ===============

    function _mutationTypeToString(MutationType mutationType) internal pure returns (string memory) {
        if (mutationType == MutationType.NONE) return "NONE";
        if (mutationType == MutationType.MILD) return "MILD";
        if (mutationType == MutationType.SEVERE) return "SEVERE";
        return "UNKNOWN";
    }

    /**
     * @dev Get token URI
     */
    function getTokenURI(uint256 tokenId) external view returns (string memory) {
        if (bytes(overrideTokenURIs[tokenId]).length > 0) {
            return overrideTokenURIs[tokenId];
        }
        return string(abi.encodePacked(baseExternalURI, tokenId.toString()));
    }

    /**
     * @dev Set base external URI
     */
    function setBaseExternalURI(string calldata newBaseURI) external onlyOwner {
        baseExternalURI = newBaseURI;
    }

    /**
     * @dev Set custom URI for specific token
     */
    function setCustomTokenURI(uint256 tokenId, string calldata uri) external onlyOwner {
        overrideTokenURIs[tokenId] = uri;
    }
}

// =============== Interfaces ===============

interface IAdrianLabCore {
    function getTokenData(uint256 tokenId) external view returns (
        uint256 generation,
        uint8 mutationType,
        bool canReplicate,
        uint256 replicationCount,
        uint256 lastReplication,
        bool hasBeenModified
    );
}

interface IAdrianHistory {
    function recordEvent(
        uint256 tokenId,
        bytes32 eventType,
        address actor,
        bytes memory eventData,
        uint256 blockNumber
    ) external;
}