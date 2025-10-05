//
//  PendingOperationsManager.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import Foundation

/// Internal helper class for managing pending operations queue
class PendingOperationsManager {
    
    private var pendingOperations: [PendingOperation] = []
    private var operationRetryCount: [String: Int] = [:]
    private let maxRetries = 3
    private let localStorageService: LocalStorageService
    
    init(localStorageService: LocalStorageService = LocalStorageService.shared) {
        self.localStorageService = localStorageService
    }
    
    // MARK: - Operations Management
    
    /// Adds a new pending operation to the queue
    /// - Parameters:
    ///   - operation: The operation to add
    ///   - userID: User ID for persistence
    func addOperation(_ operation: PendingOperation, for userID: UUID) {
        pendingOperations.append(operation)
        localStorageService.savePendingOperations(pendingOperations, for: userID)
    }
    
    /// Loads pending operations from storage
    /// - Parameter userID: User ID to load operations for
    /// - Returns: Array of pending operations
    func loadOperations(for userID: UUID) -> [PendingOperation] {
        pendingOperations = localStorageService.loadPendingOperations(for: userID)
        
        #if DEBUG
        print("🔄 PendingOperationsManager: Loaded \(pendingOperations.count) pending operations")
        #endif
        
        return pendingOperations
    }
    
    /// Clears all pending operations
    /// - Parameter userID: User ID to clear operations for
    func clearOperations(for userID: UUID) {
        pendingOperations.removeAll()
        operationRetryCount.removeAll()
        localStorageService.savePendingOperations(pendingOperations, for: userID)
    }
    
    /// Gets all pending operations
    var operations: [PendingOperation] {
        return pendingOperations
    }
    
    /// Checks if there are pending operations
    var hasOperations: Bool {
        return !pendingOperations.isEmpty
    }
    
    // MARK: - Retry Logic
    
    /// Checks if an operation has exceeded max retries
    /// - Parameter operation: Operation to check
    /// - Returns: True if max retries exceeded
    func hasExceededMaxRetries(_ operation: PendingOperation) -> Bool {
        let key = getOperationKey(operation)
        let retries = operationRetryCount[key] ?? 0
        return retries >= maxRetries
    }
    
    /// Increments retry count for an operation
    /// - Parameter operation: Operation to increment retry count for
    func incrementRetryCount(_ operation: PendingOperation) {
        let key = getOperationKey(operation)
        let currentRetries = operationRetryCount[key] ?? 0
        operationRetryCount[key] = currentRetries + 1
    }
    
    /// Removes retry count for successful operation
    /// - Parameter operation: Operation that succeeded
    func removeRetryCount(_ operation: PendingOperation) {
        let key = getOperationKey(operation)
        operationRetryCount.removeValue(forKey: key)
    }
    
    /// Gets current retry count for operation
    /// - Parameter operation: Operation to check
    /// - Returns: Current retry count
    func getRetryCount(_ operation: PendingOperation) -> Int {
        let key = getOperationKey(operation)
        return operationRetryCount[key] ?? 0
    }
    
    // MARK: - Operations Removal
    
    /// Removes successful operations from the queue
    /// - Parameters:
    ///   - successfulOperations: Operations that succeeded
    ///   - userID: User ID for persistence
    func removeSuccessfulOperations(_ successfulOperations: [PendingOperation], for userID: UUID) {
        pendingOperations.removeAll { operation in
            successfulOperations.contains { successOp in
                getOperationKey(operation) == getOperationKey(successOp)
            }
        }
        
        #if DEBUG
        print("🔄 PendingOperationsManager: Removed \(successfulOperations.count) successful operations")
        #endif
        
        localStorageService.savePendingOperations(pendingOperations, for: userID)
    }
    
    
    // MARK: - Helper Methods
    
    /// Generates a unique key for an operation
    /// - Parameter operation: Operation to generate key for
    /// - Returns: Unique string key
    private func getOperationKey(_ operation: PendingOperation) -> String {
        switch operation {
        case .create(let category):
            return "create_\(category.id.uuidString)"
        case .update(let category):
            return "update_\(category.id.uuidString)"
        }
    }
    
    
    /// Gets user ID from an operation
    /// - Parameter operation: Operation to extract user ID from
    /// - Returns: User ID
    func getUserIdFromOperation(_ operation: PendingOperation) -> UUID {
        switch operation {
        case .create(let category):
            return category.userID
        case .update(let category):
            return category.userID
        }
    }
}
