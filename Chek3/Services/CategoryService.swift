//
//  CategoryService.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import Foundation
import Combine
import Supabase

@MainActor
class CategoryService: ObservableObject {
    static let shared = CategoryService()
    
    @Published var categories: [Category] = []
    @Published var syncStatus: SyncStatus = .synced
    @Published var isOnline: Bool = true
    
    private let localStorageService: LocalStorageService
    private let syncService: SyncService
    private let networkMonitorService: NetworkMonitorService
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.localStorageService = LocalStorageService.shared
        self.syncService = SyncService.shared
        self.networkMonitorService = NetworkMonitorService.shared
        
        setupBindings()
        loadLocalCategories()
    }
    
    // MARK: - Setup and Bindings
    
    private func setupBindings() {
        // Bind network status
        networkMonitorService.$isOnline
            .assign(to: &$isOnline)
        
        // Bind sync status
        syncService.$syncStatus
            .assign(to: &$syncStatus)
        
        // Listen for sync data updates to immediately refresh UI
        NotificationCenter.default.publisher(for: .syncDataUpdated)
            .sink { [weak self] _ in
                self?.loadLocalCategories()
            }
            .store(in: &cancellables)
    }
    
    
    private func getCurrentUserID() -> UUID {
        guard let userID = AuthService.shared.currentUser?.id else {
            return UUID() // Fallback - this should not happen in normal flow
        }
        return userID
    }
    
    // MARK: - Local Storage
    
    private func loadLocalCategories() {
        let userID = getCurrentUserID()
        let oldCount = categories.count
        let newCategories = localStorageService.loadCategories(for: userID)
        
        #if DEBUG
        print("🔄 CategoryService: Loading categories - Old: \(oldCount), New: \(newCategories.count)")
        for category in newCategories {
            print("  - Category \(category.id): \(category.name) (lastEdited: \(category.lastEdited))")
        }
        #endif
        
        categories = newCategories
    }
    
    private func saveLocalCategories() {
        let userID = getCurrentUserID()
        localStorageService.saveCategories(categories, for: userID)
    }
    
    // MARK: - CRUD Operations
    
    func createCategory(_ category: Category) {
        // For system default categories, preserve the isDefault status
        // For user-created categories, ensure they are never marked as default
        let finalCategory: Category
        if category.isSystemDefault {
            // System default categories keep their isDefault = true status
            finalCategory = category
        } else {
            // User-created categories are always default = false
            finalCategory = Category(
                id: category.id,
                userID: category.userID,
                name: category.name,
                income: category.income,
                color: category.color,
                isDefault: false, // User-created categories are always default = false
                createdDate: category.createdDate,
                lastEdited: category.lastEdited,
                syncedAt: category.syncedAt,
                isDeleted: category.isDeleted,
                deletedAt: category.deletedAt
            )
        }
        
        categories.append(finalCategory)
        saveLocalCategories()
        
        let userID = getCurrentUserID()
        Task {
            await syncService.syncCreateCategory(finalCategory, for: userID)
            // Update sync status after operation
            await MainActor.run {
                syncService.updateSyncStatus()
            }
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
        
        // Check if this is a system default category and what changes are being made
        if category.isSystemDefault {
            // For system default categories, only allow color changes
            if let existingCategory = categories.first(where: { $0.id == category.id }) {
                let nameChanged = existingCategory.name != category.name
                let typeChanged = existingCategory.income != category.income
                
                if nameChanged || typeChanged {
                    #if DEBUG
                    print("⚠️ Attempted to modify protected properties of system default category: \(category.name)")
                    #endif
                    return
                }
            }
        }
        
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            let existingCategory = categories[index]
            
            // For system default categories, preserve protected properties
            let finalCategory: Category
            if existingCategory.isSystemDefault {
                // Only allow color changes for system default categories
                finalCategory = Category(
                    id: category.id,
                    userID: category.userID,
                    name: existingCategory.name, // Preserve original name
                    income: existingCategory.income, // Preserve original type
                    color: category.color, // Allow color changes
                    isDefault: existingCategory.isDefault, // Preserve original default status
                    createdDate: category.createdDate,
                    lastEdited: Date(),
                    syncedAt: category.syncedAt,
                    isDeleted: existingCategory.isDeleted, // Preserve original deletion status
                    deletedAt: existingCategory.deletedAt // Preserve original deletion timestamp
                )
            } else {
                // For user-created categories, allow all changes except default status
                finalCategory = Category(
                    id: category.id,
                    userID: category.userID,
                    name: category.name,
                    income: category.income,
                    color: category.color,
                    isDefault: false, // User-created categories are always default = false
                    createdDate: category.createdDate,
                    lastEdited: Date(),
                    syncedAt: category.syncedAt,
                    isDeleted: category.isDeleted,
                    deletedAt: category.deletedAt
                )
            }
            
            categories[index] = finalCategory
            saveLocalCategories()
            
            let userID = getCurrentUserID()
            Task {
                await syncService.syncUpdateCategory(finalCategory, for: userID)
                // Update sync status after operation
                await MainActor.run {
                    syncService.updateSyncStatus()
                }
            }
        }
    }
    
    
    // MARK: - Remote Sync
    
    func syncFromRemote() {
        let userID = getCurrentUserID()
        Task {
            await syncService.syncFromRemote(for: userID)
            // Update local categories after sync to ensure UI shows latest data
            await MainActor.run {
                loadLocalCategories()
                // Update sync status to reflect current state
                syncService.updateSyncStatus()
                #if DEBUG
                print("🔄 CategoryService: Refreshed local categories after sync - \(categories.count) categories")
                #endif
            }
        }
    }
    
    /// Force sync when app becomes active to catch any remote changes
    func syncOnAppActive() {
        guard isOnline else { return }
        
        #if DEBUG
        print("🔄 CategoryService: App became active, checking for remote changes")
        #endif
        
        syncFromRemote()
        // Note: syncFromRemote() already calls updateSyncStatus() internally
    }
    
    /// Manually update sync status
    func updateSyncStatus() {
        syncService.updateSyncStatus()
    }
    
    /// Clear all pending operations (for debugging)
    func clearPendingOperations() {
        guard let currentUser = AuthService.shared.currentUser else { return }
        syncService.clearPendingOperations(for: currentUser.id)
    }
    
    // MARK: - User Data Management
    
    /// Clear all user data when user logs out
    func clearUserData() {
        categories.removeAll()
        
        let userID = getCurrentUserID()
        syncService.clearUserData(for: userID)
    }
    
    /// Load user data when user signs in
    func loadUserData() {
        let userID = getCurrentUserID()
        syncService.loadUserData(for: userID)
        loadLocalCategories()
        
        // Update sync status after loading data
        syncService.updateSyncStatus()
        
        // Sync from remote if online (syncService.loadUserData handles initial sync status)
        if isOnline {
            syncFromRemote()
        }
    }
    
}