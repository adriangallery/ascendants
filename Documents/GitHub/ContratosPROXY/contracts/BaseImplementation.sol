// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract BaseImplementation is Initializable {
    address public implementation;
    address public admin;
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Solo el admin puede ejecutar esta funcion");
        _;
    }
    
    function initialize(address _admin) public initializer {
        admin = _admin;
    }
    
    function upgradeImplementation(address _newImplementation) external onlyAdmin {
        implementation = _newImplementation;
    }
} 