//
//  ConflictResolver.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import Foundation

/// Internal helper class for resolving conflicts between local and remote data
class ConflictResolver {
    
    /// Resolves conflicts between local and remote categories using timestamp comparison
    /// - Parameters:
    ///   - local: Local category data
    ///   - remote: Remote category data
    /// - Returns: The category to use (local if newer, remote if newer, local if equal - client wins ties)
    func resolveConflict(local: Category, remote: Category) -> Category {
        let localTime = local.lastEdited
        let remoteTime = remote.lastEdited
        
        #if DEBUG
        print("🔍 ConflictResolver: Comparing timestamps for category \(remote.id) - Local: \(localTime), Remote: \(remoteTime)")
        #endif
        
        if localTime > remoteTime {
            // Local is newer - keep local (client wins)
            #if DEBUG
            print("🔍 ConflictResolver: Local is newer, keeping local version")
            #endif
            return local
        } else if remoteTime > localTime {
            // Remote is newer - use remote (server wins)
            #if DEBUG
            print("🔍 ConflictResolver: Remote is newer, using remote version")
            #endif
            return remote
        } else {
            // Same timestamp - use remote (server wins ties for consistency)
            #if DEBUG
            print("🔍 ConflictResolver: Same timestamp, using remote version for consistency")
            #endif
            return remote
        }
    }
    
    /// Determines if a local category should be kept based on pending operations
    /// - Parameters:
    ///   - localCategory: Local category to check
    ///   - pendingOperations: Current pending operations
    /// - Returns: True if category should be kept, false if it should be removed
    func shouldKeepLocalCategory(
        _ localCategory: Category,
        pendingOperations: [PendingOperation]
    ) -> Bool {
        // Check if this category is in pending operations (truly new)
        let isInPendingOperations = pendingOperations.contains { operation in
            switch operation {
            case .create(let cat), .update(let cat):
                return cat.id == localCategory.id
            }
        }
        
        if isInPendingOperations {
            // This is a new local category that's pending sync - keep it
            return true
        } else {
            // This category is not in pending operations and doesn't exist remotely
            // This means it was deleted remotely - remove from local
            return false
        }
    }
}
