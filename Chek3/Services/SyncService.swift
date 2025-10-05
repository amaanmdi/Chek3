//
//  SyncService.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import Foundation
import Combine
import Auth

extension Notification.Name {
    static let syncDataUpdated = Notification.Name("syncDataUpdated")
}

@MainActor
class SyncService: ObservableObject {
    static let shared = SyncService()
    
    @Published var syncStatus: SyncStatus = .synced
    
    // Helper classes for focused responsibilities
    private let conflictResolver = ConflictResolver()
    private let pendingOperationsManager: PendingOperationsManager
    private let syncCoordinator: SyncCoordinator
    private let localStorageService = LocalStorageService.shared
    
    // Race condition protection
    private var isSyncingPendingOperations = false
    
    private init() {
        self.pendingOperationsManager = PendingOperationsManager()
        self.syncCoordinator = SyncCoordinator()
        
        // Listen to network changes
        NetworkMonitorService.shared.setConnectivityCallback { [weak self] isOnline in
            Task { @MainActor in
                await self?.handleNetworkChange(isOnline: isOnline)
            }
        }
    }
    
    // MARK: - Network Change Handling
    
    private func handleNetworkChange(isOnline: Bool) async {
        // If we just came back online, perform full sync to validate/amend local data
        if isOnline {
            #if DEBUG
            print("🔄 SyncService: Network restored, performing full sync to validate local data")
            #endif
            
            // Get current user ID and perform full sync
            if let currentUser = AuthService.shared.currentUser {
                await syncFromRemote(for: currentUser.id)
            }
        }
        
        updateSyncStatusForNetworkChange(isOnline: isOnline)
    }
    
    private func updateSyncStatusForNetworkChange(isOnline: Bool) {
        // If we're currently syncing, don't change the status
        if case .syncing = syncStatus {
            return
        }
        
        if isOnline {
            // Just came online - check if we need to sync
            if pendingOperationsManager.hasOperations {
                syncStatus = .pending
                #if DEBUG
                print("🌐 SyncService: Came online with pending operations - Status: .pending")
                #endif
            } else {
                // No pending operations - we're already synced
                syncStatus = .synced
                #if DEBUG
                print("🌐 SyncService: Came online with no pending operations - Status: .synced")
                #endif
            }
        } else {
            // Just went offline - local data is now source of truth
            if pendingOperationsManager.hasOperations {
                syncStatus = .pending
                #if DEBUG
                print("🌐 SyncService: Went offline with pending operations - Status: .pending")
                #endif
            } else {
                // No pending operations - local data is authoritative while offline
                syncStatus = .synced
                #if DEBUG
                print("🌐 SyncService: Went offline with no pending operations - Status: .synced")
                #endif
            }
        }
    }
    
    // MARK: - Sync Operations
    
    func syncCreateCategory(_ category: Category, for userID: UUID) async {
        guard NetworkMonitorService.shared.isOnline else {
            // If offline, just queue the operation
            pendingOperationsManager.addOperation(.create(category), for: userID)
            return
        }
        
        syncStatus = .syncing
        
        if await syncCoordinator.syncCreateCategory(category, for: userID) != nil {
            // Only set as synced if no other pending operations exist
            if !pendingOperationsManager.hasOperations {
                syncStatus = .synced
            } else {
                syncStatus = .pending
            }
        } else {
            syncStatus = .error("Failed to sync category creation")
            // Add to pending operations for retry
            pendingOperationsManager.addOperation(.create(category), for: userID)
        }
    }
    
    func syncUpdateCategory(_ category: Category, for userID: UUID) async {
        guard NetworkMonitorService.shared.isOnline else {
            // If offline, just queue the operation
            pendingOperationsManager.addOperation(.update(category), for: userID)
            return
        }
        
        syncStatus = .syncing
        
        if await syncCoordinator.syncUpdateCategory(category, for: userID) != nil {
            // Only set as synced if no other pending operations exist
            if !pendingOperationsManager.hasOperations {
                syncStatus = .synced
            } else {
                syncStatus = .pending
            }
        } else {
            syncStatus = .error("Failed to sync category update")
            // Add to pending operations for retry
            pendingOperationsManager.addOperation(.update(category), for: userID)
        }
    }
    
    
    // MARK: - Pending Operations Sync
    
    func syncPendingOperations() async {
        // Prevent concurrent execution using async-safe approach
        guard !isSyncingPendingOperations && NetworkMonitorService.shared.isOnline && pendingOperationsManager.hasOperations else {
            return
        }
        
        isSyncingPendingOperations = true
        syncStatus = .syncing
        
        await processPendingOperationsAsync()
        
        isSyncingPendingOperations = false
    }
    
    private func processPendingOperationsAsync() async {
        let operations = pendingOperationsManager.operations
        var successfulOperations: [PendingOperation] = []
        
        for operation in operations {
            // Skip if max retries exceeded
            guard !pendingOperationsManager.hasExceededMaxRetries(operation) else {
                print("Max retries exceeded for operation")
                successfulOperations.append(operation) // Remove from queue
                pendingOperationsManager.removeRetryCount(operation)
                continue
            }
            
            let success: Bool
            
            switch operation {
            case .create(let category):
                success = await syncCreateCategoryForPending(category, for: category.userID)
            case .update(let category):
                success = await syncUpdateCategoryForPending(category, for: category.userID)
            }
            
            if success {
                successfulOperations.append(operation)
                pendingOperationsManager.removeRetryCount(operation)
            } else {
                pendingOperationsManager.incrementRetryCount(operation)
            }
            
            // Small delay between operations
            try? await Task.sleep(for: .milliseconds(100))
        }
        
        // Remove successful operations
        if !successfulOperations.isEmpty {
            let userID = pendingOperationsManager.getUserIdFromOperation(successfulOperations.first!)
            pendingOperationsManager.removeSuccessfulOperations(successfulOperations, for: userID)
        }
        
        // Update sync status more accurately
        if !pendingOperationsManager.hasOperations {
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
        print("🔄 SyncService: Sync completed - Status: \(syncStatus)")
        #endif
    }
    
    
    private func syncCreateCategoryForPending(_ category: Category, for userID: UUID) async -> Bool {
        guard NetworkMonitorService.shared.isOnline else {
            return false // Will be retried later
        }
        
        return await syncCoordinator.syncCreateCategory(category, for: userID) != nil
    }
    
    private func syncUpdateCategoryForPending(_ category: Category, for userID: UUID) async -> Bool {
        guard NetworkMonitorService.shared.isOnline else {
            return false // Will be retried later
        }
        
        return await syncCoordinator.syncUpdateCategory(category, for: userID) != nil
    }
    
    
    // MARK: - Remote Sync Helpers
    
    private func syncPendingOperationsToRemote(for userID: UUID) async {
        guard pendingOperationsManager.hasOperations else { return }
        
        #if DEBUG
        print("🔄 SyncService: Syncing \(pendingOperationsManager.operations.count) pending operations to remote")
        #endif
        
        let operations = pendingOperationsManager.operations
        var successfulOperations: [PendingOperation] = []
        
        for operation in operations {
            let success: Bool
            
            switch operation {
            case .create(let category):
                success = await syncCoordinator.syncCreateCategory(category, for: userID) != nil
            case .update(let category):
                success = await syncCoordinator.syncUpdateCategory(category, for: userID) != nil
            }
            
            if success {
                successfulOperations.append(operation)
            }
        }
        
        // Remove successful operations from pending list
        if !successfulOperations.isEmpty {
            pendingOperationsManager.removeSuccessfulOperations(successfulOperations, for: userID)
            #if DEBUG
            print("🔄 SyncService: Removed \(successfulOperations.count) successful operations, \(pendingOperationsManager.operations.count) remaining")
            #endif
        }
    }
    
    // MARK: - User Data Management
    
    func loadUserData(for userID: UUID) {
        _ = pendingOperationsManager.loadOperations(for: userID)
        
        // Set initial sync status based on connectivity and pending operations
        if !NetworkMonitorService.shared.isOnline && pendingOperationsManager.hasOperations {
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
        pendingOperationsManager.clearOperations(for: userID)
        syncStatus = .synced
        localStorageService.clearUserData(for: userID)
    }
    
    func syncFromRemote(for userID: UUID) async {
        guard NetworkMonitorService.shared.isOnline else { 
            // If offline, just show pending status if there are pending operations
            if pendingOperationsManager.hasOperations {
                syncStatus = .pending
            } else {
                syncStatus = .synced
            }
            return 
        }
        
        syncStatus = .syncing
        
        // Get current remote data BEFORE syncing pending operations
        let originalRemoteCategories = await syncCoordinator.fetchRemoteCategories(for: userID) ?? []
        let localCategories = localStorageService.loadCategories(for: userID)
        
        #if DEBUG
        print("🔄 SyncService: Starting sync - Remote: \(originalRemoteCategories.count), Local: \(localCategories.count), Pending: \(pendingOperationsManager.operations.count)")
        #endif
        
        // First, sync pending operations to remote (with conflict resolution)
        await syncPendingOperationsToRemote(for: userID)
        
        // Get updated remote data after syncing pending operations
        let updatedRemoteCategories = await syncCoordinator.fetchRemoteCategories(for: userID) ?? []
        
        
        // Merge with local data, using lastEdited as source of truth
        var mergedCategories: [Category] = []
        var localCategoriesToUpdate: [Category] = []
        
        // Process remote categories
        for remoteCategory in updatedRemoteCategories {
            if let localCategory = localCategories.first(where: { $0.id == remoteCategory.id }) {
                // Use ConflictResolver to determine which version to keep
                let resolvedCategory = conflictResolver.resolveConflict(local: localCategory, remote: remoteCategory)
                mergedCategories.append(resolvedCategory)
                
                // If we kept the local version, we need to sync it to remote
                let isLocalVersion = (resolvedCategory.id == localCategory.id) && (resolvedCategory.lastEdited == localCategory.lastEdited)
                if isLocalVersion {
                    localCategoriesToUpdate.append(localCategory)
                }
            } else {
                // New remote category - add it
                mergedCategories.append(remoteCategory)
            }
        }
        
        // Handle local categories that don't exist remotely
        for localCategory in localCategories {
            if !updatedRemoteCategories.contains(where: { $0.id == localCategory.id }) {
                if conflictResolver.shouldKeepLocalCategory(localCategory, pendingOperations: pendingOperationsManager.operations) {
                    mergedCategories.append(localCategory)
                    localCategoriesToUpdate.append(localCategory)
                }
            }
        }
        
        // Save merged categories
        localStorageService.saveCategories(mergedCategories, for: userID)
        
        // Immediately update UI with latest merged data
        await MainActor.run {
            // Notify CategoryService to refresh its data
            NotificationCenter.default.post(name: .syncDataUpdated, object: mergedCategories)
        }
        
        #if DEBUG
        print("🔄 SyncService: Saved \(mergedCategories.count) merged categories to local storage")
        #endif
        
        // Sync local changes that are newer to remote
        var hasFailedOperations = false
        for category in localCategoriesToUpdate {
            let success: Bool
            
            if updatedRemoteCategories.contains(where: { $0.id == category.id }) {
                // Update existing remote category
                success = await syncCoordinator.syncUpdateCategory(category, for: userID) != nil
            } else {
                // Create new remote category
                success = await syncCoordinator.syncCreateCategory(category, for: userID) != nil
            }
            
            if !success {
                // Add back to pending operations for retry
                if updatedRemoteCategories.contains(where: { $0.id == category.id }) {
                    pendingOperationsManager.addOperation(.update(category), for: userID)
                } else {
                    pendingOperationsManager.addOperation(.create(category), for: userID)
                }
                hasFailedOperations = true
            }
        }
        
        // Set sync status based on results
        if hasFailedOperations {
            syncStatus = .pending
            #if DEBUG
            print("🔄 SyncService: Setting status to .pending due to failed operations")
            #endif
        } else if pendingOperationsManager.hasOperations {
            syncStatus = .pending
            #if DEBUG
            print("🔄 SyncService: Setting status to .pending due to remaining pending operations: \(pendingOperationsManager.operations.count)")
            for (index, op) in pendingOperationsManager.operations.enumerated() {
                switch op {
                case .create(let category):
                    print("  \(index + 1). CREATE: \(category.name) (ID: \(category.id.uuidString.prefix(8)))")
                case .update(let category):
                    print("  \(index + 1). UPDATE: \(category.name) (ID: \(category.id.uuidString.prefix(8)))")
                }
            }
            #endif
        } else {
            syncStatus = .synced
            #if DEBUG
            print("✅ SyncService: Setting status to .synced - no failed operations, no pending operations")
            #endif
        }
        
        #if DEBUG
        print("✅ SyncService: Final sync status: \(syncStatus)")
        #endif
    }
    
    func addPendingOperation(_ operation: PendingOperation, for userID: UUID) {
        pendingOperationsManager.addOperation(operation, for: userID)
    }
    
    /// Clear all pending operations (for debugging)
    func clearPendingOperations(for userID: UUID) {
        pendingOperationsManager.clearOperations(for: userID)
        updateSyncStatus()
        
        #if DEBUG
        print("🧹 SyncService: Cleared all pending operations")
        #endif
    }
    
    /// Manually update sync status based on current state
    func updateSyncStatus() {
        let wasOnline = NetworkMonitorService.shared.isOnline
        let hadOperations = pendingOperationsManager.hasOperations
        
        if wasOnline {
            if hadOperations {
                syncStatus = .pending
            } else {
                syncStatus = .synced
            }
        } else {
            if hadOperations {
                syncStatus = .pending
            } else {
                syncStatus = .synced
            }
        }
        
        #if DEBUG
        print("🔄 SyncService: Manual status update - Status: \(syncStatus), Online: \(wasOnline), PendingOps: \(hadOperations)")
        if hadOperations {
            print("  Pending operations details:")
            for (index, op) in pendingOperationsManager.operations.enumerated() {
                switch op {
                case .create(let category):
                    print("    \(index + 1). CREATE: \(category.name) (ID: \(category.id.uuidString.prefix(8)))")
                case .update(let category):
                    print("    \(index + 1). UPDATE: \(category.name) (ID: \(category.id.uuidString.prefix(8)))")
                }
            }
        }
        #endif
    }
    
    // MARK: - Sync Status Verification
    
    /// Verifies if the current sync status accurately reflects data synchronization
    /// - Parameter userID: User ID to check sync status for
    /// - Returns: True if sync status is accurate, false otherwise
    func verifySyncStatusAccuracy(for userID: UUID) async -> Bool {
        // If we're offline, local data is source of truth
        guard NetworkMonitorService.shared.isOnline else {
            // Offline: synced means local data is authoritative and no pending operations
            switch syncStatus {
            case .synced:
                return !pendingOperationsManager.hasOperations
            default:
                return true
            }
        }
        
        // Online: If there are pending operations, we're definitely not synced
        if pendingOperationsManager.hasOperations {
            switch syncStatus {
            case .synced:
                return false
            default:
                return true
            }
        }
        
        // Online: If sync status claims we're synced, verify by comparing with remote
        if case .synced = syncStatus {
            let remoteCategories = await syncCoordinator.fetchRemoteCategories(for: userID) ?? []
            let localCategories = localStorageService.loadCategories(for: userID)
            
            // Simple verification: check if counts match and no obvious discrepancies
            // This is a basic check - in a production app you might want more sophisticated verification
            return abs(remoteCategories.count - localCategories.count) <= 1
        }
        
        return true // Other statuses are generally accurate
    }
}
