//
//  CategoryViewModel.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import Foundation
import Combine

@MainActor
class CategoryViewModel: ObservableObject {
    @Published var categories: [Category] = []
    @Published var syncStatus: SyncStatus = .synced
    @Published var isOnline: Bool = true
    
    private let categoryService: CategoryService
    private var cancellables = Set<AnyCancellable>()
    
    init(categoryService: CategoryService? = nil) {
        self.categoryService = categoryService ?? CategoryService.shared
        setupBindings()
    }
    
    private func setupBindings() {
        // Bind to CategoryService published properties
        categoryService.$categories
            .assign(to: &$categories)
        
        categoryService.$syncStatus
            .assign(to: &$syncStatus)
        
        categoryService.$isOnline
            .assign(to: &$isOnline)
    }
    
    // MARK: - Category Operations
    
    /// Creates a new category
    /// - Parameter category: Category to create
    func createCategory(_ category: Category) {
        categoryService.createCategory(category)
    }
    
    /// Updates an existing category
    /// - Parameter category: Category to update
    func updateCategory(_ category: Category) {
        categoryService.updateCategory(category)
    }
    
    
    // MARK: - Sync Operations
    
    /// Triggers sync from remote server
    func syncFromRemote() {
        categoryService.syncFromRemote()
    }
    
    /// Loads user data when user signs in
    func loadUserData() {
        categoryService.loadUserData()
    }
    
    /// Clears all user data when user signs out
    func clearUserData() {
        categoryService.clearUserData()
    }
    
    /// Forces sync when app becomes active
    func syncOnAppActive() {
        categoryService.syncOnAppActive()
    }
    
    /// Manually update sync status
    func updateSyncStatus() {
        categoryService.updateSyncStatus()
    }
    
    /// Clear all pending operations (for debugging)
    func clearPendingOperations() {
        categoryService.clearPendingOperations()
    }
}
