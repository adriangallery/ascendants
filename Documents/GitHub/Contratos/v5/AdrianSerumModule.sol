// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// =============== INTERFACES ===============

interface IAdrianTraitsCore {
    function burn(address from, uint256 traitId, uint256 amount) external;
    function balanceOf(address owner, uint256 traitId) external view returns (uint256);
    function getAssetTypeEnum(uint256 traitId) external view returns (uint8);
}

interface IAdrianLabCore {
    function ownerOf(uint256 tokenId) external view returns (address);
    function isEligibleForMutation(uint256 tokenId) external view returns (bool);
    function setMutationFromSerum(uint256 tokenId, string calldata mutation, string calldata narrativeText) external;
    function applyMutationSkin(uint256 tokenId, string calldata mutation) external;
}

/**
 * @title AdrianSerumModule - SIMPLIFIED
 * @dev Ultra-simple serum usage following PackTokenMinter pattern
 * @notice Simplified: No pausing, no banning, no complex tracking, no batch operations
 */
contract AdrianSerumModule is Ownable, ReentrancyGuard {
    
    // =============== SIMPLE STRUCTS ===============
    
    struct SerumData {
        string targetMutation;
        uint256 potency;        // 0-100
    }

    struct SerumApplication {
        uint256 serumId;
        bool success;
        uint256 timestamp;
        string mutation;
    }
    
    // =============== CONSTANTS ===============
    
    // No constants needed - TraitsContract validates serum type

    // =============== STATE VARIABLES ===============
    
    IAdrianTraitsCore private traitsContract;
    IAdrianLabCore private coreContract;

    // Simple serum storage
    mapping(uint256 => SerumData) public serums;
    
    // Prevent reuse of same serum on same token (like PackTokenMinter prevents double-purchase)
    mapping(uint256 => mapping(uint256 => bool)) public serumUsedOnToken; // serumId => tokenId => used
    
    // Track serum applications per token (with success/fail history)
    mapping(uint256 => SerumApplication[]) public tokenSerumApplications; // tokenId => applications[]

    // =============== EVENTS ===============
    
    event SerumResult(
        address indexed user, 
        uint256 indexed tokenId, 
        uint256 indexed serumId, 
        bool success, 
        string mutation
    );

    // =============== CONSTRUCTOR ===============
    
    constructor(address _traits, address _core) Ownable(msg.sender) {
        require(_traits != address(0) && _traits.code.length > 0, "Invalid traits contract");
        require(_core != address(0) && _core.code.length > 0, "Invalid core contract");
        
        traitsContract = IAdrianTraitsCore(_traits);
        coreContract = IAdrianLabCore(_core);
    }

    // =============== CORE FUNCTIONS ===============

    /**
     * @dev Register a new serum (SIMPLIFIED - no metadata)
     * @param serumId ID del serum
     * @param targetMutation Mutación objetivo
     * @param potency Potencia del serum (0-100)
     */
    function registerSerum(
        uint256 serumId,
        string calldata targetMutation,
        uint256 potency
    ) external onlyOwner {
        require(traitsContract.getAssetTypeEnum(serumId) == 3, "Not a serum");
        require(potency <= 100, "Potency must be <= 100");
        require(bytes(targetMutation).length > 0, "Empty target mutation");
        
        serums[serumId] = SerumData({
            targetMutation: targetMutation,
            potency: potency
        });
    }

    /**
     * @dev Use serum on token (SIMPLIFIED - all validations inline)
     * @param serumId Serum to use
     * @param tokenId Token to mutate  
     * @param narrativeText User's story for this mutation
     */
    function useSerum(
        uint256 serumId, 
        uint256 tokenId, 
        string calldata narrativeText
    ) external nonReentrant {
        // Basic validations (inline like PackTokenMinter)
        require(traitsContract.getAssetTypeEnum(serumId) == 3, "Not a serum");
        require(bytes(serums[serumId].targetMutation).length > 0, "Serum does not exist");
        
        // Ownership and eligibility checks
        require(coreContract.ownerOf(tokenId) == msg.sender, "Not token owner");
        require(coreContract.isEligibleForMutation(tokenId), "Token not eligible for mutation");
        require(!serumUsedOnToken[serumId][tokenId], "Serum already used on this token");
        require(traitsContract.balanceOf(msg.sender, serumId) > 0, "Insufficient serum balance");

        // Get serum data
        SerumData storage serum = serums[serumId];
        string memory mutationName = serum.targetMutation;
        uint256 potency = serum.potency;
        
        require(potency > 0, "Invalid serum potency");

        // Calculate success (simplified)
        bool success = _calculateSerumSuccess(serumId, potency, tokenId);

        // Burn the serum FIRST (prevents exploit if burn fails)
        traitsContract.burn(msg.sender, serumId, 1);

        // Mark as used AFTER successful burn (prevent reuse)
        serumUsedOnToken[serumId][tokenId] = true;

        // Apply mutation if successful
        if (success) {
            coreContract.setMutationFromSerum(tokenId, mutationName, narrativeText);
            
            // Try to apply special skin (optional, no revert if fails)
            try coreContract.applyMutationSkin(tokenId, mutationName) {
                // Skin applied successfully
            } catch {
                // No special skin available, continue
            }
        }

        // Record application in token history (success or failure)
        tokenSerumApplications[tokenId].push(SerumApplication({
            serumId: serumId,
            success: success,
            timestamp: block.timestamp,
            mutation: mutationName
        }));

        // Single clear event
        emit SerumResult(msg.sender, tokenId, serumId, success, mutationName);
    }

    // =============== VIEW FUNCTIONS ===============

    /**
     * @dev Get serum info
     * @param serumId Serum ID to query
     * @return targetMutation Mutation name
     * @return potency Success rate (0-100)
     */
    function getSerumInfo(uint256 serumId) external view returns (
        string memory targetMutation,
        uint256 potency
    ) {
        SerumData storage serum = serums[serumId];
        return (serum.targetMutation, serum.potency);
    }

    /**
     * @dev Get all serum applications for a token
     * @param tokenId Token to query
     * @return applications Array of all serum applications (success and failures)
     */
    function getTokenSerumHistory(uint256 tokenId) external view returns (SerumApplication[] memory) {
        return tokenSerumApplications[tokenId];
    }

    /**
     * @dev Get count of serum applications for a token
     * @param tokenId Token to query
     * @return count Number of serum applications (total)
     */
    function getTokenSerumCount(uint256 tokenId) external view returns (uint256) {
        return tokenSerumApplications[tokenId].length;
    }

    /**
     * @dev Get specific serum application by index
     * @param tokenId Token to query
     * @param index Application index (0-based)
     * @return application Serum application details
     */
    function getTokenSerumApplication(uint256 tokenId, uint256 index) external view returns (SerumApplication memory) {
        require(index < tokenSerumApplications[tokenId].length, "Index out of bounds");
        return tokenSerumApplications[tokenId][index];
    }

    /**
     * @dev Check if token has any successful serum applications
     * @param tokenId Token to query
     * @return hasSuccessful True if token has at least one successful application
     */
    function hasSuccessfulSerumApplications(uint256 tokenId) external view returns (bool) {
        SerumApplication[] storage applications = tokenSerumApplications[tokenId];
        for (uint256 i = 0; i < applications.length; i++) {
            if (applications[i].success) {
                return true;
            }
        }
        return false;
    }

    // =============== ADMIN FUNCTIONS ===============

    /**
     * @dev Set traits contract
     * @param _traitsContract New traits contract address
     */
    function setTraitsContract(address _traitsContract) external onlyOwner {
        require(_traitsContract != address(0) && _traitsContract.code.length > 0, "Invalid traits contract");
        traitsContract = IAdrianTraitsCore(_traitsContract);
    }

    /**
     * @dev Set core contract  
     * @param _coreContract New core contract address
     */
    function setCoreContract(address _coreContract) external onlyOwner {
        require(_coreContract != address(0) && _coreContract.code.length > 0, "Invalid core contract");
        coreContract = IAdrianLabCore(_coreContract);
    }

    // =============== INTERNAL FUNCTIONS ===============

    /**
     * @dev Calculate if serum application succeeds (SIMPLIFIED)
     * @param serumId Serum being used
     * @param potency Success rate (0-100)
     * @param tokenId Token being mutated
     * @return success True if mutation succeeds
     */
    function _calculateSerumSuccess(uint256 serumId, uint256 potency, uint256 tokenId) internal view returns (bool) {
        // 100% potency = guaranteed success
        if (potency >= 100) return true;
        
        // Simple pseudo-random based on block data
        uint256 randomValue = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.prevrandao,
            msg.sender,
            serumId,
            tokenId
        ))) % 100;
        
        return randomValue < potency;
    }
}