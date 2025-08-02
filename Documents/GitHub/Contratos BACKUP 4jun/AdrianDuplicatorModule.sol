// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IAdrianHistory.sol";

interface IAdrianLabCore {
    function owner() external view returns (address);
    function safeMint(address to) external returns (uint256);
    function getTraits(uint256 tokenId) external view returns (uint256 generation, uint256 /*unused*/, string memory mutation);
    function setTokenInfo(uint256 tokenId, uint256 generation, string calldata mutation) external;
}

contract AdrianDuplicatorModule is Ownable, ReentrancyGuard {
    address public coreContract;
    address public historyContract;

    // Estado interno de duplicaciones
    mapping(uint256 => bool) public hasBeenDuplicated;

    event HistoryContractUpdated(address newContract);

    modifier onlyCoreOwner() {
        require(msg.sender == IAdrianLabCore(coreContract).owner(), "Not core owner");
        _;
    }

    constructor(address _core) {
        require(_core.code.length > 0, "Invalid address");
        coreContract = _core;
    }

    function setHistoryContract(address _historyContract) external onlyOwner {
        require(_historyContract != address(0) && _historyContract.code.length > 0, "Invalid contract");
        historyContract = _historyContract;
        emit HistoryContractUpdated(_historyContract);
    }

    function duplicateAdrian(uint256 originalTokenId, address recipient) external nonReentrant onlyCoreOwner returns (uint256) {
        require(!hasBeenDuplicated[originalTokenId], "Already duplicated");
        require(address(historyContract) != address(0), "History contract not set");

        (uint256 generation,, string memory mutation) = IAdrianLabCore(coreContract).getTraits(originalTokenId);

        uint256 newTokenId = IAdrianLabCore(coreContract).safeMint(recipient);

        IAdrianLabCore(coreContract).setTokenInfo(newTokenId, generation + 1, mutation);

        hasBeenDuplicated[originalTokenId] = true;

        // Registrar el evento en AdrianHistory
        IAdrianHistory(historyContract).recordEvent(
            newTokenId,
            keccak256("DUPLICATION"),
            msg.sender,
            abi.encodePacked(originalTokenId, block.timestamp),
            block.number
        );

        return newTokenId;
    }
}
