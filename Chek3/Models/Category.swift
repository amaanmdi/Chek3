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
enum PendingOperation: Codable {
    case create(Category)
    case update(Category)
    case delete(UUID)
}

// Sync status
enum SyncStatus {
    case synced
    case syncing
    case pending
    case error(String)
}
