// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AdrianStorage.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

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
contract AdrianLabAdmin is AdrianStorage, ReentrancyGuard, Initializable {
    address public proxyAddress;
    bool private initialized;

    event ExtensionsContractUpdated(address newContract);
    event TokenHistoryReset(uint256 indexed tokenId);
    event BatchCreated(uint256 indexed batchId, string name, uint256 price, uint256 maxSupply);
    event BatchUpdated(uint256 indexed batchId, string name, uint256 price, uint256 maxSupply);
    event BatchActivated(uint256 indexed batchId);
    event BatchDeactivated(uint256 indexed batchId);
    event WhitelistUpdated(uint256 indexed batchId, address[] accounts, bool status);
    event SkinCreated(uint256 indexed skinId, string name, uint256 rarity);
    event SkinUpdated(uint256 indexed skinId, string name, uint256 rarity);
    event SkinActivated(uint256 indexed skinId);
    event SkinDeactivated(uint256 indexed skinId);
    event PaymentTokenUpdated(address newPaymentToken);
    event TreasuryWalletUpdated(address newTreasuryWallet);
    event ReplicationSettingsUpdated(uint256 chance, uint256 maxReplications, uint256 cooldown);
    event MutationSettingsUpdated(uint256 mildChance, uint256 severeChance);
    event ContractPaused(bool paused);
    event RandomSkinEnabled(bool enabled);
    event BaseURIUpdated(string newBaseURI);

    modifier onlyProxy() {
        require(msg.sender == proxyAddress, "Solo proxy");
        _;
    }

    function initialize(address _proxy, address _core) external initializer {
        require(!initialized, "Ya inicializado");
        proxyAddress = _proxy;
        core = _core;
        initialized = true;
    }

    function updateCore(address _newCore) external onlyProxy {
        core = _newCore;
    }

    function setSerumModule(address _module) external onlyProxy {
        IAdrianLabCore(core).setSerumModule(_module);
    }

    function setAdrianLabExtensions(address _extensions) external onlyProxy {
        IAdrianLabCore(core).setAdrianLabExtensions(_extensions);
    }

    function setBaseURI(string calldata newURI) external onlyProxy {
        IAdrianLabCore(core).setBaseURI(newURI);
    }

    function setFunctionImplementation(bytes32 key, address implementation) external onlyProxy {
        IAdrianLabCore(core).setFunctionImplementation(key, implementation);
    }

    function setRandomSkin(bool enabled) external onlyProxy {
        IAdrianLabCore(core).setRandomSkin(enabled);
    }

    function setTokenModified(uint256 tokenId, bool modified) external onlyProxy {
        IAdrianLabCore(core).setTokenModified(tokenId, modified);
    }

    function setTokenDuplicated(uint256 tokenId, bool duplicated) external onlyProxy {
        IAdrianLabCore(core).setTokenDuplicated(tokenId, duplicated);
    }

    function setTokenMutatedBySerum(uint256 tokenId, bool mutated) external onlyProxy {
        IAdrianLabCore(core).setTokenMutatedBySerum(tokenId, mutated);
    }

    function setTokenMutationLevel(uint256 tokenId, uint8 level) external onlyProxy {
        IAdrianLabCore(core).setTokenMutationLevel(tokenId, level);
    }

    function setExtensionsContract(address _extensionsContract) external onlyProxy {
        extensionsContract = _extensionsContract;
        emit ExtensionsContractUpdated(_extensionsContract);
    }

    function resetTokenHistory(uint256 tokenId) external onlyProxy {
        require(extensionsContract != address(0), "Extensions not set");
        IAdrianLabExtensions(extensionsContract).resetTokenHistory(tokenId);
        emit TokenHistoryReset(tokenId);
    }
} 