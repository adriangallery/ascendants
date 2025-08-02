// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AdrianLabTrait.sol";
import "./AdrianLabLibrary.sol";

/**
 * @title AdrianLabHistory
 * @dev Gestiona funciones de historial y consulta para AdrianLab
 */
contract AdrianLabHistory is AdrianLabTrait {
    /**
     * @dev Get replication history
     */
    function getReplicationHistory(uint256 tokenId) external view returns (
        uint256[] memory parentHistory,
        uint256[] memory childHistory,
        uint256[] memory mutationHistory
    ) {
        require(_exists(tokenId), "Token not exist");
        
        // Count events by type
        (uint256 parentCount, uint256 childCount, uint256 mutationCount) = 
            _countHistoryEventTypes(tokenId);
        
        // Initialize arrays
        parentHistory = new uint256[](parentCount);
        childHistory = new uint256[](childCount);
        mutationHistory = new uint256[](mutationCount);
        
        // Fill arrays
        _fillHistoryArrays(
            tokenId, 
            parentHistory, 
            childHistory, 
            mutationHistory
        );
        
        return (parentHistory, childHistory, mutationHistory);
    }
    
    /**
     * @dev Count different event types in token history
     */
    function _countHistoryEventTypes(uint256 tokenId) private view returns (
        uint256 parentCount,
        uint256 childCount,
        uint256 mutationCount
    ) {
        for (uint256 i = 0; i < tokenHistory[tokenId].length; i++) {
            bytes32 eventType = tokenHistory[tokenId][i].eventType;
            
            if (eventType == EVENT_REPLICATE) {
                // Check event description
                bytes memory data = tokenHistory[tokenId][i].eventData;
                (string memory description, uint256 relatedToken) = abi.decode(data, (string, uint256));
                
                if (relatedToken != 0) {
                    string memory subDesc = AdrianLabLibrary.substring(description, 0, 8);
                    bytes32 subDescHash = keccak256(abi.encodePacked(subDesc));
                    
                    if (subDescHash == keccak256(abi.encodePacked("Replicated"))) {
                        childCount++;
                    } else if (keccak256(abi.encodePacked(AdrianLabLibrary.substring(description, 0, 7))) == 
                              keccak256(abi.encodePacked("Created"))) {
                        parentCount++;
                    }
                }
            } else if (eventType == EVENT_MUTATE || eventType == EVENT_SERUM_USED) {
                mutationCount++;
            }
        }
        
        return (parentCount, childCount, mutationCount);
    }
    
    /**
     * @dev Fill history arrays with event indices
     */
    function _fillHistoryArrays(
        uint256 tokenId,
        uint256[] memory parentHistory,
        uint256[] memory childHistory,
        uint256[] memory mutationHistory
    ) private view {
        uint256 parentIndex = 0;
        uint256 childIndex = 0;
        uint256 mutationIndex = 0;
        
        for (uint256 i = 0; i < tokenHistory[tokenId].length; i++) {
            bytes32 eventType = tokenHistory[tokenId][i].eventType;
            
            if (eventType == EVENT_REPLICATE) {
                bytes memory data = tokenHistory[tokenId][i].eventData;
                (string memory description, uint256 relatedToken) = abi.decode(data, (string, uint256));
                
                if (relatedToken != 0) {
                    string memory subDesc = AdrianLabLibrary.substring(description, 0, 8);
                    bytes32 subDescHash = keccak256(abi.encodePacked(subDesc));
                    
                    if (subDescHash == keccak256(abi.encodePacked("Replicated"))) {
                        childHistory[childIndex++] = i;
                    } else if (keccak256(abi.encodePacked(AdrianLabLibrary.substring(description, 0, 7))) == 
                             keccak256(abi.encodePacked("Created"))) {
                        parentHistory[parentIndex++] = i;
                    }
                }
            } else if (eventType == EVENT_MUTATE || eventType == EVENT_SERUM_USED) {
                mutationHistory[mutationIndex++] = i;
            }
        }
    }
    
    /**
     * @dev Check if a token is eligible for duplication
     * @param tokenId The token ID to check
     * @return True if eligible
     */
    function isEligibleForDuplication(uint256 tokenId) external view returns (bool) {
        return isGen0Token[tokenId] && 
               !hasBeenDuplicated[tokenId] && 
               !hasBeenMutatedBySerum[tokenId];
    }
    
    /**
     * @dev Check if a token is eligible for serum mutation
     * @param tokenId The token ID to check
     * @return True if eligible
     */
    function isEligibleForSerumMutation(uint256 tokenId) external view returns (bool) {
        return isGen0Token[tokenId] && 
               !hasBeenDuplicated[tokenId] && 
               !hasBeenMutatedBySerum[tokenId];
    }
}