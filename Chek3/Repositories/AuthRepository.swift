//
//  AuthRepository.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import Foundation
import Supabase

// Wrapper struct to provide consistent interface
struct AuthResponse {
    let session: Session?
    let user: User
}

protocol AuthRepository {
    func signUp(email: String, password: String, metadata: [String: Any]?) async throws -> AuthResponse
    func signIn(email: String, password: String) async throws -> AuthResponse
    func signOut() async throws
    func getCurrentSession() async throws -> Session
    func resendVerification(email: String) async throws
}

class SupabaseAuthRepository: AuthRepository {
    private let supabase = SupabaseClient.shared.client
    
    func signUp(email: String, password: String, metadata: [String: Any]?) async throws -> AuthResponse {
        let response = try await supabase.auth.signUp(
            email: email,
            password: password,
            data: metadata?.compactMapValues { value in
                if let stringValue = value as? String {
                    return .string(stringValue)
                }
                return nil
            }
        )
        return AuthResponse(session: response.session, user: response.user)
    }
    
    func signIn(email: String, password: String) async throws -> AuthResponse {
        let session = try await supabase.auth.signIn(
            email: email,
            password: password
        )
        return AuthResponse(session: session, user: session.user)
    }
    
    func signOut() async throws {
        try await supabase.auth.signOut()
    }
    
    func getCurrentSession() async throws -> Session {
        return try await supabase.auth.session
    }
    
    func resendVerification(email: String) async throws {
        try await supabase.auth.resend(
            email: email,
            type: .signup
        )
    }
}
