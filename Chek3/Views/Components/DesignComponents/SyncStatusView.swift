//
//  SyncStatusView.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import SwiftUI

struct SyncStatusView: View {
    let syncStatus: SyncStatus
    let isOnline: Bool
    
    var body: some View {
        HStack {
            switch syncStatus {
            case .synced:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Synced")
                    .font(.caption)
                    .foregroundColor(.green)
            case .syncing:
                ProgressView()
                    .scaleEffect(AppConstants.UI.progressViewScale)
                Text("Syncing...")
                    .font(.caption)
                    .foregroundColor(.blue)
            case .pending:
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
                Text("Pending")
                    .font(.caption)
                    .foregroundColor(.orange)
            case .error(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Error: \(message)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            Spacer()
            
            if !isOnline {
                Image(systemName: "wifi.slash")
                    .foregroundColor(.red)
                Text("Offline")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
    }
}

#Preview {
    VStack(spacing: 8) {
        SyncStatusView(syncStatus: .synced, isOnline: true)
        SyncStatusView(syncStatus: .syncing, isOnline: true)
        SyncStatusView(syncStatus: .pending, isOnline: true)
        SyncStatusView(syncStatus: .error("Network error"), isOnline: false)
        SyncStatusView(syncStatus: .synced, isOnline: false)
    }
}
