// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AdrianLabStorage.sol";

/**
 * @title AdrianLabQuery
 * @dev Gestiona funciones de consulta para AdrianLab
 */
contract AdrianLabQuery is AdrianLabStorage {
    /**
     * @dev Record event in token history
     * @param tokenId The token ID
     * @param eventType Event type
     * @param eventData Event data
     */
    function recordHistory(
        uint256 tokenId,
        bytes32 eventType,
        bytes calldata eventData
    ) external onlyHistoryWriter returns (uint256) {
        return _recordHistory(tokenId, eventType, eventData);
    }
    
    /**
     * @dev Record batch of events in token history
     * @param tokenId The token ID
     * @param eventTypes Event types
     * @param eventDatas Event data
     */
    function recordHistoryBatch(
        uint256 tokenId,
        bytes32[] calldata eventTypes,
        bytes[] calldata eventDatas
    ) external onlyHistoryWriter returns (uint256, uint256) {
        require(_exists(tokenId), "Token not exist");
        require(eventTypes.length == eventDatas.length, "Arrays length mismatch");
        
        uint256 startIndex = tokenHistory[tokenId].length;
        
        for (uint256 i = 0; i < eventTypes.length; i++) {
            HistoricalEvent memory newEvent = HistoricalEvent({
                timestamp: block.timestamp,
                eventType: eventTypes[i],
                actorAddress: msg.sender,
                eventData: eventDatas[i],
                blockNumber: block.number
            });
            
            tokenHistory[tokenId].push(newEvent);
        }
        
        uint256 endIndex = tokenHistory[tokenId].length - 1;
        
        emit HistoryBatchRecorded(tokenId, startIndex, endIndex);
        return (startIndex, endIndex);
    }
    
    /**
     * @dev Set history writer authorization
     * @param writer Address to authorize
     * @param authorized Authorization status
     */
    function setHistoryWriter(address writer, bool authorized) external onlyOwner {
        historyWriters[writer] = authorized;
        emit HistoryWriterUpdated(writer, authorized);
    }
    
    /**
     * @dev Get number of historical events for a token
     * @param tokenId The token ID
     * @return Number of events
     */
    function getHistoryCount(uint256 tokenId) external view returns (uint256) {
        return tokenHistory[tokenId].length;
    }
    
    /**
     * @dev Get a specific historical event
     * @param tokenId The token ID
     * @param eventIndex The event index
     * @return timestamp Timestamp del evento
     * @return eventType Tipo de evento
     * @return actorAddress Dirección del actor
     * @return eventData Datos del evento
     * @return blockNumber Número de bloque
     */
    function getHistoryEvent(uint256 tokenId, uint256 eventIndex) 
        external view returns (
            uint256 timestamp,
            bytes32 eventType,
            address actorAddress,
            bytes memory eventData,
            uint256 blockNumber
        ) 
    {
        require(eventIndex < tokenHistory[tokenId].length, "Index out of bounds");
        
        HistoricalEvent storage event_ = tokenHistory[tokenId][eventIndex];
        return (
            event_.timestamp,
            event_.eventType,
            event_.actorAddress,
            event_.eventData,
            event_.blockNumber
        );
    }
    
    /**
     * @dev Get token data with all attributes
     * @param tokenId The token ID
     */
    function getTokenData(uint256 tokenId) external view returns (
        uint256 tokenGeneration,
        MutationType tokenMutationLevel,
        bool tokenCanReplicate,
        uint256 tokenReplicationCount,
        uint256 tokenLastReplication,
        bool tokenHasBeenModified,
        string[] memory categories,
        uint256[] memory traitIds
    ) {
        require(_exists(tokenId), "Token not exist");
        
        // Get traits
        categories = new string[](categoryList.length);
        traitIds = new uint256[](categoryList.length);
        
        for (uint256 i = 0; i < categoryList.length; i++) {
            categories[i] = categoryList[i];
            traitIds[i] = tokenTraits[tokenId][categoryList[i]];
        }
        
        return (
            generation[tokenId],
            mutationLevel[tokenId],
            canReplicate[tokenId],
            replicationCount[tokenId],
            lastReplication[tokenId],
            hasBeenModified[tokenId],
            categories,
            traitIds
        );
    }
    
    /**
     * @dev Get all token IDs owned by an address
     * @param owner The address to check
     * @return tokenIds Array of token IDs
     */
    function getTokensOfOwner(address owner) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(owner);
        uint256[] memory tokenIds = new uint256[](tokenCount);
        
        for (uint256 i = 0; i < tokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(owner, i);
        }
        
        return tokenIds;
    }
    
    /**
     * @dev Get complete info for multiple tokens (batch request)
     * @param tokenIds Array of token IDs to query
     * @return tokensInfo Array of token complete info structures
     */
    function getBatchTokenData(uint256[] calldata tokenIds) external view returns (
        TokenCompleteInfo[] memory tokensInfo
    ) {
        tokensInfo = new TokenCompleteInfo[](tokenIds.length);
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            
            // Only process tokens that exist
            if (_exists(tokenId)) {
                // Get traits
                TokenTraitInfo[] memory traits = new TokenTraitInfo[](categoryList.length);
                uint256 traitCount = 0;
                
                for (uint256 j = 0; j < categoryList.length; j++) {
                    uint256 traitId = tokenTraits[tokenId][categoryList[j]];
                    if (traitId != 0) {
                        traits[traitCount] = TokenTraitInfo({
                            category: categoryList[j],
                            traitId: traitId
                        });
                        traitCount++;
                    }
                }
                
                // Create properly sized traits array with only non-zero traits
                TokenTraitInfo[] memory nonZeroTraits = new TokenTraitInfo[](traitCount);
                for (uint256 j = 0; j < traitCount; j++) {
                    nonZeroTraits[j] = traits[j];
                }
                
                // Fill token info
                tokensInfo[i] = TokenCompleteInfo({
                    tokenId: tokenId,
                    generation: generation[tokenId],
                    mutationLevel: mutationLevel[tokenId],
                    canReplicate: canReplicate[tokenId],
                    replicationCount: replicationCount[tokenId],
                    lastReplication: lastReplication[tokenId],
                    hasBeenModified: hasBeenModified[tokenId],
                    traits: nonZeroTraits
                });
            }
        }
        
        return tokensInfo;
    }
    
    /**
     * @dev Set distribution wallets
     * @param dev Developer wallet
     * @param artist Artist wallet
     * @param treasury Treasury wallet
     * @param community Community wallet
     */
    function setDistributionWallets(
        address dev,
        address artist,
        address treasury,
        address community
    ) external onlyOwner {
        require(dev != address(0) && artist != address(0) && 
                treasury != address(0) && community != address(0), 
                "Zero address");
        
        devWallet = dev;
        artistWallet = artist;
        treasuryWallet = treasury;
        communityWallet = community;
    }
    
    /**
     * @dev Set distribution shares
     * @param dev Developer share
     * @param artist Artist share
     * @param treasury Treasury share
     * @param community Community share
     */
    function setDistributionShares(
        uint256 dev,
        uint256 artist,
        uint256 treasury,
        uint256 community
    ) external onlyOwner {
        require(dev + artist + treasury + community == 100, "Sum must be 100");
        
        devShare = dev;
        artistShare = artist;
        treasuryShare = treasury;
        communityShare = community;
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