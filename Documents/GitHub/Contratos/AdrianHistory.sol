// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AdrianHistory
 * @dev Contrato para manejar el historial de eventos de los tokens
 * @notice UPGRADED - FASE 1: Nuevas constantes de eventos para sistema completo
 */
contract AdrianHistory is Ownable {
    // =============== Constants ===============
    
    // ✅ EXISTING: Eventos originales
    bytes32 constant EVENT_MINT = keccak256("MINT");
    bytes32 constant EVENT_REPLICATE = keccak256("REPLICATE");
    bytes32 constant EVENT_MUTATE = keccak256("MUTATE");
    bytes32 constant EVENT_TRAIT_EQUIPPED = keccak256("TRAIT_EQUIPPED");
    bytes32 constant EVENT_TRAIT_REMOVED = keccak256("TRAIT_REMOVED");
    bytes32 constant EVENT_SERUM_USED = keccak256("SERUM_USED");
    bytes32 constant EVENT_BACKGROUND_EQUIPPED = keccak256("BACKGROUND_EQUIPPED");
    bytes32 constant EVENT_DUPLICATION = keccak256("DUPLICATION");
    bytes32 constant EVENT_DUPLICATED = keccak256("DUPLICATED");
    bytes32 constant EVENT_CREATED_BY_DUPLICATION = keccak256("CREATED_BY_DUPLICATION");
    bytes32 constant EVENT_BURNT = keccak256("BURNT");
    bytes32 constant EVENT_MUTATION = keccak256("MUTATION");
    bytes32 constant EVENT_SERUM_MUTATION = keccak256("SERUM_MUTATION");
    bytes32 constant EVENT_EQUIP_TRAIT = keccak256("EQUIP_TRAIT");
    bytes32 constant EVENT_ASSET_CRAFTED = keccak256("ASSET_CRAFTED");
    bytes32 constant EVENT_TRAIT_BURNED = keccak256("TRAIT_BURNED");
    bytes32 constant EVENT_TRAIT_TRANSFORMED = keccak256("TRAIT_TRANSFORMED");
    bytes32 constant EVENT_TRAIT_EVOLVED = keccak256("TRAIT_EVOLVED");
    
    // ✅ NEW - FASE 1: Eventos para nuevas funcionalidades
    bytes32 constant EVENT_SKIN_UPDATED = keccak256("SKIN_UPDATED");
    bytes32 constant EVENT_MUTATION_SKIN_APPLIED = keccak256("MUTATION_SKIN_APPLIED");
    bytes32 constant EVENT_MAX_SUPPLY_UPDATED = keccak256("MAX_SUPPLY_UPDATED");
    bytes32 constant EVENT_FREE_PACK_CLAIMED = keccak256("FREE_PACK_CLAIMED");
    bytes32 constant EVENT_PACK_PRICING_SET = keccak256("PACK_PRICING_SET");
    bytes32 constant EVENT_SPECIAL_SKIN_APPLIED = keccak256("SPECIAL_SKIN_APPLIED");
    
    // ✅ NEW - Eventos adicionales para seguimiento completo
    bytes32 constant EVENT_SERUM_MUTATION_SUCCESS = keccak256("SERUM_MUTATION_SUCCESS");
    bytes32 constant EVENT_SERUM_MUTATION_FAILED = keccak256("SERUM_MUTATION_FAILED");
    bytes32 constant EVENT_SERUM_REGISTERED = keccak256("SERUM_REGISTERED");
    bytes32 constant EVENT_SERUM_UPDATED = keccak256("SERUM_UPDATED");

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
    
    // ✅ NEW: Event statistics tracking
    mapping(bytes32 => uint256) public eventTypeCount;
    uint256 public totalEventsRecorded;
    
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
     * @dev Record history event - INTERFACE FIXED (bytes32 eventType)
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
        
        // ✅ NEW: Update statistics
        eventTypeCount[eventType]++;
        totalEventsRecorded++;
        
        emit HistoryRecorded(tokenId, eventType, eventIndex);
        return eventIndex;
    }

    /**
     * @dev Record event - MAIN INTERFACE for modules (bytes32 eventType)
     */
    function recordEvent(
        uint256 tokenId,
        bytes32 eventType,
        address actor,
        bytes calldata eventData,
        uint256 blockNumber
    ) external onlyHistoryWriter {
        HistoricalEvent memory newEvent = HistoricalEvent({
            timestamp: block.timestamp,
            eventType: eventType,
            actorAddress: actor,
            eventData: eventData,
            blockNumber: blockNumber
        });
        
        uint256 eventIndex = tokenHistory[tokenId].length;
        tokenHistory[tokenId].push(newEvent);
        
        // ✅ NEW: Update statistics
        eventTypeCount[eventType]++;
        totalEventsRecorded++;
        
        emit HistoryRecorded(tokenId, eventType, eventIndex);
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
        
        // ✅ NEW: Update statistics
        eventTypeCount[eventType]++;
        totalEventsRecorded++;
        
        emit HistoryRecorded(tokenId, eventType, eventIndex);
    }

    /**
     * @dev Register replication event
     */
    function registerReplication(uint256 parentId, uint256 childId) external onlyHistoryWriter {
        bytes32 eventType = EVENT_REPLICATE;
        tokenHistory[parentId].push(HistoricalEvent({
            timestamp: block.timestamp,
            eventType: eventType,
            actorAddress: msg.sender,
            eventData: abi.encode(childId),
            blockNumber: block.number
        }));
        
        // ✅ NEW: Update statistics
        eventTypeCount[eventType]++;
        totalEventsRecorded++;
        
        emit HistoryRecorded(parentId, eventType, tokenHistory[parentId].length - 1);
    }

    /**
     * @dev Register mutation event
     */
    function registerMutation(uint256 tokenId, string calldata mutationName) external onlyHistoryWriter {
        bytes32 eventType = EVENT_MUTATION;
        tokenHistory[tokenId].push(HistoricalEvent({
            timestamp: block.timestamp,
            eventType: eventType,
            actorAddress: msg.sender,
            eventData: abi.encode(mutationName),
            blockNumber: block.number
        }));
        
        // ✅ NEW: Update statistics
        eventTypeCount[eventType]++;
        totalEventsRecorded++;
        
        emit HistoryRecorded(tokenId, eventType, tokenHistory[tokenId].length - 1);
    }

    /**
     * @dev Register serum event
     */
    function registerSerum(uint256 tokenId, uint256 serumId) external onlyHistoryWriter {
        bytes32 eventType = EVENT_SERUM_USED;
        tokenHistory[tokenId].push(HistoricalEvent({
            timestamp: block.timestamp,
            eventType: eventType,
            actorAddress: msg.sender,
            eventData: abi.encode(serumId),
            blockNumber: block.number
        }));
        
        // ✅ NEW: Update statistics
        eventTypeCount[eventType]++;
        totalEventsRecorded++;
        
        emit HistoryRecorded(tokenId, eventType, tokenHistory[tokenId].length - 1);
    }

    /**
     * @dev Get history for a token
     */
    function getHistory(uint256 tokenId) external view returns (HistoricalEvent[] memory) {
        return tokenHistory[tokenId];
    }

    /**
     * @dev MISSING FUNCTION ADDED - Get events for token (required by AdrianLabView)
     */
    function getEventsForToken(uint256 tokenId) external view returns (HistoricalEvent[] memory) {
        return tokenHistory[tokenId];
    }

    /**
     * @dev Alternative interface for decomposed data (if needed by other contracts)
     */
    function getTokenEventData(uint256 tokenId) external view returns (
        bytes32[] memory eventTypes,
        uint256[] memory timestamps,
        address[] memory actors,
        bytes[] memory eventData,
        uint256[] memory blockNumbers
    ) {
        HistoricalEvent[] memory events = tokenHistory[tokenId];
        uint256 length = events.length;
        
        eventTypes = new bytes32[](length);
        timestamps = new uint256[](length);
        actors = new address[](length);
        eventData = new bytes[](length);
        blockNumbers = new uint256[](length);
        
        for (uint256 i = 0; i < length; i++) {
            eventTypes[i] = events[i].eventType;
            timestamps[i] = events[i].timestamp;
            actors[i] = events[i].actorAddress;
            eventData[i] = events[i].eventData;
            blockNumbers[i] = events[i].blockNumber;
        }
    }

    // =============== NEW: Event Statistics Functions ===============

    /**
     * @dev Get count of specific event type across all tokens
     */
    function getEventTypeCount(bytes32 eventType) external view returns (uint256) {
        return eventTypeCount[eventType];
    }

    /**
     * @dev Get total events recorded across all tokens
     */
    function getTotalEventsRecorded() external view returns (uint256) {
        return totalEventsRecorded;
    }

    /**
     * @dev Get statistics for all new event types
     */
    function getPhase1EventStats() external view returns (
        uint256 skinUpdated,
        uint256 mutationSkinApplied,
        uint256 maxSupplyUpdated,
        uint256 freePackClaimed,
        uint256 packPricingSet,
        uint256 specialSkinApplied
    ) {
        return (
            eventTypeCount[EVENT_SKIN_UPDATED],
            eventTypeCount[EVENT_MUTATION_SKIN_APPLIED],
            eventTypeCount[EVENT_MAX_SUPPLY_UPDATED],
            eventTypeCount[EVENT_FREE_PACK_CLAIMED],
            eventTypeCount[EVENT_PACK_PRICING_SET],
            eventTypeCount[EVENT_SPECIAL_SKIN_APPLIED]
        );
    }

    /**
     * @dev Get serum-related event statistics
     */
    function getSerumEventStats() external view returns (
        uint256 serumUsed,
        uint256 serumSuccess,
        uint256 serumFailed,
        uint256 serumRegistered,
        uint256 serumUpdated
    ) {
        return (
            eventTypeCount[EVENT_SERUM_USED],
            eventTypeCount[EVENT_SERUM_MUTATION_SUCCESS],
            eventTypeCount[EVENT_SERUM_MUTATION_FAILED],
            eventTypeCount[EVENT_SERUM_REGISTERED],
            eventTypeCount[EVENT_SERUM_UPDATED]
        );
    }

    // =============== Admin Functions ===============

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
        // ✅ NEW: Subtract from statistics before deleting
        HistoricalEvent[] memory events = tokenHistory[tokenId];
        for (uint256 i = 0; i < events.length; i++) {
            if (eventTypeCount[events[i].eventType] > 0) {
                eventTypeCount[events[i].eventType]--;
            }
            if (totalEventsRecorded > 0) {
                totalEventsRecorded--;
            }
        }
        
        delete tokenHistory[tokenId];
    }

    /**
     * @dev Bulk authorize history writers
     */
    function bulkSetHistoryWriters(address[] calldata writers, bool authorized) external onlyOwner {
        for (uint256 i = 0; i < writers.length; i++) {
            historyWriters[writers[i]] = authorized;
            emit HistoryWriterUpdated(writers[i], authorized);
        }
    }

    /**
     * @dev Get total events across all tokens (UPDATED with actual count)
     */
    function getTotalEvents() external view returns (uint256 total) {
        return totalEventsRecorded;
    }

    /**
     * @dev Check if address is authorized history writer
     */
    function isHistoryWriter(address writer) external view returns (bool) {
        return writer == owner() || historyWriters[writer];
    }

    /**
     * @dev Get events by type for a token
     */
    function getEventsByType(uint256 tokenId, bytes32 eventType) external view returns (HistoricalEvent[] memory) {
        HistoricalEvent[] memory allEvents = tokenHistory[tokenId];
        uint256 count = 0;
        
        // Count matching events
        for (uint256 i = 0; i < allEvents.length; i++) {
            if (allEvents[i].eventType == eventType) {
                count++;
            }
        }
        
        // Create result array
        HistoricalEvent[] memory matchingEvents = new HistoricalEvent[](count);
        uint256 index = 0;
        
        for (uint256 i = 0; i < allEvents.length; i++) {
            if (allEvents[i].eventType == eventType) {
                matchingEvents[index] = allEvents[i];
                index++;
            }
        }
        
        return matchingEvents;
    }

    /**
     * @dev Get latest event for a token
     */
    function getLatestEvent(uint256 tokenId) external view returns (HistoricalEvent memory) {
        require(tokenHistory[tokenId].length > 0, "No events for token");
        return tokenHistory[tokenId][tokenHistory[tokenId].length - 1];
    }

    /**
     * @dev Check if token has specific event type
     */
    function hasEventType(uint256 tokenId, bytes32 eventType) external view returns (bool) {
        HistoricalEvent[] memory events = tokenHistory[tokenId];
        for (uint256 i = 0; i < events.length; i++) {
            if (events[i].eventType == eventType) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev ✅ NEW: Reset event statistics (emergency function)
     */
    function resetEventStatistics() external onlyOwner {
        // Reset all new event types
        eventTypeCount[EVENT_SKIN_UPDATED] = 0;
        eventTypeCount[EVENT_MUTATION_SKIN_APPLIED] = 0;
        eventTypeCount[EVENT_MAX_SUPPLY_UPDATED] = 0;
        eventTypeCount[EVENT_FREE_PACK_CLAIMED] = 0;
        eventTypeCount[EVENT_PACK_PRICING_SET] = 0;
        eventTypeCount[EVENT_SPECIAL_SKIN_APPLIED] = 0;
        eventTypeCount[EVENT_SERUM_MUTATION_SUCCESS] = 0;
        eventTypeCount[EVENT_SERUM_MUTATION_FAILED] = 0;
        eventTypeCount[EVENT_SERUM_REGISTERED] = 0;
        eventTypeCount[EVENT_SERUM_UPDATED] = 0;
        
        totalEventsRecorded = 0;
    }

    // =============== NEW: Helper Functions for Phase 1 Events (MOVED AFTER hasEventType) ===============

    /**
     * @dev Check if token has skin-related events
     */
    function hasSkinEvents(uint256 tokenId) external view returns (bool) {
        return this.hasEventType(tokenId, EVENT_SKIN_UPDATED) || 
               this.hasEventType(tokenId, EVENT_MUTATION_SKIN_APPLIED) ||
               this.hasEventType(tokenId, EVENT_SPECIAL_SKIN_APPLIED);
    }

    /**
     * @dev Check if token has mutation events (any type)
     */
    function hasMutationEvents(uint256 tokenId) external view returns (bool) {
        return this.hasEventType(tokenId, EVENT_MUTATION) || 
               this.hasEventType(tokenId, EVENT_SERUM_MUTATION) ||
               this.hasEventType(tokenId, EVENT_SERUM_MUTATION_SUCCESS) ||
               this.hasEventType(tokenId, EVENT_MUTATION_SKIN_APPLIED);
    }

    /**
     * @dev Get most recent skin event for token
     */
    function getLatestSkinEvent(uint256 tokenId) external view returns (
        HistoricalEvent memory latestEvent,
        bool hasSkinEvent
    ) {
        HistoricalEvent[] memory events = tokenHistory[tokenId];
        
        for (uint256 i = events.length; i > 0; i--) {
            bytes32 eventType = events[i-1].eventType;
            if (eventType == EVENT_SKIN_UPDATED || 
                eventType == EVENT_MUTATION_SKIN_APPLIED ||
                eventType == EVENT_SPECIAL_SKIN_APPLIED) {
                return (events[i-1], true);
            }
        }
        
        return (HistoricalEvent(0, bytes32(0), address(0), "", 0), false);
    }
}