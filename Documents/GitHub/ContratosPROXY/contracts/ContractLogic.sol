// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Storage.sol";
import "./BaseImplementation.sol";

contract ContractLogic is Storage, BaseImplementation {
    event ContractRegistered(address indexed contractAddress, address indexed owner, string name);
    event ContractUpdated(address indexed contractAddress, string name);
    event ContractDeactivated(address indexed contractAddress);
    
    function initialize(address _admin) public override initializer {
        BaseImplementation.initialize(_admin);
        admin = _admin;
    }
    
    function registerContract(
        address _contractAddress,
        string memory _name,
        string memory _description
    ) external whenNotPaused {
        require(!isContractRegistered[_contractAddress], "El contrato ya esta registrado");
        
        contracts[_contractAddress] = Contract({
            owner: msg.sender,
            name: _name,
            description: _description,
            createdAt: block.timestamp,
            isActive: true
        });
        
        isContractRegistered[_contractAddress] = true;
        contractAddresses.push(_contractAddress);
        
        emit ContractRegistered(_contractAddress, msg.sender, _name);
    }
    
    function updateContract(
        address _contractAddress,
        string memory _name,
        string memory _description
    ) external whenNotPaused {
        require(isContractRegistered[_contractAddress], "El contrato no esta registrado");
        require(contracts[_contractAddress].owner == msg.sender, "No eres el propietario del contrato");
        
        Contract storage contractData = contracts[_contractAddress];
        contractData.name = _name;
        contractData.description = _description;
        
        emit ContractUpdated(_contractAddress, _name);
    }
    
    function deactivateContract(address _contractAddress) external whenNotPaused {
        require(isContractRegistered[_contractAddress], "El contrato no esta registrado");
        require(contracts[_contractAddress].owner == msg.sender || msg.sender == admin, 
                "No tienes permisos para desactivar este contrato");
        
        contracts[_contractAddress].isActive = false;
        
        emit ContractDeactivated(_contractAddress);
    }
    
    function getContractCount() external view returns (uint256) {
        return contractAddresses.length;
    }
    
    function getContractByIndex(uint256 _index) external view returns (
        address contractAddress,
        address owner,
        string memory name,
        string memory description,
        uint256 createdAt,
        bool isActive
    ) {
        require(_index < contractAddresses.length, "Indice fuera de rango");
        address addr = contractAddresses[_index];
        Contract storage contractData = contracts[addr];
        
        return (
            addr,
            contractData.owner,
            contractData.name,
            contractData.description,
            contractData.createdAt,
            contractData.isActive
        );
    }
} 