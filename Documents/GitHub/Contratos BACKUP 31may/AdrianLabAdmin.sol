// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IAdrianLabCore {
    function setSerumModule(address _module) external;
    function setAdrianLabExtensions(address _extensions) external;
    function setBaseURI(string calldata newURI) external;
    function setFunctionImplementation(bytes32 key, address implementation) external;
    function setRandomSkin(bool enabled) external;
    function setTokenModified(uint256 tokenId, bool modified) external;
    function setTokenDuplicated(uint256 tokenId, bool duplicated) external;
    function setTokenMutatedBySerum(uint256 tokenId, bool mutated) external;
    function setTokenMutationLevel(uint256 tokenId, uint8 level) external;
}

interface IAdrianLabExtensions {
    function tokenHistory(uint256) external view returns (uint256[] memory);
    function resetTokenHistory(uint256 tokenId) external;
}

/**
 * @title AdrianLabAdmin
 * @dev Contrato para funciones administrativas del laboratorio
 */
contract AdrianLabAdmin is Ownable {
    address public core;
    IAdrianLabExtensions public extensionsContract;

    event ExtensionsContractUpdated(address newContract);
    event TokenHistoryReset(uint256 indexed tokenId);

    constructor(address _core) Ownable(msg.sender) {
        core = _core;
    }

    function updateCore(address _newCore) external onlyOwner {
        core = _newCore;
    }

    function setSerumModule(address _module) external onlyOwner {
        IAdrianLabCore(core).setSerumModule(_module);
    }

    function setAdrianLabExtensions(address _extensions) external onlyOwner {
        IAdrianLabCore(core).setAdrianLabExtensions(_extensions);
    }

    function setBaseURI(string calldata newURI) external onlyOwner {
        IAdrianLabCore(core).setBaseURI(newURI);
    }

    function setFunctionImplementation(bytes32 key, address implementation) external onlyOwner {
        IAdrianLabCore(core).setFunctionImplementation(key, implementation);
    }

    function setRandomSkin(bool enabled) external onlyOwner {
        IAdrianLabCore(core).setRandomSkin(enabled);
    }

    function setTokenModified(uint256 tokenId, bool modified) external onlyOwner {
        IAdrianLabCore(core).setTokenModified(tokenId, modified);
    }

    function setTokenDuplicated(uint256 tokenId, bool duplicated) external onlyOwner {
        IAdrianLabCore(core).setTokenDuplicated(tokenId, duplicated);
    }

    function setTokenMutatedBySerum(uint256 tokenId, bool mutated) external onlyOwner {
        IAdrianLabCore(core).setTokenMutatedBySerum(tokenId, mutated);
    }

    function setTokenMutationLevel(uint256 tokenId, uint8 level) external onlyOwner {
        IAdrianLabCore(core).setTokenMutationLevel(tokenId, level);
    }

    function setExtensionsContract(address _extensionsContract) external onlyOwner {
        extensionsContract = IAdrianLabExtensions(_extensionsContract);
        emit ExtensionsContractUpdated(_extensionsContract);
    }

    function resetTokenHistory(uint256 tokenId) external onlyOwner {
        require(address(extensionsContract) != address(0), "Extensions not set");
        extensionsContract.resetTokenHistory(tokenId);
        emit TokenHistoryReset(tokenId);
    }
} 