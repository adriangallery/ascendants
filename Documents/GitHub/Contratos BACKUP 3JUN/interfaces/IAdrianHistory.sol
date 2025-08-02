// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IAdrianHistory
 * @dev Interfaz para el contrato de historial de eventos
 */
interface IAdrianHistory {
    /**
     * @dev Registra un evento en el historial
     * @param tokenId ID del token
     * @param eventType Tipo de evento
     * @param actor Dirección del actor que realizó la acción
     * @param eventData Datos adicionales del evento
     * @param blockNumber Número de bloque en el que ocurrió el evento
     */
    function recordEvent(
        uint256 tokenId,
        bytes32 eventType,
        address actor,
        bytes memory eventData,
        uint256 blockNumber
    ) external;
} 