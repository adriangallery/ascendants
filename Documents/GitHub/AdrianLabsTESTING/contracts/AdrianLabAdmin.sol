// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AdrianLabTrait.sol";

/**
 * @title AdrianLabAdmin
 * @dev Gestiona funciones administrativas para AdrianLab
 */
contract AdrianLabAdmin is AdrianLabTrait {
    /**
     * @dev Set replication settings
     * @param chance Chance for GEN0 to replicate (0-100)
     * @param maxReplications Max replications per token
     * @param cooldown Cooldown period in seconds
     */
    function setReplicationSettings(
        uint256 chance,
        uint256 maxReplications,
        uint256 cooldown
    ) external onlyOwner {
        require(chance <= 100, "Invalid chance");
        
        replicationChanceForGen0 = chance;
        maxReplicationsPerToken = maxReplications;
        replicationCooldown = cooldown;
        
        emit ReplicationSettingsUpdated(chance, maxReplications, cooldown);
    }
    
    /**
     * @dev Set mutation probabilities
     * @param mild Mild mutation chance (0-100)
     * @param moderate Moderate mutation chance (0-100)
     * @param severe Severe mutation chance (0-100)
     */
    function setMutationProbabilities(
        uint256 mild,
        uint256 moderate,
        uint256 severe
    ) external onlyOwner {
        require(mild + moderate + severe <= 100, "Sum > 100");
        
        mildMutationChance = mild;
        moderateMutationChance = moderate;
        severeMutationChance = severe;
        
        emit MutationProbabilitiesUpdated(mild, moderate, severe);
    }
    
    /**
     * @dev Emergency restore state
     */
    function emergencyRestoreState(
        uint256 tokenId,
        string memory mutationString,
        bool canTokenReplicate,
        uint256 tokenReplicationCount
    ) external onlyOwner {
        require(emergencyMode, "Not emergency mode");
        require(_exists(tokenId), "Token not exist");
        
        // Restore mutation
        _restoreMutationLevel(tokenId, mutationString);
        
        // Restore replication
        canReplicate[tokenId] = canTokenReplicate;
        replicationCount[tokenId] = tokenReplicationCount;
        
        // History
        bytes memory data = abi.encode(mutationString, canTokenReplicate, tokenReplicationCount);
        _recordHistory(tokenId, keccak256("EMERGENCY_RESTORE"), data);
        
        emit EmergencyStateRestored(tokenId);
    }
    
    /**
     * @dev Restore a token's mutation level from string
     */
    function _restoreMutationLevel(uint256 tokenId, string memory mutationString) private {
        bytes32 mutationHash = keccak256(bytes(mutationString));
        
        if (mutationHash == keccak256(bytes("NONE"))) {
            mutationLevel[tokenId] = MutationType.NONE;
        } else if (mutationHash == keccak256(bytes("MILD"))) {
            mutationLevel[tokenId] = MutationType.MILD;
        } else if (mutationHash == keccak256(bytes("MODERATE"))) {
            mutationLevel[tokenId] = MutationType.MODERATE;
        } else if (mutationHash == keccak256(bytes("SEVERE"))) {
            mutationLevel[tokenId] = MutationType.SEVERE;
        }
    }
    
    /**
     * @dev For admin to select tokens GEN0 for duplication
     * @param tokenIds Array of token IDs to duplicate
     */
    function duplicateGen0Tokens(uint256[] calldata tokenIds) external onlyOwner {
        require(tokenIds.length > 0, "No tokens specified");
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _duplicateSingleToken(tokenIds[i]);
        }
    }
    
    /**
     * @dev Duplicate a single token
     */
    function _duplicateSingleToken(uint256 tokenId) private {
        // Validate token
        require(_exists(tokenId), "Token not exist");
        require(isGen0Token[tokenId], "Not a GEN0 token");
        require(!hasBeenDuplicated[tokenId], "Already duplicated");
        require(!hasBeenMutatedBySerum[tokenId], "Already mutated");
        
        // Mark as duplicated
        hasBeenDuplicated[tokenId] = true;
        
        // Create new token with mutation
        uint256 newTokenId = ++tokenCounter;
        MutationType mutation = _determineRandomMutation();
        mutationLevel[newTokenId] = mutation;
        
        // Mint to original owner
        address originalOwner = ownerOf(tokenId);
        _mint(originalOwner, newTokenId);
        
        // Record history
        _recordDuplicationHistory(tokenId, newTokenId, mutation);
        
        emit TokenDuplicated(tokenId, newTokenId, mutation);
    }
    
    /**
     * @dev Record duplication history
     */
    function _recordDuplicationHistory(
        uint256 originalId, 
        uint256 newTokenId,
        MutationType mutation
    ) private {
        _addNarrativeEvent(
            originalId,
            keccak256("DUPLICATED"),
            "GEN0 token duplicated",
            newTokenId
        );
        
        _addNarrativeEvent(
            newTokenId,
            keccak256("CREATED_BY_DUPLICATION"),
            string(abi.encodePacked(
                "Created as ", _mutationTypeToString(mutation), 
                " mutation from GEN0 #", _uintToString(originalId)
            )),
            originalId
        );
    }
    
    /**
     * @dev Determines a random mutation based on configured probabilities
     * @return Mutation type
     */
    function _determineRandomMutation() internal view returns (MutationType) {
        // Verify that probabilities don't exceed 100
        require(
            mildMutationChance + moderateMutationChance + severeMutationChance <= 100,
            "Invalid probs"
        );
        
        // Generate random number 1-100
        uint256 randomNum = uint256(keccak256(abi.encodePacked(
            block.timestamp, 
            block.prevrandao,
            msg.sender,
            tokenCounter
        ))) % 100 + 1; // 1-100
        
        // Determine mutation type
        uint256 cumulativeChance = 0;
        
        cumulativeChance += mildMutationChance;
        if (randomNum <= cumulativeChance) return MutationType.MILD;
        
        cumulativeChance += moderateMutationChance;
        if (randomNum <= cumulativeChance) return MutationType.MODERATE;
        
        cumulativeChance += severeMutationChance;
        if (randomNum <= cumulativeChance) return MutationType.SEVERE;
        
        return MutationType.NONE;
    }
} 