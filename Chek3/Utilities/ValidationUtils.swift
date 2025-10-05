//
//  ValidationUtils.swift
//  Chek3
//
//  Created by Amaan Mahdi on 04/10/2025.
//

import Foundation

struct ValidationUtils {
    
    // MARK: - Email Validation Cache
    private static var emailValidationCache: [String: Bool] = [:]
    private static let emailValidationQueue = DispatchQueue(label: "email.validation", qos: .userInitiated)
    
    // MARK: - Email Validation
    static func isValidEmail(_ email: String) -> Bool {
        // Check cache first for performance
        if let cachedResult = emailValidationCache[email] {
            return cachedResult
        }
        
        // Quick length check before regex
        guard email.count > AppConstants.Validation.emailMinLength && email.count < AppConstants.Validation.emailMaxLength else {
            emailValidationCache[email] = false
            return false
        }
        
        // Use cached regex for better performance
        let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        let isValid = emailPredicate.evaluate(with: email)
        
        // Cache the result (limit cache size to prevent memory issues)
        emailValidationQueue.async {
            if emailValidationCache.count > AppConstants.Validation.emailCacheLimit {
                // Remove oldest entries by creating new dictionary with recent entries
                let recentEntries = Array(emailValidationCache.suffix(AppConstants.Validation.emailCacheTrimSize))
                emailValidationCache = Dictionary(uniqueKeysWithValues: recentEntries)
            }
            emailValidationCache[email] = isValid
        }
        
        return isValid
    }
    
    static func validateEmail(_ email: String) -> ValidationResult {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedEmail.isEmpty {
            return .failure("Email is required")
        }
        
        if !isValidEmail(trimmedEmail) {
            return .failure("Please enter a valid email address")
        }
        
        if trimmedEmail.count > AppConstants.Validation.emailMaxLength {
            return .failure("Email address is too long")
        }
        
        return .success(trimmedEmail)
    }
    
    // MARK: - Password Validation
    static func validatePassword(_ password: String) -> ValidationResult {
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedPassword.isEmpty {
            return .failure("Password is required")
        }
        
        if trimmedPassword.count < AppConstants.Validation.passwordMinLength {
            return .failure("Password must be at least \(AppConstants.Validation.passwordMinLength) characters long")
        }
        
        if trimmedPassword.count > AppConstants.Validation.passwordMaxLength {
            return .failure("Password is too long")
        }
        
        return .success(trimmedPassword)
    }
    
}

// MARK: - Validation Result
enum ValidationResult {
    case success(String)
    case failure(String)
    
    var isValid: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
    
    var value: String? {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return nil
        }
    }
    
    var errorMessage: String? {
        switch self {
        case .success:
            return nil
        case .failure(let message):
            return message
        }
    }
}
