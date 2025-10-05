//
//  CategoryEditSheet.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import SwiftUI
import Supabase

struct CategoryEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var categoryService = CategoryService.shared
    @StateObject private var authService = AuthService.shared
    
    let category: Category?
    @State private var name: String = ""
    @State private var income: Bool = false
    @State private var color: Color = .blue
    @State private var isDefault: Bool = false
    
    var isEditing: Bool {
        category != nil
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Category Details") {
                    TextField("Category Name", text: $name)
                    
                    Toggle("Income Category", isOn: $income)
                    
                    Toggle("Default Category", isOn: $isDefault)
                }
                
                Section("Color") {
                    ColorPicker("Category Color", selection: $color)
                }
            }
            .navigationTitle(isEditing ? "Edit Category" : "New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveCategory()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            setupInitialValues()
        }
    }
    
    private func setupInitialValues() {
        if let category = category {
            name = category.name
            income = category.income
            color = Color(
                red: category.color.red,
                green: category.color.green,
                blue: category.color.blue
            ).opacity(category.color.alpha)
            isDefault = category.isDefault
        }
    }
    
    private func saveCategory() {
        guard let currentUser = authService.currentUser else { return }
        
        let colorData = ColorData(
            red: color.components.red,
            green: color.components.green,
            blue: color.components.blue,
            alpha: color.components.alpha
        )
        
        if let existingCategory = category {
            // Validate ownership before updating
            guard existingCategory.userID == currentUser.id else {
                // Handle unauthorized access - this should not happen in normal flow
                // but provides defense in depth
                #if DEBUG
                print("⚠️ Security Warning: Attempted to edit category not owned by current user")
                print("⚠️ Category User ID: \(existingCategory.userID)")
                print("⚠️ Current User ID: \(currentUser.id)")
                #endif
                
                // Log security incident and dismiss
                ErrorSanitizer.logError(
                    NSError(domain: "SecurityError", code: 403, userInfo: [
                        NSLocalizedDescriptionKey: "Unauthorized category access attempt",
                        "category_id": existingCategory.id,
                        "category_user_id": existingCategory.userID,
                        "current_user_id": currentUser.id
                    ]),
                    context: "CategoryEditSheet.saveCategory"
                )
                
                dismiss()
                return
            }
            
            // Update existing category
            let updatedCategory = Category(
                id: existingCategory.id,
                userID: existingCategory.userID,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                income: income,
                color: colorData,
                isDefault: isDefault,
                createdDate: existingCategory.createdDate,
                lastEdited: Date(),
                syncedAt: existingCategory.syncedAt
            )
            categoryService.updateCategory(updatedCategory)
        } else {
            // Create new category
            let newCategory = Category(
                userID: currentUser.id,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                income: income,
                color: colorData,
                isDefault: isDefault
            )
            categoryService.createCategory(newCategory)
        }
        
        dismiss()
    }
}

// Extension to get color components
extension Color {
    var components: (red: Double, green: Double, blue: Double, alpha: Double) {
        #if canImport(UIKit)
        typealias NativeColor = UIColor
        #elseif canImport(AppKit)
        typealias NativeColor = NSColor
        #endif
        
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        #if canImport(UIKit)
        NativeColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        #elseif canImport(AppKit)
        NativeColor(self).usingColorSpace(.sRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a) ?? (0, 0, 0, 0)
        #endif
        
        return (Double(r), Double(g), Double(b), Double(a))
    }
}

#Preview {
    CategoryEditSheet(category: nil)
}
