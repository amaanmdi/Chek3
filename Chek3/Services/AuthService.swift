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
    private let authRepository: AuthRepository
    private let sessionManager: SessionManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    private init() {
        self.authRepository = SupabaseAuthRepository()
        self.sessionManager = SessionManager.shared
        
        setupBindings()
        checkAuthStatus()
    }
    
    // MARK: - Setup and Bindings
    
    private func setupBindings() {
        // Bind session manager state to auth service state
        sessionManager.$isSessionValid
            .assign(to: &$isAuthenticated)
        
        sessionManager.$currentSession
            .map { $0?.user }
            .assign(to: &$currentUser)
        
        sessionManager.$currentSession
            .map { $0?.user.emailConfirmedAt != nil }
            .assign(to: &$isEmailVerified)
    }
    
    // MARK: - Authentication Status
    func checkAuthStatus() {
        Task {
            await sessionManager.checkSessionStatus()
            
            if sessionManager.isSessionValid {
                // Load user data
                CategoryService.shared.loadUserData()
                
                // Check if this is a new user and create default categories
                if let currentUser = sessionManager.currentSession?.user {
                    await checkAndSetupDefaultCategories(for: currentUser.id)
                }
            }
        }
    }
    
    // MARK: - Validation Helpers
    
    private func validateCredentials(email: String, password: String) async -> (email: String, password: String)? {
        // Validate inputs
        let emailValidation = ValidationUtils.validateEmail(email)
        guard emailValidation.isValid, let validEmail = emailValidation.value else {
            await MainActor.run {
                errorMessage = emailValidation.errorMessage
            }
            return nil
        }
        
        let passwordValidation = ValidationUtils.validatePassword(password)
        guard passwordValidation.isValid, let validPassword = passwordValidation.value else {
            await MainActor.run {
                errorMessage = passwordValidation.errorMessage
            }
            return nil
        }
        
        return (validEmail, validPassword)
    }
    
    // MARK: - Sign Up
    func signUp(email: String, password: String, firstName: String = "", lastName: String = "") async {
        
        // Validate inputs
        guard let credentials = await validateCredentials(email: email, password: password) else {
            return
        }
        let validEmail = credentials.email
        let validPassword = credentials.password
        
        
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
            
            let metadata = displayName.isEmpty ? nil : ["full_name": displayName]
            let response = try await authRepository.signUp(
                email: validEmail,
                password: validPassword,
                metadata: metadata
            )
            
            
            // Check if email confirmation is required
            await MainActor.run {
                if response.user.emailConfirmedAt == nil {
                    errorMessage = "Please check your email and confirm your account before signing in."
                    isEmailVerified = false
                } else if let session = response.session {
                    sessionManager.setSession(session)
                    isEmailVerified = true
                    
                    // Load user data
                    CategoryService.shared.loadUserData()
                } else {
                    // This shouldn't happen for confirmed users, but handle gracefully
                    errorMessage = "Account created but unable to establish session. Please try signing in."
                    isEmailVerified = false
                }
                isLoading = false
            }
            
        } catch {
            
            await MainActor.run {
                errorMessage = ErrorSanitizer.sanitizeAuthError(error)
                isLoading = false
            }
            ErrorSanitizer.logError(error, context: "signUp")
        }
    }
    
    // MARK: - Sign In
    func signIn(email: String, password: String) async {
        
        // Validate inputs
        guard let credentials = await validateCredentials(email: email, password: password) else {
            return
        }
        let validEmail = credentials.email
        let validPassword = credentials.password
        
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let response = try await authRepository.signIn(
                email: validEmail,
                password: validPassword
            )
            
            await MainActor.run {
                if let session = response.session {
                    sessionManager.setSession(session)
                    isLoading = false
                    
                    // Load user data
                    CategoryService.shared.loadUserData()
                    
                    // Check if this is a new user and create default categories
                    Task {
                        await checkAndSetupDefaultCategories(for: session.user.id)
                    }
                } else {
                    errorMessage = "Unable to establish session. Please try again."
                    isLoading = false
                }
            }
            
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
                    // Provide helpful message for invalid credentials
                    errorMessage = "Invalid email or password. Please check your credentials and try again."
                } else {
                    errorMessage = ErrorSanitizer.sanitizeAuthError(error)
                }
                isLoading = false
            }
            ErrorSanitizer.logError(error, context: "signIn")
        }
    }
    
    // MARK: - Sign Out
    func signOut() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            try await authRepository.signOut()
            await sessionManager.invalidateSession()
            
            await MainActor.run {
                isLoading = false
                
                // Clear all user-specific data
                CategoryService.shared.clearUserData()
            }
            
        } catch {
            await MainActor.run {
                errorMessage = ErrorSanitizer.sanitizeAuthError(error)
                isLoading = false
            }
            ErrorSanitizer.logError(error, context: "signOut")
        }
    }
    
    // MARK: - Email Verification
    func resendEmailVerification() async {
        guard let currentUser = currentUser,
              let email = currentUser.email else { return }
        
        do {
            try await authRepository.resendVerification(email: email)
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
    
    // MARK: - Default Category Setup
    
    /// Checks if user has any categories and sets up default categories if they don't
    /// - Parameter userID: The ID of the user to check
    private func checkAndSetupDefaultCategories(for userID: UUID) async {
        // Check if user already has categories
        let existingCategories = CategoryService.shared.categories
        
        #if DEBUG
        print("🔍 AuthService: Checking default categories for user \(userID) - Found \(existingCategories.count) existing categories")
        #endif
        
        // If user has no categories, create default ones
        if existingCategories.isEmpty {
            do {
                try await DefaultCategoryService.shared.setupDefaultCategories(for: userID)
                
                #if DEBUG
                print("✅ AuthService: Created default categories for new user \(userID)")
                #endif
            } catch {
                #if DEBUG
                print("⚠️ AuthService: Failed to setup default categories for user \(userID): \(error)")
                #endif
            }
        } else {
            #if DEBUG
            print("ℹ️ AuthService: User \(userID) already has \(existingCategories.count) categories, skipping default setup")
            #endif
        }
    }
}
