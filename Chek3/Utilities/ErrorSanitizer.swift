//
//  ErrorSanitizer.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import Foundation
import Supabase

struct ErrorSanitizer {
    
    // MARK: - Public Methods
    static func sanitizeAuthError(_ error: Error) -> String {
        // Log the actual error for debugging (only in debug builds)
        #if DEBUG
        print("🔍 Actual error: \(error.localizedDescription)")
        #endif
        
        // Check if it's a Supabase AuthError
        if let authError = error as? AuthError {
            return sanitizeSupabaseAuthError(authError)
        }
        
        // Check if it's a network error
        if let urlError = error as? URLError {
            return sanitizeNetworkError(urlError)
        }
        
        // Generic fallback
        return getGenericErrorMessage()
    }
    
    // MARK: - Private Methods
    private static func sanitizeSupabaseAuthError(_ error: AuthError) -> String {
        // Handle common Supabase AuthError cases based on error messages
        let errorMessage = error.localizedDescription.lowercased()
        
        if errorMessage.contains("invalid login credentials") || errorMessage.contains("invalid credentials") {
            return "Invalid email or password. Please check your credentials and try again."
        }
        
        if errorMessage.contains("email not confirmed") || errorMessage.contains("confirm your email") {
            return "Please check your email and confirm your account before signing in."
        }
        
        if errorMessage.contains("user not found") || errorMessage.contains("no user found") {
            return "No account found with this email address. Please sign up first."
        }
        
        if errorMessage.contains("weak password") || errorMessage.contains("password is too weak") {
            return "Password doesn't meet requirements. Please choose a different password."
        }
        
        if errorMessage.contains("user already registered") || errorMessage.contains("email already registered") {
            return "An account with this email already exists. Please sign in instead."
        }
        
        if errorMessage.contains("invalid email") || errorMessage.contains("email format") {
            return "Please enter a valid email address."
        }
        
        if errorMessage.contains("password too short") {
            return "Password must be at least 6 characters long."
        }
        
        if errorMessage.contains("too many requests") || errorMessage.contains("rate limit") {
            return "Too many attempts. Please wait a moment before trying again."
        }
        
        if errorMessage.contains("network") || errorMessage.contains("connection") {
            return "Network error. Please check your internet connection and try again."
        }
        
        if errorMessage.contains("server") || errorMessage.contains("internal error") {
            return "Server error. Please try again later."
        }
        
        return getGenericErrorMessage()
    }
    
    private static func sanitizeNetworkError(_ error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return "No internet connection. Please check your network and try again."
        case .timedOut:
            return "Request timed out. Please try again."
        case .cannotFindHost, .cannotConnectToHost:
            return "Unable to connect to server. Please try again later."
        case .serverCertificateUntrusted, .secureConnectionFailed:
            return "Security error. Please try again later."
        default:
            return getGenericErrorMessage()
        }
    }
    
    private static func getGenericErrorMessage() -> String {
        return "Something went wrong. Please try again."
    }
    
    // MARK: - Logging (Debug Only)
    static func logError(_ error: Error, context: String) {
        #if DEBUG
        print("🚨 Error in \(context): \(error)")
        if let authError = error as? AuthError {
            print("🚨 AuthError details: \(authError)")
        }
        #endif
    }
}
