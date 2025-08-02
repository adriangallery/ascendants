// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IAdrianLabCore {
    function safeMint(address to) external returns (uint256);
    function owner() external view returns (address);
}

contract AdrianMintModule is Ownable {
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
        bool useMerkleWhitelist;
        bytes32 merkleRoot;
    }

    address public coreContract;
    IERC20 public paymentToken;
    address public treasuryWallet;

    mapping(uint256 => BatchConfig) public batches;
    uint256 public activeBatch;
    uint256 public nextBatchId;
    bool public mintPaused;

    mapping(uint256 => bool) public isWhitelistEnabledForBatch;
    mapping(address => mapping(uint256 => bool)) public isWhitelistedForBatch;
    mapping(uint256 => mapping(address => uint256)) public mintedPerWalletPerBatch;

    event BatchCreated(uint256 indexed batchId, string name, uint256 price, uint256 maxSupply);
    event BatchActivated(uint256 indexed batchId);
    event BatchDeactivated(uint256 indexed batchId);
    event BatchCompleted(uint256 indexed batchId, uint256 totalMinted);
    event BatchUpdated(uint256 indexed batchId);
    event MintPriceUpdated(uint256 newPrice);
    event Mint(address indexed to, uint256 indexed tokenId);
    event MerkleRootUpdated(uint256 indexed batchId, bytes32 root, bool enabled);

    constructor(
        address _coreContract,
        address _paymentToken,
        address _treasuryWallet
    ) Ownable(msg.sender) {
        require(_coreContract.code.length > 0, "Invalid core");
        coreContract = _coreContract;
        paymentToken = IERC20(_paymentToken);
        treasuryWallet = _treasuryWallet;
    }

    modifier onlyCoreOwner() {
        require(msg.sender == IAdrianLabCore(coreContract).owner(), "Not core owner");
        _;
    }

    function createBatch(
        string memory name,
        uint256 price,
        uint256 maxSupply,
        uint256 startTime,
        uint256 endTime,
        bool makeActive,
        bool enableWhitelist,
        uint256 maxPerWallet
    ) external onlyOwner {
        require(maxSupply > 0, "Invalid supply");
        require(maxPerWallet > 0, "Invalid max per wallet");

        uint256 batchId = nextBatchId++;

        batches[batchId] = BatchConfig({
            id: batchId,
            price: price,
            maxSupply: maxSupply,
            minted: 0,
            active: false,
            name: name,
            startTime: startTime,
            endTime: endTime,
            maxPerWallet: maxPerWallet,
            useMerkleWhitelist: false,
            merkleRoot: bytes32(0)
        });

        isWhitelistEnabledForBatch[batchId] = enableWhitelist;

        if (makeActive) {
            activeBatch = batchId;
            batches[batchId].active = true;
            emit BatchActivated(batchId);
        }

        emit BatchCreated(batchId, name, price, maxSupply);
    }

    function setMerkleRoot(uint256 batchId, bytes32 root, bool enabled) external onlyOwner {
        require(batchId < nextBatchId, "Invalid batch");
        batches[batchId].merkleRoot = root;
        batches[batchId].useMerkleWhitelist = enabled;
        emit MerkleRootUpdated(batchId, root, enabled);
    }

    function activateBatch(uint256 batchId) external onlyOwner {
        require(batchId < nextBatchId, "Invalid batch");
        require(batches[batchId].minted < batches[batchId].maxSupply, "Sold out");

        if (activeBatch != 0) {
            batches[activeBatch].active = false;
            emit BatchDeactivated(activeBatch);
        }

        activeBatch = batchId;
        batches[batchId].active = true;
        emit BatchActivated(batchId);
    }

    function deactivateCurrentBatch() external onlyOwner {
        if (activeBatch != 0) {
            batches[activeBatch].active = false;
            emit BatchDeactivated(activeBatch);
            activeBatch = 0;
        }
    }

    function updateBatch(
        uint256 batchId,
        uint256 newPrice,
        uint256 newMaxSupply,
        uint256 newStartTime,
        uint256 newEndTime,
        string memory newName
    ) external onlyOwner {
        require(batchId < nextBatchId, "Invalid batch");
        BatchConfig storage batch = batches[batchId];
        require(newMaxSupply >= batch.minted, "Invalid supply");
        
        batch.price = newPrice;
        batch.maxSupply = newMaxSupply;
        batch.startTime = newStartTime;
        batch.endTime = newEndTime;
        batch.name = newName;

        emit BatchUpdated(batchId);
    }

    function setMintPaused(bool paused) external onlyOwner {
        mintPaused = paused;
    }

    function updateWhitelistForBatch(
        uint256 batchId,
        address[] calldata addresses,
        bool enabled
    ) external onlyOwner {
        require(batchId < nextBatchId, "Invalid batch");
        for (uint256 i = 0; i < addresses.length; i++) {
            isWhitelistedForBatch[addresses[i]][batchId] = enabled;
        }
    }

    function setWhitelistEnabledForBatch(uint256 batchId, bool enabled) external onlyOwner {
        require(batchId < nextBatchId, "Invalid batch");
        isWhitelistEnabledForBatch[batchId] = enabled;
    }

    function mint(bytes32[] calldata merkleProof) external {
        require(!mintPaused && activeBatch != 0, "!active");
        BatchConfig storage batch = batches[activeBatch];
        require(batch.active && batch.minted < batch.maxSupply, "!avail");

        if (batch.startTime > 0) {
            require(block.timestamp >= batch.startTime, "!started");
        }
        if (batch.endTime > 0) {
            require(block.timestamp <= batch.endTime, "ended");
        }

        if (isWhitelistEnabledForBatch[activeBatch]) {
            require(isWhitelistedForBatch[msg.sender][activeBatch], "Not whitelisted");
        }

        if (batch.useMerkleWhitelist) {
            bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
            require(MerkleProof.verify(merkleProof, batch.merkleRoot, leaf), "Invalid merkle proof");
        }

        uint256 userMints = mintedPerWalletPerBatch[activeBatch][msg.sender];
        require(userMints + 1 <= batch.maxPerWallet, "Mint limit exceeded");

        if (batch.price > 0) {
            require(paymentToken.transferFrom(msg.sender, treasuryWallet, batch.price), "!pay");
        }

        uint256 tokenId = IAdrianLabCore(coreContract).safeMint(msg.sender);
        mintedPerWalletPerBatch[activeBatch][msg.sender]++;
        batch.minted++;

        emit Mint(msg.sender, tokenId);

        if (batch.minted >= batch.maxSupply) {
            batch.active = false;
            activeBatch = 0;
            emit BatchCompleted(batch.id, batch.minted);
        }
    }

    function mintMultiple(uint256 quantity, bytes32[] calldata merkleProof) external {
        require(quantity > 0 && quantity <= 10, "Invalid quantity");
        require(!mintPaused && activeBatch != 0, "!active");
        BatchConfig storage batch = batches[activeBatch];
        require(batch.active && batch.minted + quantity <= batch.maxSupply, "!avail");

        if (batch.startTime > 0) {
            require(block.timestamp >= batch.startTime, "!started");
        }
        if (batch.endTime > 0) {
            require(block.timestamp <= batch.endTime, "ended");
        }

        if (isWhitelistEnabledForBatch[activeBatch]) {
            require(isWhitelistedForBatch[msg.sender][activeBatch], "Not whitelisted");
        }

        if (batch.useMerkleWhitelist) {
            bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
            require(MerkleProof.verify(merkleProof, batch.merkleRoot, leaf), "Invalid merkle proof");
        }

        uint256 userMints = mintedPerWalletPerBatch[activeBatch][msg.sender];
        require(userMints + quantity <= batch.maxPerWallet, "Mint limit exceeded");

        if (batch.price > 0) {
            uint256 totalCost = batch.price * quantity;
            require(paymentToken.transferFrom(msg.sender, treasuryWallet, totalCost), "!pay");
        }

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = IAdrianLabCore(coreContract).safeMint(msg.sender);
            emit Mint(msg.sender, tokenId);
        }

        mintedPerWalletPerBatch[activeBatch][msg.sender] += quantity;
        batch.minted += quantity;

        if (batch.minted >= batch.maxSupply) {
            batch.active = false;
            activeBatch = 0;
            emit BatchCompleted(batch.id, batch.minted);
        }
    }

    function getCurrentBatchInfo() external view returns (
        uint256 batchId,
        string memory name,
        uint256 price,
        uint256 minted,
        uint256 maxSupply,
        bool active,
        uint256 startTime,
        uint256 endTime,
        bool useMerkleWhitelist
    ) {
        if (activeBatch == 0) {
            return (0, "", 0, 0, 0, false, 0, 0, false);
        }

        BatchConfig storage batch = batches[activeBatch];
        return (
            batch.id,
            batch.name,
            batch.price,
            batch.minted,
            batch.maxSupply,
            batch.active,
            batch.startTime,
            batch.endTime,
            batch.useMerkleWhitelist
        );
    }

    function getBatchInfo(uint256 batchId) external view returns (
        uint256 id,
        string memory name,
        uint256 price,
        uint256 minted,
        uint256 maxSupply,
        bool active,
        uint256 startTime,
        uint256 endTime,
        bool useMerkleWhitelist
    ) {
        require(batchId < nextBatchId, "Invalid batch");
        
        BatchConfig storage batch = batches[batchId];
        return (
            batch.id,
            batch.name,
            batch.price,
            batch.minted,
            batch.maxSupply,
            batch.active,
            batch.startTime,
            batch.endTime,
            batch.useMerkleWhitelist
        );
    }

    function canMint() external view returns (
        bool mintable,
        string memory reason,
        uint256 price,
        uint256 available
    ) {
        if (mintPaused) {
            return (false, "paused", 0, 0);
        }
        
        if (activeBatch == 0) {
            return (false, "no batch", 0, 0);
        }
        
        BatchConfig storage batch = batches[activeBatch];
        
        if (!batch.active) {
            return (false, "!active", 0, 0);
        }
        
        if (batch.minted >= batch.maxSupply) {
            return (false, "sold out", 0, 0);
        }
        
        if (batch.startTime > 0 && block.timestamp < batch.startTime) {
            return (false, "!started", 0, 0);
        }
        
        if (batch.endTime > 0 && block.timestamp > batch.endTime) {
            return (false, "ended", 0, 0);
        }
        
        return (
            true, 
            "ok", 
            batch.price, 
            batch.maxSupply - batch.minted
        );
    }
}
