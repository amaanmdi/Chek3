//
//  AuthViewModel.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import Foundation
import Combine
import Supabase

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isEmailVerified = false
    
    private let authService: AuthService
    private var cancellables = Set<AnyCancellable>()
    
    init(authService: AuthService? = nil) {
        self.authService = authService ?? AuthService.shared
        setupBindings()
    }
    
    private func setupBindings() {
        // Bind to AuthService published properties
        authService.$isAuthenticated
            .assign(to: &$isAuthenticated)
        
        authService.$currentUser
            .assign(to: &$currentUser)
        
        authService.$isLoading
            .assign(to: &$isLoading)
        
        authService.$errorMessage
            .assign(to: &$errorMessage)
        
        authService.$isEmailVerified
            .assign(to: &$isEmailVerified)
    }
    
    // MARK: - Authentication Operations
    
    /// Signs up a new user
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    ///   - firstName: User's first name
    ///   - lastName: User's last name
    func signUp(email: String, password: String, firstName: String, lastName: String) async {
        await authService.signUp(email: email, password: password, firstName: firstName, lastName: lastName)
    }
    
    /// Signs in an existing user
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    func signIn(email: String, password: String) async {
        await authService.signIn(email: email, password: password)
    }
    
    /// Signs out the current user
    func signOut() async {
        await authService.signOut()
    }
    
    /// Resends email verification for the current user
    func resendEmailVerification() async {
        await authService.resendEmailVerification()
    }
    
    /// Checks the current authentication status
    func checkAuthStatus() {
        authService.checkAuthStatus()
    }
}
