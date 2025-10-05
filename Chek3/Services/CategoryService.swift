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
        categories.append(category)
        saveLocalCategories()
        
        let userID = getCurrentUserID()
        Task {
            await syncService.syncCreateCategory(category, for: userID)
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
            
            let userID = getCurrentUserID()
            Task {
                await syncService.syncUpdateCategory(category, for: userID)
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
        
        let userID = getCurrentUserID()
        Task {
            await syncService.syncDeleteCategory(id: id, for: userID)
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
        
        // Sync from remote if online (syncService.loadUserData handles initial sync status)
        if isOnline {
            syncFromRemote()
        }
    }
    
    /// Delete a category with confirmation
    func deleteCategory(_ category: Category) {
        // Remove from local array immediately
        categories.removeAll { $0.id == category.id }
        saveLocalCategories()
        
        let userID = getCurrentUserID()
        Task {
            await syncService.syncDeleteCategory(id: category.id, for: userID)
        }
    }
}