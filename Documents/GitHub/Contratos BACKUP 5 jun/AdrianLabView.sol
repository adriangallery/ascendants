// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAdrianLabCore {
    function ownerOf(uint256 tokenId) external view returns (address);
    function getTraits(uint256 tokenId) external view returns (uint256 generation, uint256, string memory mutation);
    function tokenCounter() external view returns (uint256);
    function exists(uint256 tokenId) external view returns (bool);
    function hasBeenDuplicated(uint256 tokenId) external view returns (bool);
    function mutationLevel(uint256 tokenId) external view returns (uint8);
    function canDuplicate(uint256 tokenId) external view returns (bool);
}

interface IAdrianLabExtensions {
    struct TokenTraitInfo {
        string category;
        uint256 traitId;
    }

    function getEquippedTraits(uint256 tokenId) external view returns (TokenTraitInfo[] memory);
}

interface IAdrianTraitsCore {
    function balanceOf(address account, uint256 id) external view returns (uint256);
}

interface IAdrianHistory {
    struct HistoricalEvent {
        bytes32 eventType;
        uint256 timestamp;
        address actor;
        bytes data;
        uint256 blockNumber;
    }

    function getEventsForToken(uint256 tokenId) external view returns (HistoricalEvent[] memory);
}

interface IAdrianInventoryModule {
    function getEquippedTraits(uint256 tokenId) external view returns (uint256[] memory);
    function getInventoryItems(uint256 tokenId) external view returns (uint256[] memory, uint256[] memory);
}

contract AdrianLabView {
    address public labCore;
    address public labExtensions;
    address public traitsCore;
    address public historyContract;
    address public inventoryModule;
    IAdrianLabCore public lab;

    constructor(
        address _core,
        address _ext,
        address _traits,
        address _history,
        address _inventory
    ) {
        labCore = _core;
        labExtensions = _ext;
        traitsCore = _traits;
        historyContract = _history;
        inventoryModule = _inventory;
        lab = IAdrianLabCore(_core);
    }

    struct TokenView {
        address owner;
        uint256 generation;
        string mutation;
        IAdrianLabExtensions.TokenTraitInfo[] equippedTraits;
        uint256[] inventoryTraitIds;
        uint256[] inventoryBalances;
        IAdrianHistory.HistoricalEvent[] history;
    }

    function getFullTokenState(uint256 tokenId, uint256[] calldata inventoryTraitIds)
        external
        view
        returns (TokenView memory state)
    {
        state.owner = IAdrianLabCore(labCore).ownerOf(tokenId);

        (state.generation,, state.mutation) = IAdrianLabCore(labCore).getTraits(tokenId);

        state.equippedTraits = IAdrianLabExtensions(labExtensions).getEquippedTraits(tokenId);

        // Inventario: leer balances de traits específicos
        uint256 len = inventoryTraitIds.length;
        state.inventoryTraitIds = inventoryTraitIds;
        state.inventoryBalances = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            state.inventoryBalances[i] = IAdrianTraitsCore(traitsCore).balanceOf(state.owner, inventoryTraitIds[i]);
        }

        // Historia del token
        if (historyContract != address(0)) {
            state.history = IAdrianHistory(historyContract).getEventsForToken(tokenId);
        }
    }

    /// @notice Obtiene los items del inventario de un token
    function getInventoryItems(uint256 tokenId) external view returns (
        uint256[] memory traitIds,
        uint256[] memory amounts
    ) {
        require(inventoryModule != address(0), "Inventory module not set");
        return IAdrianInventoryModule(inventoryModule).getInventoryItems(tokenId);
    }

    /// @notice Obtiene los traits equipados de un token
    function getEquippedTraits(uint256 tokenId) external view returns (uint256[] memory) {
        require(inventoryModule != address(0), "Inventory module not set");
        return IAdrianInventoryModule(inventoryModule).getEquippedTraits(tokenId);
    }

    /// @notice Obtiene el estado de mutación de un token
    function getMutationStatus(uint256 tokenId) external view returns (
        uint8 mutationLevel,
        bool hasBeenDuplicated,
        bool canDuplicate
    ) {
        return (
            IAdrianLabCore(labCore).mutationLevel(tokenId),
            IAdrianLabCore(labCore).hasBeenDuplicated(tokenId),
            IAdrianLabCore(labCore).canDuplicate(tokenId)
        );
    }

    /// @notice Devuelve todos los tokens que posee un wallet
    function tokensOfOwner(address owner) external view returns (uint256[] memory) {
        uint256 total = lab.tokenCounter();
        uint256 count = 0;

        for (uint256 i = 0; i < total; ++i) {
            if (lab.exists(i) && lab.ownerOf(i) == owner) {
                count++;
            }
        }

        uint256[] memory result = new uint256[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < total; ++i) {
            if (lab.exists(i) && lab.ownerOf(i) == owner) {
                result[index] = i;
                index++;
            }
        }

        return result;
    }

    /// @notice Devuelve todos los tokens existentes
    function allTokens() external view returns (uint256[] memory) {
        uint256 total = lab.tokenCounter();
        uint256 count = 0;

        for (uint256 i = 0; i < total; ++i) {
            if (lab.exists(i)) {
                count++;
            }
        }

        uint256[] memory result = new uint256[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < total; ++i) {
            if (lab.exists(i)) {
                result[index] = i;
                index++;
            }
        }

        return result;
    }

    /// @notice Devuelve el token de un owner en un índice específico (como tokenOfOwnerByIndex)
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256) {
        uint256 total = lab.tokenCounter();
        uint256 count = 0;

        for (uint256 i = 0; i < total; ++i) {
            if (lab.exists(i) && lab.ownerOf(i) == owner) {
                if (count == index) {
                    return i;
                }
                count++;
            }
        }

        revert("Index out of bounds");
    }

    /// @notice Devuelve el token global en un índice específico (como tokenByIndex)
    function tokenByIndex(uint256 index) external view returns (uint256) {
        uint256 total = lab.tokenCounter();
        uint256 count = 0;

        for (uint256 i = 0; i < total; ++i) {
            if (lab.exists(i)) {
                if (count == index) {
                    return i;
                }
                count++;
            }
        }

        revert("Index out of bounds");
    }

    function getAllTokenIdsOfOwner(address owner) external view returns (uint256[] memory) {
        uint256 total = lab.tokenCounter();
        uint256 count = 0;

        for (uint256 i = 0; i < total; ++i) {
            if (lab.exists(i) && lab.ownerOf(i) == owner) {
                count++;
            }
        }

        uint256[] memory tokenIds = new uint256[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < total; ++i) {
            if (lab.exists(i) && lab.ownerOf(i) == owner) {
                tokenIds[index] = i;
                index++;
            }
        }

        return tokenIds;
    }

    function getDuplicableTokensOfOwner(address owner) external view returns (uint256[] memory) {
        uint256 total = lab.tokenCounter();
        uint256 count = 0;

        for (uint256 i = 0; i < total; ++i) {
            if (!lab.exists(i)) continue;

            if (
                lab.ownerOf(i) == owner &&
                !lab.hasBeenDuplicated(i) &&
                lab.mutationLevel(i) == 0 && // MutationType.NONE
                lab.canDuplicate(i)
            ) {
                count++;
            }
        }

        uint256[] memory result = new uint256[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < total; ++i) {
            if (!lab.exists(i)) continue;

            if (
                lab.ownerOf(i) == owner &&
                !lab.hasBeenDuplicated(i) &&
                lab.mutationLevel(i) == 0 &&
                lab.canDuplicate(i)
            ) {
                result[index] = i;
                index++;
            }
        }

        return result;
    }

    /// @notice Obtiene el historial completo de un token en formato HistoricalEvent
    function getTokenHistory(uint256 tokenId) external view returns (IAdrianHistory.HistoricalEvent[] memory) {
        require(historyContract != address(0), "History contract not set");
        return IAdrianHistory(historyContract).getEventsForToken(tokenId);
    }

    /// @notice Obtiene el estado completo del token incluyendo historia e inventario
    function getFullStateWithHistory(uint256 tokenId, uint256[] calldata inventoryTraitIds)
        external
        view
        returns (TokenView memory state)
    {
        state = this.getFullTokenState(tokenId, inventoryTraitIds);
        if (historyContract != address(0)) {
            state.history = IAdrianHistory(historyContract).getEventsForToken(tokenId);
        }
    }
}
