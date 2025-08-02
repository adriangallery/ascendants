// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title AdrianLabProxy
 * @dev Proxy para el contrato AdrianLab usando ERC1967Proxy de OpenZeppelin
 */
contract AdrianLabProxy is ERC1967Proxy {
    /**
     * @dev Constructor que configura la dirección de implementación inicial y los datos de inicialización.
     * @param _implementation La dirección del contrato de implementación
     * @param _data Los datos a pasar al método de inicialización de la implementación
     */
    constructor(address _implementation, bytes memory _data) 
        ERC1967Proxy(_implementation, _data) 
    {}
}