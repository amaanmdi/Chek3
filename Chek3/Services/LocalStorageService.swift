//
//  LocalStorageService.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import Foundation

class LocalStorageService {
    static let shared = LocalStorageService()
    
    private init() {}
    
    func getUserSpecificKey(_ baseKey: String, userID: UUID) -> String {
        return "\(baseKey)_\(userID.uuidString)"
    }
    
    func save<T: Codable>(_ data: T, forKey key: String) {
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    func load<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    
    func remove(forKey key: String) {
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    func saveCategories(_ categories: [Category], for userID: UUID) {
        let key = getUserSpecificKey("categories", userID: userID)
        save(categories, forKey: key)
    }
    
    func loadCategories(for userID: UUID) -> [Category] {
        let key = getUserSpecificKey("categories", userID: userID)
        return load([Category].self, forKey: key) ?? []
    }
    
    func savePendingOperations(_ operations: [PendingOperation], for userID: UUID) {
        let key = getUserSpecificKey("pending_operations", userID: userID)
        save(operations, forKey: key)
    }
    
    func loadPendingOperations(for userID: UUID) -> [PendingOperation] {
        let key = getUserSpecificKey("pending_operations", userID: userID)
        return load([PendingOperation].self, forKey: key) ?? []
    }
    
    func clearUserData(for userID: UUID) {
        let categoriesKey = getUserSpecificKey("categories", userID: userID)
        let operationsKey = getUserSpecificKey("pending_operations", userID: userID)
        remove(forKey: categoriesKey)
        remove(forKey: operationsKey)
    }
}
