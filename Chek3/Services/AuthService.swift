//
//  AuthService.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import Foundation
import Combine
import Supabase

class AuthService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = AuthService()
    
    // MARK: - Published Properties
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isEmailVerified = false
    
    // MARK: - Private Properties
    private let supabase = SupabaseClient.shared.client
    private var sessionRefreshTimer: Timer?
    
    // MARK: - Initialization
    private init() {
        #if DEBUG
        print("🔐 AuthService: Initializing AuthService")
        #endif
        setupSessionRefresh()
        checkAuthStatus()
    }
    
    // MARK: - Session Management
    private func setupSessionRefresh() {
        // Refresh session every 50 minutes (tokens expire after 1 hour)
        sessionRefreshTimer = Timer.scheduledTimer(withTimeInterval: 3000, repeats: true) { [weak self] _ in
            Task.detached { @MainActor in
                await self?.refreshSessionIfNeeded()
            }
        }
    }
    
    private func refreshSessionIfNeeded() async {
        guard isAuthenticated else { return }
        
        do {
            let _ = try await supabase.auth.session
            // Session is automatically refreshed by Supabase if needed
            #if DEBUG
            print("🔄 AuthService: Session refreshed successfully")
            #endif
        } catch {
            #if DEBUG
            print("❌ AuthService: Session refresh failed - \(error.localizedDescription)")
            #endif
            await signOut()
        }
    }
    
    // MARK: - Authentication Status
    func checkAuthStatus() {
        #if DEBUG
        print("🔍 AuthService: Checking authentication status...")
        #endif
        Task {
            do {
                let session = try await supabase.auth.session
                await MainActor.run {
                    isAuthenticated = true
                    currentUser = session.user
                    isEmailVerified = session.user.emailConfirmedAt != nil
                    
                    // Load user data
                    CategoryService.shared.loadUserData()
                }
                #if DEBUG
                print("✅ AuthService: User is authenticated - User ID: \(session.user.id)")
                #endif
            } catch {
                await MainActor.run {
                    isAuthenticated = false
                    currentUser = nil
                    isEmailVerified = false
                }
                #if DEBUG
                print("❌ AuthService: No valid session found - \(error.localizedDescription)")
                #endif
            }
        }
    }
    
    // MARK: - Sign Up
    func signUp(email: String, password: String, firstName: String = "", lastName: String = "") async {
        #if DEBUG
        print("📝 AuthService: Starting sign up process for email: \(email)")
        #endif
        
        // Validate inputs
        let emailValidation = ValidationUtils.validateEmail(email)
        guard emailValidation.isValid, let validEmail = emailValidation.value else {
            await MainActor.run {
                errorMessage = emailValidation.errorMessage
            }
            return
        }
        
        let passwordValidation = ValidationUtils.validatePassword(password)
        guard passwordValidation.isValid, let validPassword = passwordValidation.value else {
            await MainActor.run {
                errorMessage = passwordValidation.errorMessage
            }
            return
        }
        
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // Combine firstName and lastName to create display name
            let displayName = [firstName.trimmingCharacters(in: .whitespacesAndNewlines), 
                             lastName.trimmingCharacters(in: .whitespacesAndNewlines)]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            
            let response = try await supabase.auth.signUp(
                email: validEmail,
                password: validPassword,
                data: displayName.isEmpty ? nil : ["full_name": .string(displayName)]
            )
            
            #if DEBUG
            if !displayName.isEmpty {
                print("✅ AuthService: Display name set to: \(displayName)")
            }
            #endif
            
            // Check if email confirmation is required
            await MainActor.run {
                if response.user.emailConfirmedAt == nil {
                    errorMessage = "Please check your email and confirm your account before signing in."
                    isEmailVerified = false
                } else {
                    isAuthenticated = true
                    currentUser = response.user
                    isEmailVerified = true
                    
                    // Load user data
                    CategoryService.shared.loadUserData()
                }
                isLoading = false
            }
            
            #if DEBUG
            print("✅ AuthService: Sign up successful - User ID: \(response.user.id.uuidString)")
            #endif
        } catch {
            
            await MainActor.run {
                errorMessage = ErrorSanitizer.sanitizeAuthError(error)
                isLoading = false
            }
            ErrorSanitizer.logError(error, context: "signUp")
        }
        #if DEBUG
        print("🔄 AuthService: Sign up process completed")
        #endif
    }
    
    // MARK: - Sign In
    func signIn(email: String, password: String) async {
        #if DEBUG
        print("🔑 AuthService: Starting sign in process for email: \(email)")
        #endif
        
        // Validate inputs
        let emailValidation = ValidationUtils.validateEmail(email)
        guard emailValidation.isValid, let validEmail = emailValidation.value else {
            await MainActor.run {
                errorMessage = emailValidation.errorMessage
            }
            return
        }
        
        let passwordValidation = ValidationUtils.validatePassword(password)
        guard passwordValidation.isValid, let validPassword = passwordValidation.value else {
            await MainActor.run {
                errorMessage = passwordValidation.errorMessage
            }
            return
        }
        
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let response = try await supabase.auth.signIn(
                email: validEmail,
                password: validPassword
            )
            
            await MainActor.run {
                isAuthenticated = true
                currentUser = response.user
                isEmailVerified = response.user.emailConfirmedAt != nil
                isLoading = false
                
                // Load user data
                CategoryService.shared.loadUserData()
            }
            
            #if DEBUG
            print("✅ AuthService: Sign in successful - User ID: \(response.user.id.uuidString)")
            #endif
        } catch {
            
            await MainActor.run {
                // Check error message for common unverified email patterns
                let errorString = error.localizedDescription.lowercased()
                if errorString.contains("email not confirmed") || 
                   errorString.contains("email not verified") ||
                   errorString.contains("confirm your email") ||
                   errorString.contains("email confirmation") {
                    errorMessage = "Please verify your email before signing in. Check your inbox for a verification link."
                } else if errorString.contains("invalid credentials") || 
                          errorString.contains("invalid login") {
                    // Provide helpful message for invalid credentials that might be due to unverified email
                    errorMessage = "Invalid credentials. If you recently signed up, please check your email and verify your account before signing in."
                } else {
                    errorMessage = ErrorSanitizer.sanitizeAuthError(error)
                }
                isLoading = false
            }
            ErrorSanitizer.logError(error, context: "signIn")
        }
        #if DEBUG
        print("🔄 AuthService: Sign in process completed")
        #endif
    }
    
    // MARK: - Sign Out
    func signOut() async {
        #if DEBUG
        print("🚪 AuthService: Starting sign out process")
        #endif
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            try await supabase.auth.signOut()
            sessionRefreshTimer?.invalidate()
            sessionRefreshTimer = nil
            
            await MainActor.run {
                isAuthenticated = false
                currentUser = nil
                isEmailVerified = false
                isLoading = false
                
                // Clear all user-specific data
                CategoryService.shared.clearUserData()
            }
            
            #if DEBUG
            print("✅ AuthService: Sign out successful")
            #endif
        } catch {
            await MainActor.run {
                errorMessage = ErrorSanitizer.sanitizeAuthError(error)
                isLoading = false
            }
            ErrorSanitizer.logError(error, context: "signOut")
        }
        #if DEBUG
        print("🔄 AuthService: Sign out process completed")
        #endif
    }
    
    // MARK: - Email Verification
    func resendEmailVerification() async {
        guard let currentUser = currentUser,
              let email = currentUser.email else { return }
        
        do {
            try await supabase.auth.resend(
                email: email,
                type: .signup
            )
            await MainActor.run {
                errorMessage = "Verification email sent. Please check your inbox."
            }
        } catch {
            await MainActor.run {
                errorMessage = ErrorSanitizer.sanitizeAuthError(error)
            }
            ErrorSanitizer.logError(error, context: "resendEmailVerification")
        }
    }
    
    // MARK: - Deinitializer
    deinit {
        sessionRefreshTimer?.invalidate()
    }
}
