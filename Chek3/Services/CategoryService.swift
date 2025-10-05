//
//  CategoryService.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import Foundation
import Combine
import Network
import Supabase

@MainActor
class CategoryService: ObservableObject {
    static let shared = CategoryService()
    
    @Published var categories: [Category] = []
    @Published var syncStatus: SyncStatus = .synced
    @Published var isOnline: Bool = true
    
    private let supabase = SupabaseClient.shared.client
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    private var cancellables = Set<AnyCancellable>()
    private var pendingOperations: [PendingOperation] = []
    
    // Race condition protection and retry tracking
    private var isSyncingPendingOperations = false
    private var operationRetryCount: [String: Int] = [:]
    private let maxRetries = 3
    private let syncLock = NSLock()
    
    private init() {
        setupNetworkMonitoring()
        loadLocalCategories()
        
        // Set initial sync status based on connectivity and pending operations
        if !isOnline && !pendingOperations.isEmpty {
            syncStatus = .pending
        } else if !isOnline {
            syncStatus = .synced
        }
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                let wasOnline = self.isOnline
                self.isOnline = path.status == .satisfied
                
                #if DEBUG
                print("🌐 Network status changed: \(wasOnline ? "Online" : "Offline") → \(self.isOnline ? "Online" : "Offline")")
                #endif
                
                // Update sync status immediately based on new connectivity
                self.updateSyncStatusForNetworkChange(wasOnline: wasOnline)
                
                // Only sync if we just came back online and have pending operations
                if !wasOnline && self.isOnline && !self.pendingOperations.isEmpty {
                    #if DEBUG
                    print("🔄 Network restored, syncing \(self.pendingOperations.count) pending operations")
                    #endif
                    self.syncPendingOperations()
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    private func updateSyncStatusForNetworkChange(wasOnline: Bool) {
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
    
    // MARK: - Local Storage
    
    private func operationKey(_ operation: PendingOperation) -> String {
        switch operation {
        case .create(let category):
            return "create_\(category.id.uuidString)"
        case .update(let category):
            return "update_\(category.id.uuidString)"
        case .delete(let id):
            return "delete_\(id.uuidString)"
        }
    }
    
    private func getUserSpecificKey(_ baseKey: String) -> String {
        guard let userId = AuthService.shared.currentUser?.id else {
            return baseKey
        }
        return "\(baseKey)_\(userId.uuidString)"
    }
    
    private func loadLocalCategories() {
        let categoriesKey = getUserSpecificKey("categories")
        let operationsKey = getUserSpecificKey("pending_operations")
        
        if let data = UserDefaults.standard.data(forKey: categoriesKey),
           let categories = try? JSONDecoder().decode([Category].self, from: data) {
            self.categories = categories
        }
        
        if let data = UserDefaults.standard.data(forKey: operationsKey),
           let operations = try? JSONDecoder().decode([PendingOperation].self, from: data) {
            self.pendingOperations = operations
        }
    }
    
    private func saveLocalCategories() {
        let categoriesKey = getUserSpecificKey("categories")
        let operationsKey = getUserSpecificKey("pending_operations")
        
        if let data = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(data, forKey: categoriesKey)
        }
        
        if let data = try? JSONEncoder().encode(pendingOperations) {
            UserDefaults.standard.set(data, forKey: operationsKey)
        }
    }
    
    // MARK: - CRUD Operations
    
    func createCategory(_ category: Category) {
        categories.append(category)
        saveLocalCategories()
        
        if isOnline {
            syncCreateCategory(category)
        } else {
            pendingOperations.append(.create(category))
            saveLocalCategories()
        }
    }
    
    func updateCategory(_ category: Category) {
        // Validate user ownership
        guard let currentUser = AuthService.shared.currentUser,
              category.userID == currentUser.id else {
            #if DEBUG
            print("⚠️ Security Warning: Attempted to update category not owned by current user")
            #endif
            return
        }
        
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = category
            saveLocalCategories()
            
            if isOnline {
                syncUpdateCategory(category)
            } else {
                // Remove any existing update operation for this category
                pendingOperations.removeAll { operation in
                    if case .update(let existingCategory) = operation {
                        return existingCategory.id == category.id
                    }
                    return false
                }
                pendingOperations.append(.update(category))
                saveLocalCategories()
            }
        }
    }
    
    func deleteCategory(id: UUID) {
        // Validate user ownership before deletion
        guard let currentUser = AuthService.shared.currentUser,
              let categoryToDelete = categories.first(where: { $0.id == id }),
              categoryToDelete.userID == currentUser.id else {
            #if DEBUG
            print("⚠️ Security Warning: Attempted to delete category not owned by current user")
            #endif
            return
        }
        
        categories.removeAll { $0.id == id }
        saveLocalCategories()
        
        if isOnline {
            syncDeleteCategory(id: id)
        } else {
            // Remove any existing operations for this category
            pendingOperations.removeAll { operation in
                switch operation {
                case .create(let category), .update(let category):
                    return category.id == id
                case .delete(let categoryId):
                    return categoryId == id
                }
            }
            pendingOperations.append(.delete(id))
            saveLocalCategories()
        }
    }
    
    // MARK: - Remote Sync
    
    private func syncCreateCategory(_ category: Category) {
        guard isOnline else {
            // If offline, just queue the operation
            pendingOperations.append(.create(category))
            saveLocalCategories()
            return
        }
        
        syncStatus = .syncing
        
        Task {
            do {
                let _: Category = try await supabase
                    .from("categories")
                    .insert(category)
                    .select()
                    .single()
                    .execute()
                    .value
                
                await MainActor.run {
                    // Update local category with synced timestamp
                    if let index = categories.firstIndex(where: { $0.id == category.id }) {
                        categories[index] = Category(
                            id: category.id,
                            userID: category.userID,
                            name: category.name,
                            income: category.income,
                            color: category.color,
                            isDefault: category.isDefault,
                            createdDate: category.createdDate,
                            lastEdited: category.lastEdited,
                            syncedAt: Date()
                        )
                        saveLocalCategories()
                    }
                    
                    syncStatus = .synced
                }
            } catch {
                await MainActor.run {
                    syncStatus = .error(error.localizedDescription)
                    // Add to pending operations for retry
                    pendingOperations.append(.create(category))
                    saveLocalCategories()
                }
            }
        }
    }
    
    private func syncUpdateCategory(_ category: Category) {
        guard let currentUser = AuthService.shared.currentUser else { return }
        guard isOnline else {
            // If offline, just queue the operation
            pendingOperations.append(.update(category))
            saveLocalCategories()
            return
        }
        
        syncStatus = .syncing
        
        Task {
            do {
                let _: Category = try await supabase
                    .from("categories")
                    .update(category)
                    .eq("id", value: category.id)
                    .eq("user_id", value: currentUser.id)
                    .select()
                    .single()
                    .execute()
                    .value
                
                await MainActor.run {
                    // Update local category with synced timestamp
                    if let index = categories.firstIndex(where: { $0.id == category.id }) {
                        categories[index] = Category(
                            id: category.id,
                            userID: category.userID,
                            name: category.name,
                            income: category.income,
                            color: category.color,
                            isDefault: category.isDefault,
                            createdDate: category.createdDate,
                            lastEdited: category.lastEdited,
                            syncedAt: Date()
                        )
                        saveLocalCategories()
                    }
                    
                    syncStatus = .synced
                }
            } catch {
                await MainActor.run {
                    syncStatus = .error(error.localizedDescription)
                    // Add to pending operations for retry
                    pendingOperations.append(.update(category))
                    saveLocalCategories()
                }
            }
        }
    }
    
    private func syncDeleteCategory(id: UUID) {
        guard let currentUser = AuthService.shared.currentUser else { return }
        guard isOnline else {
            // If offline, just queue the operation
            pendingOperations.append(.delete(id))
            saveLocalCategories()
            return
        }
        
        syncStatus = .syncing
        
        Task {
            do {
                try await supabase
                    .from("categories")
                    .delete()
                    .eq("id", value: id)
                    .eq("user_id", value: currentUser.id)
                    .execute()
                
                await MainActor.run {
                    syncStatus = .synced
                }
            } catch {
                await MainActor.run {
                    syncStatus = .error(error.localizedDescription)
                    // Add to pending operations for retry
                    pendingOperations.append(.delete(id))
                    saveLocalCategories()
                }
            }
        }
    }
    
    // MARK: - Pending Operations Sync Methods (Return Success Status)
    
    private func syncCreateCategoryForPending(_ category: Category) async -> Bool {
        guard isOnline else {
            return false // Will be retried later
        }
        
        guard AuthService.shared.currentUser != nil else {
            return false
        }
        
        do {
            let _: Category = try await supabase
                .from("categories")
                .insert(category)
                .select()
                .single()
                .execute()
                .value
            
            await MainActor.run {
                // Update local category with synced timestamp
                if let index = categories.firstIndex(where: { $0.id == category.id }) {
                    categories[index] = Category(
                        id: category.id,
                        userID: category.userID,
                        name: category.name,
                        income: category.income,
                        color: category.color,
                        isDefault: category.isDefault,
                        createdDate: category.createdDate,
                        lastEdited: category.lastEdited,
                        syncedAt: Date()
                    )
                    saveLocalCategories()
                }
            }
            
            return true
        } catch {
            await MainActor.run {
                // Only update status if we're not already syncing
                if case .syncing = syncStatus {
                    // Keep syncing status, error will be handled by retry logic
                } else {
                    syncStatus = .error(error.localizedDescription)
                }
            }
            return false
        }
    }
    
    private func syncUpdateCategoryForPending(_ category: Category) async -> Bool {
        guard isOnline else {
            return false // Will be retried later
        }
        
        guard let currentUser = AuthService.shared.currentUser else {
            return false
        }
        
        do {
            let _: Category = try await supabase
                .from("categories")
                .update(category)
                .eq("id", value: category.id)
                .eq("user_id", value: currentUser.id)
                .select()
                .single()
                .execute()
                .value
            
            await MainActor.run {
                // Update local category with synced timestamp
                if let index = categories.firstIndex(where: { $0.id == category.id }) {
                    categories[index] = Category(
                        id: category.id,
                        userID: category.userID,
                        name: category.name,
                        income: category.income,
                        color: category.color,
                        isDefault: category.isDefault,
                        createdDate: category.createdDate,
                        lastEdited: category.lastEdited,
                        syncedAt: Date()
                    )
                    saveLocalCategories()
                }
            }
            
            return true
        } catch {
            await MainActor.run {
                // Only update status if we're not already syncing
                if case .syncing = syncStatus {
                    // Keep syncing status, error will be handled by retry logic
                } else {
                    syncStatus = .error(error.localizedDescription)
                }
            }
            return false
        }
    }
    
    private func syncDeleteCategoryForPending(id: UUID) async -> Bool {
        guard isOnline else {
            return false // Will be retried later
        }
        
        guard let currentUser = AuthService.shared.currentUser else {
            return false
        }
        
        do {
            try await supabase
                .from("categories")
                .delete()
                .eq("id", value: id)
                .eq("user_id", value: currentUser.id)
                .execute()
            
            return true
        } catch {
            await MainActor.run {
                // Only update status if we're not already syncing
                if case .syncing = syncStatus {
                    // Keep syncing status, error will be handled by retry logic
                } else {
                    syncStatus = .error(error.localizedDescription)
                }
            }
            return false
        }
    }
    
    
    // MARK: - Initial Sync
    
    func syncFromRemote() {
        guard isOnline else { 
            // If offline, just show pending status if there are pending operations
            if !pendingOperations.isEmpty {
                syncStatus = .pending
            } else {
                syncStatus = .synced
            }
            return 
        }
        guard let currentUser = AuthService.shared.currentUser else { return }
        
        syncStatus = .syncing
        
        Task {
            do {
                let remoteCategories: [Category] = try await supabase
                    .from("categories")
                    .select()
                    .eq("user_id", value: currentUser.id)
                    .execute()
                    .value
                
                await MainActor.run {
                    // Get list of pending deletions to avoid resurrecting deleted categories
                    let pendingDeletions = pendingOperations.compactMap { operation in
                        if case .delete(let id) = operation {
                            return id
                        }
                        return nil
                    }
                    
                    // Merge with local data, using lastEdited as source of truth
                    var mergedCategories: [Category] = []
                    
                    for remoteCategory in remoteCategories {
                        // Skip categories that are pending deletion
                        if pendingDeletions.contains(remoteCategory.id) {
                            continue
                        }
                        
                        if let localCategory = categories.first(where: { $0.id == remoteCategory.id }) {
                            // Use the one with the latest lastEdited timestamp
                            if localCategory.lastEdited > remoteCategory.lastEdited {
                                mergedCategories.append(localCategory)
                            } else {
                                mergedCategories.append(remoteCategory)
                            }
                        } else {
                            mergedCategories.append(remoteCategory)
                        }
                    }
                    
                    // Add local-only categories (excluding those pending deletion)
                    for localCategory in categories {
                        if !remoteCategories.contains(where: { $0.id == localCategory.id }) &&
                           !pendingDeletions.contains(localCategory.id) {
                            mergedCategories.append(localCategory)
                        }
                    }
                    
                    categories = mergedCategories
                    saveLocalCategories()
                    syncStatus = .synced
                }
                
            } catch {
                await MainActor.run {
                    syncStatus = .error(error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Pending Operations Sync
    
    private func syncPendingOperations() {
        // Prevent concurrent execution using atomic lock
        syncLock.lock()
        defer { syncLock.unlock() }
        
        guard !isSyncingPendingOperations && isOnline && !pendingOperations.isEmpty else {
            return
        }
        
        isSyncingPendingOperations = true
        syncStatus = .syncing
        
        Task {
            await processPendingOperationsAsync()
            
            await MainActor.run {
                isSyncingPendingOperations = false
            }
        }
    }

    private func processPendingOperationsAsync() async {
        let operations = await MainActor.run { pendingOperations }
        var successfulOperations: [PendingOperation] = []
        
        for operation in operations {
            let key = operationKey(operation)
            let retries = operationRetryCount[key] ?? 0
            
            // Skip if max retries exceeded
            guard retries < maxRetries else {
                print("Max retries exceeded for operation: \(key)")
                successfulOperations.append(operation) // Remove from queue
                _ = await MainActor.run {
                    operationRetryCount.removeValue(forKey: key)
                }
                continue
            }
            
            let success: Bool
            
            switch operation {
            case .create(let category):
                // Use synchronous version that returns success status
                success = await syncCreateCategoryForPending(category)
            case .update(let category):
                // Use synchronous version that returns success status
                success = await syncUpdateCategoryForPending(category)
            case .delete(let id):
                // Use synchronous version that returns success status
                success = await syncDeleteCategoryForPending(id: id)
            }
            
            if success {
                successfulOperations.append(operation)
                _ = await MainActor.run {
                    operationRetryCount.removeValue(forKey: key)
                }
            } else {
                _ = await MainActor.run {
                    operationRetryCount[key] = retries + 1
                }
            }
            
            // Small delay between operations
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        // Remove successful operations
        await MainActor.run {
            pendingOperations.removeAll { operation in
                successfulOperations.contains { successOp in
                    operationKey(operation) == operationKey(successOp)
                }
            }
            saveLocalCategories()
            
            // Update sync status more accurately
            if pendingOperations.isEmpty {
                if isOnline {
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
    }
    
    // MARK: - User Data Management
    
    /// Clear all user data when user logs out
    func clearUserData() {
        categories.removeAll()
        pendingOperations.removeAll()
        syncStatus = .synced
        
        // Clear user-specific storage
        let categoriesKey = getUserSpecificKey("categories")
        let operationsKey = getUserSpecificKey("pending_operations")
        UserDefaults.standard.removeObject(forKey: categoriesKey)
        UserDefaults.standard.removeObject(forKey: operationsKey)
    }
    
    /// Load user data when user signs in
    func loadUserData() {
        loadLocalCategories()
        
        // Set initial sync status based on connectivity and pending operations
        if !isOnline && !pendingOperations.isEmpty {
            syncStatus = .pending
        } else if !isOnline {
            syncStatus = .synced
        } else {
            // Try to sync from remote if online
            syncFromRemote()
        }
    }
    
    /// Delete a category with confirmation
    func deleteCategory(_ category: Category) {
        // Remove from local array immediately
        categories.removeAll { $0.id == category.id }
        
        // Add to pending operations if offline
        if !isOnline {
            pendingOperations.append(.delete(category.id))
            syncStatus = .pending
        } else {
            // Sync immediately if online
            syncDeleteCategory(id: category.id)
        }
        
        saveLocalCategories()
    }
}