// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AdrianStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract AdrianLabCore is AdrianStorage, ERC721Enumerable, ReentrancyGuard, Initializable {
    using Strings for uint256;

    function initialize(
        string memory name_,
        string memory symbol_,
        address _admin
    ) public initializer {
        __ERC721_init(name_, symbol_);
        __ERC721Enumerable_init();
        admin = _admin;
    }

    // Mantener solo funciones y eventos propios. El storage y structs están en AdrianStorage.
    // ...
}

// =============== Interfaces ===============

interface AdrianLabExtensions {
    function registerReplication(uint256 parentId, uint256 childId) external;
    function registerMutation(uint256 tokenId, string calldata mutation) external;
    function registerSerum(uint256 tokenId, uint256 serumId) external;
}

interface IAdrianLabExtensions {
    function onTokenMinted(uint256 tokenId, address to) external;
    function onTokenReplicated(uint256 parentId, uint256 childId) external;
    function onTokenDuplicated(uint256 originalId, uint256 newId) external;
    function onSerumApplied(uint256 tokenId, uint256 serumId) external;
    function getTokenURI(uint256 tokenId) external view returns (string memory);
    function recordHistory(uint256 tokenId, bytes32 eventType, bytes calldata eventData) external returns (uint256);
}

interface ITraitsContract {
    function getCategory(uint256 traitId) external view returns (string memory);
}