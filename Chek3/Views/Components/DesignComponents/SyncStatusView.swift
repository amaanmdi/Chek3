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
    let onRetryTap: (() -> Void)?
    
    init(syncStatus: SyncStatus, isOnline: Bool, onRetryTap: (() -> Void)? = nil) {
        self.syncStatus = syncStatus
        self.isOnline = isOnline
        self.onRetryTap = onRetryTap
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Main status indicator
            HStack(spacing: 4) {
                statusIcon
                statusText
            }
            
            Spacer()
            
            // Network indicator and action buttons
            HStack(spacing: 8) {
                networkIndicator
                actionButton
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(backgroundColor)
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch syncStatus {
        case .synced:
            if isOnline {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        case .syncing:
            ProgressView()
                .scaleEffect(AppConstants.UI.progressViewScale)
        case .pending:
            Image(systemName: "clock.fill")
                .foregroundColor(.orange)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
        }
    }
    
    @ViewBuilder
    private var statusText: some View {
        switch syncStatus {
        case .synced:
            if isOnline {
                Text("Synced")
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                Text("Local Data")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        case .syncing:
            Text("Syncing...")
                .font(.caption)
                .foregroundColor(.blue)
        case .pending:
            Text("Pending Sync")
                .font(.caption)
                .foregroundColor(.orange)
        case .error:
            Text("Sync Failed")
                .font(.caption)
                .foregroundColor(.red)
        }
    }
    
    @ViewBuilder
    private var networkIndicator: some View {
        if isOnline {
            Image(systemName: "wifi")
                .foregroundColor(.green)
                .font(.caption)
        } else {
            Image(systemName: "wifi.slash")
                .foregroundColor(.red)
                .font(.caption)
        }
    }
    
    @ViewBuilder
    private var actionButton: some View {
        switch syncStatus {
        case .error:
            if let onRetryTap = onRetryTap {
                Button("Retry") {
                    onRetryTap()
                }
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(4)
            }
        case .pending:
            if isOnline {
                if let onRetryTap = onRetryTap {
                    Button("Sync") {
                        onRetryTap()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                }
            }
        default:
            EmptyView()
        }
    }
    
    private var backgroundColor: Color {
        switch syncStatus {
        case .synced:
            return isOnline ? Color.green.opacity(0.1) : Color.blue.opacity(0.1)
        case .syncing:
            return Color.blue.opacity(0.1)
        case .pending:
            return Color.orange.opacity(0.1)
        case .error:
            return Color.red.opacity(0.1)
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        SyncStatusView(syncStatus: .synced, isOnline: true)
        SyncStatusView(syncStatus: .syncing, isOnline: true)
        SyncStatusView(syncStatus: .pending, isOnline: true, onRetryTap: {})
        SyncStatusView(syncStatus: .error("Network error"), isOnline: false, onRetryTap: {})
        SyncStatusView(syncStatus: .synced, isOnline: false)
        SyncStatusView(syncStatus: .pending, isOnline: false)
    }
    .padding()
}
