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
                let wasOnline = self?.isOnline ?? false
                self?.isOnline = path.status == .satisfied
                
                // Only sync if we just came back online and have pending operations
                if !wasOnline && self?.isOnline == true && !(self?.pendingOperations.isEmpty ?? true) {
                    self?.syncPendingOperations()
                }
                
                // Update sync status based on connectivity
                if self?.isOnline == false && !(self?.pendingOperations.isEmpty ?? true) {
                    self?.syncStatus = .pending
                } else if self?.isOnline == false {
                    self?.syncStatus = .synced
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    // MARK: - Local Storage
    
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
    
    // MARK: - Async Sync Methods for Pending Operations
    
    private func syncCreateCategoryAsync(_ category: Category) async {
        guard AuthService.shared.currentUser != nil else { return }
        
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
        } catch {
            await MainActor.run {
                // Re-queue the operation for retry
                pendingOperations.append(.create(category))
                saveLocalCategories()
            }
        }
    }
    
    private func syncUpdateCategoryAsync(_ category: Category) async {
        guard let currentUser = AuthService.shared.currentUser else { return }
        
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
        } catch {
            await MainActor.run {
                // Re-queue the operation for retry
                pendingOperations.append(.update(category))
                saveLocalCategories()
            }
        }
    }
    
    private func syncDeleteCategoryAsync(id: UUID) async {
        guard let currentUser = AuthService.shared.currentUser else { return }
        
        do {
            try await supabase
                .from("categories")
                .delete()
                .eq("id", value: id)
                .eq("user_id", value: currentUser.id)
                .execute()
            
            // Success - deletion is complete, no need to update local state
            // since the category was already removed locally during offline deletion
        } catch {
            await MainActor.run {
                // Re-queue the operation for retry
                pendingOperations.append(.delete(id))
                saveLocalCategories()
            }
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
        guard isOnline && !pendingOperations.isEmpty else { return }
        
        // Process operations sequentially to avoid race conditions
        Task {
            let operations = pendingOperations
            pendingOperations.removeAll()
            await MainActor.run {
                saveLocalCategories()
            }
            
            for operation in operations {
                switch operation {
                case .create(let category):
                    await syncCreateCategoryAsync(category)
                case .update(let category):
                    await syncUpdateCategoryAsync(category)
                case .delete(let id):
                    await syncDeleteCategoryAsync(id: id)
                }
                
                // Small delay between operations to prevent overwhelming the server
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
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
