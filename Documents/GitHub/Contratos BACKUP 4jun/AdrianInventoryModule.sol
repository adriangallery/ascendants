// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAdrianTraitsCore {
    function burn(address from, uint256 id, uint256 amount) external;
    function mint(address to, uint256 id, uint256 amount) external;
    function owner() external view returns (address);
}

interface IAdrianHistory {
    function recordEvent(
        uint256 tokenId,
        bytes32 eventType,
        address actor,
        bytes calldata eventData
    ) external;
}

contract AdrianInventoryModule {
    address public traitsCore;
    address public historyContract;

    modifier onlyCoreOwner() {
        require(msg.sender == IAdrianTraitsCore(traitsCore).owner(), "Not core owner");
        _;
    }

    constructor(address _traitsCore, address _history) {
        require(_traitsCore.code.length > 0, "Invalid traits core");
        traitsCore = _traitsCore;
        historyContract = _history;
    }

    // 🔥 Quema básica
    function burnTrait(address from, uint256 id, uint256 amount) external onlyCoreOwner {
        IAdrianTraitsCore(traitsCore).burn(from, id, amount);
        _logHistory(id, "TRAIT_BURNED", from, abi.encode(from, id, amount));
    }

    // 🔁 Transformación: quema A, entrega B
    function transformTrait(address user, uint256 burnId, uint256 burnAmount, uint256 newId, uint256 newAmount) external onlyCoreOwner {
        IAdrianTraitsCore(traitsCore).burn(user, burnId, burnAmount);
        IAdrianTraitsCore(traitsCore).mint(user, newId, newAmount);

        _logHistory(newId, "TRAIT_TRANSFORMED", user, abi.encode(user, burnId, newId));
    }

    // 🧪 Evolución: quema varios, da 1 evolucionado
    function evolveTraits(
        address user,
        uint256[] calldata burnIds,
        uint256[] calldata burnAmounts,
        uint256 evolvedId
    ) external onlyCoreOwner {
        require(burnIds.length == burnAmounts.length, "Invalid input");

        for (uint256 i = 0; i < burnIds.length; i++) {
            IAdrianTraitsCore(traitsCore).burn(user, burnIds[i], burnAmounts[i]);
        }

        IAdrianTraitsCore(traitsCore).mint(user, evolvedId, 1);
        _logHistory(evolvedId, "TRAIT_EVOLVED", user, abi.encode(user, burnIds, evolvedId));
    }

    // Interno: registrar evento en historial
    function _logHistory(uint256 traitId, bytes32 eventType, address user, bytes memory data) internal {
        if (historyContract != address(0)) {
            IAdrianHistory(historyContract).recordEvent(traitId, eventType, user, data);
        }
    }
}
