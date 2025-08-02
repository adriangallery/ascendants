// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AdrianStorage.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IAdrianTraitsCore {
    function getSerumData(uint256 serumId) external view returns (uint8, string memory, uint256);
    function burn(address from, uint256 traitId, uint256 amount) external;
}

interface IAdrianLabCore {
    function applyMutationFromSerum(uint256 tokenId, string calldata newMutation, string calldata narrativeText) external;
    function ownerOf(uint256 tokenId) external view returns (address);
    function isEligibleForMutation(uint256 tokenId) external view returns (bool);
}

contract AdrianSerumModule is AdrianStorage, ReentrancyGuard, Initializable {
    address public proxyAddress;
    bool private initialized;
    address public admin;

    modifier onlyProxy() {
        require(msg.sender == proxyAddress, "Solo proxy");
        _;
    }

    function initialize(address _proxy, address _traits, address _core, address _admin) external initializer {
        require(!initialized, "Ya inicializado");
        proxyAddress = _proxy;
        serum_traitsContract = _traits;
        serum_coreContract = _core;
        admin = _admin;
        initialized = true;
    }

    event SerumResult(address indexed user, uint256 indexed tokenId, uint256 indexed serumId, bool success, string mutation);
    event SerumApplied(uint256 indexed tokenId, uint256 serumId, bool success);
    event SerumUsed(uint256 indexed serumId, uint256 indexed tokenId);
    event SerumSuccess(uint256 indexed serumId, uint256 indexed tokenId);
    event SerumFailure(uint256 indexed serumId, uint256 indexed tokenId);
    event TraitsContractUpdated(address newContract);
    event CoreContractUpdated(address newContract);

    function useSerum(uint256 serumId, uint256 tokenId, string calldata narrativeText) external {
        require(IERC721(coreContract).ownerOf(tokenId) == msg.sender, "!owner");
        require(IAdrianLabCore(coreContract).isEligibleForMutation(tokenId), "!eligible");
        require(!serumUsedOnToken[serumId][tokenId], "Already used");

        (, string memory mutationName, uint256 potency) = IAdrianTraitsCore(traitsContract).getSerumData(serumId);

        bool success = true;
        if (potency < 100) {
            uint256 rand = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, serumId, tokenId))) % 100;
            success = rand < potency;
        }

        totalUsed[serumId]++;
        serumsUsed[msg.sender].push(serumId);
        tokenSerumHistory[tokenId].push(serumId);
        serumUsedOnToken[serumId][tokenId] = true;

        IAdrianTraitsCore(traitsContract).burn(msg.sender, serumId, 1);

        if (success) {
            totalSuccess[serumId]++;
            IAdrianLabCore(coreContract).applyMutationFromSerum(tokenId, mutationName, narrativeText);
            emit SerumSuccess(serumId, tokenId);
        } else {
            emit SerumFailure(serumId, tokenId);
        }

        emit SerumResult(msg.sender, tokenId, serumId, success, mutationName);
    }

    function simulateUse(uint256 serumId, uint256 tokenId) external view returns (bool) {
        (, , uint256 potency) = IAdrianTraitsCore(traitsContract).getSerumData(serumId);
        if (potency >= 100) return true;
        uint256 rand = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, serumId, tokenId))) % 100;
        return rand < potency;
    }

    function updateTraitsContract(address newContract) external onlyProxy {
        serum_traitsContract = newContract;
        emit TraitsContractUpdated(newContract);
    }

    function updateCoreContract(address newContract) external onlyProxy {
        serum_coreContract = newContract;
        emit CoreContractUpdated(newContract);
    }
} 
