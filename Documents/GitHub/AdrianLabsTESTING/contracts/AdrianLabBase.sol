// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AdrianLabStorage.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "./AdrianLabLibrary.sol";

/**
 * @title AdrianLabBase
 * @dev Contrato principal para AdrianLab, implementa funciones core
 */
contract AdrianLabBase is AdrianLabStorage {
    using Strings for uint256;

    /**
     * @dev Inicializa el contrato en lugar del constructor
     */
    function initialize(
        address _devWallet,
        address _artistWallet,
        address _treasuryWallet,
        address _communityWallet
    ) public initializer {
        __ERC721_init("BareAdrians", "BADRIAN");
        __ERC721Enumerable_init();
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        
        devWallet = _devWallet;
        artistWallet = _artistWallet;
        treasuryWallet = _treasuryWallet;
        communityWallet = _communityWallet;
        
        // Inicialización de valores por defecto
        mintBatchSize = 100;
        mintPrice = 0.05 ether;
        mintPaused = false;
        
        replicationChanceForGen0 = 80; // 80%
        maxReplicationsPerToken = 3;
        replicationCooldown = 1 days;
        mildMutationChance = 10; // 10%
        moderateMutationChance = 5; // 5%
        severeMutationChance = 2; // 2%
        
        devShare = 30; // 30%
        artistShare = 30; // 30%
        treasuryShare = 30; // 30%
        communityShare = 10; // 10%
        
        renderBaseURI = "https://adrianlab-renderer.vercel.app/api/render/";
        
        // Inicializar categorías
        categoryList = [
            "BACKGROUND",
            "BASE",
            "BODY",
            "CLOTHING",
            "EYES",
            "MOUTH",
            "HEAD",
            "ACCESSORIES"
        ];
    }
    
    /**
     * @dev Mint a new BareAdrian token
     */
    function mint() external payable nonReentrant notPaused(this.mint.selector) {
        require(!mintPaused, "Minting paused");
        require(mintedInCurrentBatch < mintBatchSize, "Batch limit reached");
        require(msg.value >= mintPrice, "Insufficient payment");
        
        // Create new token
        uint256 tokenId = ++tokenCounter;
        
        // Mark as GEN0
        isGen0Token[tokenId] = true;
        generation[tokenId] = 0;
        totalGen0Tokens++;
        
        // Assign replication ability (80% chance)
        if (_randomChance(replicationChanceForGen0)) {
            canReplicate[tokenId] = true;
            emit ReplicationEnabled(tokenId);
        }
        
        // Set mutation level to NONE (GEN0)
        mutationLevel[tokenId] = MutationType.NONE;
        
        // Mint the token
        _mint(msg.sender, tokenId);
        mintedInCurrentBatch++;
        
        // Register history
        _addNarrativeEvent(
            tokenId,
            EVENT_MINT,
            "A new GEN0 BareAdrian was created",
            0
        );
        
        // Distribute payment
        _distributePayment(msg.value);
        
        // Check if batch is complete
        if (mintedInCurrentBatch >= mintBatchSize) {
            mintedInCurrentBatch = 0;
            emit MintBatchCompleted(tokenCounter / mintBatchSize, tokenCounter);
        }
        
        emit Mint(msg.sender, tokenId);
    }
    
    /**
     * @dev Get metadata URI for a token
     * @param tokenId The token ID
     * @return URI string
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "URI query for nonexistent token");
        
        // If in emergency mode and renderBaseURI is empty, return on-chain fallback
        if (emergencyMode && bytes(renderBaseURI).length == 0) {
            return _generateOnChainMetadata(tokenId);
        }
        
        return string(abi.encodePacked(renderBaseURI, tokenId.toString()));
    }
    
    /**
     * @dev Generate on-chain metadata as fallback
     * @param tokenId The token ID
     * @return JSON metadata string
     */
    function _generateOnChainMetadata(uint256 tokenId) internal view returns (string memory) {
        string memory tokenName = string(abi.encodePacked("BareAdrian #", tokenId.toString()));
        string memory description = "A BareAdrian from the AdrianLab collection";
        
        // Get mutation level
        string memory mutationStr = _mutationTypeToString(mutationLevel[tokenId]);
        
        // Build attributes JSON
        string memory attributes = string(abi.encodePacked(
            '[{"trait_type":"Generation","value":', generation[tokenId].toString(), '},',
            '{"trait_type":"Mutation","value":"', mutationStr, '"},',
            '{"trait_type":"CanReplicate","value":', canReplicate[tokenId] ? "true" : "false", '}]'
        ));
        
        // Build complete JSON
        string memory json = Base64.encode(bytes(string(abi.encodePacked(
            '{"name":"', tokenName, '",',
            '"description":"', description, '",',
            '"attributes":', attributes, '}'
        ))));
        
        return string(abi.encodePacked('data:application/json;base64,', json));
    }
    
    /**
     * @dev Convert MutationType enum to string
     * @param mutation Mutation type
     * @return String representation
     */
    function _mutationTypeToString(MutationType mutation) internal pure returns (string memory) {
        return AdrianLabLibrary.mutationTypeToString(uint8(mutation));
    }
    
    /**
     * @dev Distribute payment to wallets
     * @param amount Amount to distribute
     */
    function _distributePayment(uint256 amount) internal {
        pendingProceeds[devWallet] += (amount * devShare) / 100;
        pendingProceeds[artistWallet] += (amount * artistShare) / 100;
        pendingProceeds[treasuryWallet] += (amount * treasuryShare) / 100;
        pendingProceeds[communityWallet] += (amount * communityShare) / 100;
    }
    
    /**
     * @dev Generate random number
     * @param seed Seed for randomness
     * @param max Maximum value (exclusive)
     * @return Random value
     */
    function _random(uint256 seed, uint256 max) internal view returns (uint256) {
        return AdrianLabLibrary.random(seed, max);
    }
    
    /**
     * @dev Check random chance (0-100)
     * @param chance Percentage chance (0-100)
     * @return True if successful
     */
    function _randomChance(uint256 chance) internal view returns (bool) {
        return AdrianLabLibrary.randomChance(chance, tokenCounter);
    }
    
    /**
     * @dev Verifica si un token existe
     * @param tokenId ID del token a verificar
     * @return bool True si el token existe
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }
    
    /**
     * @dev Set mint price
     * @param newPrice New price in wei
     */
    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
        emit MintPriceUpdated(newPrice);
    }
    
    /**
     * @dev Set mint batch size
     * @param newSize New batch size
     */
    function setMintBatchSize(uint256 newSize) external onlyOwner {
        require(newSize > 0, "Batch size must be positive");
        mintBatchSize = newSize;
    }
    
    /**
     * @dev Toggle mint pause state
     * @param paused New pause state
     */
    function setMintPaused(bool paused) external onlyOwner {
        mintPaused = paused;
    }
    
    /**
     * @dev Set traits contract address
     * @param newTraitsContract New traits contract address
     */
    function setTraitsContract(address newTraitsContract) external onlyOwner {
        traitsContractAddress = newTraitsContract;
        emit TraitsContractUpdated(newTraitsContract);
    }
    
    /**
     * @dev Set renderer base URI
     * @param newBaseURI New base URI
     */
    function setRenderBaseURI(string calldata newBaseURI) external onlyOwner {
        renderBaseURI = newBaseURI;
        emit RenderBaseURIUpdated(newBaseURI);
    }
    
    /**
     * @dev Withdraw pending proceeds
     * @param wallet Wallet to withdraw from
     */
    function withdrawProceeds(address wallet) external onlyOwner {
        uint256 amount = pendingProceeds[wallet];
        require(amount > 0, "No proceeds to withdraw");
        
        pendingProceeds[wallet] = 0;
        
        (bool success, ) = payable(wallet).call{value: amount}("");
        require(success, "Transfer failed");
        
        emit ProceedsWithdrawn(wallet, amount);
    }
    
    /**
     * @dev Set emergency mode
     * @param enabled Emergency mode status
     */
    function setEmergencyMode(bool enabled) external onlyOwner {
        emergencyMode = enabled;
        emit EmergencyModeSet(enabled);
    }
    
    /**
     * @dev Set function pause status
     * @param functionSelector Function selector to pause
     * @param paused Pause status
     */
    function setFunctionPaused(bytes4 functionSelector, bool paused) external onlyOwner {
        pausedFunctions[functionSelector] = paused;
        emit FunctionPauseToggled(functionSelector, paused);
    }
    
    /**
     * @dev Internal helper to record a historical event
     */
    function _recordHistory(
        uint256 tokenId,
        bytes32 eventType,
        bytes memory eventData
    ) internal returns (uint256) {
        require(_exists(tokenId), "Token not exist");
        
        HistoricalEvent memory newEvent = HistoricalEvent({
            timestamp: block.timestamp,
            eventType: eventType,
            actorAddress: msg.sender,
            eventData: eventData,
            blockNumber: block.number
        });
        
        tokenHistory[tokenId].push(newEvent);
        uint256 eventIndex = tokenHistory[tokenId].length - 1;
        
        emit HistoryRecorded(tokenId, eventType, eventIndex);
        return eventIndex;
    }
    
    /**
     * @dev Add narrative event with related token info
     */
    function _addNarrativeEvent(
        uint256 tokenId,
        bytes32 eventType,
        string memory description,
        uint256 relatedTokenId
    ) internal returns (uint256) {
        bytes memory data = abi.encode(description, relatedTokenId);
        return _recordHistory(tokenId, eventType, data);
    }
}