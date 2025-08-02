// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Storage {
    struct Contract {
        address owner;
        string name;
        string description;
        uint256 createdAt;
        bool isActive;
    }
    
    mapping(address => Contract) public contracts;
    mapping(address => bool) public isContractRegistered;
    address[] public contractAddresses;
    
    // Variables de control
    address public admin;
    bool public paused;
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Solo el admin puede ejecutar esta funcion");
        _;
    }
    
    modifier whenNotPaused() {
        require(!paused, "El contrato esta pausado");
        _;
    }
    
    function setAdmin(address _newAdmin) external onlyAdmin {
        admin = _newAdmin;
    }
    
    function setPaused(bool _paused) external onlyAdmin {
        paused = _paused;
    }
} 