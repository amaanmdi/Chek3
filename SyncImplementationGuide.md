# Offline-First Sync Implementation Guide

## Overview

This document describes a robust offline-first synchronization system designed for mobile applications with intermittent connectivity. The implementation ensures data consistency, handles conflicts gracefully, and provides seamless user experience regardless of network availability.

## Core Philosophy

### 1. **Offline-First Architecture**
- All operations work offline by default
- Data is immediately available to users regardless of connectivity
- Network operations are treated as sync operations, not primary operations

### 2. **Client Wins Conflict Resolution**
- When timestamps are equal, client data takes precedence
- Prevents accidental data loss from network issues
- Maintains user confidence in their data

### 3. **Timestamp-Based Synchronization**
- Uses `lastEdited` timestamps as the source of truth
- Simple, predictable conflict resolution
- No complex vector clocks or CRDTs required

### 4. **Graceful Degradation**
- App remains fully functional offline
- Network issues don't break user workflows
- Automatic retry with exponential backoff

## Architecture Components

### 1. **SyncService** (Main Orchestrator)
- **Purpose**: Central coordination point for all sync operations
- **Responsibilities**:
  - Network connectivity monitoring
  - Sync status management
  - Operation queuing and retry logic
  - User data lifecycle management

```swift
@MainActor
class SyncService: ObservableObject {
    @Published var syncStatus: SyncStatus = .synced
    
    private let conflictResolver = ConflictResolver()
    private let pendingOperationsManager: PendingOperationsManager
    private let syncCoordinator: SyncCoordinator
    private var isSyncingPendingOperations = false
}
```

### 2. **SyncCoordinator** (Network Operations)
- **Purpose**: Handles individual sync operations with remote server
- **Responsibilities**:
  - CRUD operations with remote API
  - Local storage updates after successful sync
  - Error handling and logging

```swift
class SyncCoordinator {
    func syncCreateCategory(_ category: Category, for userID: UUID) async -> Category?
    func syncUpdateCategory(_ category: Category, for userID: UUID) async -> Category?
    func fetchRemoteCategories(for userID: UUID) async -> [Category]?
}
```

### 3. **ConflictResolver** (Data Consistency)
- **Purpose**: Resolves conflicts between local and remote data
- **Strategy**: Timestamp-based with client preference
- **Logic**:
  - `local.lastEdited > remote.lastEdited` → Keep local
  - `remote.lastEdited > local.lastEdited` → Keep remote  
  - `local.lastEdited == remote.lastEdited` → Keep local (client wins)

```swift
class ConflictResolver {
    func resolveConflict(local: Category, remote: Category) -> Category {
        let localTime = local.lastEdited
        let remoteTime = remote.lastEdited
        
        if localTime > remoteTime {
            return local  // Client wins
        } else if remoteTime > localTime {
            return remote // Server wins
        } else {
            return local  // Client wins ties
        }
    }
}
```

### 4. **PendingOperationsManager** (Queue Management)
- **Purpose**: Manages offline operation queue with retry logic
- **Features**:
  - Persistent storage of pending operations
  - Retry counting with max limit (3 retries)
  - Operation deduplication
  - User-scoped operation isolation

```swift
class PendingOperationsManager {
    private var pendingOperations: [PendingOperation] = []
    private var operationRetryCount: [String: Int] = [:]
    private let maxRetries = 3
    
    func addOperation(_ operation: PendingOperation, for userID: UUID)
    func hasExceededMaxRetries(_ operation: PendingOperation) -> Bool
    func incrementRetryCount(_ operation: PendingOperation)
}
```

## Data Model Requirements

### Essential Properties
Every syncable entity must include these properties:

```swift
struct Entity: Codable, Identifiable, Equatable {
    let id: UUID                    // Unique identifier
    let userID: UUID               // User isolation
    var lastEdited: Date           // Conflict resolution timestamp
    var syncedAt: Date?            // Last successful sync timestamp
    
    // ... your entity-specific properties
}
```

### Pending Operation Types
```swift
enum PendingOperation: Codable, Equatable {
    case create(Entity)
    case update(Entity)  
}
```

### Sync Status Tracking
```swift
enum SyncStatus {
    case synced      // All data synchronized
    case syncing     // Currently syncing
    case pending     // Has pending operations
    case error(String) // Sync error occurred
}
```

## Sync Flow Logic

### 1. **Online Operations**
```
User Action → Immediate Local Update → Sync to Remote → Update Local with Server Response
```

### 2. **Offline Operations**
```
User Action → Immediate Local Update → Queue Operation → Wait for Network
```

### 3. **Network Restoration**
```
Network Available → Process Pending Queue → Resolve Conflicts → Update Local Storage
```

### 4. **Full Sync Process**
```
1. Fetch Remote Data
2. Sync Pending Operations to Remote
3. Fetch Updated Remote Data  
4. Merge Local and Remote Data (with conflict resolution)
5. Save Merged Data Locally
6. Sync Local Changes Back to Remote
7. Update Sync Status
```

## Implementation Steps

### Step 1: Create Data Model
```swift
struct YourEntity: Codable, Identifiable, Equatable {
    let id: UUID
    let userID: UUID
    var lastEdited: Date
    var syncedAt: Date?
    // ... your properties
}
```

### Step 2: Create Repository Protocol
```swift
protocol YourEntityRepository {
    func fetchEntities(for userID: UUID) async throws -> [YourEntity]
    func createEntity(_ entity: YourEntity) async throws -> YourEntity
    func updateEntity(_ entity: YourEntity, for userID: UUID) async throws -> YourEntity
    func deleteEntity(id: UUID, for userID: UUID) async throws
}
```

### Step 3: Implement Sync Helpers
- **ConflictResolver**: Timestamp-based conflict resolution
- **PendingOperationsManager**: Operation queue with retry logic
- **SyncCoordinator**: Network operations coordination

### Step 4: Create Sync Service
- Follow the exact pattern from `SyncService`
- Implement all CRUD sync methods
- Add network change handling
- Include pending operations processing

### Step 5: Add Local Storage Methods
```swift
// In LocalStorageService
func saveEntities(_ entities: [YourEntity], for userID: UUID)
func loadEntities(for userID: UUID) -> [YourEntity]
func savePendingOperations(_ operations: [PendingOperation], for userID: UUID)
func loadPendingOperations(for userID: UUID) -> [PendingOperation]
```

## Key Implementation Details

### Race Condition Prevention
```swift
private var isSyncingPendingOperations = false

func syncPendingOperations() async {
    guard !isSyncingPendingOperations && NetworkMonitorService.shared.isOnline else {
        return
    }
    
    isSyncingPendingOperations = true
    // ... sync logic
    isSyncingPendingOperations = false
}
```

### Network Change Handling
```swift
NetworkMonitorService.shared.setConnectivityCallback { [weak self] isOnline in
    Task { @MainActor in
        await self?.handleNetworkChange(isOnline: isOnline)
    }
}
```

### Retry Logic with Exponential Backoff
- Max 3 retries per operation
- Operations exceeding retry limit are removed from queue
- Small delay between operations (100ms) to prevent API overload

### User Data Isolation
- All operations are scoped to `userID`
- Pending operations are stored per user
- Local storage is partitioned by user

## Error Handling Strategy

### 1. **Network Errors**
- Operations queued for retry
- User sees pending status
- Automatic retry on network restoration

### 2. **Sync Failures**
- Failed operations added to pending queue
- Retry with exponential backoff
- Max retry limit prevents infinite loops

### 3. **Data Conflicts**
- Timestamp-based resolution
- Client wins on ties
- No data loss scenarios

## Performance Considerations

### 1. **Batch Operations**
- Process pending operations in sequence
- Small delays between operations
- Avoid overwhelming the server

### 2. **Efficient Merging**
- Use Set operations for pending deletions
- Minimize unnecessary network calls
- Cache remote data during sync

### 3. **Memory Management**
- Clear old pending operations after success
- Limit retry counts to prevent memory leaks
- Use weak references in callbacks

## Testing Strategy

### 1. **Unit Tests**
- Conflict resolution logic
- Pending operations management
- Network error scenarios

### 2. **Integration Tests**
- Full sync flows
- Network connectivity changes
- Multiple user scenarios

### 3. **Edge Cases**
- Clock skew between devices
- Concurrent modifications
- Network interruptions during sync

## Benefits of This Approach

### ✅ **Reliability**
- Works offline seamlessly
- No data loss scenarios
- Automatic retry mechanisms

### ✅ **Simplicity**
- Timestamp-based conflicts (no CRDTs)
- Clear separation of concerns
- Easy to understand and debug

### ✅ **Performance**
- Immediate local updates
- Efficient conflict resolution
- Minimal network overhead

### ✅ **Scalability**
- User-scoped operations
- Template-based for new entities
- No complex state machines

### ✅ **User Experience**
- Always responsive interface
- Clear sync status indicators
- No blocking operations

## Template for New Entities

The `SyncTemplate.swift` file provides complete templates for implementing sync for new data models. Simply:

1. Replace "Entity" with your model name
2. Follow the exact patterns shown
3. Add repository implementation
4. Integrate with existing `SyncService`

This approach ensures consistency across all syncable entities while maintaining the robustness and reliability of the offline-first architecture.
