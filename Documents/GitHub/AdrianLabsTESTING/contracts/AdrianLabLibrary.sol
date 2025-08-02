// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title AdrianLabLibrary
 * @dev Biblioteca de utilidades para los contratos AdrianLab
 */
library AdrianLabLibrary {
    using Strings for uint256;
    
    /**
     * @dev Convierte un MutationType enum a string
     * @param mutation Tipo de mutación
     * @return Representación en string
     */
    function mutationTypeToString(uint8 mutation) public pure returns (string memory) {
        if (mutation == 1) return "MILD";
        if (mutation == 2) return "MODERATE";
        if (mutation == 3) return "SEVERE";
        return "NONE";
    }
    
    /**
     * @dev Genera un número aleatorio
     * @param seed Semilla para el aleatorio
     * @param max Valor máximo (exclusivo)
     * @return Valor aleatorio
     */
    function random(uint256 seed, uint256 max) public view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            blockhash(block.number - 1),
            block.timestamp,
            msg.sender,
            seed
        ))) % max;
    }
    
    /**
     * @dev Comprueba probabilidad aleatoria (0-100)
     * @param chance Porcentaje de probabilidad (0-100)
     * @param counter Un contador para generar aleatoriedad
     * @return True si exitoso
     */
    function randomChance(uint256 chance, uint256 counter) public view returns (bool) {
        require(chance <= 100, "Chance must be 0-100");
        return random(counter, 100) < chance;
    }
    
    /**
     * @dev Obtiene una subcadena de un string
     * @param str String original
     * @param startIndex Índice de inicio
     * @param endIndex Índice de fin (exclusivo)
     * @return Subcadena
     */
    function substring(string memory str, uint256 startIndex, uint256 endIndex) public pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        
        if (endIndex > strBytes.length) {
            endIndex = strBytes.length;
        }
        
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        
        return string(result);
    }
    
    /**
     * @dev Convierte uint256 a string
     * @param value Valor a convertir
     * @return Representación en string
     */
    function uintToString(uint256 value) public pure returns (string memory) {
        return value.toString();
    }
} 