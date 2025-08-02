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
    function setAdminContract(address admin) external;
    function ownerOf(uint256 tokenId) external view returns (address);
}

interface IAdrianLabExtensions {
    function tokenHistory(uint256) external view returns (uint256[] memory);
    function resetTokenHistory(uint256 tokenId) external;
    function getTraits(uint256 tokenId) external view returns (uint256, uint256, string memory);
}

interface IAdrianTraitsCore {
    function getTraitInfo(uint256 assetId) external view returns (string memory, bool);
}

interface IAdrianSerumModule {
    function getSerumData(uint256 serumId) external view returns (string memory, uint256);
}

interface IAdrianInventoryModule {
    function getEquippedTraits(uint256 tokenId) external view returns (uint256[] memory);
}

interface IAdrianHistory {
    function getHistory(uint256 tokenId) external view returns (bytes32[] memory, uint256[] memory, address[] memory, bytes[] memory, uint256[] memory);
}

interface IAdrianDuplicatorModule {
    function hasBeenDuplicated(uint256 tokenId) external view returns (bool);
}

interface IAdrianMintModule {
    function getMintStatus(uint256 tokenId) external view returns (bool);
}

/**
 * @title AdrianLabAdmin
 * @dev Contrato para funciones administrativas del laboratorio
 */
contract AdrianLabAdmin is Ownable {
    address public core;
    IAdrianLabExtensions public extensionsContract;
    address public traitsContract;
    address public serumModule;
    address public inventoryModule;
    address public historyContract;
    address public duplicatorModule;
    address public mintModule;

    event ExtensionsContractUpdated(address newContract);
    event TokenHistoryReset(uint256 indexed tokenId);
    event TraitsContractUpdated(address newContract);
    event SerumModuleUpdated(address newContract);
    event InventoryModuleUpdated(address newContract);
    event HistoryContractUpdated(address newContract);
    event DuplicatorModuleUpdated(address newContract);
    event MintModuleUpdated(address newContract);

    constructor(address _core) Ownable(msg.sender) {
        core = _core;
    }

    function updateCore(address _newCore) external onlyOwner {
        core = _newCore;
    }

    function setSerumModule(address _module) external onlyOwner {
        require(_module != address(0) && _module.code.length > 0, "Invalid module");
        try IAdrianSerumModule(_module).getSerumData(1) returns (string memory, uint256) {
            IAdrianLabCore(core).setSerumModule(_module);
            serumModule = _module;
            emit SerumModuleUpdated(_module);
        } catch {
            revert("Invalid serum module");
        }
    }

    function setAdrianLabExtensions(address _extensions) external onlyOwner {
        require(_extensions != address(0) && _extensions.code.length > 0, "Invalid extensions");
        try IAdrianLabExtensions(_extensions).getTraits(1) returns (uint256, uint256, string memory) {
            IAdrianLabCore(core).setAdrianLabExtensions(_extensions);
            extensionsContract = IAdrianLabExtensions(_extensions);
            emit ExtensionsContractUpdated(_extensions);
        } catch {
            revert("Invalid extensions contract");
        }
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
        require(_extensionsContract != address(0) && _extensionsContract.code.length > 0, "Invalid contract");
        try IAdrianLabExtensions(_extensionsContract).getTraits(1) returns (uint256, uint256, string memory) {
            extensionsContract = IAdrianLabExtensions(_extensionsContract);
            emit ExtensionsContractUpdated(_extensionsContract);
        } catch {
            revert("Invalid extensions contract");
        }
    }

    function resetTokenHistory(uint256 tokenId) external onlyOwner {
        require(address(extensionsContract) != address(0), "Extensions not set");
        extensionsContract.resetTokenHistory(tokenId);
        emit TokenHistoryReset(tokenId);
    }

    function setCoreContract(address _contract) external onlyOwner {
        require(_contract != address(0) && _contract.code.length > 0, "Invalid contract");
        try IAdrianLabCore(_contract).ownerOf(1) returns (address) {
            core = _contract;
            IAdrianLabCore(_contract).setAdminContract(address(this));
        } catch {
            revert("Invalid core contract");
        }
    }

    function setTraitsContract(address _contract) external onlyOwner {
        require(_contract != address(0) && _contract.code.length > 0, "Invalid contract");
        try IAdrianTraitsCore(_contract).getTraitInfo(1) returns (string memory, bool) {
            traitsContract = _contract;
            emit TraitsContractUpdated(_contract);
        } catch {
            revert("Invalid traits contract");
        }
    }

    function setInventoryModule(address _module) external onlyOwner {
        require(_module != address(0) && _module.code.length > 0, "Invalid module");
        try IAdrianInventoryModule(_module).getEquippedTraits(1) returns (uint256[] memory) {
            inventoryModule = _module;
            emit InventoryModuleUpdated(_module);
        } catch {
            revert("Invalid inventory module");
        }
    }

    function setHistoryContract(address _contract) external onlyOwner {
        require(_contract != address(0) && _contract.code.length > 0, "Invalid contract");
        try IAdrianHistory(_contract).getHistory(1) returns (bytes32[] memory, uint256[] memory, address[] memory, bytes[] memory, uint256[] memory) {
            historyContract = _contract;
            emit HistoryContractUpdated(_contract);
        } catch {
            revert("Invalid history contract");
        }
    }

    function setDuplicatorModule(address _module) external onlyOwner {
        require(_module != address(0) && _module.code.length > 0, "Invalid module");
        try IAdrianDuplicatorModule(_module).hasBeenDuplicated(1) returns (bool) {
            duplicatorModule = _module;
            emit DuplicatorModuleUpdated(_module);
        } catch {
            revert("Invalid duplicator module");
        }
    }

    function setMintModule(address _module) external onlyOwner {
        require(_module != address(0) && _module.code.length > 0, "Invalid module");
        try IAdrianMintModule(_module).getMintStatus(1) returns (bool) {
            mintModule = _module;
            emit MintModuleUpdated(_module);
        } catch {
            revert("Invalid mint module");
        }
    }
} 