//
//  SessionManager.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import Foundation
import Combine
import Supabase

class SessionManager: ObservableObject {
    static let shared = SessionManager()
    
    @Published var currentSession: Session?
    @Published var isSessionValid = false
    
    private let authRepository: AuthRepository
    private var sessionRefreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.authRepository = SupabaseAuthRepository()
        setupSessionRefresh()
    }
    
    // MARK: - Session Management
    
    private func setupSessionRefresh() {
        // Refresh session every 50 minutes (tokens expire after 1 hour)
        sessionRefreshTimer = Timer.scheduledTimer(withTimeInterval: AppConstants.Auth.sessionRefreshInterval, repeats: true) { [weak self] _ in
            Task.detached { @MainActor in
                await self?.refreshSessionIfNeeded()
            }
        }
    }
    
    private func refreshSessionIfNeeded() async {
        guard isSessionValid else { return }
        
        do {
            let session = try await authRepository.getCurrentSession()
            currentSession = session
            isSessionValid = true
            #if DEBUG
            print("🔄 SessionManager: Session refreshed successfully")
            #endif
        } catch {
            #if DEBUG
            print("❌ SessionManager: Session refresh failed - \(error.localizedDescription)")
            #endif
            await invalidateSession()
        }
    }
    
    func checkSessionStatus() async {
        #if DEBUG
        print("🔍 SessionManager: Checking session status...")
        #endif
        do {
            let session = try await authRepository.getCurrentSession()
            currentSession = session
            isSessionValid = true
            #if DEBUG
            print("✅ SessionManager: Valid session found - User ID: \(session.user.id)")
            #endif
        } catch {
            currentSession = nil
            isSessionValid = false
            #if DEBUG
            print("❌ SessionManager: No valid session found - \(error.localizedDescription)")
            #endif
        }
    }
    
    func invalidateSession() async {
        currentSession = nil
        isSessionValid = false
        sessionRefreshTimer?.invalidate()
        sessionRefreshTimer = nil
        #if DEBUG
        print("🚪 SessionManager: Session invalidated")
        #endif
    }
    
    func setSession(_ session: Session) {
        currentSession = session
        isSessionValid = true
        #if DEBUG
        print("✅ SessionManager: Session set - User ID: \(session.user.id)")
        #endif
    }
    
    deinit {
        sessionRefreshTimer?.invalidate()
        sessionRefreshTimer = nil
        #if DEBUG
        print("🔐 SessionManager: Deinitialized")
        #endif
    }
}
