//
//  AccountValidationService.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import Foundation
import Supabase

/// Protocol defining the contract for validating user account existence
protocol AccountValidationProtocol {
    /// Validates if the current user's account still exists on the server
    /// - Parameter userID: The ID of the user to validate
    /// - Returns: True if the account exists and is valid, false otherwise
    func validateAccountExists(for userID: UUID) async -> Bool
    
    /// Performs cleanup of local data and signs out the user if account is invalid
    /// - Parameter userID: The ID of the user to clean up
    func cleanupInvalidAccount(for userID: UUID) async
}

/// Service responsible for validating user account existence and cleanup
class AccountValidationService: AccountValidationProtocol {
    static let shared = AccountValidationService()
    
    private let authRepository: AuthRepository
    private let authService: AuthService
    private let categoryService: CategoryService
    private let syncService: SyncService
    private let localStorageService: LocalStorageService
    
    private init() {
        self.authRepository = SupabaseAuthRepository()
        self.authService = AuthService.shared
        self.categoryService = CategoryService.shared
        self.syncService = SyncService.shared
        self.localStorageService = LocalStorageService.shared
    }
    
    /// Validates if the current user's account still exists on the server
    /// - Parameter userID: The ID of the user to validate
    /// - Returns: True if the account exists and is valid, false otherwise
    func validateAccountExists(for userID: UUID) async -> Bool {
        guard NetworkMonitorService.shared.isOnline else {
            #if DEBUG
            print("🔍 AccountValidationService: Offline - skipping account validation for user \(userID)")
            #endif
            return true // Assume account is valid when offline
        }
        
        do {
            // Try to validate the user exists by refreshing the session
            // This will fail if the user account has been deleted or is invalid
            let accountExists = try await authRepository.validateUserExists(userID: userID)
            
            #if DEBUG
            print("🔍 AccountValidationService: Account validation for user \(userID) - Exists: \(accountExists)")
            #endif
            
            return accountExists
            
        } catch {
            #if DEBUG
            print("⚠️ AccountValidationService: Failed to validate account for user \(userID): \(error)")
            #endif
            
            // If we can't validate the account (network error, etc.), assume it's valid
            // to avoid signing out users due to temporary network issues
            return true
        }
    }
    
    /// Performs cleanup of local data and signs out the user if account is invalid
    /// - Parameter userID: The ID of the user to clean up
    func cleanupInvalidAccount(for userID: UUID) async {
        #if DEBUG
        print("🧹 AccountValidationService: Starting cleanup for invalid account \(userID)")
        #endif
        
        // Clear all user-specific data
        await MainActor.run {
            // Clear categories
            categoryService.clearUserData()
            
            // Clear sync data
            syncService.clearUserData(for: userID)
            
            // Clear local storage
            localStorageService.clearUserData(for: userID)
        }
        
        // Sign out the user
        await authService.signOut()
        
        #if DEBUG
        print("✅ AccountValidationService: Completed cleanup for invalid account \(userID)")
        #endif
    }
    
    /// Validates the current user's account and performs cleanup if invalid
    /// This is the main method to call on app load
    func validateCurrentUserAccount() async {
        guard let currentUser = authService.currentUser else {
            #if DEBUG
            print("ℹ️ AccountValidationService: No current user to validate")
            #endif
            return
        }
        
        let userID = currentUser.id
        let accountExists = await validateAccountExists(for: userID)
        
        if !accountExists {
            #if DEBUG
            print("🚨 AccountValidationService: Account no longer exists for user \(userID) - performing cleanup")
            #endif
            
            await cleanupInvalidAccount(for: userID)
        } else {
            #if DEBUG
            print("✅ AccountValidationService: Account validation successful for user \(userID)")
            #endif
        }
    }
}
