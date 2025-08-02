// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAdrianTraitsCore {
    function getSerumData(uint256 serumId) external view returns (uint8, string memory, uint256);
    function burn(address from, uint256 traitId, uint256 amount) external;
    function balanceOf(address owner, uint256 traitId) external view returns (uint256);
    function getAssetType(uint256 traitId) external view returns (uint8);
}

interface IAdrianLabCore {
    function applyMutationFromSerum(uint256 tokenId, string calldata newMutation, string calldata narrativeText) external;
    function ownerOf(uint256 tokenId) external view returns (address);
    function isEligibleForMutation(uint256 tokenId) external view returns (bool);
    function setSerumModule(address _serumModule) external;
}

contract AdrianSerumModule {
    address public owner;
    IAdrianTraitsCore public traitsContract;
    IAdrianLabCore public coreContract;

    mapping(address => uint256[]) public serumsUsed;
    mapping(uint256 => uint256[]) public tokenSerumHistory;
    mapping(uint256 => uint256) public totalUsed;
    mapping(uint256 => uint256) public totalSuccess;
    mapping(uint256 => mapping(uint256 => bool)) public serumUsedOnToken; // serumId => tokenId => used

    event SerumResult(address indexed user, uint256 indexed tokenId, uint256 indexed serumId, bool success, string mutation);
    event Warning(string message);

    modifier onlyOwner() {
        require(msg.sender == owner, "!owner");
        _;
    }

    constructor(address _traits, address _core) {
        owner = msg.sender;
        traitsContract = IAdrianTraitsCore(_traits);
        coreContract = IAdrianLabCore(_core);
    }

    function setTraitsContract(address _traits) external onlyOwner {
        require(_traits != address(0) && _traits.code.length > 0, "Invalid contract");
        traitsContract = IAdrianTraitsCore(_traits);
        IAdrianTraitsExtensions(_traits).setLabCoreContract(address(this));
    }

    function setCoreContract(address _core) external onlyOwner {
        require(_core != address(0) && _core.code.length > 0, "Invalid contract");
        coreContract = IAdrianLabCore(_core);
        try coreContract.setSerumModule(address(this)) {
            // Bidireccional ok
        } catch {
            revert("Core does not accept serum module");
        }
    }

    function useSerum(uint256 serumId, uint256 tokenId, string calldata narrativeText) external {
        require(coreContract.ownerOf(tokenId) == msg.sender, "!owner");
        require(coreContract.isEligibleForMutation(tokenId), "!eligible");
        require(!serumUsedOnToken[serumId][tokenId], "Already used");
        require(address(traitsContract) != address(0), "Traits contract not set");
        require(address(coreContract) != address(0), "Core contract not set");

        (, string memory mutationName, uint256 potency) = traitsContract.getSerumData(serumId);
        require(traitsContract.balanceOf(msg.sender, serumId) > 0, "Insufficient serum balance");
        require(traitsContract.getAssetType(serumId) == uint8(AssetType.CONSUMABLE), "Serum not consumable");

        bool success = true;
        if (potency < 100) {
            uint256 rand = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, serumId, tokenId))) % 100;
            success = rand < potency;
        }

        totalUsed[serumId]++;
        serumsUsed[msg.sender].push(serumId);
        tokenSerumHistory[tokenId].push(serumId);
        serumUsedOnToken[serumId][tokenId] = true;

        traitsContract.burn(msg.sender, serumId, 1);

        if (success) {
            totalSuccess[serumId]++;
            coreContract.applyMutationFromSerum(tokenId, mutationName, narrativeText);
        }

        emit SerumResult(msg.sender, tokenId, serumId, success, mutationName);
    }

    function simulateUse(uint256 serumId, uint256 tokenId) external view returns (bool) {
        (, , uint256 potency) = traitsContract.getSerumData(serumId);
        if (potency >= 100) return true;
        uint256 rand = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, serumId, tokenId))) % 100;
        return rand < potency;
    }

    function applySerum(uint256 tokenId, uint256 serumId) external nonReentrant returns (bool) {
        // ... existing code ...
    }

    // =============== Interfaces ===============
    interface IAdrianTraitsExtensions {
        function setLabCoreContract(address _core) external;
    }
} 
