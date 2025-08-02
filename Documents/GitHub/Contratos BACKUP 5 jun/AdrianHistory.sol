// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AdrianHistory
 * @dev Contrato para manejar el historial de eventos de los tokens
 */
contract AdrianHistory is Ownable {
    // =============== Constants ===============
    
    bytes32 constant EVENT_MINT = keccak256("MINT");
    bytes32 constant EVENT_REPLICATE = keccak256("REPLICATE");
    bytes32 constant EVENT_MUTATE = keccak256("MUTATE");
    bytes32 constant EVENT_TRAIT_EQUIPPED = keccak256("TRAIT_EQUIPPED");
    bytes32 constant EVENT_TRAIT_REMOVED = keccak256("TRAIT_REMOVED");
    bytes32 constant EVENT_SERUM_USED = keccak256("SERUM_USED");
    bytes32 constant EVENT_BACKGROUND_EQUIPPED = keccak256("BACKGROUND_EQUIPPED");

    // =============== Type Definitions ===============
    
    struct HistoricalEvent {
        uint256 timestamp;
        bytes32 eventType;
        address actorAddress;
        bytes eventData;
        uint256 blockNumber;
    }

    // =============== State Variables ===============
    
    // History system
    mapping(uint256 => HistoricalEvent[]) public tokenHistory;
    mapping(address => bool) public historyWriters;
    
    // =============== Events ===============
    
    event HistoryRecorded(uint256 indexed tokenId, bytes32 indexed eventType, uint256 eventIndex);
    event HistoryWriterUpdated(address writer, bool authorized);

    constructor() Ownable(msg.sender) {}

    // =============== Modifiers ===============
    
    modifier onlyHistoryWriter() {
        require(msg.sender == owner() || historyWriters[msg.sender], "!writer");
        _;
    }

    // =============== Core Functions ===============

    /**
     * @dev Get history count
     */
    function getHistoryCount(uint256 tokenId) external view returns (uint256) {
        return tokenHistory[tokenId].length;
    }

    /**
     * @dev Get specific history event
     */
    function getHistoryEvent(uint256 tokenId, uint256 eventIndex) 
        external view returns (
            uint256 timestamp,
            bytes32 eventType,
            address actorAddress,
            bytes memory eventData,
            uint256 blockNumber
        ) 
    {
        require(eventIndex < tokenHistory[tokenId].length, "!index");
        
        HistoricalEvent storage event_ = tokenHistory[tokenId][eventIndex];
        return (
            event_.timestamp,
            event_.eventType,
            event_.actorAddress,
            event_.eventData,
            event_.blockNumber
        );
    }

    /**
     * @dev Record history event
     */
    function recordHistory(
        uint256 tokenId,
        bytes32 eventType,
        bytes memory eventData
    ) external onlyHistoryWriter returns (uint256) {
        HistoricalEvent memory newEvent = HistoricalEvent({
            timestamp: block.timestamp,
            eventType: eventType,
            actorAddress: msg.sender,
            eventData: eventData,
            blockNumber: block.number
        });
        
        uint256 eventIndex = tokenHistory[tokenId].length;
        tokenHistory[tokenId].push(newEvent);
        
        emit HistoryRecorded(tokenId, eventType, eventIndex);
        return eventIndex;
    }

    /**
     * @dev Add narrative event
     */
    function addNarrativeEvent(
        uint256 tokenId,
        bytes32 eventType,
        string memory description,
        uint256 relatedId
    ) external onlyHistoryWriter {
        HistoricalEvent memory newEvent = HistoricalEvent({
            timestamp: block.timestamp,
            eventType: eventType,
            actorAddress: msg.sender,
            eventData: abi.encode(description, relatedId),
            blockNumber: block.number
        });

        uint256 eventIndex = tokenHistory[tokenId].length;
        tokenHistory[tokenId].push(newEvent);
        
        emit HistoryRecorded(tokenId, eventType, eventIndex);
    }

    /**
     * @dev Register replication event
     */
    function registerReplication(uint256 parentId, uint256 childId) external onlyHistoryWriter {
        tokenHistory[parentId].push(HistoricalEvent({
            timestamp: block.timestamp,
            eventType: keccak256("REPLICATION"),
            actorAddress: msg.sender,
            eventData: abi.encode(childId),
            blockNumber: block.number
        }));
    }

    /**
     * @dev Register mutation event
     */
    function registerMutation(uint256 tokenId, string calldata mutationName) external onlyHistoryWriter {
        tokenHistory[tokenId].push(HistoricalEvent({
            timestamp: block.timestamp,
            eventType: keccak256("MUTATION"),
            actorAddress: msg.sender,
            eventData: abi.encode(mutationName),
            blockNumber: block.number
        }));
    }

    /**
     * @dev Register serum event
     */
    function registerSerum(uint256 tokenId, uint256 serumId) external onlyHistoryWriter {
        tokenHistory[tokenId].push(HistoricalEvent({
            timestamp: block.timestamp,
            eventType: keccak256("SERUM"),
            actorAddress: msg.sender,
            eventData: abi.encode(serumId),
            blockNumber: block.number
        }));
    }

    /**
     * @dev Get history for a token
     */
    function getHistory(uint256 tokenId) external view returns (HistoricalEvent[] memory) {
        return tokenHistory[tokenId];
    }

    /**
     * @dev Set history writer
     */
    function setHistoryWriter(address writer, bool authorized) external onlyOwner {
        historyWriters[writer] = authorized;
        emit HistoryWriterUpdated(writer, authorized);
    }

    /**
     * @dev Reset token history
     */
    function resetTokenHistory(uint256 tokenId) external onlyOwner {
        delete tokenHistory[tokenId];
    }
} 