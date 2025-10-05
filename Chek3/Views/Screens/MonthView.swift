//
//  MonthView.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import SwiftUI
import Supabase

struct MonthView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var categoryViewModel = CategoryViewModel()
    @State private var showingCategorySheet = false
    @State private var selectedCategory: Category?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // User Display Name
                if let currentUser = authViewModel.currentUser {
                    userDisplayNameView(currentUser)
                }
                
                // Sync Status Indicator
                SyncStatusView(
                    syncStatus: categoryViewModel.syncStatus,
                    isOnline: categoryViewModel.isOnline,
                    onRetryTap: {
                        categoryViewModel.syncFromRemote()
                    }
                )
                
                // Categories List
                if authViewModel.currentUser != nil {
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
                        print("🔧 MonthView: Sheet appeared with category: \(selectedCategory?.name ?? "nil")")
                        #endif
                    }
            }
            .onChange(of: showingCategorySheet) { _, isPresented in
                // Reset selectedCategory when sheet is dismissed
                if !isPresented {
                    #if DEBUG
                    print("🔧 MonthView: Sheet dismissed, resetting selectedCategory")
                    #endif
                    selectedCategory = nil
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
            ForEach(categoryViewModel.categories.filter { !$0.isDeleted }) { category in
                CategoryRowView(category: category) {
                    // Ensure selectedCategory is properly set before showing sheet
                    selectedCategory = category
                    #if DEBUG
                    print("🔧 MonthView: Setting selectedCategory to \(category.name) (ID: \(category.id))")
                    #endif
                    // Add a small delay to ensure state is set before sheet presentation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showingCategorySheet = true
                        #if DEBUG
                        print("🔧 MonthView: Showing sheet with selectedCategory: \(selectedCategory?.name ?? "nil")")
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
        // For now, only allow soft deleting one category at a time for better UX
        if let index = offsets.first {
            let category = categoryViewModel.categories[index]
            
            // Toggle the isDeleted property
            let updatedCategory = Category(
                id: category.id,
                userID: category.userID,
                name: category.name,
                income: category.income,
                color: category.color,
                isDefault: category.isDefault,
                createdDate: category.createdDate,
                lastEdited: Date(),
                syncedAt: category.syncedAt,
                isDeleted: !category.isDeleted,
                deletedAt: !category.isDeleted ? Date() : category.deletedAt
            )
            
            categoryViewModel.updateCategory(updatedCategory)
        }
    }
}

#Preview {
    MonthView()
}
