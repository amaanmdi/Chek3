//
//  SyncTemplate.swift
//  Chek3
//
//  Created by Amaan Mahdi on 05/10/2025.
//

import Foundation

/*
 
 SYNC SERVICE TEMPLATE FOR NEW DATA MODELS
 =========================================
 
 This template shows how to create a sync service for any new data model.
 Follow these steps to add sync functionality to a new entity:
 
 1. Create your data model (e.g., Transaction, Budget, etc.)
 2. Make sure it has these properties:
    - id: UUID (for Identifiable)
    - userID: UUID
    - lastEdited: Date
    - syncedAt: Date?
    - Conforms to Codable, Identifiable, Equatable
 
 3. Create a repository protocol and implementation (follow CategoryRepository pattern)
 4. Add methods to LocalStorageService for your entity
 5. Create sync helper classes (follow Category pattern)
 6. Create a sync service (follow CategorySyncService pattern)
 
 EXAMPLE IMPLEMENTATION:
 
 // 1. Data Model
 struct Transaction: Codable, Identifiable, Equatable {
     let id: UUID
     let userID: UUID
     var amount: Double
     var description: String
     var lastEdited: Date
     var syncedAt: Date?
 }
 
 // 2. Repository Protocol
 protocol TransactionRepository {
     func fetchTransactions(for userID: UUID) async throws -> [Transaction]
     func createTransaction(_ transaction: Transaction) async throws -> Transaction
     func updateTransaction(_ transaction: Transaction, for userID: UUID) async throws -> Transaction
     func deleteTransaction(id: UUID, for userID: UUID) async throws
 }
 
 // 3. Add to LocalStorageService
 func saveTransactions(_ transactions: [Transaction], for userID: UUID) { ... }
 func loadTransactions(for userID: UUID) -> [Transaction] { ... }
 
 // 4. Create sync helpers (TransactionConflictResolver, TransactionPendingOperationsManager, etc.)
 // 5. Create TransactionSyncService following the exact same pattern as CategorySyncService
 
 BENEFITS OF THIS APPROACH:
 - ✅ Maintains backwards compatibility
 - ✅ Follows established patterns
 - ✅ Easy to implement for new models
 - ✅ No complex generics or protocols
 - ✅ Clear separation of concerns
 - ✅ Easy to test and debug
 
 */

// MARK: - Sync Helper Template Classes

/*
 
 Copy these template classes and replace "Entity" with your model name (e.g., Transaction)
 
 */

/*
class EntityConflictResolver {
    func resolveConflict(local: Entity, remote: Entity) -> Entity {
        let localTime = local.lastEdited
        let remoteTime = remote.lastEdited
        
        if localTime > remoteTime {
            return local
        } else if remoteTime > localTime {
            return remote
        } else {
            return local
        }
    }
    
    func shouldKeepLocalEntity(
        _ localEntity: Entity,
        pendingOperations: [PendingOperation],
        pendingDeletions: Set<UUID>
    ) -> Bool {
        if pendingDeletions.contains(localEntity.id) {
            return false
        }
        
        let isInPendingOperations = pendingOperations.contains { operation in
            switch operation {
            case .create(let entity), .update(let entity):
                return entity.id == localEntity.id
            }
        }
        
        return isInPendingOperations
    }
}

class EntityPendingOperationsManager {
    private var pendingOperations: [PendingOperation] = []
    private var operationRetryCount: [String: Int] = [:]
    private let maxRetries = 3
    private let localStorageService: LocalStorageService
    
    init(localStorageService: LocalStorageService = .shared) {
        self.localStorageService = localStorageService
    }
    
    var operations: [PendingOperation] { pendingOperations }
    var hasOperations: Bool { !pendingOperations.isEmpty }
    
    func addOperation(_ operation: PendingOperation, for userID: UUID) {
        pendingOperations.append(operation)
        localStorageService.savePendingOperations(pendingOperations, for: userID)
    }
    
    func loadOperations(for userID: UUID) -> [PendingOperation] {
        pendingOperations = localStorageService.loadPendingOperations(for: userID)
        return pendingOperations
    }
    
    func clearOperations(for userID: UUID) {
        pendingOperations.removeAll()
        operationRetryCount.removeAll()
        localStorageService.savePendingOperations(pendingOperations, for: userID)
    }
    
    // ... rest of the methods follow the same pattern as PendingOperationsManager
}

class EntitySyncCoordinator {
    private let repository: EntityRepository
    private let localStorageService: LocalStorageService
    
    init(repository: EntityRepository = SupabaseEntityRepository(),
         localStorageService: LocalStorageService = .shared) {
        self.repository = repository
        self.localStorageService = localStorageService
    }
    
    func syncCreateEntity(_ entity: Entity, for userID: UUID) async -> Entity? {
        do {
            let syncedEntity = try await repository.createEntity(entity)
            updateLocalEntityWithSyncTimestamp(syncedEntity, for: userID)
            return syncedEntity
        } catch {
            return nil
        }
    }
    
    // ... rest of the methods follow the same pattern as SyncCoordinator
}

@MainActor
class EntitySyncService: ObservableObject {
    static let shared = EntitySyncService()
    
    @Published var syncStatus: SyncStatus = .synced
    
    private let conflictResolver = EntityConflictResolver()
    private let pendingOperationsManager: EntityPendingOperationsManager
    private let syncCoordinator: EntitySyncCoordinator
    private let localStorageService = LocalStorageService.shared
    
    private var isSyncingPendingOperations = false
    
    private init() {
        self.pendingOperationsManager = EntityPendingOperationsManager()
        self.syncCoordinator = EntitySyncCoordinator()
        
        NetworkMonitorService.shared.setConnectivityCallback { [weak self] isOnline in
            Task { @MainActor in
                await self?.handleNetworkChange(isOnline: isOnline)
            }
        }
    }
    
    // ... rest of the implementation follows the exact same pattern as SyncService
    
    func syncCreateEntity(_ entity: Entity, for userID: UUID) async {
        // Implementation follows same pattern as syncCreateCategory
    }
    
    func syncUpdateEntity(_ entity: Entity, for userID: UUID) async {
        // Implementation follows same pattern as syncUpdateCategory
    }
    
    
    // ... all other methods follow the same pattern
}
 
*/
