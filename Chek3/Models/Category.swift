//
//  Category.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import Foundation
import Supabase

struct Category: Codable, Identifiable, Equatable {
    let id: UUID
    let userID: UUID
    var name: String
    var income: Bool
    var color: ColorData
    var isDefault: Bool
    let createdDate: Date
    var lastEdited: Date
    var syncedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case name
        case income
        case color
        case isDefault = "is_default"
        case createdDate = "created_date"
        case lastEdited = "last_edited"
        case syncedAt = "synced_at"
    }
    
    init(
        id: UUID = UUID(),
        userID: UUID,
        name: String,
        income: Bool = false,
        color: ColorData = ColorData.default,
        isDefault: Bool = false,
        createdDate: Date = Date(),
        lastEdited: Date = Date(),
        syncedAt: Date? = nil
    ) {
        self.id = id
        self.userID = userID
        self.name = name
        self.income = income
        self.color = color
        self.isDefault = isDefault
        self.createdDate = createdDate
        self.lastEdited = lastEdited
        self.syncedAt = syncedAt
    }
    
    // MARK: - Computed Properties
    
    /// Returns true if this is a system default category that cannot be renamed or deleted
    var isSystemDefault: Bool {
        return isDefault && DefaultCategoryService.isDefaultCategoryName(name)
    }
    
    /// Returns true if this category can be renamed by the user
    var canBeRenamed: Bool {
        return !isSystemDefault
    }
    
    /// Returns true if this category can be deleted by the user
    var canBeDeleted: Bool {
        return !isSystemDefault
    }
    
    /// Returns true if this category's color can be changed by the user
    var canChangeColor: Bool {
        return true // All categories can have their colors changed
    }
    
    /// Returns true if this category's income/expense type can be changed by the user
    var canChangeType: Bool {
        return !isSystemDefault // System default categories keep their predefined types
    }
    
    /// Returns true if the default status can be toggled by the user
    var canToggleDefault: Bool {
        return false // Users can no longer toggle default status
    }
}

// Color data structure for JSONB storage
struct ColorData: Codable, Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
    
    static let `default` = ColorData(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0)
    
    init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

// Pending operation for offline sync
enum PendingOperation: Codable, Equatable {
    case create(Category)
    case update(Category)
    case delete(UUID, userID: UUID)
}


// Sync status
enum SyncStatus {
    case synced
    case syncing
    case pending
    case error(String)
}
