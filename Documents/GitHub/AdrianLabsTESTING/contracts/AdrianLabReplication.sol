// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AdrianLabTrait.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./AdrianLabLibrary.sol";

/**
 * @title AdrianLabReplication
 * @dev Manages token replication for AdrianLab
 */
contract AdrianLabReplication is AdrianLabTrait {
    using Strings for uint256;
    
    /**
     * @dev Replicate a token to create a new one
     * @param tokenId The token to replicate
     */
    function replicate(uint256 tokenId) external nonReentrant notPaused(this.replicate.selector) {
        _validateReplication(tokenId);
        
        // Create new token
        uint256 newTokenId = ++tokenCounter;
        
        // Set generation and mutation
        generation[newTokenId] = generation[tokenId] + 1;
        mutationLevel[newTokenId] = _determineMutation(tokenId);
        
        // Check if can replicate
        _checkChildReplication(newTokenId);
        
        // Mint and update parent
        _mint(msg.sender, newTokenId);
        _updateParentAfterReplication(tokenId);
        
        // History and events
        _recordReplicationHistory(tokenId, newTokenId);
        
        emit Replicated(tokenId, newTokenId);
        
        // Mutation event
        if (mutationLevel[newTokenId] != MutationType.NONE) {
            emit MutationAssigned(newTokenId);
        }
    }
    
    /**
     * @dev Validate a token for replication
     */
    function _validateReplication(uint256 tokenId) private view {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        require(canReplicate[tokenId], "Not allowed to replicate");
        require(replicationCount[tokenId] < maxReplicationsPerToken, "Max replications reached");
        require(block.timestamp >= lastReplication[tokenId] + replicationCooldown, "Cooldown active");
        
        // Check mutation level restrictions
        if (mutationLevel[tokenId] == MutationType.MILD) {
            require(replicationCount[tokenId] == 0, "Mild: 1 replication max");
        } else if (mutationLevel[tokenId] == MutationType.MODERATE || 
                 mutationLevel[tokenId] == MutationType.SEVERE) {
            revert("Cannot replicate");
        }
    }
    
    /**
     * @dev Check if child can replicate (50% chance)
     */
    function _checkChildReplication(uint256 newTokenId) private {
        if (mutationLevel[newTokenId] == MutationType.NONE || 
            mutationLevel[newTokenId] == MutationType.MILD) {
            if (_randomChance(50)) {
                canReplicate[newTokenId] = true;
                emit ReplicationEnabled(newTokenId);
            }
        }
    }
    
    /**
     * @dev Update parent token after replication
     */
    function _updateParentAfterReplication(uint256 tokenId) private {
        replicationCount[tokenId]++;
        lastReplication[tokenId] = block.timestamp;
    }
    
    /**
     * @dev Record history for replication event
     */
    function _recordReplicationHistory(uint256 parentId, uint256 childId) private {
        _addNarrativeEvent(
            parentId,
            EVENT_REPLICATE,
            string(abi.encodePacked(
                "Replicated to create token #", 
                _uintToString(childId)
            )),
            childId
        );
        
        _addNarrativeEvent(
            childId,
            EVENT_REPLICATE,
            string(abi.encodePacked(
                "Created by replication from token #", 
                _uintToString(parentId)
            )),
            parentId
        );
    }
    
    /**
     * @dev Determine mutation level for a child token
     * @param parentId The parent token ID
     * @return Mutation level
     */
    function _determineMutation(uint256 parentId) internal view returns (MutationType) {
        // If parent is already mutated, higher chances of mutation in child
        if (mutationLevel[parentId] == MutationType.MILD) {
            // Mild parent has higher chance of producing moderate/severe child
            uint256 rand = _random(parentId, 100);
            if (rand < 60) return MutationType.MODERATE;
            if (rand < 80) return MutationType.SEVERE;
            return MutationType.MILD;
        } else {
            // Normal parent has standard mutation chances
            uint256 rand = _random(parentId, 100);
            uint256 cumulativeChance = 0;
            
            cumulativeChance += mildMutationChance;
            if (rand < cumulativeChance) return MutationType.MILD;
            
            cumulativeChance += moderateMutationChance;
            if (rand < cumulativeChance) return MutationType.MODERATE;
            
            cumulativeChance += severeMutationChance;
            if (rand < cumulativeChance) return MutationType.SEVERE;
            
            return MutationType.NONE;
        }
    }
}