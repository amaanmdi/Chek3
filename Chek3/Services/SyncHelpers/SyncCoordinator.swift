//
//  SyncCoordinator.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import Foundation

/// Internal helper class for coordinating individual sync operations
class SyncCoordinator {
    
    private let categoryRepository: CategoryRepository
    private let localStorageService: LocalStorageService
    
    init(
        categoryRepository: CategoryRepository = SupabaseCategoryRepository(),
        localStorageService: LocalStorageService = LocalStorageService.shared
    ) {
        self.categoryRepository = categoryRepository
        self.localStorageService = localStorageService
    }
    
    // MARK: - Sync Operations
    
    /// Syncs a category creation to remote
    /// - Parameters:
    ///   - category: Category to create
    ///   - userID: User ID for the operation
    /// - Returns: The synced category if successful, nil if failed
    func syncCreateCategory(_ category: Category, for userID: UUID) async -> Category? {
        do {
            let syncedCategory = try await categoryRepository.createCategory(category)
            
            // Update local storage with synced timestamp
            updateLocalCategoryWithSyncTimestamp(syncedCategory, for: userID)
            
            // Notify that data has been updated
            await MainActor.run {
                NotificationCenter.default.post(name: .syncDataUpdated, object: nil)
            }
            
            return syncedCategory
        } catch {
            #if DEBUG
            print("❌ SyncCoordinator: Failed to create category: \(error.localizedDescription)")
            #endif
            return nil
        }
    }
    
    /// Syncs a category update to remote
    /// - Parameters:
    ///   - category: Category to update
    ///   - userID: User ID for the operation
    /// - Returns: The synced category if successful, nil if failed
    func syncUpdateCategory(_ category: Category, for userID: UUID) async -> Category? {
        do {
            let syncedCategory = try await categoryRepository.updateCategory(category, for: userID)
            
            // Update local storage with synced timestamp
            updateLocalCategoryWithSyncTimestamp(syncedCategory, for: userID)
            
            // Notify that data has been updated
            await MainActor.run {
                NotificationCenter.default.post(name: .syncDataUpdated, object: nil)
            }
            
            return syncedCategory
        } catch {
            #if DEBUG
            print("❌ SyncCoordinator: Failed to update category: \(error.localizedDescription)")
            #endif
            return nil
        }
    }
    
    
    /// Fetches all categories for a user from remote
    /// - Parameter userID: User ID to fetch categories for
    /// - Returns: Array of remote categories, nil if failed
    func fetchRemoteCategories(for userID: UUID) async -> [Category]? {
        do {
            let remoteCategories = try await categoryRepository.fetchCategories(for: userID)
            return remoteCategories
        } catch {
            #if DEBUG
            print("❌ SyncCoordinator: Failed to fetch remote categories: \(error.localizedDescription)")
            #endif
            return nil
        }
    }
    
    // MARK: - Local Storage Helpers
    
    /// Updates a local category with sync timestamp, preserving client timestamp if newer
    /// - Parameters:
    ///   - syncedCategory: Category with sync information
    ///   - userID: User ID for storage
    private func updateLocalCategoryWithSyncTimestamp(_ syncedCategory: Category, for userID: UUID) {
        var localCategories = localStorageService.loadCategories(for: userID)
        if let index = localCategories.firstIndex(where: { $0.id == syncedCategory.id }) {
            // Use server timestamp for consistency (server is source of truth after sync)
            let finalTimestamp = syncedCategory.lastEdited
            
            localCategories[index] = Category(
                id: syncedCategory.id,
                userID: syncedCategory.userID,
                name: syncedCategory.name,
                income: syncedCategory.income,
                color: syncedCategory.color,
                isDefault: syncedCategory.isDefault,
                createdDate: syncedCategory.createdDate,
                lastEdited: finalTimestamp, // Use preserved timestamp
                syncedAt: Date(),
                isDeleted: syncedCategory.isDeleted,
                deletedAt: syncedCategory.deletedAt
            )
            localStorageService.saveCategories(localCategories, for: userID)
        }
    }
}
