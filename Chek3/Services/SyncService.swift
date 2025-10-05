//
//  SyncService.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import Foundation
import Combine

@MainActor
class SyncService: ObservableObject {
    static let shared = SyncService()
    
    @Published var syncStatus: SyncStatus = .synced
    
    private let categoryRepository: CategoryRepository
    private let localStorageService: LocalStorageService
    private var pendingOperations: [PendingOperation] = []
    
    // Race condition protection and retry tracking
    private var isSyncingPendingOperations = false
    private var operationRetryCount: [String: Int] = [:]
    private let maxRetries = 3
    
    private init() {
        self.categoryRepository = SupabaseCategoryRepository()
        self.localStorageService = LocalStorageService.shared
        
        // Listen to network changes
        NetworkMonitorService.shared.setConnectivityCallback { [weak self] isOnline in
            Task { @MainActor in
                await self?.handleNetworkChange(isOnline: isOnline)
            }
        }
    }
    
    // MARK: - Network Change Handling
    
    private func handleNetworkChange(isOnline: Bool) async {
        #if DEBUG
        print("🌐 SyncService: Network change detected - isOnline: \(isOnline), pending operations: \(pendingOperations.count)")
        #endif
        
        // If we just came back online and have pending operations, sync them
        if isOnline && !pendingOperations.isEmpty {
            #if DEBUG
            print("🔄 Network restored, syncing \(pendingOperations.count) pending operations")
            #endif
            await syncPendingOperations()
        }
        
        updateSyncStatusForNetworkChange(isOnline: isOnline)
    }
    
    private func updateSyncStatusForNetworkChange(isOnline: Bool) {
        // If we're currently syncing, don't change the status
        if case .syncing = syncStatus {
            #if DEBUG
            print("🔄 Currently syncing, keeping sync status unchanged")
            #endif
            return
        }
        
        if isOnline {
            // Just came online
            if !pendingOperations.isEmpty {
                syncStatus = .pending
                #if DEBUG
                print("📡 Online with \(pendingOperations.count) pending operations")
                #endif
            } else {
                syncStatus = .synced
                #if DEBUG
                print("✅ Online with no pending operations")
                #endif
            }
        } else {
            // Just went offline
            if !pendingOperations.isEmpty {
                syncStatus = .pending
                #if DEBUG
                print("📴 Offline with \(pendingOperations.count) pending operations")
                #endif
            } else {
                syncStatus = .synced
                #if DEBUG
                print("📴 Offline with no pending operations")
                #endif
            }
        }
    }
    
    // MARK: - Sync Operations
    
    func syncCreateCategory(_ category: Category, for userID: UUID) async {
        guard NetworkMonitorService.shared.isOnline else {
            // If offline, just queue the operation
            pendingOperations.append(.create(category))
            localStorageService.savePendingOperations(pendingOperations, for: userID)
            return
        }
        
        syncStatus = .syncing
        
        do {
            let syncedCategory = try await categoryRepository.createCategory(category)
            
            // Update local storage with synced timestamp
            updateLocalCategoryWithSyncTimestamp(syncedCategory, for: userID)
            
            syncStatus = .synced
        } catch {
            syncStatus = .error(error.localizedDescription)
            // Add to pending operations for retry
            pendingOperations.append(.create(category))
            localStorageService.savePendingOperations(pendingOperations, for: userID)
        }
    }
    
    func syncUpdateCategory(_ category: Category, for userID: UUID) async {
        guard NetworkMonitorService.shared.isOnline else {
            // If offline, just queue the operation
            pendingOperations.append(.update(category))
            localStorageService.savePendingOperations(pendingOperations, for: userID)
            return
        }
        
        syncStatus = .syncing
        
        do {
            let syncedCategory = try await categoryRepository.updateCategory(category, for: userID)
            
            // Update local storage with synced timestamp
            updateLocalCategoryWithSyncTimestamp(syncedCategory, for: userID)
            
            syncStatus = .synced
        } catch {
            syncStatus = .error(error.localizedDescription)
            // Add to pending operations for retry
            pendingOperations.append(.update(category))
            localStorageService.savePendingOperations(pendingOperations, for: userID)
        }
    }
    
    func syncDeleteCategory(id: UUID, for userID: UUID) async {
        guard NetworkMonitorService.shared.isOnline else {
            // If offline, just queue the operation
            pendingOperations.append(.delete(id, userID: userID))
            localStorageService.savePendingOperations(pendingOperations, for: userID)
            return
        }
        
        syncStatus = .syncing
        
        do {
            try await categoryRepository.deleteCategory(id: id, for: userID)
            syncStatus = .synced
        } catch {
            syncStatus = .error(error.localizedDescription)
            // Add to pending operations for retry
            pendingOperations.append(.delete(id, userID: userID))
            localStorageService.savePendingOperations(pendingOperations, for: userID)
        }
    }
    
    // MARK: - Pending Operations Sync
    
    func syncPendingOperations() async {
        // Prevent concurrent execution using async-safe approach
        guard !isSyncingPendingOperations && NetworkMonitorService.shared.isOnline && !pendingOperations.isEmpty else {
            return
        }
        
        isSyncingPendingOperations = true
        syncStatus = .syncing
        
        await processPendingOperationsAsync()
        
        isSyncingPendingOperations = false
    }
    
    private func processPendingOperationsAsync() async {
        let operations = pendingOperations
        var successfulOperations: [PendingOperation] = []
        
        for operation in operations {
            let key = operationKey(operation)
            let retries = operationRetryCount[key] ?? 0
            
            // Skip if max retries exceeded
            guard retries < maxRetries else {
                print("Max retries exceeded for operation: \(key)")
                successfulOperations.append(operation) // Remove from queue
                operationRetryCount.removeValue(forKey: key)
                continue
            }
            
            let success: Bool
            
            switch operation {
            case .create(let category):
                #if DEBUG
                print("🔄 SyncService: Processing pending create operation for category \(category.id)")
                #endif
                success = await syncCreateCategoryForPending(category, for: category.userID)
            case .update(let category):
                #if DEBUG
                print("🔄 SyncService: Processing pending update operation for category \(category.id)")
                #endif
                success = await syncUpdateCategoryForPending(category, for: category.userID)
            case .delete(let id, let userID):
                #if DEBUG
                print("🔄 SyncService: Processing pending delete operation for category \(id)")
                #endif
                success = await syncDeleteCategoryForPending(id: id, for: userID)
            }
            
            if success {
                successfulOperations.append(operation)
                operationRetryCount.removeValue(forKey: key)
            } else {
                operationRetryCount[key] = retries + 1
            }
            
            // Small delay between operations
            try? await Task.sleep(for: .milliseconds(100))
        }
        
        // Remove successful operations
        pendingOperations.removeAll { operation in
            successfulOperations.contains { successOp in
                operationKey(operation) == operationKey(successOp)
            }
        }
        
        #if DEBUG
        print("🔄 SyncService: Removed \(successfulOperations.count) successful operations. Remaining: \(pendingOperations.count)")
        #endif
        
        // Save updated pending operations
        if !successfulOperations.isEmpty {
            // Get userID from the first successful operation
            let userID = getUserIdFromOperation(successfulOperations.first!)
            localStorageService.savePendingOperations(pendingOperations, for: userID)
        }
        
        // Update sync status more accurately
        if pendingOperations.isEmpty {
            if NetworkMonitorService.shared.isOnline {
                syncStatus = .synced
            } else {
                // We're offline but no pending operations, so we're effectively synced
                syncStatus = .synced
            }
        } else {
            // Still have pending operations
            syncStatus = .pending
        }
        
        #if DEBUG
        print("🔄 Sync completed. Remaining pending: \(pendingOperations.count), Status: \(syncStatus)")
        #endif
    }
    
    // MARK: - Helper Methods
    
    private func updateLocalCategoryWithSyncTimestamp(_ syncedCategory: Category, for userID: UUID) {
        var localCategories = localStorageService.loadCategories(for: userID)
        if let index = localCategories.firstIndex(where: { $0.id == syncedCategory.id }) {
            localCategories[index] = Category(
                id: syncedCategory.id,
                userID: syncedCategory.userID,
                name: syncedCategory.name,
                income: syncedCategory.income,
                color: syncedCategory.color,
                isDefault: syncedCategory.isDefault,
                createdDate: syncedCategory.createdDate,
                lastEdited: syncedCategory.lastEdited,
                syncedAt: Date()
            )
            localStorageService.saveCategories(localCategories, for: userID)
        }
    }
    
    private func operationKey(_ operation: PendingOperation) -> String {
        switch operation {
        case .create(let category):
            return "create_\(category.id.uuidString)"
        case .update(let category):
            return "update_\(category.id.uuidString)"
        case .delete(let id, _):
            return "delete_\(id.uuidString)"
        }
    }
    
    private func getUserIdFromOperation(_ operation: PendingOperation) -> UUID {
        switch operation {
        case .create(let category):
            return category.userID
        case .update(let category):
            return category.userID
        case .delete(_, let userID):
            return userID
        }
    }
    
    private func syncCreateCategoryForPending(_ category: Category, for userID: UUID) async -> Bool {
        guard NetworkMonitorService.shared.isOnline else {
            return false // Will be retried later
        }
        
        do {
            let syncedCategory = try await categoryRepository.createCategory(category)
            
            // Update local storage with synced timestamp
            updateLocalCategoryWithSyncTimestamp(syncedCategory, for: userID)
            
            return true
        } catch {
            return false
        }
    }
    
    private func syncUpdateCategoryForPending(_ category: Category, for userID: UUID) async -> Bool {
        guard NetworkMonitorService.shared.isOnline else {
            return false // Will be retried later
        }
        
        do {
            let syncedCategory = try await categoryRepository.updateCategory(category, for: userID)
            
            // Update local storage with synced timestamp
            updateLocalCategoryWithSyncTimestamp(syncedCategory, for: userID)
            
            return true
        } catch {
            return false
        }
    }
    
    private func syncDeleteCategoryForPending(id: UUID, for userID: UUID) async -> Bool {
        guard NetworkMonitorService.shared.isOnline else {
            return false // Will be retried later
        }
        
        do {
            try await categoryRepository.deleteCategory(id: id, for: userID)
            #if DEBUG
            print("✅ SyncService: Successfully deleted category \(id) from remote")
            #endif
            return true
        } catch {
            #if DEBUG
            print("❌ SyncService: Failed to delete category \(id) from remote: \(error.localizedDescription)")
            #endif
            return false
        }
    }
    
    // MARK: - Remote Sync Helpers
    
    private func syncPendingOperationsToRemote(for userID: UUID) async {
        guard !pendingOperations.isEmpty else { return }
        
        #if DEBUG
        print("🔄 SyncService: Syncing \(pendingOperations.count) pending operations to remote")
        #endif
        
        let operations = pendingOperations
        var successfulOperations: [PendingOperation] = []
        
        for operation in operations {
            let success: Bool
            
            switch operation {
            case .create(let category):
                do {
                    let _ = try await categoryRepository.createCategory(category)
                    success = true
                    #if DEBUG
                    print("✅ SyncService: Synced pending create for category \(category.id)")
                    #endif
                } catch {
                    success = false
                    #if DEBUG
                    print("❌ SyncService: Failed to sync pending create for category \(category.id): \(error.localizedDescription)")
                    #endif
                }
            case .update(let category):
                do {
                    let _ = try await categoryRepository.updateCategory(category, for: userID)
                    success = true
                    #if DEBUG
                    print("✅ SyncService: Synced pending update for category \(category.id)")
                    #endif
                } catch {
                    success = false
                    #if DEBUG
                    print("❌ SyncService: Failed to sync pending update for category \(category.id): \(error.localizedDescription)")
                    #endif
                }
            case .delete(let id, let userID):
                do {
                    try await categoryRepository.deleteCategory(id: id, for: userID)
                    success = true
                    #if DEBUG
                    print("✅ SyncService: Synced pending delete for category \(id)")
                    #endif
                } catch {
                    success = false
                    #if DEBUG
                    print("❌ SyncService: Failed to sync pending delete for category \(id): \(error.localizedDescription)")
                    #endif
                }
            }
            
            if success {
                successfulOperations.append(operation)
            }
        }
        
        // Remove successful operations from pending list
        pendingOperations.removeAll { operation in
            successfulOperations.contains { successOp in
                operationKey(operation) == operationKey(successOp)
            }
        }
        
        // Save updated pending operations
        if !successfulOperations.isEmpty {
            localStorageService.savePendingOperations(pendingOperations, for: userID)
            #if DEBUG
            print("🔄 SyncService: Removed \(successfulOperations.count) successful operations, \(pendingOperations.count) remaining")
            #endif
        }
    }
    
    // MARK: - User Data Management
    
    func loadUserData(for userID: UUID) {
        pendingOperations = localStorageService.loadPendingOperations(for: userID)
        
        #if DEBUG
        print("🔄 SyncService: Loaded \(pendingOperations.count) pending operations for user \(userID)")
        for (index, operation) in pendingOperations.enumerated() {
            switch operation {
            case .create(let category):
                print("  \(index): CREATE category \(category.id)")
            case .update(let category):
                print("  \(index): UPDATE category \(category.id)")
            case .delete(let id, _):
                print("  \(index): DELETE category \(id)")
            }
        }
        #endif
        
        // Set initial sync status based on connectivity and pending operations
        if !NetworkMonitorService.shared.isOnline && !pendingOperations.isEmpty {
            syncStatus = .pending
        } else if !NetworkMonitorService.shared.isOnline {
            syncStatus = .synced
        } else {
            // Try to sync from remote if online
            Task {
                await syncFromRemote(for: userID)
            }
        }
    }
    
    func clearUserData(for userID: UUID) {
        pendingOperations.removeAll()
        syncStatus = .synced
        localStorageService.clearUserData(for: userID)
    }
    
    func syncFromRemote(for userID: UUID) async {
        guard NetworkMonitorService.shared.isOnline else { 
            // If offline, just show pending status if there are pending operations
            if !pendingOperations.isEmpty {
                syncStatus = .pending
            } else {
                syncStatus = .synced
            }
            return 
        }
        
        syncStatus = .syncing
        
        do {
            let remoteCategories = try await categoryRepository.fetchCategories(for: userID)
            let localCategories = localStorageService.loadCategories(for: userID)
            
            #if DEBUG
            print("🔄 SyncService: Starting sync - Remote: \(remoteCategories.count), Local: \(localCategories.count), Pending: \(pendingOperations.count)")
            print("🔄 SyncService: Local category IDs: \(localCategories.map { $0.id })")
            print("🔄 SyncService: Remote category IDs: \(remoteCategories.map { $0.id })")
            #endif
            
            // First, sync any pending operations to remote
            await syncPendingOperationsToRemote(for: userID)
            
            // Get updated remote data after syncing pending operations
            let updatedRemoteCategories = try await categoryRepository.fetchCategories(for: userID)
            
            // Get list of pending deletions to avoid resurrecting deleted categories
            let pendingDeletions = pendingOperations.compactMap { operation in
                if case .delete(let id, _) = operation {
                    return id
                }
                return nil
            }
            
            // Merge with local data, using lastEdited as source of truth
            var mergedCategories: [Category] = []
            var localCategoriesToUpdate: [Category] = []
            
            // Process remote categories
            for remoteCategory in updatedRemoteCategories {
                // Skip categories that are pending deletion
                if pendingDeletions.contains(remoteCategory.id) {
                    #if DEBUG
                    print("🔄 SyncService: Skipping remote category \(remoteCategory.id) - pending deletion")
                    #endif
                    continue
                }
                
                if let localCategory = localCategories.first(where: { $0.id == remoteCategory.id }) {
                    // Compare lastEdited timestamps
                    let localTime = localCategory.lastEdited
                    let remoteTime = remoteCategory.lastEdited
                    
                    #if DEBUG
                    print("🔍 SyncService: Comparing timestamps for category \(remoteCategory.id)")
                    print("🔍 SyncService: Local lastEdited: \(localTime)")
                    print("🔍 SyncService: Remote lastEdited: \(remoteTime)")
                    print("🔍 SyncService: Local > Remote: \(localTime > remoteTime)")
                    print("🔍 SyncService: Remote > Local: \(remoteTime > localTime)")
                    #endif
                    
                    if localTime > remoteTime {
                        // Local is newer - keep local and sync to remote
                        #if DEBUG
                        print("🔄 SyncService: Local category \(localCategory.id) is newer, keeping local")
                        #endif
                        mergedCategories.append(localCategory)
                        localCategoriesToUpdate.append(localCategory)
                    } else if remoteTime > localTime {
                        // Remote is newer - use remote
                        #if DEBUG
                        print("🔄 SyncService: Remote category \(remoteCategory.id) is newer, using remote")
                        #endif
                        mergedCategories.append(remoteCategory)
                    } else {
                        // Same timestamp - use remote (server is source of truth for conflicts)
                        #if DEBUG
                        print("🔄 SyncService: Same timestamp for category \(remoteCategory.id), using remote")
                        #endif
                        mergedCategories.append(remoteCategory)
                    }
                } else {
                    // New remote category - add it
                    #if DEBUG
                    print("🔄 SyncService: Adding new remote category \(remoteCategory.id)")
                    #endif
                    mergedCategories.append(remoteCategory)
                }
            }
            
            // Handle local categories that don't exist remotely
            for localCategory in localCategories {
                if !updatedRemoteCategories.contains(where: { $0.id == localCategory.id }) {
                    #if DEBUG
                    print("🔍 SyncService: Local category \(localCategory.id) not found in remote data")
                    print("🔍 SyncService: Pending deletions contains \(localCategory.id): \(pendingDeletions.contains(localCategory.id))")
                    #endif
                    
                    if pendingDeletions.contains(localCategory.id) {
                        // Local category is pending deletion - skip it (don't add to merged)
                        #if DEBUG
                        print("🔄 SyncService: Skipping local category \(localCategory.id) - pending deletion")
                        #endif
                    } else {
                        // Check if this category is in pending operations (truly new)
                        let isInPendingOperations = pendingOperations.contains { operation in
                            switch operation {
                            case .create(let cat), .update(let cat):
                                return cat.id == localCategory.id
                            case .delete(let id, _):
                                return id == localCategory.id
                            }
                        }
                        
                        if isInPendingOperations {
                            // This is a new local category that's pending sync - add it
                            #if DEBUG
                            print("🔄 SyncService: Adding new local category \(localCategory.id) - in pending operations")
                            #endif
                            mergedCategories.append(localCategory)
                            localCategoriesToUpdate.append(localCategory)
                        } else {
                            // This category is not in pending operations and doesn't exist remotely
                            // This means it was deleted remotely - remove from local
                            #if DEBUG
                            print("🗑️ SyncService: Category \(localCategory.id) was deleted remotely - removing from local")
                            #endif
                            // Don't add to mergedCategories - this effectively deletes it locally
                        }
                    }
                }
            }
            
            // Save merged categories
            localStorageService.saveCategories(mergedCategories, for: userID)
            
            #if DEBUG
            print("🔄 SyncService: Saved \(mergedCategories.count) merged categories to local storage")
            for category in mergedCategories {
                print("  - Category \(category.id): \(category.name) (lastEdited: \(category.lastEdited))")
            }
            #endif
            
            // Sync local changes that are newer to remote
            for category in localCategoriesToUpdate {
                do {
                    if updatedRemoteCategories.contains(where: { $0.id == category.id }) {
                        // Update existing remote category
                        let _ = try await categoryRepository.updateCategory(category, for: userID)
                        #if DEBUG
                        print("✅ SyncService: Updated remote category \(category.id)")
                        #endif
                    } else {
                        // Create new remote category
                        let _ = try await categoryRepository.createCategory(category)
                        #if DEBUG
                        print("✅ SyncService: Created remote category \(category.id)")
                        #endif
                    }
                    
                    // Category successfully synced
                } catch {
                    #if DEBUG
                    print("❌ SyncService: Failed to sync local category \(category.id): \(error.localizedDescription)")
                    #endif
                    // Add back to pending operations for retry
                    if updatedRemoteCategories.contains(where: { $0.id == category.id }) {
                        pendingOperations.append(.update(category))
                    } else {
                        pendingOperations.append(.create(category))
                    }
                }
            }
            
            // Sync completed
            
            // Save any new pending operations
            if !localCategoriesToUpdate.isEmpty {
                localStorageService.savePendingOperations(pendingOperations, for: userID)
            }
            
            syncStatus = .synced
            
            #if DEBUG
            print("✅ SyncService: Sync completed - Final categories: \(mergedCategories.count)")
            #endif
            
        } catch {
            syncStatus = .error(error.localizedDescription)
            #if DEBUG
            print("❌ SyncService: Sync failed: \(error.localizedDescription)")
            #endif
        }
    }
    
    func addPendingOperation(_ operation: PendingOperation, for userID: UUID) {
        pendingOperations.append(operation)
        localStorageService.savePendingOperations(pendingOperations, for: userID)
    }
}
