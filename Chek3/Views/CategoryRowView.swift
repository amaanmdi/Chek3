//
//  CategoryRowView.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import SwiftUI

struct CategoryRowView: View {
    let category: Category
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // Color indicator
                Circle()
                    .fill(Color(
                        red: category.color.red,
                        green: category.color.green,
                        blue: category.color.blue
                    ).opacity(category.color.alpha))
                    .frame(width: 20, height: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        if category.income {
                            Text("Income")
                                .font(.caption)
                                .padding(.horizontal, AppConstants.UI.smallHorizontalPadding)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                        }
                        
                        if category.isDefault {
                            Text("Default")
                                .font(.caption)
                                .padding(.horizontal, AppConstants.UI.smallHorizontalPadding)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                        
                        // Sync status indicator
                        if category.syncedAt == nil {
                            Image(systemName: "clock.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    List {
        CategoryRowView(
            category: Category(
                userID: UUID(),
                name: "Food & Dining",
                income: false,
                color: ColorData(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0),
                isDefault: true
            )
        ) {
            print("Tapped")
        }
        
        CategoryRowView(
            category: Category(
                userID: UUID(),
                name: "Salary",
                income: true,
                color: ColorData(red: 0.0, green: 0.8, blue: 0.0, alpha: 1.0),
                isDefault: false
            )
        ) {
            print("Tapped")
        }
    }
}
