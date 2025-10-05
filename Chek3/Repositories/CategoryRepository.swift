//
//  CategoryRepository.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import Foundation
import Supabase

protocol CategoryRepository {
    func fetchCategories(for userID: UUID) async throws -> [Category]
    func createCategory(_ category: Category) async throws -> Category
    func updateCategory(_ category: Category, for userID: UUID) async throws -> Category
    func deleteCategory(id: UUID, for userID: UUID) async throws
}

class SupabaseCategoryRepository: CategoryRepository {
    private let supabase = SupabaseClient.shared.client
    
    func fetchCategories(for userID: UUID) async throws -> [Category] {
        return try await supabase
            .from("categories")
            .select()
            .eq("user_id", value: userID)
            .execute()
            .value
    }
    
    func createCategory(_ category: Category) async throws -> Category {
        return try await supabase
            .from("categories")
            .insert(category)
            .select()
            .single()
            .execute()
            .value
    }
    
    func updateCategory(_ category: Category, for userID: UUID) async throws -> Category {
        return try await supabase
            .from("categories")
            .update(category)
            .eq("id", value: category.id)
            .eq("user_id", value: userID)
            .select()
            .single()
            .execute()
            .value
    }
    
    func deleteCategory(id: UUID, for userID: UUID) async throws {
        try await supabase
            .from("categories")
            .delete()
            .eq("id", value: id)
            .eq("user_id", value: userID)
            .execute()
    }
}
