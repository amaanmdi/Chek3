//
//  AppView.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import SwiftUI

struct AppView: View {
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                NavigationStack {
                    MonthView()
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Sign Out") {
                                    #if DEBUG
                                    print("🚪 AppView: Sign out button tapped")
                                    #endif
                                    Task {
                                        await authViewModel.signOut()
                                    }
                                }
                            }
                        }
                }
                .onAppear {
                    #if DEBUG
                    print("👀 AppView: Main app view appeared (user authenticated)")
                    #endif
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
        .onChange(of: authViewModel.isAuthenticated) { _, isAuthenticated in
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
