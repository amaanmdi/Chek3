//
//  FirstView.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import SwiftUI
import Supabase

struct FirstView: View {
    @StateObject private var authService = AuthService.shared
    @StateObject private var categoryService = CategoryService.shared
    @State private var showingCategorySheet = false
    @State private var selectedCategory: Category?
    @State private var showingDeleteConfirmation = false
    @State private var categoryToDelete: Category?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // User Display Name
                if let currentUser = authService.currentUser {
                    userDisplayNameView(currentUser)
                }
                
                // Sync Status Indicator
                SyncStatusView(
                    syncStatus: categoryService.syncStatus,
                    isOnline: categoryService.isOnline
                )
                
                // Categories List
                if authService.currentUser != nil {
                    categoriesListView
                } else {
                    noUserView
                }
            }
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        selectedCategory = nil
                        showingCategorySheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCategorySheet) {
                CategoryEditSheet(category: selectedCategory)
                    .onAppear {
                        #if DEBUG
                        print("🔧 FirstView: Sheet appeared with category: \(selectedCategory?.name ?? "nil")")
                        #endif
                    }
            }
            .onChange(of: showingCategorySheet) { _, isPresented in
                // Reset selectedCategory when sheet is dismissed
                if !isPresented {
                    #if DEBUG
                    print("🔧 FirstView: Sheet dismissed, resetting selectedCategory")
                    #endif
                    selectedCategory = nil
                }
            }
            .confirmationDialog(
                "Delete Category",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let category = categoryToDelete {
                        categoryService.deleteCategory(category)
                    }
                    categoryToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    categoryToDelete = nil
                }
            } message: {
                if let category = categoryToDelete {
                    Text("Are you sure you want to delete '\(category.name)'? This action cannot be undone.")
                }
            }
            .onAppear {
                // Data loading is now handled automatically by CategoryService
                // when user authentication state changes
            }
        }
    }
    
    private func userDisplayNameView(_ user: User) -> some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .foregroundColor(.blue)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.userMetadata["full_name"]?.stringValue ?? user.email ?? "User")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(user.email ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.1))
    }
    
    
    private var categoriesListView: some View {
        List {
            ForEach(categoryService.categories) { category in
                CategoryRowView(category: category) {
                    // Ensure selectedCategory is properly set before showing sheet
                    selectedCategory = category
                    #if DEBUG
                    print("🔧 FirstView: Setting selectedCategory to \(category.name) (ID: \(category.id))")
                    #endif
                    // Add a small delay to ensure state is set before sheet presentation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showingCategorySheet = true
                        #if DEBUG
                        print("🔧 FirstView: Showing sheet with selectedCategory: \(selectedCategory?.name ?? "nil")")
                        #endif
                    }
                }
            }
            .onDelete(perform: deleteCategories)
        }
        .listStyle(PlainListStyle())
    }
    
    private var noUserView: some View {
        VStack {
            Text("No user signed in")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func deleteCategories(offsets: IndexSet) {
        // For now, only allow deleting one category at a time for better UX
        if let index = offsets.first {
            let category = categoryService.categories[index]
            categoryToDelete = category
            showingDeleteConfirmation = true
        }
    }
}

#Preview {
    FirstView()
}
