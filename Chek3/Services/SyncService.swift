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
        // If we just came back online and have pending operations, sync them
        if isOnline && pendingOperationsManager.hasOperations {
            #if DEBUG
            print("🔄 SyncService: Network restored, syncing pending operations")
            #endif
            await syncPendingOperations()
        }
        
        updateSyncStatusForNetworkChange(isOnline: isOnline)
    }
    
    private func updateSyncStatusForNetworkChange(isOnline: Bool) {
        // If we're currently syncing, don't change the status
        if case .syncing = syncStatus {
            return
        }
        
        if isOnline {
            // Just came online
            if pendingOperationsManager.hasOperations {
                syncStatus = .pending
            } else {
                syncStatus = .synced
            }
        } else {
            // Just went offline
            if pendingOperationsManager.hasOperations {
                syncStatus = .pending
            } else {
                syncStatus = .synced
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
            syncStatus = .synced
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
            syncStatus = .synced
        } else {
            syncStatus = .error("Failed to sync category update")
            // Add to pending operations for retry
            pendingOperationsManager.addOperation(.update(category), for: userID)
        }
    }
    
    func syncDeleteCategory(id: UUID, for userID: UUID) async {
        guard NetworkMonitorService.shared.isOnline else {
            // If offline, just queue the operation
            pendingOperationsManager.addOperation(.delete(id, userID: userID), for: userID)
            return
        }
        
        syncStatus = .syncing
        
        if await syncCoordinator.syncDeleteCategory(id: id, for: userID) {
            syncStatus = .synced
        } else {
            syncStatus = .error("Failed to sync category deletion")
            // Add to pending operations for retry
            pendingOperationsManager.addOperation(.delete(id, userID: userID), for: userID)
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
            case .delete(let id, let userID):
                success = await syncDeleteCategoryForPending(id: id, for: userID)
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
    
    private func syncDeleteCategoryForPending(id: UUID, for userID: UUID) async -> Bool {
        guard NetworkMonitorService.shared.isOnline else {
            return false // Will be retried later
        }
        
        return await syncCoordinator.syncDeleteCategory(id: id, for: userID)
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
            case .delete(let id, let userID):
                success = await syncCoordinator.syncDeleteCategory(id: id, for: userID)
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
        
        // Get list of pending deletions to avoid resurrecting deleted categories
        let pendingDeletions = pendingOperationsManager.getPendingDeletionIds()
        
        // Merge with local data, using lastEdited as source of truth
        var mergedCategories: [Category] = []
        var localCategoriesToUpdate: [Category] = []
        
        // Process remote categories
        for remoteCategory in updatedRemoteCategories {
            // Skip categories that are pending deletion
            if pendingDeletions.contains(remoteCategory.id) {
                continue
            }
            
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
                if conflictResolver.shouldKeepLocalCategory(localCategory, pendingOperations: pendingOperationsManager.operations, pendingDeletions: pendingDeletions) {
                    mergedCategories.append(localCategory)
                    localCategoriesToUpdate.append(localCategory)
                }
            }
        }
        
        // Save merged categories
        localStorageService.saveCategories(mergedCategories, for: userID)
        
        #if DEBUG
        print("🔄 SyncService: Saved \(mergedCategories.count) merged categories to local storage")
        #endif
        
        // Sync local changes that are newer to remote
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
            }
        }
        
        syncStatus = .synced
        
        #if DEBUG
        print("✅ SyncService: Sync completed successfully")
        #endif
    }
    
    func addPendingOperation(_ operation: PendingOperation, for userID: UUID) {
        pendingOperationsManager.addOperation(operation, for: userID)
    }
}
