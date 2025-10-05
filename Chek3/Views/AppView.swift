//
//  AppView.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import SwiftUI

struct AppView: View {
    @StateObject private var viewModel = AppViewModel()
    @StateObject private var authService = AuthService.shared
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                NavigationStack {
                    FirstView()
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Sign Out") {
                                    #if DEBUG
                                    print("🚪 AppView: Sign out button tapped")
                                    #endif
                                    Task {
                                        await authService.signOut()
                                    }
                                }
                            }
                        }
                }
                .onAppear {
                    #if DEBUG
                    print("👀 AppView: Main app view appeared (user authenticated)")
                    #endif
                    viewModel.onAppear()
                }
            } else {
                AuthView()
                    .onAppear {
                        #if DEBUG
                        print("👀 AppView: Auth view appeared (user not authenticated)")
                        #endif
                    }
            }
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            #if DEBUG
            print("🔄 AppView: Authentication state changed to: \(isAuthenticated)")
            if isAuthenticated {
                print("✅ AppView: User authenticated, showing main app")
            } else {
                print("❌ AppView: User not authenticated, showing auth view")
            }
            #endif
        }
    }
}

#Preview {
    AppView()
}
