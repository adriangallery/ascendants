// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AdrianStorage.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AdrianLabExtensions is AdrianStorage, ReentrancyGuard, Initializable {
    event TraitEquipped(uint256 indexed tokenId, string category, uint256 traitId);
    event TraitUnequipped(uint256 indexed tokenId, string category);
    event CategoryAdded(string category);
    event CategoryRemoved(string category);
    event ExtensionAuthorized(address extension);
    event ExtensionRevoked(address extension);
    event EmergencyModeActivated();
    event EmergencyModeDeactivated();
    event FunctionPaused(bytes4 functionSelector);
    event FunctionUnpaused(bytes4 functionSelector);

    function initialize(address _admin) public initializer {
        admin = _admin;
    }

    // Mantener solo funciones y eventos propios. El storage y structs están en AdrianStorage.
    // ...
}