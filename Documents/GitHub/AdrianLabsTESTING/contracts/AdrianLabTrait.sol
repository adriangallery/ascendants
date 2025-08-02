// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./AdrianLabStorage.sol";
import "./AdrianLabLibrary.sol";

/**
 * @title AdrianLabTrait
 * @dev Contract to manage traits for AdrianLab NFTs
 */
contract AdrianLabTrait is AdrianLabStorage {
    using Strings for uint256;

    // Helper function in case toString doesn't work
    function _uintToString(uint256 value) internal pure returns (string memory) {
        return AdrianLabLibrary.uintToString(value);
    }

    /**
     * @dev Equip a trait to a token
     * @param tokenId The token to equip the trait to
     * @param traitId The trait to equip
     */
    function equipTrait(uint256 tokenId, uint256 traitId) external notPaused(this.equipTrait.selector) {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        
        // Verify trait ownership through traits contract
        require(ITraits(traitsContractAddress).balanceOf(msg.sender, traitId) > 0, "Not trait owner");
        
        // Get trait info
        (string memory category, bool isTemporary) = ITraits(traitsContractAddress).getTraitInfo(traitId);
        
        // If not temporary, burn the trait
        if (!isTemporary) {
            ITraits(traitsContractAddress).burn(msg.sender, traitId, 1);
        }
        
        _equipTraitInternal(tokenId, traitId, category);
    }
    
    /**
     * @dev Internal function to equip a trait
     */
    function _equipTraitInternal(uint256 tokenId, uint256 traitId, string memory category) internal {
        // Mark token as modified if first time
        if (!hasBeenModified[tokenId]) {
            hasBeenModified[tokenId] = true;
            emit FirstModification(tokenId);
        }
        
        // Equip trait
        tokenTraits[tokenId][category] = traitId;
        
        // Register history
        _addNarrativeEvent(
            tokenId,
            EVENT_TRAIT_EQUIPPED,
            string(abi.encodePacked(
                "Equipped trait #", 
                _uintToString(traitId),
                " in category ",
                category
            )),
            0
        );
        
        emit TraitEquipped(tokenId, category, traitId);
    }
    
    /**
     * @dev Remove a trait from a token
     * @param tokenId The token to remove the trait from
     * @param category The category of trait to remove
     */
    function removeTrait(uint256 tokenId, string calldata category) external notPaused(this.removeTrait.selector) {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        require(tokenTraits[tokenId][category] != 0, "No trait equipped");
        
        // Get trait ID before removing
        uint256 traitId = tokenTraits[tokenId][category];
        
        // Check if temporary to return to owner
        (,bool isTemporary) = ITraits(traitsContractAddress).getTraitInfo(traitId);
        if (isTemporary) {
            // Return to owner
            ITraits(traitsContractAddress).safeTransferFrom(
                address(this),
                msg.sender,
                traitId,
                1,
                ""
            );
        }
        
        _removeTraitInternal(tokenId, traitId, category);
    }
    
    /**
     * @dev Internal function to remove a trait
     */
    function _removeTraitInternal(uint256 tokenId, uint256 traitId, string memory category) internal {
        // Reset trait
        tokenTraits[tokenId][category] = 0;
        
        // Register history
        _addNarrativeEvent(
            tokenId,
            EVENT_TRAIT_REMOVED,
            string(abi.encodePacked(
                "Removed trait #", 
                _uintToString(traitId),
                " from category ",
                category
            )),
            0
        );
        
        emit TraitRemoved(tokenId, category);
    }
    
    /**
     * @dev Equip a background to a token
     * @param tokenId The token to equip the background to
     * @param backgroundId The background trait to equip
     */
    function equipBackground(uint256 tokenId, uint256 backgroundId) external notPaused(this.equipBackground.selector) {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        
        // Verify that the trait is a background
        string memory category = ITraits(traitsContractAddress).getCategory(backgroundId);
        require(keccak256(bytes(category)) == keccak256(bytes("BACKGROUND")), "Not a background");
        
        // Verify ownership
        require(ITraits(traitsContractAddress).balanceOf(msg.sender, backgroundId) > 0, "Don't own this background");
        
        // If permanent, burn it
        bool isTemporary = ITraits(traitsContractAddress).isTemporary(backgroundId);
        if (!isTemporary) {
            ITraits(traitsContractAddress).burn(msg.sender, backgroundId, 1);
        }
        
        // Use the internal equip function with specific category
        _equipBackgroundInternal(tokenId, backgroundId);
    }
    
    /**
     * @dev Internal function to equip background
     */
    function _equipBackgroundInternal(uint256 tokenId, uint256 backgroundId) internal {
        // Mark token as modified if first time
        if (!hasBeenModified[tokenId]) {
            hasBeenModified[tokenId] = true;
            emit FirstModification(tokenId);
        }
        
        // Equip background
        tokenTraits[tokenId]["BACKGROUND"] = backgroundId;
        
        // Register history
        _addNarrativeEvent(
            tokenId,
            EVENT_BACKGROUND_EQUIPPED,
            string(abi.encodePacked(
                "Background changed to ", 
                ITraits(traitsContractAddress).getName(backgroundId)
            )),
            0
        );
        
        emit BackgroundEquipped(tokenId, backgroundId);
    }
    
    /**
     * @dev Hook for ERC1155 traits contract to use a serum on a token
     * @param user The user applying the serum
     * @param tokenId The token to apply the serum to
     * @param serumId The serum type to use
     * @return success True if successful
     */
    function applySerumFromTraits(
        address user, 
        uint256 tokenId, 
        uint256 serumId
    ) external onlyTraitsContract returns (bool) {
        require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == user, "Not token owner");
        
        // Get serum data
        (SerumType serumType, string memory targetMutation, uint256 potency) = 
            ITraits(traitsContractAddress).getSerumData(serumId);
        
        return _processSerumEffect(tokenId, serumType, targetMutation, potency);
    }
    
    /**
     * @dev Process serum effect
     */
    function _processSerumEffect(
        uint256 tokenId, 
        SerumType serumType, 
        string memory targetMutation, 
        uint256 potency
    ) internal returns (bool) {
        // Process mutation based on serum type
        if (serumType == SerumType.BASIC_MUTATION) {
            // Basic mutation: random mutation with probability based on potency
            if (_random(tokenId, 100) <= potency) {
                mutationLevel[tokenId] = MutationType.MILD;
                emit MutationAssigned(tokenId);
                
                // Register history
                _addNarrativeEvent(
                    tokenId,
                    EVENT_SERUM_USED,
                    "Mutated using a basic serum",
                    0
                );
                
                return true;
            }
        } 
        else if (serumType == SerumType.DIRECTED_MUTATION) {
            // Directed mutation: set to specific mutation
            if (keccak256(bytes(targetMutation)) == keccak256(bytes("MILD"))) {
                mutationLevel[tokenId] = MutationType.MILD;
            } else if (keccak256(bytes(targetMutation)) == keccak256(bytes("MODERATE"))) {
                mutationLevel[tokenId] = MutationType.MODERATE;
            } else if (keccak256(bytes(targetMutation)) == keccak256(bytes("SEVERE"))) {
                mutationLevel[tokenId] = MutationType.SEVERE;
            }
            
            emit MutationAssigned(tokenId);
            
            // Register history
            _addNarrativeEvent(
                tokenId,
                EVENT_SERUM_USED,
                string(abi.encodePacked("Mutated to ", targetMutation, " using a directed serum")),
                0
            );
            
            return true;
        }
        else if (serumType == SerumType.ADVANCED_MUTATION) {
            // Advanced mutation: effects depend on gameData and specific logic
            
            // Example: allow mutation in gen 1 tokens
            if (generation[tokenId] <= 1) {
                mutationLevel[tokenId] = MutationType.MODERATE;
                emit MutationAssigned(tokenId);
                
                // Register history
                _addNarrativeEvent(
                    tokenId,
                    EVENT_SERUM_USED,
                    "Transformed using an advanced serum",
                    0
                );
                
                return true;
            }
        }
        
        return false;
    }
    
    /**
     * @dev Emergency restore traits
     * @param tokenId The token to restore traits for
     * @param categories Categories to restore
     * @param traitIds Trait IDs to restore
     */
    function emergencyRestoreTraits(
        uint256 tokenId,
        string[] calldata categories,
        uint256[] calldata traitIds
    ) external onlyOwner {
        require(emergencyMode, "Not in emergency mode");
        require(_exists(tokenId), "Token does not exist");
        require(categories.length == traitIds.length, "Arrays length mismatch");
        
        for (uint256 i = 0; i < categories.length; i++) {
            tokenTraits[tokenId][categories[i]] = traitIds[i];
        }
        
        emit EmergencyTraitsRestored(tokenId);
    }
    
    /**
     * @dev Set traits contract address
     * @param _traitsContractAddress New traits contract address
     */
    function setTraitsContract(address _traitsContractAddress) external onlyOwner {
        require(_traitsContractAddress != address(0), "Zero address");
        traitsContractAddress = _traitsContractAddress;
        emit TraitsContractUpdated(_traitsContractAddress);
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
    
    /**
     * @dev Helper function to generate random number
     */
    function _random(uint256 seed, uint256 max) internal view returns (uint256) {
        return AdrianLabLibrary.random(seed, max);
    }
}
}