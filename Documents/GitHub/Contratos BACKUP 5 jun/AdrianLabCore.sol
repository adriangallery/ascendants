// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AdrianLabCore
 * @dev ERC721Enumerable con lógica inmutable para mutación y minting externalizado
 */
contract AdrianLabCore is ERC721Enumerable, Ownable, ReentrancyGuard {
    using Strings for uint256;

    // =============== Type Definitions ===============
    enum MutationType {
        NONE,
        MILD,
        SEVERE
    }

    struct Skin {
        string name;           // "BareAdrian", "Medium", "Alien"
        uint256 rarity;        // Peso de rareza (1-1000)
        bool active;           // Si está activo para mint
    }

    // =============== State Variables ===============
    
    // Token counters
    uint256 public totalGen0Tokens;

    // Skin system
    mapping(uint256 => Skin) public skins;
    mapping(uint256 => uint256) public tokenSkin;
    uint256 public nextSkinId = 1;
    uint256 public totalSkinWeight;
    bool public randomSkinEnabled = true;
    
    // Base URI for metadata
    string public baseURI = "https://adrianlab.vercel.app/api/metadata/";

    // Payment token
    IERC20 public paymentToken;

    // Contract references
    address public extensionsContract;
    address public traitsContract;
    address public adrianLabExtensions;
    
    // Financial distribution
    address public treasuryWallet;

    // Token Data Mappings
    mapping(uint256 => uint256) public generation;
    mapping(uint256 => bool) public isGen0Token;
    mapping(uint256 => MutationType) public mutationLevel;
    mapping(uint256 => bool) public hasBeenModified;
    mapping(uint256 => bool) public hasBeenMutatedBySerum;
    mapping(uint256 => string) public mutationLevelName;
    
    // Módulos
    address public serumModule;
    address public mintModule;

    // Traits
    mapping(uint256 => mapping(string => uint256)) public tokenTraits;
    
    // Dynamic extension system
    mapping(bytes4 => address) public functionImplementations;

    // History contract
    IAdrianHistory public history;

    // =============== Events ===============
    
    event TokenMinted(address indexed to, uint256 indexed tokenId);
    event SkinCreated(uint256 indexed skinId, string name, uint256 rarity);
    event SkinAssigned(uint256 indexed tokenId, uint256 skinId, string name);
    event RandomSkinToggled(bool enabled);
    event BaseURIUpdated(string newURI);
    event MutationAssigned(uint256 indexed tokenId);
    event SerumApplied(uint256 indexed tokenId, uint256 serumId);
    event MutationNameAssigned(uint256 indexed tokenId, string newMutation);
    event ExtensionsContractUpdated(address newContract);
    event TraitsContractUpdated(address newContract);
    event PaymentTokenUpdated(address newToken);
    event ProceedsWithdrawn(address indexed wallet, uint256 amount);
    event TreasuryWalletUpdated(address newWallet);
    event FirstModification(uint256 indexed tokenId);
    event FunctionImplementationUpdated(bytes4 indexed selector, address indexed implementation);
    event TokenBurnt(uint256 indexed tokenId, address indexed burner);

    // =============== Modifiers ===============
    
    modifier onlyExtensions() {
        require(msg.sender == extensionsContract, "!ext");
        _;
    }

    modifier onlyTraitsContract() {
        require(msg.sender == traitsContract, "!traits");
        _;
    }
    
    modifier onlySerumModule() {
        require(msg.sender == serumModule, "!serum");
        _;
    }

    modifier onlyMintModule() {
        require(msg.sender == mintModule || msg.sender == owner(), "Not authorized");
        _;
    }

    // =============== Constructor ===============
    
    constructor(
        address _paymentToken,
        address _treasuryWallet
    ) ERC721("AdrianZERO", "BADRIAN") Ownable(msg.sender) {
        paymentToken = IERC20(_paymentToken);
        treasuryWallet = _treasuryWallet;
    }

    // =============== Main Functions ===============

    function setMintModule(address _module) external onlyOwner {
        require(_module != address(0) && _module.code.length > 0, "Invalid module");
        mintModule = _module;
    }

    function safeMint(address to) external onlyMintModule returns (uint256) {
        uint256 tokenId = totalSupply() + 1;
        _safeMint(to, tokenId);

        emit TokenMinted(to, tokenId);
        return tokenId;
    }

    function createSkin(string memory name, uint256 rarity) public onlyOwner returns (uint256) {
        require(rarity > 0 && rarity <= 1000, "!rarity");

        uint256 skinId = nextSkinId++;
        
        skins[skinId] = Skin({
            name: name,
            rarity: rarity,
            active: true
        });
        
        totalSkinWeight += rarity;
        
        emit SkinCreated(skinId, name, rarity);
        return skinId;
    }

    function initializeSkins() external onlyOwner {
        require(nextSkinId == 1, "!init");
        
        createSkin("BareAdrian", 750);  // 75%
        createSkin("Medium", 240);       // 24%
        createSkin("Alien", 10);         // 1%
        
        randomSkinEnabled = true;
    }

    function isTokenModified(uint256 tokenId) public view returns (bool) {
        return hasBeenModified[tokenId];
    }

    function setExtensionsContract(address _extensionsContract) external onlyOwner {
        require(_extensionsContract != address(0) && _extensionsContract.code.length > 0, "Invalid contract");
        extensionsContract = _extensionsContract;
        IAdrianLabExtensions(_extensionsContract).setCoreContract(address(this));
        emit ExtensionsContractUpdated(_extensionsContract);
    }

    // =============== View Functions ===============

    function getSkin(uint256 skinId) external view returns (
        string memory name,
        uint256 rarity,
        bool active
    ) {
        Skin memory skin = skins[skinId];
        return (skin.name, skin.rarity, skin.active);
    }

    function getTokenSkin(uint256 tokenId) external view returns (
        uint256 skinId,
        string memory name
    ) {
        require(_exists(tokenId), "!exist");
        
        skinId = tokenSkin[tokenId];
        if (skinId > 0) {
            return (skinId, skins[skinId].name);
        }
        
        return (0, "BareAdrian");
    }

    function getSkinRarityPercentage(uint256 skinId) external view returns (uint256) {
        if (totalSkinWeight == 0) return 0;
        return (skins[skinId].rarity * 10000) / totalSkinWeight;
    }

    function getTokenData(uint256 tokenId) external view returns (
        uint256 tokenGeneration,
        MutationType tokenMutationLevel,
        bool tokenHasBeenModified
    ) {
        require(_exists(tokenId), "!exist");
        
        return (
            generation[tokenId],
            mutationLevel[tokenId],
            hasBeenModified[tokenId]
        );
    }

    function isEligibleForMutation(uint256 tokenId) external view returns (bool) {
        return isGen0Token[tokenId] && 
               !hasBeenMutatedBySerum[tokenId] &&
               _exists(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "URI query for nonexistent token");
        if (extensionsContract != address(0)) {
            try IAdrianLabExtensions(extensionsContract).getTokenURI(tokenId) returns (string memory uri) {
                return uri;
            } catch {
                return string(abi.encodePacked(baseURI, tokenId.toString()));
            }
        }
        return string(abi.encodePacked(baseURI, tokenId.toString()));
    }

    function exists(uint256 tokenId) public view returns (bool) {
        return _exists(tokenId);
    }

    // =============== Admin Functions ===============

    function setTraitsContract(address _traitsContract) external onlyOwner {
        require(_traitsContract != address(0) && _traitsContract.code.length > 0, "Invalid contract");
        traitsContract = _traitsContract;
        emit TraitsContractUpdated(_traitsContract);
    }

    function setPaymentToken(address _paymentToken) external onlyOwner {
        require(_paymentToken != address(0) && _paymentToken.code.length > 0, "Invalid contract");
        paymentToken = IERC20(_paymentToken);
        emit PaymentTokenUpdated(_paymentToken);
    }

    function withdrawProceeds(address wallet) external onlyOwner {
        uint256 amount = paymentToken.balanceOf(address(this));
        require(amount > 0, "!funds");
        paymentToken.transfer(wallet, amount);
        emit ProceedsWithdrawn(wallet, amount);
    }

    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner(), amount);
    }

    function assignTokenAttributes(uint256 tokenId) external nonReentrant {
        require(ownerOf(tokenId) == msg.sender, "!owner");
        require(tokenSkin[tokenId] == 0, "already assigned");
        
        if (randomSkinEnabled && totalSkinWeight > 0) {
            uint256 skinId = _selectRandomSkin();
            tokenSkin[tokenId] = skinId;
            emit SkinAssigned(tokenId, skinId, skins[skinId].name);
        }
    }

    function setTreasuryWallet(address _treasuryWallet) external onlyOwner {
        require(_treasuryWallet != address(0), "!zero");
        treasuryWallet = _treasuryWallet;
        emit TreasuryWalletUpdated(_treasuryWallet);
    }

    function setHistoryContract(address _history) external onlyOwner {
        require(_history != address(0) && _history.code.length > 0, "Invalid contract");
        history = IAdrianHistory(_history);
    }

    function burn(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender || getApproved(tokenId) == msg.sender || isApprovedForAll(ownerOf(tokenId), msg.sender), "Not owner or approved");
        require(address(history) != address(0), "History contract not set");
        
        history.recordEvent(
            tokenId,
            "BURNT",
            msg.sender,
            abi.encode("sacrifice"),
            block.number
        );

        hasBeenModified[tokenId] = false;
        delete mutationLevel[tokenId];
        
        emit TokenBurnt(tokenId, msg.sender);
        
        _burn(tokenId);
    }

    function setSerumModule(address _module) external onlyOwner {
        require(_module != address(0) && _module.code.length > 0, "Invalid module");
        serumModule = _module;
    }

    function setAdrianLabExtensions(address _extensions) external onlyOwner {
        extensionsContract = _extensions;
    }

    function setBaseURI(string calldata newURI) external onlyOwner {
        baseURI = newURI;
        emit BaseURIUpdated(newURI);
    }

    function setRandomSkin(bool enabled) external onlyOwner {
        randomSkinEnabled = enabled;
        emit RandomSkinToggled(enabled);
    }

    function setMutationFromSerum(uint256 tokenId, string calldata mutation, string calldata narrative) external {
        require(msg.sender == serumModule, "Not serum module");

        mutationLevelName[tokenId] = mutation;
        emit MutationNameAssigned(tokenId, mutation);

        if (address(history) != address(0)) {
            bytes memory data = abi.encode(narrative);
            history.recordEvent(tokenId, "MUTATION", msg.sender, data, block.number);
        }
    }

    function setFunctionImplementation(bytes4 selector, address implementation) external onlyOwner {
        functionImplementations[selector] = implementation;
        emit FunctionImplementationUpdated(selector, implementation);
    }

    // =============== Internal Functions ===============

    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    function _selectRandomSkin() internal view returns (uint256) {
        uint256 rand = _random(block.timestamp + totalSupply(), totalSkinWeight);
        uint256 cumulative = 0;

        for (uint256 i = 1; i < nextSkinId; i++) {
            if (skins[i].active) {
                cumulative += skins[i].rarity;
                if (rand < cumulative) {
                    return i;
                }
            }
        }

        return 1;
    }

    function _random(uint256 seed, uint256 max) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            blockhash(block.number - 1),
            block.timestamp,
            msg.sender,
            seed
        ))) % max;
    }

    // =============== Fallback and Receive ===============
    
    fallback() external payable {
        address implementation = functionImplementations[msg.sig];
        require(implementation != address(0), "!impl");

        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}
}

// =============== Interfaces ===============

interface IAdrianLabExtensions {
    function onTokenMinted(uint256 tokenId, address to) external;
    function onSerumApplied(uint256 tokenId, uint256 serumId) external;
    function getTokenURI(uint256 tokenId) external view returns (string memory);
    function recordHistory(uint256 tokenId, bytes32 eventType, bytes calldata eventData) external returns (uint256);
    function setCoreContract(address _core) external;
}

interface ITraitsContract {
    function getCategory(uint256 traitId) external view returns (string memory);
}

interface IAdrianHistory {
    function recordEvent(
        uint256 tokenId,
        string calldata eventType,
        address caller,
        bytes calldata eventData,
        uint256 blockNumber
    ) external;
}