//
//  DefaultCategoryService.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import Foundation

/// Protocol defining the contract for setting up default categories for new users
protocol DefaultCategorySetupProtocol {
    /// Creates the default categories for a new user
    /// - Parameter userID: The ID of the user to create default categories for
    func setupDefaultCategories(for userID: UUID) async throws
}

/// Service responsible for creating default categories for new users
class DefaultCategoryService: DefaultCategorySetupProtocol {
    static let shared = DefaultCategoryService()
    
    private let categoryService: CategoryService
    private let categoryRepository: CategoryRepository
    
    private init() {
        self.categoryService = CategoryService.shared
        self.categoryRepository = SupabaseCategoryRepository()
    }
    
    /// Creates the default categories for a new user
    /// - Parameter userID: The ID of the user to create default categories for
    func setupDefaultCategories(for userID: UUID) async throws {
        let defaultCategories = createDefaultCategories(for: userID)
        
        // Create categories locally first
        for category in defaultCategories {
            categoryService.createCategory(category)
        }
        
        // Sync to remote if online
        if NetworkMonitorService.shared.isOnline {
            do {
                for category in defaultCategories {
                    _ = try await categoryRepository.createCategory(category)
                }
                
                #if DEBUG
                print("✅ DefaultCategoryService: Successfully created \(defaultCategories.count) default categories for user \(userID)")
                #endif
            } catch {
                #if DEBUG
                print("⚠️ DefaultCategoryService: Failed to sync default categories to remote: \(error)")
                #endif
                // Don't throw error here - categories are created locally and will sync later
            }
        }
    }
    
    /// Creates the predefined default categories for a user
    /// - Parameter userID: The ID of the user
    /// - Returns: Array of default categories
    private func createDefaultCategories(for userID: UUID) -> [Category] {
        let currentDate = Date()
        
        return [
            // Income category
            Category(
                id: UUID(),
                userID: userID,
                name: "Other",
                income: true,
                color: ColorData(red: 0.2, green: 0.8, blue: 0.2, alpha: 1.0), // Green for income
                isDefault: true,
                createdDate: currentDate,
                lastEdited: currentDate
            ),
            
            // Expense categories
            Category(
                id: UUID(),
                userID: userID,
                name: "Backlog",
                income: false,
                color: ColorData(red: 0.8, green: 0.4, blue: 0.2, alpha: 1.0), // Orange
                isDefault: true,
                createdDate: currentDate,
                lastEdited: currentDate
            ),
            
            Category(
                id: UUID(),
                userID: userID,
                name: "Fixed",
                income: false,
                color: ColorData(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0), // Blue
                isDefault: true,
                createdDate: currentDate,
                lastEdited: currentDate
            ),
            
            Category(
                id: UUID(),
                userID: userID,
                name: "One-off",
                income: false,
                color: ColorData(red: 0.6, green: 0.2, blue: 0.8, alpha: 1.0), // Purple
                isDefault: true,
                createdDate: currentDate,
                lastEdited: currentDate
            )
        ]
    }
    
    /// Validates if a category name is a default category name
    /// - Parameter name: The category name to check
    /// - Returns: True if the name matches a default category
    static func isDefaultCategoryName(_ name: String) -> Bool {
        let defaultNames = ["Other", "Backlog", "Fixed", "One-off"]
        return defaultNames.contains(name)
    }
    
    /// Gets the list of default category names
    /// - Returns: Array of default category names
    static func getDefaultCategoryNames() -> [String] {
        return ["Other", "Backlog", "Fixed", "One-off"]
    }
}
